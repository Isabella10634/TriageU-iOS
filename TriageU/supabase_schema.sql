-- Ejecutar en Supabase > SQL Editor (idempotente).
-- Requiere Authentication > Providers > Email habilitado.

create table if not exists public.activities (
  id uuid primary key,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  title text not null,
  subject text not null,
  type text not null,
  due_date timestamptz not null,
  weight_percent int,
  preparation int not null,
  duration_min int not null,
  priority text not null,
  completed boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Migración desde la versión anterior (device_id, sin login).
alter table public.activities
  add column if not exists user_id uuid default auth.uid() references auth.users(id) on delete cascade;
alter table public.activities drop column if exists device_id;
alter table public.activities
  add column if not exists updated_at timestamptz not null default now();
-- Las filas anónimas anteriores no tienen dueño y quedan inaccesibles; se eliminan.
delete from public.activities where user_id is null;
alter table public.activities alter column user_id set not null;

create index if not exists activities_user_idx on public.activities (user_id);

alter table public.activities enable row level security;

drop policy if exists "anon full access" on public.activities;
drop policy if exists "own rows select" on public.activities;
drop policy if exists "own rows insert" on public.activities;
drop policy if exists "own rows update" on public.activities;
drop policy if exists "own rows delete" on public.activities;

create policy "own rows select" on public.activities
  for select to authenticated using (auth.uid() = user_id);
create policy "own rows insert" on public.activities
  for insert to authenticated with check (auth.uid() = user_id);
create policy "own rows update" on public.activities
  for update to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "own rows delete" on public.activities
  for delete to authenticated using (auth.uid() = user_id);


-- ========== Cambios v3 ==========
alter table public.activities
  add column if not exists has_due_time boolean not null default false;

create table if not exists public.subjects (
  id uuid primary key,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  name text not null,
  color_hex text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists subjects_user_idx on public.subjects (user_id);
alter table public.subjects enable row level security;

drop policy if exists "own subjects select" on public.subjects;
drop policy if exists "own subjects insert" on public.subjects;
drop policy if exists "own subjects update" on public.subjects;
drop policy if exists "own subjects delete" on public.subjects;

create policy "own subjects select" on public.subjects
  for select to authenticated using (auth.uid() = user_id);
create policy "own subjects insert" on public.subjects
  for insert to authenticated with check (auth.uid() = user_id);
create policy "own subjects update" on public.subjects
  for update to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "own subjects delete" on public.subjects
  for delete to authenticated using (auth.uid() = user_id);
