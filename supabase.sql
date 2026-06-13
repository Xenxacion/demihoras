-- Estructura y migraciones necesarias para BRADEM
-- Ejecutar en Supabase SQL Editor

create extension if not exists "pgcrypto";

create table if not exists bw_roles (
  id integer generated always as identity primary key,
  email text not null unique,
  rol text not null check (rol in ('admin','empleado'))
);

create table if not exists bw_bonos (
  id integer primary key,
  name text,
  descripcion text,
  porc numeric default 0,
  tipo text default 'porcentaje' check (tipo in ('porcentaje','fijo')),
  valor numeric default 0
);

create table if not exists bw_config (
  key text primary key,
  value numeric default 0
);

insert into bw_config (key, value) values
  ('tarifa_oficina', 7000),
  ('tarifa_evento', 7000),
  ('porc_extra', 50)
on conflict (key) do nothing;

create table if not exists bw_meses (
  mes text not null,
  email text not null,
  hrs_oficina numeric default 0,
  hrs_evento numeric default 0,
  gastos numeric default 0,
  adelantos numeric default 0,
  dias jsonb default '[]'::jsonb,
  bonos_sel jsonb default '[]'::jsonb,
  tarifa_oficina numeric default 7000,
  tarifa_evento numeric default 7000,
  primary key (email, mes)
);

create table if not exists bw_solicitudes (
  id uuid default gen_random_uuid() primary key,
  empleado_email text not null,
  mes text not null,
  fecha text not null,
  dia text not null,
  tipo text not null,
  hora_inicio text default '',
  hora_fin text default '',
  horas numeric not null,
  descripcion text default '',
  gastos numeric default 0,
  det_gastos text default '',
  adelanto numeric default 0,
  estado text default 'pendiente',
  created_at timestamptz default now()
);

alter table bw_meses add column if not exists tarifa_oficina numeric default 7000;
alter table bw_meses add column if not exists tarifa_evento numeric default 7000;
alter table bw_bonos add column if not exists tipo text default 'porcentaje';
alter table bw_bonos add column if not exists valor numeric default 0;
alter table bw_bonos drop constraint if exists bw_bonos_tipo_check;
update bw_bonos set valor = coalesce(valor, porc, 0), tipo = coalesce(tipo, 'porcentaje');
alter table bw_bonos add constraint bw_bonos_tipo_check check (tipo in ('porcentaje','fijo'));
alter table bw_solicitudes add column if not exists hora_inicio text default '';
alter table bw_solicitudes add column if not exists hora_fin text default '';

alter table bw_roles enable row level security;
alter table bw_bonos enable row level security;
alter table bw_meses enable row level security;
alter table bw_solicitudes enable row level security;
alter table bw_config enable row level security;

drop policy if exists "authenticated can select bw_roles" on bw_roles;
create policy "authenticated can select bw_roles"
  on bw_roles for select to authenticated using (true);

drop policy if exists "authenticated can select bw_bonos" on bw_bonos;
create policy "authenticated can select bw_bonos"
  on bw_bonos for select to authenticated using (true);

drop policy if exists "admin manage bw_bonos" on bw_bonos;
create policy "admin manage bw_bonos"
  on bw_bonos for all to authenticated
  using (exists (select 1 from bw_roles where email = auth.email() and rol = 'admin'))
  with check (exists (select 1 from bw_roles where email = auth.email() and rol = 'admin'));

drop policy if exists "authenticated can select bw_config" on bw_config;
create policy "authenticated can select bw_config"
  on bw_config for select to authenticated using (true);

drop policy if exists "admin manage bw_config" on bw_config;
create policy "admin manage bw_config"
  on bw_config for all to authenticated
  using (exists (select 1 from bw_roles where email = auth.email() and rol = 'admin'))
  with check (exists (select 1 from bw_roles where email = auth.email() and rol = 'admin'));

drop policy if exists "authenticated can select bw_meses" on bw_meses;
create policy "authenticated can select bw_meses"
  on bw_meses for select to authenticated using (true);

drop policy if exists "admin manage bw_meses" on bw_meses;
create policy "admin manage bw_meses"
  on bw_meses for all to authenticated
  using (exists (select 1 from bw_roles where email = auth.email() and rol = 'admin'))
  with check (exists (select 1 from bw_roles where email = auth.email() and rol = 'admin'));

drop policy if exists "empleado insert" on bw_solicitudes;
create policy "empleado insert"
  on bw_solicitudes for insert to authenticated
  with check (empleado_email = auth.email());

drop policy if exists "select solicitudes" on bw_solicitudes;
create policy "select solicitudes"
  on bw_solicitudes for select to authenticated
  using (
    empleado_email = auth.email()
    or exists (select 1 from bw_roles where email = auth.email() and rol = 'admin')
  );

drop policy if exists "admin update" on bw_solicitudes;
create policy "admin update"
  on bw_solicitudes for update to authenticated
  using (exists (select 1 from bw_roles where email = auth.email() and rol = 'admin'));

drop policy if exists "admin delete" on bw_solicitudes;
create policy "admin delete"
  on bw_solicitudes for delete to authenticated
  using (exists (select 1 from bw_roles where email = auth.email() and rol = 'admin'));

alter table bw_meses replica identity full;
alter table bw_solicitudes replica identity full;
alter table bw_config replica identity full;

drop publication if exists supabase_realtime;
create publication supabase_realtime for table bw_meses, bw_solicitudes, bw_config;

insert into bw_roles (email, rol) values ('bradem@gmail.com', 'admin')
on conflict (email) do update set rol = excluded.rol;

insert into bw_bonos (id, name, descripcion, porc, tipo, valor) values
  (1, 'Bono 1 — Presentismo', 'Sin ausencias en el mes', 10, 'porcentaje', 10),
  (2, 'Bono 2 — Evento Especial', 'Participación en evento especial', 15, 'porcentaje', 15),
  (3, 'Bono 3 — Horas Extra', 'Superar 160 hrs en el mes', 20, 'porcentaje', 20),
  (4, 'Bono 4 — Productividad', 'Objetivos del mes cumplidos', 25, 'porcentaje', 25)
on conflict (id) do nothing;
