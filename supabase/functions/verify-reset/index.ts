// Disable TypeScript language server checks for Deno remote imports in-editor.
// This file is intended to run on Deno (Supabase Edge Functions) where remote imports are supported.
// @ts-nocheck
import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.14.0/dist/esm/index.js';

// Environment variables required (dashboard disallows names starting with SUPABASE_):
// SUPABASE_URL, SERVICE_ROLE_KEY (or SERVROLE_KEY / SERVICE_ROLE / SUPABASE_SERVICE_ROLE_KEY)

serve(async (req: Request) => {
  try {
    if (req.method !== 'POST') return new Response('Method Not Allowed', { status: 405 });

    const env = Deno.env;
    const SUPABASE_URL = env.get('SUPABASE_URL');
    const SUPABASE_SERVICE_ROLE_KEY = env.get('SERVROLE_KEY') || env.get('SERVICE_ROLE_KEY') || env.get('SERVICE_ROLE') || env.get('SUPABASE_SERVICE_ROLE_KEY');

    if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
      return new Response(JSON.stringify({ error: 'Missing server configuration' }), { status: 500 });
    }

    const body = await req.json().catch(() => ({}));
    const email = (body.email || '').toString().trim();
    const otp = (body.otp || '').toString().trim();
    const newPassword = (body.new_password || '').toString();

    if (!email || !otp || newPassword.length < 6) return new Response(JSON.stringify({ error: 'invalid' }), { status: 400 });

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, { global: { headers: { 'x-edge-runtime': 'deno' } } });

    // Find account by email
    const { data: accounts, error: accErr } = await supabase
      .from('accounts')
      .select('owner_id')
      .eq('email', email)
      .limit(1);

    if (accErr) {
      console.error('DB error finding account:', accErr);
      return new Response(JSON.stringify({ error: 'invalid' }), { status: 400 });
    }

    if (!accounts || accounts.length === 0) {
      // Do not reveal whether email exists
      return new Response(JSON.stringify({ error: 'invalid' }), { status: 400 });
    }

    const ownerId = accounts[0].owner_id;

    // Hash provided OTP
    const enc = new TextEncoder();
    const otpHashBuf = await crypto.subtle.digest('SHA-256', enc.encode(otp));
    const otpHashArray = Array.from(new Uint8Array(otpHashBuf));
    const otpHash = otpHashArray.map(b => b.toString(16).padStart(2,'0')).join('');

    // Find matching, unused, unexpired token for this owner
    const { data: rows, error: fetchErr } = await supabase
      .from('password_resets')
      .select('id, expires_at, used')
      .eq('owner_id', ownerId)
      .eq('token_hash', otpHash)
      .eq('used', false)
      .order('created_at', { ascending: false })
      .limit(1);

    if (fetchErr) {
      console.error('DB error', fetchErr);
      return new Response(JSON.stringify({ error: 'internal' }), { status: 500 });
    }

    if (!rows || rows.length === 0) return new Response(JSON.stringify({ error: 'invalid_or_used' }), { status: 400 });

    const row = rows[0];
    if (new Date(row.expires_at) < new Date()) {
      return new Response(JSON.stringify({ error: 'expired' }), { status: 400 });
    }

    // Update auth user password using admin API
    try {
      const { data, error } = await supabase.auth.admin.updateUserById(ownerId, { password: newPassword });
      if (error) {
        console.error('Failed to update user password', error);
        return new Response(JSON.stringify({ error: 'failed_update' }), { status: 500 });
      }

      // Mark token used
      await supabase.from('password_resets').update({ used: true, used_at: new Date().toISOString() }).eq('id', row.id);

      return new Response(JSON.stringify({ ok: true }), { status: 200 });
    } catch (e) {
      console.error('update error', e);
      return new Response(JSON.stringify({ error: 'internal' }), { status: 500 });
    }
  } catch (e) {
    console.error(e);
    return new Response(JSON.stringify({ error: 'internal' }), { status: 500 });
  }
});
