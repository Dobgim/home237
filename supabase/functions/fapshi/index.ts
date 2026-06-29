// Fapshi payment proxy for Home237.
//
// Keeps the Fapshi API key server-side and performs server-to-server calls,
// which avoids the TLS "handshake terminated" failures seen when the mobile
// app calls live.fapshi.com directly over a flaky carrier network.
//
// Secrets (set with `supabase secrets set ...`):
//   FAPSHI_API_USER  — Fapshi apiuser
//   FAPSHI_API_KEY   — Fapshi apikey (FAK_...)
//   FAPSHI_MODE      — "live" (default) or "sandbox"
//
// Request body (JSON): { action, ...params }
//   action "direct-pay":     { amount, phone, medium, message?, userId?, externalId? }
//   action "payment-status": { transId }
//   action "payout":         { amount, phone, medium }
//
// Always responds HTTP 200 with a normalized body so the client never has to
// deal with thrown FunctionExceptions for Fapshi-level outcomes:
//   success:  { ok: true, ... }
//   failure:  { ok: false, httpStatus?, message? }

const LIVE_URL = "https://live.fapshi.com";
const SANDBOX_URL = "https://sandbox.fapshi.com";

const API_USER = Deno.env.get("FAPSHI_API_USER") ?? "";
const API_KEY = Deno.env.get("FAPSHI_API_KEY") ?? "";
const MODE = (Deno.env.get("FAPSHI_MODE") ?? "live").toLowerCase();
const BASE_URL = MODE === "sandbox" ? SANDBOX_URL : LIVE_URL;

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, "Content-Type": "application/json" },
  });
}

// Normalise a Cameroonian number to the 9-digit local format Fapshi expects.
function normalizePhone(raw: string): string {
  let p = (raw ?? "").replace(/[\s\-+]/g, "");
  while (p.startsWith("0")) p = p.slice(1);
  if (p.startsWith("237") && p.length > 9) p = p.slice(3);
  return p;
}

const fapshiHeaders = {
  "Content-Type": "application/json",
  "apiuser": API_USER,
  "apikey": API_KEY,
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS });
  }

  if (!API_USER || !API_KEY) {
    return jsonResponse({
      ok: false,
      message: "Fapshi credentials are not configured on the server.",
    });
  }

  let payload: Record<string, unknown>;
  try {
    payload = await req.json();
  } catch (_) {
    return jsonResponse({ ok: false, message: "Invalid JSON body." });
  }

  const action = String(payload.action ?? "");

  try {
    // ── Direct Pay (MoMo / OM push prompt) ──────────────────────────────────
    if (action === "direct-pay") {
      // deno-lint-ignore no-explicit-any
      const { amount, phone, medium, message, userId, externalId } =
        payload as any;
      if (!amount || !phone || !medium) {
        return jsonResponse({
          ok: false,
          message: "Missing amount, phone, or medium.",
        });
      }
      const body: Record<string, unknown> = {
        amount,
        phone: normalizePhone(String(phone)),
        medium,
      };
      if (message) body.message = message;
      if (userId) body.userId = userId;
      if (externalId) body.externalId = externalId;

      const res = await fetch(`${BASE_URL}/direct-pay`, {
        method: "POST",
        headers: fapshiHeaders,
        body: JSON.stringify(body),
      });
      // deno-lint-ignore no-explicit-any
      const data = await res.json().catch(() => ({} as any));

      if (res.status === 200 || res.status === 201) {
        return jsonResponse({ ok: true, transId: data.transId ?? null });
      }
      return jsonResponse({
        ok: false,
        httpStatus: res.status,
        message: data.message ?? "Payment could not be initiated.",
      });
    }

    // ── Payment status ──────────────────────────────────────────────────────
    if (action === "payment-status") {
      // deno-lint-ignore no-explicit-any
      const { transId } = payload as any;
      if (!transId) {
        return jsonResponse({ ok: false, message: "Missing transId." });
      }
      const res = await fetch(`${BASE_URL}/payment-status/${transId}`, {
        method: "GET",
        headers: fapshiHeaders,
      });
      // deno-lint-ignore no-explicit-any
      const raw = await res.json().catch(() => ({} as any));
      if (res.status !== 200) {
        // Forward Fapshi's own error text so the app can show a real reason
        // instead of a generic "payment failed" message.
        const errItem = Array.isArray(raw) ? (raw[0] ?? {}) : raw;
        return jsonResponse({
          ok: false,
          httpStatus: res.status,
          message: errItem.message ?? "",
        });
      }
      const item = Array.isArray(raw) ? (raw[0] ?? {}) : raw;
      return jsonResponse({
        ok: true,
        status: item.status ?? "",
        reason: item.reason ?? "",
        message: item.message ?? "",
      });
    }

    // ── Payout (disbursement) ───────────────────────────────────────────────
    if (action === "payout") {
      // deno-lint-ignore no-explicit-any
      const { amount, phone, medium } = payload as any;
      if (!amount || !phone || !medium) {
        return jsonResponse({
          ok: false,
          message: "Missing amount, phone, or medium.",
        });
      }
      const res = await fetch(`${BASE_URL}/payout`, {
        method: "POST",
        headers: fapshiHeaders,
        body: JSON.stringify({
          amount,
          phone: normalizePhone(String(phone)),
          medium,
        }),
      });
      // deno-lint-ignore no-explicit-any
      const data = await res.json().catch(() => ({} as any));
      if (res.status === 200 || res.status === 201) {
        return jsonResponse({ ok: true });
      }
      return jsonResponse({
        ok: false,
        httpStatus: res.status,
        message: data.message ?? "Payout failed.",
      });
    }

    return jsonResponse({ ok: false, message: `Unknown action: ${action}` });
  } catch (err) {
    return jsonResponse({
      ok: false,
      message: `Server error reaching Fapshi: ${err}`,
    });
  }
});
