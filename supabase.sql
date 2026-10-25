-- =====================================================================
-- ARTE O CRINGE: reportes, suspensiones, cuentas, monedas y ranking
-- Pégalo completo en Supabase → SQL Editor → Run. Se puede correr varias veces.
--
-- ANTES: en Authentication activa "Allow anonymous sign-ins" (cada jugador
-- recibe una cuenta sin registrarse). Para el botón "Guardar con Google"
-- activa también "Allow manual linking" y configura el proveedor de Google.
--
-- Cómo moderar:
--   1. Table Editor → reportes: aquí llega cada reporte (motivo, sala, tema, quién).
--   2. Storage → reportes: aquí está la imagen de cada dibujo reportado
--      (la columna "imagen" de la tabla trae la ruta).
--   3. Para suspender a alguien, copia su "reportado_dispositivo" y agrégalo
--      en Table Editor → baneados. Ya no podrá crear ni entrar a salas.
--   4. Marca el reporte como revisado = true y escribe en "accion" qué hiciste.
-- El juego solo puede ENVIAR reportes; nadie puede leerlos desde el juego.
-- =====================================================================

create table if not exists public.reportes (
  id bigint generated always as identity primary key,
  creado timestamptz not null default now(),
  tipo text not null check (tipo in ('dibujo', 'jugador')),
  motivo text not null check (char_length(motivo) <= 40),
  sala text check (char_length(sala) <= 8),
  ronda int,
  tema text check (char_length(tema) <= 120),
  reportado_dispositivo text check (char_length(reportado_dispositivo) <= 40),
  reportado_nombre text check (char_length(reportado_nombre) <= 40),
  reporta_dispositivo text check (char_length(reporta_dispositivo) <= 40),
  imagen text check (char_length(imagen) <= 200),
  revisado boolean not null default false,
  accion text
);
alter table public.reportes enable row level security;

drop policy if exists "El juego puede enviar reportes" on public.reportes;
create policy "El juego puede enviar reportes" on public.reportes
  for insert to anon, authenticated
  with check (revisado = false and accion is null);

create table if not exists public.baneados (
  dispositivo text primary key,
  motivo text,
  creado timestamptz not null default now()
);
alter table public.baneados enable row level security;
-- Sin políticas: el juego no puede ver la lista completa, solo preguntar por su propio dispositivo.

create or replace function public.esta_baneado(d text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select 1 from public.baneados where dispositivo = d);
$$;
grant execute on function public.esta_baneado(text) to anon, authenticated;

-- Carpeta privada para las imágenes de los dibujos reportados (máximo 300 KB cada una).
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('reportes', 'reportes', false, 300000, array['image/webp', 'image/jpeg', 'image/png'])
on conflict (id) do nothing;

drop policy if exists "El juego puede subir imágenes de reportes" on storage.objects;
create policy "El juego puede subir imágenes de reportes" on storage.objects
  for insert to anon, authenticated
  with check (bucket_id = 'reportes');

-- =====================================================================
-- CUENTAS, MONEDAS Y RANKING
-- Todo pasa por las funciones de abajo; el juego no puede escribir directo
-- en las tablas. Los límites (60 monedas por ronda, 1,500 al día, 5 anuncios
-- al día, una ronda cada 30 segundos) frenan a quien intente hacer trampa.
-- Para cambiar un precio en monedas, edítalo en la tabla "catalogo".
-- =====================================================================
create table if not exists public.perfiles (
  id uuid primary key references auth.users(id) on delete cascade,
  nombre text not null default 'Jugador' check (char_length(nombre) between 1 and 16),
  mascota text not null default 'mascota_ajolote' check (char_length(mascota) <= 40),
  monedas int not null default 0 check (monedas >= 0),
  compras text[] not null default '{}',
  puntos_total int not null default 0,
  puntos_semana int not null default 0,
  semana date not null default date_trunc('week', now())::date,
  anuncios_hoy int not null default 0,
  monedas_hoy int not null default 0,
  dia date not null default current_date,
  ultima_ronda timestamptz,
  creado timestamptz not null default now()
);
alter table public.perfiles enable row level security;

create table if not exists public.rondas_cobradas (
  usuario uuid not null references auth.users(id) on delete cascade,
  sala text not null,
  ronda int not null,
  creado timestamptz not null default now(),
  primary key (usuario, sala, ronda)
);
alter table public.rondas_cobradas enable row level security;

