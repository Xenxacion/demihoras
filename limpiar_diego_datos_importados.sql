-- Limpia datos que pudieron haberse autogenerado por la semilla vieja de Mayo.
-- Ejecutar en Supabase -> SQL Editor si diego@gmail.com ve datos importados que no son suyos.
-- IMPORTANTE: ejecutar primero migrate_meses_por_email.sql para cambiar la clave a (email, mes).
-- Solo borra filas de diego@gmail.com que coinciden con el paquete importado viejo.

delete from bw_meses
where email = 'diego@gmail.com'
  and mes = 'Mayo'
  and coalesce(hrs_oficina,0) = 8
  and coalesce(hrs_evento,0) = 63
  and coalesce(gastos,0) = 48850
  and coalesce(adelantos,0) = 0
  and jsonb_array_length(coalesce(dias,'[]'::jsonb)) >= 10;

-- Si queres dejarle una fila limpia de Mayo ya creada:
insert into bw_meses (email, mes, hrs_oficina, hrs_evento, gastos, adelantos, dias, bonos_sel)
select 'diego@gmail.com', 'Mayo', 0, 0, 0, 0, '[]'::jsonb, '[]'::jsonb
where not exists (
  select 1 from bw_meses where email = 'diego@gmail.com' and mes = 'Mayo'
);
