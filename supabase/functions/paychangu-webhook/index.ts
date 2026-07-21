import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.0';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, signature',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') || '';
const SERVICE_ROLE_KEY = Deno.env.get('SERVICE_ROLE_KEY') || '';
const PAYCHANGU_WEBHOOK_SECRET = Deno.env.get('PAYCHANGU_WEBHOOK_SECRET') || '';

interface PayChanguWebhookPayload {
  event_type: string;
  tx_ref?: string;
  reference?: string;
  amount: number;
  currency: string;
  status: string;
  charge_id?: string;
  meta?: {
    order_id?: string;
    payer_customer_id?: string;
    establishment_id?: string;
    table_id?: string;
    [key: string]: any;
  };
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'Method not allowed' }), {
      status: 405,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  try {
    const rawBody = await req.text();
    const signature = req.headers.get('signature') || req.headers.get('Signature') || '';

    // ── Verify signature (per PayChangu webhook docs) ──
    if (PAYCHANGU_WEBHOOK_SECRET) {
      const encoder = new TextEncoder();
      const key = await crypto.subtle.importKey(
        'raw',
        encoder.encode(PAYCHANGU_WEBHOOK_SECRET),
        { name: 'HMAC', hash: 'SHA-256' },
        false,
        ['sign'],
      );
      const sigBuffer = await crypto.subtle.sign('HMAC', key, encoder.encode(rawBody));
      const computedSignature = Array.from(new Uint8Array(sigBuffer))
        .map((b) => b.toString(16).padStart(2, '0'))
        .join('');

      if (computedSignature !== signature) {
        console.error('Invalid webhook signature');
        return new Response(JSON.stringify({ error: 'Invalid signature' }), {
          status: 401,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
      }
    } else {
      console.warn('PAYCHANGU_WEBHOOK_SECRET not set — skipping signature verification (unsafe for production)');
    }

    const payload: PayChanguWebhookPayload = JSON.parse(rawBody);
    const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

    const txRef = payload.tx_ref;
    const orderId = payload.meta?.order_id;
    const userId = payload.meta?.payer_customer_id;

    if (!txRef) {
      return new Response(JSON.stringify({ error: 'Missing tx_ref' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // ── Always re-query PayChangu before trusting the webhook ──
    const PAYCHANGU_SECRET_KEY = Deno.env.get('PAYCHANGU_SECRET_KEY') || '';
    const verifyResp = await fetch(`https://api.paychangu.com/verify-payment/${txRef}`, {
      headers: { Authorization: `Bearer ${PAYCHANGU_SECRET_KEY}`, Accept: 'application/json' },
    });
    const verifyData = await verifyResp.json();
    const confirmedStatus = verifyData?.data?.status ?? payload.status;

    // idempotency_key IS the tx_ref in your schema
    const paymentsQuery = supabase.from('payments').update;

    if (confirmedStatus === 'success') {
      const { error: paymentError } = await supabase
        .from('payments')
        .update({
          status: 'paid',
          provider_payment_id: verifyData?.data?.reference ?? payload.reference,
          webhook_received_at: new Date().toISOString(),
          metadata: {
            paychangu_status: confirmedStatus,
            verified_amount: verifyData?.data?.amount,
            verified_currency: verifyData?.data?.currency,
          },
          updated_at: new Date().toISOString(),
        })
        .eq('idempotency_key', txRef);

      if (paymentError) console.error('Payment update error:', paymentError);

      if (orderId) {
        const { error: orderError } = await supabase
          .from('orders')
          .update({
            payment_status: 'paid',
            status: 'confirmed',
            updated_at: new Date().toISOString(),
          })
          .eq('id', orderId);
        if (orderError) console.error('Order update error:', orderError);
      }

      // Credit DineCoins (1 MWK = 1 coin) via your existing ledger table
      if (userId && payload.amount > 0) {
        const coins = Math.floor(payload.amount);
        await supabase.from('dinecoins_ledger').insert({
          user_id: userId,
          establishment_id: payload.meta?.establishment_id ?? null,
          amount: coins,
          transaction_type: 'credit',
          description: `Earned ${coins} DineCoins from order payment`,
        });
        // Keep users.dine_coins_balance in sync
        const { data: currentBalance } = await supabase
          .from('users')
          .select('dine_coins_balance')
          .eq('id', userId)
          .single();
        await supabase
          .from('users')
          .update({ dine_coins_balance: (currentBalance?.dine_coins_balance ?? 0) + coins })
          .eq('id', userId);
      }
    } else if (confirmedStatus === 'failed') {
      await supabase
        .from('payments')
        .update({ status: 'failed', updated_at: new Date().toISOString() })
        .eq('idempotency_key', txRef);

      if (orderId) {
        await supabase
          .from('orders')
          .update({ payment_status: 'failed', updated_at: new Date().toISOString() })
          .eq('id', orderId);
      }
    }
    // Any other/cancelled status: leave payment as 'pending' — payment_status
    // enum has no 'cancelled' value, so don't try to write one.

    return new Response(JSON.stringify({ success: true }), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  } catch (error) {
    console.error('Webhook processing error:', error);
    return new Response(JSON.stringify({ error: 'Internal server error', details: error.message }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});