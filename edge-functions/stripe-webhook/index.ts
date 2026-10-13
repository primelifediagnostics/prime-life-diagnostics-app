// Edge Function to receive Stripe webhooks and mark orders/appointments paid
// Deploy via Supabase Edge Functions. Set STRIPE_WEBHOOK_SECRET and other env vars.

import { serve } from "std/server";
import Stripe from "stripe";

const STRIPE_SECRET = Deno.env.get("STRIPE_SECRET")!;
const STRIPE_WEBHOOK_SECRET = Deno.env.get("STRIPE_WEBHOOK_SECRET")!;
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE")!;

const stripe = new Stripe(STRIPE_SECRET, { apiVersion: "2022-11-15" });

serve(async (req) => {
  const buf = await req.arrayBuffer();
  const sig = req.headers.get("stripe-signature")!;
  let event: Stripe.Event;

  try {
    event = stripe.webhooks.constructEvent(Buffer.from(buf), sig, STRIPE_WEBHOOK_SECRET);
  } catch (err) {
    console.error("Webhook signature verification failed:", err);
    return new Response("Invalid signature", { status: 400 });
  }

  try {
    if (event.type === "checkout.session.completed") {
      const session = event.data.object as Stripe.Checkout.Session;
      const sessionId = session.id;
      const appointmentId = session.metadata?.appointment_id;

      // update order status in Supabase
      await fetch(`${SUPABASE_URL}/rest/v1/orders?stripe_session_id=eq.${sessionId}`, {
        method: "PATCH",
        headers: {
          apikey: SUPABASE_SERVICE_ROLE,
          Authorization: `Bearer ${SUPABASE_SERVICE_ROLE}`,
          "Content-Type": "application/json",
          Prefer: "return=representation",
        },
        body: JSON.stringify({
          status: "paid",
          stripe_payment_intent: session.payment_intent
        }),
      });

      // also mark appointment as paid (optional: update a column or order relation)
      if (appointmentId) {
        await fetch(`${SUPABASE_URL}/rest/v1/appointments?id=eq.${appointmentId}`, {
          method: "PATCH",
          headers: {
            apikey: SUPABASE_SERVICE_ROLE,
            Authorization: `Bearer ${SUPABASE_SERVICE_ROLE}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            status: "booked"
          }),
        });
      }

      // create audit log (optional)
      await fetch(`${SUPABASE_URL}/rest/v1/audit_logs`, {
        method: "POST",
        headers: {
          apikey: SUPABASE_SERVICE_ROLE,
          Authorization: `Bearer ${SUPABASE_SERVICE_ROLE}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          actor_id: null,
          action: "stripe_payment_completed",
          entity: "orders",
          entity_id: sessionId,
          meta: { session }
        }),
      });
    }

    return new Response("ok", { status: 200 });
  } catch (err) {
    console.error("Error processing webhook:", err);
    return new Response("webhook handler error", { status: 500 });
  }
});