create table if not exists public.catalogo (
  id text primary key,
  monedas int not null check (monedas > 0)
);
alter table public.catalogo enable row level security;
insert into public.catalogo (id, monedas) values
  ('paquete_mexico', 1500), ('paquete_terror', 1500), ('paquete_internet', 1500),
  ('paquete_ajolote', 2500), ('paquete_fiesta', 2500),
  ('mascota_gato', 2500), ('mascota_salchicha', 2500), ('mascota_fantasma', 2500),
  ('mascota_taco', 2500), ('mascota_pollito', 2500),
  ('paquete_muertos', 2500), ('paquete_telenovela', 1500), ('paquete_videojuegos', 1500),
  ('mascota_xolo', 2500), ('mascota_calaverita', 2500), ('mascota_mapache', 2500)
on conflict (id) do update set monedas = excluded.monedas;

-- Crea el perfil si no existe y reinicia los contadores del día y de la semana.
create or replace function public._perfil(p uuid)
returns public.perfiles
language plpgsql security definer set search_path = '' as $$
declare r public.perfiles;
begin
  insert into public.perfiles (id) values (p) on conflict (id) do nothing;
  update public.perfiles set
    puntos_semana = case when semana < date_trunc('week', now())::date then 0 else puntos_semana end,
    semana = date_trunc('week', now())::date,
    anuncios_hoy = case when dia < current_date then 0 else anuncios_hoy end,
    monedas_hoy = case when dia < current_date then 0 else monedas_hoy end,
    dia = current_date
  where id = p
  returning * into r;
  return r;
end $$;

create or replace function public._json(r public.perfiles)
returns jsonb
language sql stable set search_path = '' as $$
  select jsonb_build_object('monedas', r.monedas, 'compras', to_jsonb(r.compras), 'puntos_total', r.puntos_total,
    'puntos_semana', r.puntos_semana, 'nombre', r.nombre, 'mascota', r.mascota);
$$;

create or replace function public.mi_perfil(p_nombre text default null)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare r public.perfiles; u uuid := auth.uid();
begin
  if u is null then raise exception 'sin sesión'; end if;
  r := public._perfil(u);
  if char_length(btrim(coalesce(p_nombre, ''))) between 1 and 16 and btrim(p_nombre) <> r.nombre then
    update public.perfiles set nombre = btrim(p_nombre) where id = u returning * into r;
  end if;
  return public._json(r);
end $$;

create or replace function public.actualizar_perfil(p_nombre text, p_mascota text)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare r public.perfiles; u uuid := auth.uid();
begin
  if u is null then raise exception 'sin sesión'; end if;
  r := public._perfil(u);
  update public.perfiles set
    nombre = case when char_length(btrim(coalesce(p_nombre, ''))) between 1 and 16 then btrim(p_nombre) else nombre end,
    mascota = case when p_mascota = 'mascota_ajolote' or p_mascota = any(compras) then p_mascota else mascota end
  where id = u
  returning * into r;
  return public._json(r);
end $$;

-- Monedas y puntos de una ronda. Cada ronda se cobra una sola vez.
create or replace function public.registrar_ronda(p_sala text, p_ronda int, p_puntos int, p_monedas int, p_humanos int)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare r public.perfiles; u uuid := auth.uid(); m int; p int;
begin
  if u is null then raise exception 'sin sesión'; end if;
  r := public._perfil(u);
  if r.ultima_ronda is not null and r.ultima_ronda > now() - interval '30 seconds' then return public._json(r); end if;
  insert into public.rondas_cobradas (usuario, sala, ronda)
  values (u, left(coalesce(p_sala, ''), 8), coalesce(p_ronda, 0))
  on conflict do nothing;
  if not found then return public._json(r); end if;
  m := least(greatest(coalesce(p_monedas, 0), 0), 60, greatest(1500 - r.monedas_hoy, 0));
  p := case when coalesce(p_humanos, 0) >= 2 then least(greatest(coalesce(p_puntos, 0), 0), 50) else 0 end;
  update public.perfiles set
    monedas = monedas + m, monedas_hoy = monedas_hoy + m,
    puntos_total = puntos_total + p, puntos_semana = puntos_semana + p,
    ultima_ronda = now()
  where id = u
  returning * into r;
  return public._json(r);
end $$;

create or replace function public.recompensa_anuncio()
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare r public.perfiles; u uuid := auth.uid();
begin
  if u is null then raise exception 'sin sesión'; end if;
  r := public._perfil(u);
  if r.anuncios_hoy >= 5 then raise exception 'límite de anuncios de hoy'; end if;
  update public.perfiles set monedas = monedas + 50, anuncios_hoy = anuncios_hoy + 1
  where id = u
  returning * into r;
  return public._json(r);
