import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.0';

// CORS headers
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-paychangu-signature',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

// Environment variables
const SUPABASE_URL = Deno.env.get('SUPABASE_URL') || 'https://boqgamdpxjejneyjnsgz.supabase.co';
const SERVICE_ROLE_KEY = Deno.env.get('SERVICE_ROLE_KEY') || '';
const PAYCHANGU_SECRET_KEY = Deno.env.get('PAYCHANGU_SECRET_KEY') || '';

interface PayChanguWebhookPayload {
  event: string;
  data: {
    reference: string;
    tx_ref: string;
    amount: number;
    currency: string;
    email: string;
    status: string;
    payment_type: string;
    created_at: string;
    customer: {
      email: string;
      name: string;
    };
    meta?: {
      order_id?: string;
      payer_customer_id?: string;   // FIXED: was user_id, now matches client
      establishment_id?: string;
      table_id?: string;
      [key: string]: any;
    };
  };
}

Deno.serve(async (req: Request) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'Method not allowed' }), {
      status: 405,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  try {
    const rawBody = await req.text();
    const signature = req.headers.get('x-paychangu-signature') || '';

    // Verify webhook signature if secret is configured
    if (PAYCHANGU_SECRET_KEY && signature) {
      const encoder = new TextEncoder();
      const key = await crypto.subtle.importKey(
        'raw',
        encoder.encode(PAYCHANGU_SECRET_KEY),
        { name: 'HMAC', hash: 'SHA-256' },
        false,
        ['verify']
      );
      const sigBytes = base64ToBytes(signature);
      const bodyBytes = encoder.encode(rawBody);
      const isValid = await crypto.subtle.verify('HMAC', key, sigBytes, bodyBytes);

      if (!isValid) {
        console.error('Invalid webhook signature');
        return new Response(JSON.stringify({ error: 'Invalid signature' }), {
          status: 401,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
      }
    }

    const payload: PayChanguWebhookPayload = JSON.parse(rawBody);
    console.log('PayChangu webhook received:', payload.event, payload.data.reference);

    const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
    const { event, data } = payload;
    const { reference, tx_ref, amount, currency, status, meta } = data;

    // ═══════════════════════════════════════════════════════════════
    // FIXED: Use payer_customer_id (matches client-side meta key)
    // ═══════════════════════════════════════════════════════════════
    const orderId = meta?.order_id;
    const userId = meta?.payer_customer_id;   // FIXED: was meta?.user_id
    const establishmentId = meta?.establishment_id;
    const tableId = meta?.table_id;

    // Process based on event type
    switch (event) {
      case 'payment.success': {
        await handlePaymentSuccess(supabase, {
          reference,
          txRef: tx_ref,
          amount,
          currency,
          status,
          orderId,
          userId,
          establishmentId,
          tableId,
          customerEmail: data.customer.email,
          customerName: data.customer.name,
          paymentType: data.payment_type,
        });
        break;
      }

      case 'payment.failed': {
        await handlePaymentFailed(supabase, {
          reference,
          txRef: tx_ref,
          orderId,
          userId,
          amount,
          status,
        });
        break;
      }

      case 'payment.cancelled': {
        await handlePaymentCancelled(supabase, {
          reference,
          orderId,
          userId,
        });
        break;
      }

      case 'payment.refunded': {
        await handlePaymentRefunded(supabase, {
          reference,
          orderId,
          userId,
          amount,
        });
        break;
      }

      default: {
        console.log('Unhandled event type:', event);
      }
    }

    return new Response(JSON.stringify({ success: true }), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });

  } catch (error) {
    console.error('Webhook processing error:', error);
    return new Response(
      JSON.stringify({ error: 'Internal server error', details: error.message }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );
  }
});

// ─── Handlers ───────────────────────────────────────────────

async function handlePaymentSuccess(
  supabase: any,
  params: {
    reference: string;
    txRef: string;
    amount: number;
    currency: string;
    status: string;
    orderId?: string;
    userId?: string;
    establishmentId?: string;
    tableId?: string;
    customerEmail: string;
    customerName: string;
    paymentType: string;
  }
) {
  const {
    reference, txRef, amount, currency, status,
    orderId, userId, establishmentId, tableId,
    customerEmail, customerName, paymentType,
  } = params;

  // 1. Update payment record
  const { error: paymentError } = await supabase
    .from('payments')
    .update({
      status: 'success',
      reference: reference,
      paid_at: new Date().toISOString(),
      metadata: {
        paychangu_reference: reference,
        paychangu_status: status,
        customer_email: customerEmail,
        customer_name: customerName,
        payment_type: paymentType,
        processed_at: new Date().toISOString(),
      },
    })
    .eq('tx_ref', txRef);

  if (paymentError) {
    console.error('Payment update error:', paymentError);
  }

  // 2. Create receipt record
  const { data: receipt, error: receiptError } = await supabase
    .from('receipts')
    .insert({
      order_id: orderId,
      payment_reference: reference,
      tx_ref: txRef,
      amount,
      currency: currency || 'MWK',
      payment_method: paymentType,
      status: 'completed',
      customer_email: customerEmail,
      customer_name: customerName,
      metadata: {
        paychangu_reference: reference,
        paychangu_status: status,
        processed_at: new Date().toISOString(),
      },
    })
    .select()
    .single();

  if (receiptError) {
    console.error('Receipt creation error:', receiptError);
  }

  // 3. Update order status to paid
  if (orderId) {
    const { error: orderError } = await supabase
      .from('orders')
      .update({
        payment_status: 'paid',
        payment_reference: reference,
        receipt_id: receipt?.id,
        status: 'confirmed',
        updated_at: new Date().toISOString(),
      })
      .eq('id', orderId);

    if (orderError) {
      console.error('Order update error:', orderError);
    }
  }

  // 4. Credit DineCoins (1 MWK = 1 coin)
  if (userId && amount > 0) {
    const coinsToCredit = Math.floor(amount);
    await creditDineCoins(supabase, userId, coinsToCredit, orderId, reference);
  }

  // 5. Notify customer
  if (userId) {
    await supabase.from('notifications').insert({
      user_id: userId,
      establishment_id: establishmentId,
      title: 'Payment Successful',
      body: `Your payment of ${currency || 'MWK'} ${amount.toLocaleString()} has been received. Order is now being prepared.`,
      type: 'payment',
      priority: 'normal',
      data: {
        order_id: orderId,
        receipt_id: receipt?.id,
        amount,
        reference,
      },
    });
  }

  // 6. Notify kitchen staff
  if (establishmentId && orderId) {
    await supabase.from('notifications').insert({
      role: 'kitchen',
      establishment_id: establishmentId,
      title: 'New Paid Order',
      body: `Order for Table ${tableId || 'N/A'} has been paid. Start preparing!`,
      type: 'order',
      priority: 'urgent',
      data: {
        order_id: orderId,
        table_id: tableId,
        amount,
      },
    });
  }

  // 7. Notify operator
  if (establishmentId && orderId) {
    await supabase.from('notifications').insert({
      role: 'operator',
      establishment_id: establishmentId,
      title: 'Payment Received',
      body: `Payment of ${currency || 'MWK'} ${amount.toLocaleString()} received for order.`,
      type: 'payment',
      priority: 'normal',
      data: {
        order_id: orderId,
        receipt_id: receipt?.id,
        amount,
        reference,
      },
    });
  }

  console.log('Payment success processed:', reference);
}

async function handlePaymentFailed(
  supabase: any,
  params: {
    reference: string;
    txRef: string;
    orderId?: string;
    userId?: string;
    amount: number;
    status: string;
  }
) {
  const { reference, txRef, orderId, userId, amount } = params;

  await supabase.from('payments').update({
    status: 'failed',
    reference: reference,
    metadata: {
      failure_reason: 'Payment declined by PayChangu',
      processed_at: new Date().toISOString(),
    },
  }).eq('tx_ref', txRef);

  if (orderId) {
    await supabase
      .from('orders')
      .update({
        payment_status: 'failed',
        payment_reference: reference,
        updated_at: new Date().toISOString(),
      })
      .eq('id', orderId);
  }

  if (userId) {
    await supabase.from('notifications').insert({
      user_id: userId,
      title: 'Payment Failed',
      body: `Your payment of MWK ${amount.toLocaleString()} could not be processed. Please try again.`,
      type: 'payment',
      priority: 'high',
      data: {
        order_id: orderId,
        reference,
        amount,
      },
    });
  }

  console.log('Payment failure processed:', reference);
}

async function handlePaymentCancelled(
  supabase: any,
  params: {
    reference: string;
    orderId?: string;
    userId?: string;
  }
) {
  const { reference, orderId, userId } = params;

  await supabase.from('payments').update({
    status: 'cancelled',
    updated_at: new Date().toISOString(),
  }).eq('tx_ref', reference);

  if (orderId) {
    await supabase
      .from('orders')
      .update({
        payment_status: 'cancelled',
        status: 'cancelled',
        updated_at: new Date().toISOString(),
      })
      .eq('id', orderId);
  }

  if (userId) {
    await supabase.from('notifications').insert({
      user_id: userId,
      title: 'Payment Cancelled',
      body: 'Your payment was cancelled. You can retry anytime.',
      type: 'payment',
      priority: 'normal',
      data: { order_id: orderId, reference },
    });
  }

  console.log('Payment cancellation processed:', reference);
}

async function handlePaymentRefunded(
  supabase: any,
  params: {
    reference: string;
    orderId?: string;
    userId?: string;
    amount: number;
  }
) {
  const { reference, orderId, userId, amount } = params;

  await supabase.from('payments').update({
    status: 'refunded',
    refunded_at: new Date().toISOString(),
  }).eq('tx_ref', reference);

  await supabase
    .from('receipts')
    .update({
      status: 'refunded',
      refunded_at: new Date().toISOString(),
    })
    .eq('payment_reference', reference);

  if (orderId) {
    await supabase
      .from('orders')
      .update({
        payment_status: 'refunded',
        status: 'cancelled',
        updated_at: new Date().toISOString(),
      })
      .eq('id', orderId);
  }

  if (userId && amount > 0) {
    const coinsToDebit = Math.floor(amount);
    await debitDineCoins(supabase, userId, coinsToDebit, orderId, reference);
  }

  if (userId) {
    await supabase.from('notifications').insert({
      user_id: userId,
      title: 'Payment Refunded',
      body: `A refund of MWK ${amount.toLocaleString()} has been processed.`,
      type: 'payment',
      priority: 'high',
      data: { order_id: orderId, reference, amount },
    });
  }

  console.log('Payment refund processed:', reference);
}

// ─── DineCoins Helpers ──────────────────────────────────────

async function creditDineCoins(
  supabase: any,
  userId: string,
  amount: number,
  orderId?: string,
  reference?: string
) {
  const { data: account } = await supabase
    .from('loyalty_accounts')
    .select('*')
    .eq('user_id', userId)
    .single();

  if (account) {
    const newTotal = account.total_coins + amount;
    const newAvailable = account.available_coins + amount;
    const newLifetime = account.lifetime_earned + amount;
    const newProgress = account.tier_progress + amount;

    const { data: nextTier } = await supabase
      .from('loyalty_tiers')
      .select('*')
      .gt('min_coins', account.lifetime_earned)
      .order('min_coins', { ascending: true })
      .limit(1)
      .single();

    let newTier = account.tier;
    let newThreshold = account.next_tier_threshold;

    if (nextTier && newLifetime >= nextTier.min_coins) {
      newTier = nextTier.name;
      const { data: followingTier } = await supabase
        .from('loyalty_tiers')
        .select('min_coins')
        .gt('min_coins', nextTier.min_coins)
        .order('min_coins', { ascending: true })
        .limit(1)
        .single();
      newThreshold = followingTier?.min_coins || nextTier.min_coins * 2;
    }

    await supabase
      .from('loyalty_accounts')
      .update({
        total_coins: newTotal,
        available_coins: newAvailable,
        lifetime_earned: newLifetime,
        tier: newTier,
        tier_progress: newProgress,
        next_tier_threshold: newThreshold,
        updated_at: new Date().toISOString(),
      })
      .eq('user_id', userId);
  } else {
    await supabase.from('loyalty_accounts').insert({
      user_id: userId,
      total_coins: amount,
      available_coins: amount,
      lifetime_earned: amount,
      tier: 'bronze',
      tier_progress: amount,
      next_tier_threshold: 1000,
    });
  }

  await supabase.from('loyalty_transactions').insert({
    account_id: account?.id,
    type: 'earn',
    amount,
    description: `Earned ${amount} DineCoins from order payment`,
    order_id: orderId,
    expiry_date: new Date(Date.now() + 365 * 24 * 60 * 60 * 1000).toISOString(),
  });

  await supabase.from('notifications').insert({
    user_id: userId,
    title: 'DineCoins Earned!',
    body: `You earned ${amount} DineCoins from your recent order!`,
    type: 'promotion',
    priority: 'normal',
    data: { coins_earned: amount, order_id: orderId, reference },
  });
}

async function debitDineCoins(
  supabase: any,
  userId: string,
  amount: number,
  orderId?: string,
  reference?: string
) {
  const { data: account } = await supabase
    .from('loyalty_accounts')
    .select('*')
    .eq('user_id', userId)
    .single();

  if (!account || account.available_coins < amount) return;

  await supabase
    .from('loyalty_accounts')
    .update({
      total_coins: Math.max(0, account.total_coins - amount),
      available_coins: Math.max(0, account.available_coins - amount),
      lifetime_redeemed: (account.lifetime_redeemed || 0) + amount,
      updated_at: new Date().toISOString(),
    })
    .eq('user_id', userId);

  await supabase.from('loyalty_transactions').insert({
    account_id: account.id,
    type: 'expiry',
    amount: -amount,
    description: `Debited ${amount} DineCoins due to refund`,
    order_id: orderId,
  });
}

// ─── Utilities ──────────────────────────────────────────────

function base64ToBytes(base64: string): Uint8Array {
  const binaryString = atob(base64);
  const bytes = new Uint8Array(binaryString.length);
  for (let i = 0; i < binaryString.length; i++) {
    bytes[i] = binaryString.charCodeAt(i);
  }
  return bytes;
}