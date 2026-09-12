'use strict';

// Minimal Kavenegar client. Uses the "verify/lookup" template endpoint, which is
// the correct one for OTP codes: the message body is fixed in the template and
// the code is passed as the `token`.
//
// Docs: https://kavenegar.com/rest.html#verify-lookup

const BASE = 'https://api.kavenegar.com/v1';

/** Send an OTP code to `phone` via the configured verify-lookup template. */
async function sendOtp(phone, code) {
  const apiKey = process.env.KAVENEGAR_API_KEY;
  const template = process.env.KAVENEGAR_TEMPLATE;
  if (!apiKey) {
    throw new Error('KAVENEGAR_API_KEY is not set');
  }

  if (template) {
    const url = `${BASE}/${apiKey}/verify/lookup.json?receptor=${encodeURIComponent(
      phone
    )}&token=${encodeURIComponent(code)}&template=${encodeURIComponent(template)}`;
    return request(url);
  }

  // Fallback: plain send (needs a sender line). Kept so the server still works
  // before a template is approved.
  const sender = process.env.KAVENEGAR_SENDER;
  if (!sender) {
    throw new Error('Set KAVENEGAR_TEMPLATE (preferred) or KAVENEGAR_SENDER');
  }
  const message = `کد ورود شما به ویژن مستر: ${code}`;
  const url = `${BASE}/${apiKey}/sms/send.json?receptor=${encodeURIComponent(
    phone
  )}&sender=${encodeURIComponent(sender)}&message=${encodeURIComponent(message)}`;
  return request(url);
}

async function request(url) {
  const res = await fetch(url, { method: 'GET' });
  const body = await res.json().catch(() => ({}));
  const status = body && body.return ? body.return.status : res.status;
  if (!res.ok || status !== 200) {
    const msg = body && body.return ? body.return.message : `HTTP ${res.status}`;
    throw new Error(`Kavenegar error: ${msg}`);
  }
  return body;
}

module.exports = { sendOtp };
