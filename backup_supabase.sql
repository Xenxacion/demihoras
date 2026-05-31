-- ============================================================
-- BACKUP COMPLETO — BRADEM WIFI 2026
-- Fecha: 06/05/2026
-- Proyecto Supabase: okusszgwseinqxynykvh
-- ============================================================
-- Correr en: Supabase → SQL Editor
-- IMPORTANTE: correr en orden de arriba hacia abajo
-- ============================================================


-- ── 1. EXTENSIONES ──────────────────────────────────────────
create extension if not exists "pgcrypto";


-- ── 2. TABLAS ───────────────────────────────────────────────

-- Roles de usuario (admin / empleado)
create table if not exists bw_roles (
  id    integer generated always as identity primary key,
  email text not null,
  rol   text not null
);

-- Bonos configurables
create table if not exists bw_bonos (
  id          integer primary key,
  name        text,
  descripcion text,
  ars         numeric default 0
);

-- Registro mensual de horas por empleado
create table if not exists bw_meses (
  mes         text not null,
  hrs_oficina numeric default 0,
  hrs_evento  numeric default 0,
  gastos      numeric default 0,
  adelantos   numeric default 0,
  dias        jsonb default '[]'::jsonb,
  email       text default 'neienowo@gmail.com'
);

-- Solicitudes de horas pendientes de aprobación
create table if not exists bw_solicitudes (
  id             uuid default gen_random_uuid() primary key,
  empleado_email text not null,
  mes            text not null,
  fecha          text not null,
  dia            text not null,
  tipo           text not null,
  horas          numeric not null,
  descripcion    text default '',
  gastos         numeric default 0,
  det_gastos     text default '',
  adelanto       numeric default 0,
  estado         text default 'pendiente',
  created_at     timestamptz default now()
);


-- ── 3. RLS (Row Level Security) ─────────────────────────────

alter table bw_roles       enable row level security;
alter table bw_bonos       enable row level security;
alter table bw_meses       enable row level security;
alter table bw_solicitudes enable row level security;


-- ── 4. POLÍTICAS ────────────────────────────────────────────

-- bw_roles
drop policy if exists "authenticated can select bw_roles" on bw_roles;
create policy "authenticated can select bw_roles"
  on bw_roles for select to authenticated using (true);

-- bw_bonos
drop policy if exists "authenticated can select bw_bonos" on bw_bonos;
create policy "authenticated can select bw_bonos"
  on bw_bonos for select to authenticated using (true);

drop policy if exists "admin manage bw_bonos" on bw_bonos;
create policy "admin manage bw_bonos"
  on bw_bonos for all to authenticated
  using (exists (select 1 from bw_roles where email = auth.email() and rol = 'admin'))
  with check (exists (select 1 from bw_roles where email = auth.email() and rol = 'admin'));

-- bw_meses
drop policy if exists "authenticated can select bw_meses" on bw_meses;
create policy "authenticated can select bw_meses"
  on bw_meses for select to authenticated using (true);

drop policy if exists "admin manage bw_meses" on bw_meses;
create policy "admin manage bw_meses"
  on bw_meses for all to authenticated
  using (exists (select 1 from bw_roles where email = auth.email() and rol = 'admin'))
  with check (exists (select 1 from bw_roles where email = auth.email() and rol = 'admin'));

-- bw_solicitudes
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


-- ── 5. REALTIME ─────────────────────────────────────────────

alter table bw_meses       replica identity full;
alter table bw_solicitudes replica identity full;

drop publication if exists supabase_realtime;
create publication supabase_realtime for table bw_meses, bw_solicitudes;


-- ── 6. DATOS INICIALES — ROLES ──────────────────────────────
-- Reemplazá los emails si cambian
-- Admin principal
insert into bw_roles (email, rol) values ('bradem@gmail.com', 'admin')
  on conflict do nothing;

-- Empleado
insert into bw_roles (email, rol) values ('neienowo@gmail.com', 'empleado')
  on conflict do nothing;


-- ── 7. DATOS INICIALES — BONOS ──────────────────────────────
insert into bw_bonos (id, name, descripcion, ars) values
  (1, 'Bono 1 — Presentismo',    'Sin ausencias en el mes',         5000),
  (2, 'Bono 2 — Evento Especial','Participación en evento especial', 10000),
  (3, 'Bono 3 — Horas Extra',    'Superar 160 hrs en el mes',        15000),
  (4, 'Bono 4 — Productividad',  'Objetivos del mes cumplidos',      20000)
on conflict (id) do update set
  name        = excluded.name,
  descripcion = excluded.descripcion,
  ars         = excluded.ars;


-- ── FIN DEL BACKUP ──────────────────────────────────────────
-- Para agregar un nuevo empleado:
--   insert into bw_roles (email, rol) values ('nuevo@email.com', 'empleado');
-- Para agregar un nuevo admin:
--   insert into bw_roles (email, rol) values ('nuevo@email.com', 'admin');