end $$;

create or replace function public.comprar_con_monedas(p_item text)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare r public.perfiles; u uuid := auth.uid(); precio int;
begin
  if u is null then raise exception 'sin sesión'; end if;
  select monedas into precio from public.catalogo where id = p_item;
  if precio is null then raise exception 'ese artículo no existe'; end if;
  perform public._perfil(u);
  select * into r from public.perfiles where id = u for update;
  if p_item = any(r.compras) then return public._json(r); end if;
  if r.monedas < precio then raise exception 'saldo insuficiente'; end if;
  update public.perfiles set monedas = monedas - precio, compras = array_append(compras, p_item)
  where id = u
  returning * into r;
  return public._json(r);
end $$;

-- Ranking: top 50 de la semana o de siempre, y tu lugar.
create or replace function public.ranking(p_tipo text default 'semana')
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare u uuid := auth.uid(); semanal boolean := coalesce(p_tipo, 'semana') = 'semana'; lunes date := date_trunc('week', now())::date; top jsonb; yo jsonb;
begin
  select coalesce(jsonb_agg(jsonb_build_object('nombre', t.nombre, 'mascota', t.mascota, 'puntos', t.pts, 'yo', t.id = u) order by t.pos, t.nombre), '[]'::jsonb)
  into top
  from (
    select b.id, b.nombre, b.mascota, b.pts, rank() over (order by b.pts desc) as pos
    from (select id, nombre, mascota, case when semanal then (case when semana = lunes then puntos_semana else 0 end) else puntos_total end as pts
          from public.perfiles) b
    where b.pts > 0
    order by b.pts desc
    limit 50
  ) t;
  select jsonb_build_object('pos', t.pos, 'puntos', t.pts) into yo
  from (
    select b.id, b.pts, rank() over (order by b.pts desc) as pos
    from (select id, case when semanal then (case when semana = lunes then puntos_semana else 0 end) else puntos_total end as pts
          from public.perfiles) b
    where b.pts > 0
  ) t
  where t.id = u;
  return jsonb_build_object('top', top, 'yo', yo);
end $$;

-- Solo usuarios con sesión (incluye las cuentas anónimas) pueden llamar estas funciones.
revoke all on function public._perfil(uuid) from public, anon, authenticated;
revoke all on function public._json(public.perfiles) from public, anon, authenticated;
revoke all on function public.mi_perfil(text) from public, anon;
revoke all on function public.actualizar_perfil(text, text) from public, anon;
revoke all on function public.registrar_ronda(text, int, int, int, int) from public, anon;
revoke all on function public.recompensa_anuncio() from public, anon;
revoke all on function public.comprar_con_monedas(text) from public, anon;
revoke all on function public.ranking(text) from public, anon;
grant execute on function public.mi_perfil(text) to authenticated;
grant execute on function public.actualizar_perfil(text, text) to authenticated;
grant execute on function public.registrar_ronda(text, int, int, int, int) to authenticated;
grant execute on function public.recompensa_anuncio() to authenticated;
grant execute on function public.comprar_con_monedas(text) to authenticated;
grant execute on function public.ranking(text) to authenticated;

-- =====================================================================
-- BORRAR MIS DATOS (lo pide Google Play)
-- El jugador puede borrar su cuenta desde el juego: inicio → "Borrar mis datos".
-- Al borrar la cuenta se borran en cascada su perfil, monedas, compras,
-- puntos del ranking y rondas cobradas. Los reportes y suspensiones se
-- conservan el tiempo que dice el aviso de privacidad, para moderación.
-- =====================================================================
create or replace function public.borrar_mis_datos()
returns void
language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then return; end if;
  delete from auth.users where id = auth.uid();
end $$;
revoke all on function public.borrar_mis_datos() from public, anon;
grant execute on function public.borrar_mis_datos() to authenticated;

