-- Prime Life Diagnostics schema (run in Supabase SQL editor)
-- Tables: tests, appointments, appointment_tests, orders, results, labs, locations, audit_logs

-- Enable pgcrypto extension for gen_random_uuid if not already enabled
create extension if not exists pgcrypto;

-- tests: catalog of available blood tests
create table if not exists public.tests (
  id uuid default gen_random_uuid() primary key,
  code text unique,
  name text not null,
  category text,
  description text,
  prep_instructions text,
  turnaround_days int,
  price_cents int not null,
  sample_type text,
  active boolean default true,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- appointments: a patient's booking
create table if not exists public.appointments (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users(id) on delete cascade,
  location_id uuid references public.locations(id),
  scheduled_at timestamptz not null,
  status text not null default 'booked', -- booked, cancelled, completed
  currency text default 'GBP',
  total_cents int not null,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- appointment_tests: join table for tests in an appointment
create table if not exists public.appointment_tests (
  id uuid default gen_random_uuid() primary key,
  appointment_id uuid references public.appointments(id) on delete cascade,
  test_id uuid references public.tests(id) on delete restrict,
  quantity int default 1,
  unit_price_cents int not null,
  created_at timestamptz default now()
);

-- orders/payments: one order per appointment/payment
create table if not exists public.orders (
  id uuid default gen_random_uuid() primary key,
  appointment_id uuid references public.appointments(id) on delete cascade,
  user_id uuid references auth.users(id) on delete cascade,
  stripe_session_id text,
  stripe_payment_intent text,
  amount_cents int not null,
  currency text default 'GBP',
  status text default 'pending', -- pending, paid, failed, refunded
  metadata jsonb,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- results: uploaded result record; file_path points to Supabase Storage object
create table if not exists public.results (
  id uuid default gen_random_uuid() primary key,
  appointment_id uuid references public.appointments(id) on delete cascade,
  uploaded_by uuid references auth.users(id),
  file_path text, -- path in storage bucket
  structured_results jsonb,
  visible_to_user boolean default false,
  issued_at timestamptz,
  created_at timestamptz default now()
);

-- labs table (optional)
create table if not exists public.labs (
  id uuid default gen_random_uuid() primary key,
  name text not null,
  address text,
  phone text
);

-- locations table (clinic or home visit options)
create table if not exists public.locations (
  id uuid default gen_random_uuid() primary key,
  name text not null,
  address text,
  phone text,
  active boolean default true
);

-- audit logs
create table if not exists public.audit_logs (
  id uuid default gen_random_uuid() primary key,
  actor_id uuid references auth.users(id),
  action text not null,
  entity text,
  entity_id text,
  meta jsonb,
  created_at timestamptz default now()
);

-- Indexes and triggers to update updated_at
create function public.trigger_set_timestamp()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger tests_updated before update on public.tests for each row execute procedure public.trigger_set_timestamp();
create trigger appointments_updated before update on public.appointments for each row execute procedure public.trigger_set_timestamp();
create trigger orders_updated before update on public.orders for each row execute procedure public.trigger_set_timestamp();

-- Minimal sample data (optional)
insert into public.tests (code, name, category, description, prep_instructions, turnaround_days, price_cents, sample_type)
values
('FBC','Full Blood Count','General','Evaluates blood indices','No fasting required',2,5900,'Blood'),
('VITD','Vitamin D','Wellness','Measures vitamin D','No special preparation',3,7900,'Blood')
on conflict do nothing;
