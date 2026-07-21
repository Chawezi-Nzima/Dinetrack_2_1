import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.0';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

const PAYCHANGU_SECRET_KEY = Deno.env.get('PAYCHANGU_SECRET_KEY') || '';

Deno.serve(async (req: Request) => {
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
    // Parse body — handle both JSON object and JSON string
    let body: any;
    const contentType = req.headers.get('content-type') || '';
    const rawBody = await req.text();

    try {
      body = JSON.parse(rawBody);
    } catch {
      return new Response(
        JSON.stringify({ error: 'Invalid JSON body', received: rawBody.substring(0, 200) }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Log what we received for debugging
    console.log('Received body:', JSON.stringify(body, null, 2));

    const {
      amount,
      currency = 'MWK',
      email,
      first_name,
      last_name,
      tx_ref,
      callback_url,
      return_url,
      meta,
    } = body;

    // Validate required fields
    const missing: string[] = [];
    if (amount == null) missing.push('amount');
    if (!email) missing.push('email');
    if (!tx_ref) missing.push('tx_ref');

    if (missing.length > 0) {
      return new Response(
        JSON.stringify({
          error: `Missing required fields: ${missing.join(', ')}`,
          received: body
        }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Call PayChangu API
    const response = await fetch('https://api.paychangu.com/payment', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${PAYCHANGU_SECRET_KEY}`,
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: JSON.stringify({
        amount,
        currency,
        email,
        first_name,
        last_name,
        tx_ref,
        callback_url,
        return_url,
        meta,
      }),
    });

    const data = await response.json();

    if (!response.ok) {
      console.error('PayChangu API error:', data);
      return new Response(
        JSON.stringify({ error: 'PayChangu API error', details: data }),
        { status: 502, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    return new Response(
      JSON.stringify({
        success: true,
        checkout_url: data.data?.checkout_url || data.checkout_url,
        tx_ref,
        reference: data.data?.reference,
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );

  } catch (error) {
    console.error('Edge function error:', error);
    return new Response(
      JSON.stringify({ error: 'Internal error', details: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});