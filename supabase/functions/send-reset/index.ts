// @ts-nocheck
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

serve(async (req) => {
    try {
        if (req.method !== "POST") {
            return new Response("Method Not Allowed", { status: 405 });
        }

        const { email } = await req.json();
        if (!email) {
            return new Response(JSON.stringify({ error: "Email required" }), {
                status: 400,
            });
        }

        // ENV VARS
        const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
        const SERVICE_ROLE_KEY =
            Deno.env.get("SERVROLE_KEY") ||
            Deno.env.get("SERVICE_ROLE_KEY") ||
            Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

        const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY");
        const FROM_EMAIL = Deno.env.get("FROM_EMAIL");

        if (!SUPABASE_URL || !SERVICE_ROLE_KEY || !RESEND_API_KEY || !FROM_EMAIL) {
            return new Response(
                JSON.stringify({ error: "Missing server configuration" }),
                { status: 500 }
            );
        }

        const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

        // Find user account
        const { data: account } = await supabase
            .from("accounts")
            .select("owner_id")
            .eq("email", email)
            .single();

        if (!account) {
            // Prevent email enumeration
            return new Response(JSON.stringify({ ok: true }), { status: 200 });
        }

        const owner_id = account.owner_id;

        // Generate 6-digit OTP
        const otp = Math.floor(100000 + Math.random() * 900000).toString();

        // Hash OTP
        const hashBuffer = await crypto.subtle.digest(
            "SHA-256",
            new TextEncoder().encode(otp)
        );
        const hashArray = Array.from(new Uint8Array(hashBuffer));
        const otp_hash = hashArray.map(b => b.toString(16).padStart(2, "0")).join("");

        const expires_at = new Date(Date.now() + 20 * 60 * 1000).toISOString();

        // Store OTP
        await supabase.from("password_resets").insert({
            owner_id,
            token_hash: otp_hash,
            expires_at,
            used: false,
        });

        // Send email via Resend
        await fetch("https://api.resend.com/emails", {
            method: "POST",
            headers: {
                "Authorization": `Bearer ${RESEND_API_KEY}`,
                "Content-Type": "application/json",
            },
            body: JSON.stringify({
                from: FROM_EMAIL,
                to: [email],
                subject: "Your verification code",
                text: `Your verification code is: ${otp}\n\nThis code expires in 20 minutes.`,
            }),
        });

        return new Response(JSON.stringify({ ok: true }), { status: 200 });
    } catch (err) {
        console.error(err);
        return new Response(JSON.stringify({ error: "Internal error" }), {
            status: 500,
        });
    }
});