-- =====================================================================
-- COMPRAS EN LA WEB CON MERCADO PAGO
-- Los precios en pesos se cambian aquí abajo o en la tabla "precios_web"
-- (Table Editor). Para dejar de vender algo, pon activo = false.
-- Solo la función "pagos" (Edge Functions) registra pagos, y antes de
-- entregar algo revisa el pago directamente con Mercado Pago.
-- =====================================================================
create table if not exists public.precios_web (
  id text primary key,
  nombre text not null,
  mxn numeric(10,2) not null check (mxn > 0),
  activo boolean not null default true
);
alter table public.precios_web enable row level security;
insert into public.precios_web (id, nombre, mxn) values
  ('paquete_mexico', 'Puro México', 39), ('paquete_terror', 'Noche de terror', 39), ('paquete_internet', 'Vida en internet', 39),
  ('paquete_ajolote', 'Ajolotes', 59), ('paquete_fiesta', 'Fiesta', 59),
  ('mascota_gato', 'Gato juez', 59), ('mascota_salchicha', 'Salchicha', 59), ('mascota_fantasma', 'Fantasmita', 59),
  ('mascota_taco', 'Taquito', 59), ('mascota_pollito', 'Pollito', 59),
  ('sin_anuncios', 'Sin anuncios', 99),
  ('paquete_muertos', 'Día de Muertos', 59), ('paquete_telenovela', 'Telenovela', 39), ('paquete_videojuegos', 'Videojuegos', 39),
  ('mascota_xolo', 'Xolo', 59), ('mascota_calaverita', 'Calaverita', 59), ('mascota_mapache', 'Mapache', 59)
on conflict (id) do nothing;   -- si ya cambiaste un precio, no lo regresa

create table if not exists public.pagos_web (
  id text primary key,                 -- número de operación de Mercado Pago
  usuario uuid references auth.users(id) on delete cascade,
  producto text not null,
  estado text not null,                -- approved, pending, in_process, rejected, refunded, charged_back…
  monto numeric(10,2) not null,
  moneda text not null,
  creado timestamptz not null default now(),
  actualizado timestamptz not null default now()
);
alter table public.pagos_web enable row level security;
create index if not exists pagos_web_usuario on public.pagos_web (usuario);

-- Precios para la tienda (cualquiera puede verlos).
create or replace function public.precios_web_lista()
returns jsonb
language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_object_agg(id, mxn), '{}'::jsonb) from public.precios_web where activo;
$$;

-- Guarda el estado de un pago y entrega o quita el artículo.
-- Si el pago ya existía, se queda con el dueño que tenía (por si se recuperó en otra cuenta).
create or replace function public.registrar_pago_web(p_id text, p_usuario uuid, p_producto text, p_estado text, p_monto numeric, p_moneda text)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare precio numeric; dueno uuid; entregado boolean := false;
begin
  select mxn into precio from public.precios_web where id = p_producto;
  if precio is null then raise exception 'producto desconocido'; end if;
  -- Si esa cuenta ya se borró, el pago se guarda sin dueño (no se entrega a nadie).
  if p_usuario is not null and not exists (select 1 from auth.users where id = p_usuario) then p_usuario := null; end if;
  insert into public.pagos_web (id, usuario, producto, estado, monto, moneda)
  values (p_id, p_usuario, p_producto, p_estado, p_monto, p_moneda)
  on conflict (id) do update set estado = excluded.estado, monto = excluded.monto, moneda = excluded.moneda, actualizado = now()
  returning usuario into dueno;
  if dueno is null then
    return jsonb_build_object('entregado', false, 'estado', p_estado, 'producto', p_producto);
  end if;
  perform public._perfil(dueno);
  if p_estado = 'approved' and p_moneda = 'MXN' and p_monto >= precio then
    update public.perfiles set compras = array_append(compras, p_producto)
    where id = dueno and not (p_producto = any(compras));
    entregado := true;
  elsif p_estado in ('refunded', 'charged_back', 'cancelled') then
    -- Reembolso o contracargo: se quita, salvo que tenga otro pago aprobado del mismo artículo.
    if not exists (select 1 from public.pagos_web where usuario = dueno and producto = p_producto and estado = 'approved' and id <> p_id) then
      update public.perfiles set compras = array_remove(compras, p_producto) where id = dueno;
    end if;
  end if;
  return jsonb_build_object('entregado', entregado, 'estado', p_estado, 'producto', p_producto);
end $$;

-- Pasa una compra a otra cuenta (cuando alguien perdió la suya y comprueba que pagó).
create or replace function public.reasignar_pago_web(p_id text, p_usuario uuid)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare r public.pagos_web;
begin
  select * into r from public.pagos_web where id = p_id for update;
  if not found then raise exception 'pago desconocido'; end if;
  if r.usuario is not null and r.usuario <> p_usuario then
    update public.perfiles set compras = array_remove(compras, r.producto) where id = r.usuario
      and not exists (select 1 from public.pagos_web where usuario = r.usuario and producto = r.producto and estado = 'approved' and id <> p_id);
  end if;
  update public.pagos_web set usuario = p_usuario, actualizado = now() where id = p_id;
  return public.registrar_pago_web(r.id, p_usuario, r.producto, r.estado, r.monto, r.moneda);
