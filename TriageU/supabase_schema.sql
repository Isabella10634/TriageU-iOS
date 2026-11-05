-- Ejecutar en Supabase > SQL Editor
create table if not exists public.activities (
  id uuid primary key,
  device_id text not null,
  title text not null,
  subject text not null,
  type text not null,
  due_date timestamptz not null,
  weight_percent int,
  preparation int not null,
  duration_min int not null,
  priority text not null,
  completed boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists activities_device_idx on public.activities (device_id);

alter table public.activities enable row level security;

-- MVP sin login: acceso con la anon key. Cuando agregues Supabase Auth,
-- reemplaza esta política por una basada en auth.uid().
create policy "anon full access" on public.activities
  for all to anon using (true) with check (true);
