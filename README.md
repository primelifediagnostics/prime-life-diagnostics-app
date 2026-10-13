# Prime Life Diagnostics — Mobile app & backend scaffold

This repository contains a scaffold for Prime Life Diagnostics: a cross-platform Flutter mobile app (iOS & Android) plus backend integration patterns using Supabase and Stripe.

What's included
- Flutter app (lib/) — UI, mock data service, booking flow and screens (start here for mobile client)
- Supabase schema (supabase/schema.sql) — database tables for tests, appointments, orders, results, locations, labs and audit logs
- Edge Functions (edge-functions/) — create-checkout-session and stripe-webhook (TypeScript/Deno) to integrate Stripe securely
- Admin example (admin/) — Next.js API example to upload result PDFs to Supabase Storage (server-side uses service role key)
- README with next steps to configure Supabase, Stripe and Flutter

Next steps (high level)
1. Create a Supabase project and run `supabase/schema.sql` in the SQL editor.
2. Create a private Storage bucket named `results`.
3. Enable RLS and add policies for appointments, orders and results (see README for examples).
4. Deploy Edge Functions and set env vars (SUPABASE_URL, SUPABASE_SERVICE_ROLE, STRIPE_SECRET, STRIPE_WEBHOOK_SECRET).
5. Configure your Flutter .env with SUPABASE_URL and SUPABASE_ANON_KEY and EDGE_FUNCTION_BASE.
6. Build and run the Flutter app.

I can continue by deploying the Edge Functions and wiring secrets if you want — tell me which step you'd like me to do next.