end $$;

revoke all on function public.precios_web_lista() from public;
revoke all on function public.registrar_pago_web(text, uuid, text, text, numeric, text) from public, anon, authenticated;
revoke all on function public.reasignar_pago_web(text, uuid) from public, anon, authenticated;
grant execute on function public.precios_web_lista() to anon, authenticated;
grant execute on function public.registrar_pago_web(text, uuid, text, text, numeric, text) to service_role;
grant execute on function public.reasignar_pago_web(text, uuid) to service_role;

-- =====================================================================
-- SALAS PÚBLICAS
-- El anfitrión de una sala pública avisa cada 15 segundos que sigue abierta.
-- La lista del inicio solo muestra salas con aviso reciente y lugares libres.
-- Una sala pública por cuenta; las viejas se borran solas.
-- =====================================================================
create table if not exists public.salas_publicas (
  codigo text primary key check (codigo ~ '^[A-Z]{4}$'),
  anfitrion uuid not null references auth.users(id) on delete cascade,
  nombre text not null check (char_length(nombre) between 1 and 16),
  jugadores int not null check (jugadores between 0 and 50),
  cupo int not null check (cupo between 2 and 12),
  estado text not null check (estado in ('espera', 'jugando')),
  modo text not null default 'clasico' check (char_length(modo) <= 20),
  actualizado timestamptz not null default now()
);
alter table public.salas_publicas enable row level security;
create index if not exists salas_publicas_actualizado on public.salas_publicas (actualizado);

create or replace function public.publicar_sala(p_codigo text, p_nombre text, p_jugadores int, p_cupo int, p_estado text, p_modo text)
returns void
language plpgsql security definer set search_path = '' as $$
declare u uuid := auth.uid(); c text := upper(btrim(coalesce(p_codigo, '')));
begin
  if u is null then raise exception 'sin sesión'; end if;
  if c !~ '^[A-Z]{4}$' then raise exception 'código inválido'; end if;
  delete from public.salas_publicas where actualizado < now() - interval '10 minutes';
  delete from public.salas_publicas where anfitrion = u and codigo <> c;
  insert into public.salas_publicas as s (codigo, anfitrion, nombre, jugadores, cupo, estado, modo, actualizado)
  values (c, u, left(coalesce(nullif(btrim(p_nombre), ''), 'Jugador'), 16),
          least(greatest(coalesce(p_jugadores, 1), 0), 50), least(greatest(coalesce(p_cupo, 8), 2), 12),
          case when p_estado = 'jugando' then 'jugando' else 'espera' end,
          left(coalesce(nullif(btrim(p_modo), ''), 'clasico'), 20), now())
  on conflict (codigo) do update set
    anfitrion = excluded.anfitrion, nombre = excluded.nombre, jugadores = excluded.jugadores, cupo = excluded.cupo,
    estado = excluded.estado, modo = excluded.modo, actualizado = now()
  where s.anfitrion = u or s.actualizado < now() - interval '1 minute';   -- nadie se adueña de la sala de otro
end $$;

create or replace function public.quitar_sala(p_codigo text)
returns void
language sql security definer set search_path = '' as $$
  delete from public.salas_publicas where codigo = upper(btrim(coalesce(p_codigo, ''))) and anfitrion = auth.uid();
$$;

create or replace function public.salas_publicas_lista()
returns jsonb
language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(jsonb_build_object('codigo', s.codigo, 'nombre', s.nombre, 'jugadores', s.jugadores, 'cupo', s.cupo,
    'estado', s.estado, 'modo', s.modo) order by (s.estado = 'espera') desc, s.jugadores desc, s.actualizado desc), '[]'::jsonb)
  from (select * from public.salas_publicas
        where actualizado > now() - interval '45 seconds' and jugadores < cupo
        order by (estado = 'espera') desc, jugadores desc, actualizado desc
        limit 30) s;
$$;

revoke all on function public.publicar_sala(text, text, int, int, text, text) from public, anon;
revoke all on function public.quitar_sala(text) from public, anon;
revoke all on function public.salas_publicas_lista() from public;
grant execute on function public.publicar_sala(text, text, int, int, text, text) to authenticated;
grant execute on function public.quitar_sala(text) to authenticated;
grant execute on function public.salas_publicas_lista() to anon, authenticated;
