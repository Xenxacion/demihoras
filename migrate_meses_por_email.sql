-- Separa bw_meses por email y ajusta RLS para no mezclar registros.
-- Ejecutar una vez en Supabase -> SQL Editor.

alter table bw_meses add column if not exists email text;

-- Completa registros viejos sin email. Cambia este email si el historico pertenece a otro usuario.
update bw_meses
set email = 'neienowo@gmail.com'
where email is null or trim(email) = '';

alter table bw_meses alter column email set not null;

-- La clave vieja por mes mezcla usuarios: no permite "Mayo" para mas de un email.
-- La clave correcta es una fila por cada (email, mes).
alter table bw_meses drop constraint if exists bw_meses_pkey;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'bw_meses'::regclass
      and conname = 'bw_meses_pkey'
  ) then
    alter table bw_meses add constraint bw_meses_pkey primary key (email, mes);
  end if;
end $$;

drop policy if exists "authenticated can select bw_meses" on bw_meses;
drop policy if exists "admin manage bw_meses" on bw_meses;
drop policy if exists "owner select bw_meses" on bw_meses;
drop policy if exists "owner manage bw_meses" on bw_meses;
drop policy if exists "admin select bw_meses" on bw_meses;
drop policy if exists "admin manage bw_meses by email" on bw_meses;

create policy "owner select bw_meses"
  on bw_meses for select to authenticated
  using (
    email = auth.email()
    or exists (select 1 from bw_roles where bw_roles.email = auth.email() and rol = 'admin')
  );

create policy "owner manage bw_meses"
  on bw_meses for all to authenticated
  using (email = auth.email())
  with check (email = auth.email());

create policy "admin manage bw_meses by email"
  on bw_meses for all to authenticated
  using (exists (select 1 from bw_roles where bw_roles.email = auth.email() and rol = 'admin'))
  with check (exists (select 1 from bw_roles where bw_roles.email = auth.email() and rol = 'admin'));
