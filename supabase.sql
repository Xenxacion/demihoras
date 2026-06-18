-- BRADEM - SQL unico para Supabase
-- Ejecutar completo en Supabase SQL Editor.
-- Incluye tablas, migraciones, RLS, realtime y datos iniciales.

create extension if not exists "pgcrypto";

-- 1) Tablas
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

create table if not exists bw_sueldos (
  id uuid default gen_random_uuid() primary key,
  email text not null,
  mes text not null,
  fecha_pago date not null default current_date,
  monto numeric not null check (monto > 0),
  metodo text not null default 'transferencia',
  estado text not null default 'parcial',
  nota text default '',
  created_by text default auth.email(),
  created_at timestamptz default now()
);

-- 2) Migraciones idempotentes
insert into bw_config (key, value) values
  ('tarifa_oficina', 7000),
  ('tarifa_evento', 7000),
  ('porc_extra', 50)
on conflict (key) do nothing;

alter table bw_roles add column if not exists email text;
alter table bw_roles add column if not exists rol text;
create unique index if not exists bw_roles_email_unique_idx on bw_roles (email);

alter table bw_meses add column if not exists email text;
alter table bw_meses add column if not exists tarifa_oficina numeric default 7000;
alter table bw_meses add column if not exists tarifa_evento numeric default 7000;

alter table bw_bonos add column if not exists tipo text default 'porcentaje';
alter table bw_bonos add column if not exists valor numeric default 0;
alter table bw_bonos drop constraint if exists bw_bonos_tipo_check;
update bw_bonos set valor = coalesce(valor, porc, 0), tipo = coalesce(tipo, 'porcentaje');
alter table bw_bonos add constraint bw_bonos_tipo_check check (tipo in ('porcentaje','fijo'));

alter table bw_solicitudes add column if not exists hora_inicio text default '';
alter table bw_solicitudes add column if not exists hora_fin text default '';

alter table bw_sueldos add column if not exists metodo text default 'transferencia';
alter table bw_sueldos add column if not exists estado text default 'parcial';
alter table bw_sueldos add column if not exists nota text default '';
alter table bw_sueldos add column if not exists created_by text default auth.email();
alter table bw_sueldos alter column estado set default 'parcial';
update bw_sueldos
set metodo = 'transferencia'
where metodo is null
   or metodo not in ('efectivo','transferencia','mercado_pago','otro');
alter table bw_sueldos drop constraint if exists bw_sueldos_metodo_check;
alter table bw_sueldos add constraint bw_sueldos_metodo_check check (metodo in ('efectivo','transferencia','mercado_pago','otro'));
alter table bw_sueldos drop constraint if exists bw_sueldos_estado_check;
do $$
declare
  con record;
begin
  for con in
    select c.conname
    from pg_constraint c
    join pg_class t on t.oid = c.conrelid
    join pg_namespace n on n.oid = t.relnamespace
    where n.nspname = 'public'
      and t.relname = 'bw_sueldos'
      and c.contype = 'c'
      and pg_get_constraintdef(c.oid) ilike '%estado%'
  loop
    execute format('alter table public.bw_sueldos drop constraint if exists %I', con.conname);
  end loop;
end $$;
update bw_sueldos
set estado = 'parcial'
where estado is null
   or estado not in ('parcial','completo','falta_pagar');
alter table bw_sueldos add constraint bw_sueldos_estado_check check (estado in ('parcial','completo','falta_pagar'));

-- 3) RLS
alter table bw_roles enable row level security;
alter table bw_bonos enable row level security;
alter table bw_config enable row level security;
alter table bw_meses enable row level security;
alter table bw_solicitudes enable row level security;
alter table bw_sueldos enable row level security;

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
drop policy if exists "admin manage bw_meses" on bw_meses;
drop policy if exists "select own or admin bw_meses" on bw_meses;
create policy "select own or admin bw_meses"
  on bw_meses for select to authenticated
  using (
    email = auth.email()
    or exists (select 1 from bw_roles where email = auth.email() and rol = 'admin')
  );

drop policy if exists "owner insert bw_meses" on bw_meses;
create policy "owner insert bw_meses"
  on bw_meses for insert to authenticated
  with check (
    email = auth.email()
    or exists (select 1 from bw_roles where email = auth.email() and rol = 'admin')
  );

drop policy if exists "owner update bw_meses" on bw_meses;
create policy "owner update bw_meses"
  on bw_meses for update to authenticated
  using (
    email = auth.email()
    or exists (select 1 from bw_roles where email = auth.email() and rol = 'admin')
  )
  with check (
    email = auth.email()
    or exists (select 1 from bw_roles where email = auth.email() and rol = 'admin')
  );

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

drop policy if exists "select sueldos" on bw_sueldos;
create policy "select sueldos"
  on bw_sueldos for select to authenticated
  using (
    email = auth.email()
    or exists (select 1 from bw_roles where email = auth.email() and rol = 'admin')
  );

drop policy if exists "insert sueldos" on bw_sueldos;
create policy "insert sueldos"
  on bw_sueldos for insert to authenticated
  with check (
    email = auth.email()
    or exists (select 1 from bw_roles where email = auth.email() and rol = 'admin')
  );

drop policy if exists "update sueldos" on bw_sueldos;
create policy "update sueldos"
  on bw_sueldos for update to authenticated
  using (
    email = auth.email()
    or exists (select 1 from bw_roles where email = auth.email() and rol = 'admin')
  )
  with check (
    email = auth.email()
    or exists (select 1 from bw_roles where email = auth.email() and rol = 'admin')
  );

drop policy if exists "delete sueldos" on bw_sueldos;
create policy "delete sueldos"
  on bw_sueldos for delete to authenticated
  using (
    email = auth.email()
    or exists (select 1 from bw_roles where email = auth.email() and rol = 'admin')
  );

-- 4) Realtime
alter table bw_meses replica identity full;
alter table bw_solicitudes replica identity full;
alter table bw_config replica identity full;
alter table bw_sueldos replica identity full;

do $$
declare
  tbl text;
begin
  if not exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    create publication supabase_realtime;
  end if;

  foreach tbl in array array['bw_meses', 'bw_solicitudes', 'bw_config', 'bw_sueldos']
  loop
    begin
      execute format('alter publication supabase_realtime add table %I', tbl);
    exception
      when duplicate_object then null;
      when undefined_table then null;
    end;
  end loop;
end $$;

-- 5) Datos iniciales
insert into bw_roles (email, rol) values
  ('bradem@gmail.com', 'admin'),
  ('neienowo@gmail.com', 'empleado')
on conflict (email) do update set rol = excluded.rol;

insert into bw_bonos (id, name, descripcion, porc, tipo, valor) values
  (1, 'Bono 1 - Presentismo', 'Sin ausencias en el mes', 10, 'porcentaje', 10),
  (2, 'Bono 2 - Evento Especial', 'Participacion en evento especial', 15, 'porcentaje', 15),
  (3, 'Bono 3 - Horas Extra', 'Superar 160 hrs en el mes', 20, 'porcentaje', 20),
  (4, 'Bono 4 - Productividad', 'Objetivos del mes cumplidos', 25, 'porcentaje', 25)
on conflict (id) do nothing;
