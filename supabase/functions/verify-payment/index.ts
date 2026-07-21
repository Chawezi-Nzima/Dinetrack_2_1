import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.0';

// ═════════════════════════════════════════════════════════════════
// PayChangu Verify Payment Edge Function
// Server-side transaction verification — CALL THIS from Flutter
// after client-side success to prevent fraud
// ═════════════════════════════════════════════════════════════════

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') || '';
const SERVICE_ROLE_KEY = Deno.env.get('SERVICE_ROLE_KEY') || '';
const PAYCHANGU_SECRET_KEY = Deno.env.get('PAYCHANGU_SECRET_KEY') || '';

interface VerifyRequest {
  tx_ref: string;
  expected_amount?: number;
  expected_currency?: string;
}

interface PayChanguVerifyResponse {
  status: string;
  message: string;
  data?: {
    reference: string;
    tx_ref: string;
    amount: number;
    currency: string;
    charged_amount: number;
    status: string;
    payment_type: string;
    created_at: string;
    customer: {
      email: string;
      name: string;
    };
    meta?: Record<string, any>;
  };
}

Deno.serve(async (req: Request) => {
  // CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (req.method !== 'POST') {
    return new Response(
      JSON.stringify({ success: false, error: 'Method not allowed. Use POST.' }),
      { status: 405, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }

  try {
    const body: VerifyRequest = await req.json();
    const { tx_ref, expected_amount, expected_currency } = body;

    if (!tx_ref) {
      return new Response(
        JSON.stringify({ success: false, error: 'tx_ref is required' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // ─── 1. Call PayChangu API to verify transaction ─────────
    const verifyUrl = `https://api.paychangu.com/transaction/verify/${tx_ref}`;

    const paychanguResponse = await fetch(verifyUrl, {
      method: 'GET',
      headers: {
        'Authorization': `Bearer ${PAYCHANGU_SECRET_KEY}`,
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    });

    if (!paychanguResponse.ok) {
      const errorText = await paychanguResponse.text();
      console.error('PayChangu API error:', paychanguResponse.status, errorText);
      return new Response(
        JSON.stringify({
          success: false,
          error: 'PayChangu API verification failed',
          details: errorText,
        }),
        { status: 502, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const verifyData: PayChanguVerifyResponse = await paychanguResponse.json();

    // ─── 2. Validate response structure ────────────────────────
    if (!verifyData.data) {
      return new Response(
        JSON.stringify({
          success: false,
          error: 'Invalid PayChangu response',
          paychangu_status: verifyData.status,
          paychangu_message: verifyData.message,
        }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const transaction = verifyData.data;

    // ─── 3. Business rule validation ───────────────────────────
    const validations: string[] = [];

    if (transaction.status !== 'success') {
      validations.push(`Transaction status is '${transaction.status}', expected 'success'`);
    }

    if (expected_amount !== undefined) {
      // Allow small floating point differences (0.01 tolerance)
      const diff = Math.abs(transaction.charged_amount - expected_amount);
      if (diff > 0.01) {
        validations.push(`Amount mismatch: charged ${transaction.charged_amount}, expected ${expected_amount}`);
      }
    }

    if (expected_currency && transaction.currency !== expected_currency) {
      validations.push(`Currency mismatch: ${transaction.currency} !== ${expected_currency}`);
    }

    const isValid = validations.length === 0;

    // ─── 4. Update database with verification result ───────────
    const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

    // Update payment record with verification metadata
    const { error: updateError } = await supabase
      .from('payments')
      .update({
        status: isValid ? 'paid' : 'verification_failed',
        verified_at: new Date().toISOString(),
        verification_result: {
          paychangu_status: transaction.status,
          paychangu_reference: transaction.reference,
          charged_amount: transaction.charged_amount,
          currency: transaction.currency,
          payment_type: transaction.payment_type,
          validations,
          is_valid: isValid,
          verified_at: new Date().toISOString(),
        },
      })
      .eq('tx_ref', tx_ref);

    if (updateError) {
      console.error('Database update error:', updateError);
    }

    // ─── 5. Return result to Flutter app ───────────────────────
    return new Response(
      JSON.stringify({
        success: isValid,
        verified: true,
        transaction: {
          reference: transaction.reference,
          tx_ref: transaction.tx_ref,
          amount: transaction.amount,
          charged_amount: transaction.charged_amount,
          currency: transaction.currency,
          status: transaction.status,
          payment_type: transaction.payment_type,
          created_at: transaction.created_at,
          customer: transaction.customer,
        },
        validations: validations.length > 0 ? validations : undefined,
        message: isValid
          ? 'Payment verified successfully'
          : `Verification failed: ${validations.join(', ')}`,
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );

  } catch (error) {
    console.error('Verify payment error:', error);
    return new Response(
      JSON.stringify({
        success: false,
        error: 'Internal server error',
        details: error.message,
      }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});