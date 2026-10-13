// Edge Function (Deno / TypeScript) - create-checkout-session
// Deploy via Supabase CLI or the Supabase dashboard

import { serve } from "std/server";
import Stripe from "stripe";

const STRIPE_SECRET = Deno.env.get("STRIPE_SECRET")!;
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE")!;

const stripe = new Stripe(STRIPE_SECRET, { apiVersion: "2022-11-15" });

serve(async (req) => {
  try {
    const body = await req.json();
    const { appointment_id, success_url, cancel_url } = body;

    if (!appointment_id || !success_url || !cancel_url) {
      return new Response(JSON.stringify({ error: "Missing params" }), { status: 400 });
    }

    // fetch appointment and user from Supabase (server-side)
    const supabaseRes = await fetch(`${SUPABASE_URL}/rest/v1/appointments?id=eq.${appointment_id}&select=*,user:appointments_user!inner(user_id)` , {
      headers: {
        apikey: SUPABASE_SERVICE_ROLE,
        Authorization: `Bearer ${SUPABASE_SERVICE_ROLE}`,
      },
    });

    if (!supabaseRes.ok) {
      return new Response(JSON.stringify({ error: "Failed to fetch appointment" }), { status: 500 });
    }
    const [appointment] = await supabaseRes.json();

    if (!appointment) return new Response(JSON.stringify({ error: "Appointment not found" }), { status: 404 });

    const amount = appointment.total_cents;

    // Create Stripe Checkout Session
    const session = await stripe.checkout.sessions.create({
      payment_method_types: ["card"],
      mode: "payment",
      customer_email: appointment.user_email ?? undefined,
      line_items: [
        {
          price_data: {
            currency: (appointment.currency || 'GBP').toLowerCase(),
            product_data: {
              name: `Booking for appointment ${appointment_id}`,
            },
            unit_amount: amount,
          },
          quantity: 1,
        },
      ],
      metadata: {
        appointment_id,
      },
      success_url,
      cancel_url,
    });

    // create an order record in Supabase (server-side)
    const createOrderRes = await fetch(`${SUPABASE_URL}/rest/v1/orders`, {
      method: "POST",
      headers: {
        apikey: SUPABASE_SERVICE_ROLE,
        Authorization: `Bearer ${SUPABASE_SERVICE_ROLE}`,
        "Content-Type": "application/json",
        Prefer: "return=representation",
      },
      body: JSON.stringify({
        appointment_id,
        user_id: appointment.user_id,
        stripe_session_id: session.id,
        amount_cents: amount,
        currency: appointment.currency || "GBP",
        status: "pending",
      }),
    });

    if (!createOrderRes.ok) {
      console.error("Failed to create order in Supabase", await createOrderRes.text());
    }

    return new Response(JSON.stringify({ url: session.url, sessionId: session.id }), {
      headers: { "Content-Type": "application/json" },
      status: 200,
    });
  } catch (err) {
    console.error(err);
    return new Response(JSON.stringify({ error: "server error", detail: String(err) }), { status: 500 });
  }
});
