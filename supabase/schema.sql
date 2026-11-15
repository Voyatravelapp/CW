-- ============================================================
-- CW Inmobiliaria · Portal del propietario
-- Esquema para Supabase (PostgreSQL)
--
-- Cómo usarlo:
--   1. Supabase → SQL Editor → New query
--   2. Pega TODO este archivo y pulsa Run
--   3. Crea el usuario asesor en Authentication → Users
--   4. Si el correo del asesor no es el de la línea "insert into
--      public.asesores", cámbialo aquí y vuelve a ejecutar solo esa línea.
--
-- El script es idempotente: se puede ejecutar más de una vez sin romper nada.
-- ============================================================

create extension if not exists pgcrypto;

-- ------------------------------------------------------------
-- 1. Tablas
-- ------------------------------------------------------------

-- Una fila por propiedad. El id es el "token" del enlace personal del
-- propietario (se genera aleatoriamente en el navegador del asesor).
create table if not exists public.propiedades (
  id                text primary key,
  propietario       text        not null default '',
  propietario_email text        not null default '',
  asesor_whatsapp   text        not null default '',
  propiedad         text        not null default '',
  direccion         text        not null default '',
  etapa             smallint    not null default 0 check (etapa between 0 and 5),
  interesados       integer     not null default 0 check (interesados >= 0),
  propuestas        integer     not null default 0 check (propuestas >= 0),
  resumen           text        not null default '',
  resumen_fecha     date,
  visitas           jsonb       not null default '[]'::jsonb check (jsonb_typeof(visitas) = 'array'),
  documentos        jsonb       not null default '[]'::jsonb check (jsonb_typeof(documentos) = 'array'),
  actualizado       timestamptz not null default now(),
  creado_en         timestamptz not null default now()
);

-- Si la tabla ya existía de una versión anterior, agrega las columnas sin perder datos.
alter table public.propiedades
  add column if not exists propietario_email text not null default '';
alter table public.propiedades
  add column if not exists asesor_whatsapp text not null default '';

create index if not exists propiedades_actualizado_idx
  on public.propiedades (actualizado desc);

create index if not exists propiedades_propietario_email_idx
  on public.propiedades (lower(propietario_email));

-- Chat entre asesor y propietario, una fila por mensaje.
create table if not exists public.mensajes (
  id            text primary key,
  propiedad_id  text not null references public.propiedades(id) on delete cascade,
  de            text not null check (de in ('asesor', 'propietario')),
  texto         text not null check (char_length(texto) between 1 and 1000),
  fecha         timestamptz not null default now()
);

create index if not exists mensajes_propiedad_fecha_idx
  on public.mensajes (propiedad_id, fecha);

-- Lista blanca de correos que pueden administrar el portal.
-- No se expone por la API a clientes: solo admins la gestionan y es_asesor() la lee.
create table if not exists public.asesores (
  email      text primary key,
  rol        text not null default 'asesor' check (rol in ('admin', 'asesor')),
  creado_en  timestamptz not null default now()
);

alter table public.asesores
  add column if not exists rol text not null default 'asesor';

-- ------------------------------------------------------------
-- 2. Actualización automática de la fecha "actualizado"
-- ------------------------------------------------------------

create or replace function public.cw_set_actualizado()
returns trigger
language plpgsql
as $$
begin
  new.actualizado := now();
  return new;
end;
$$;

drop trigger if exists propiedades_set_actualizado on public.propiedades;
create trigger propiedades_set_actualizado
  before update on public.propiedades
  for each row execute function public.cw_set_actualizado();

-- ------------------------------------------------------------
-- 3. ¿El usuario que hace la petición es asesor?
-- ------------------------------------------------------------
-- Compara el correo del JWT de Supabase con la lista blanca asesores.
-- Es SECURITY DEFINER para poder leer asesores aunque la tabla esté
-- cerrada al público.

create or replace function public.es_asesor()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.asesores a
    where lower(a.email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  );
$$;

create or replace function public.es_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.asesores a
    where lower(a.email) = lower(coalesce(auth.jwt() ->> 'email', ''))
      and a.rol = 'admin'
  );
$$;

create or replace function public.mi_rol()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (select a.rol
     from public.asesores a
     where lower(a.email) = lower(coalesce(auth.jwt() ->> 'email', ''))
     limit 1),
    'propietario'
  );
$$;

revoke all on function public.es_asesor() from public;
grant execute on function public.es_asesor() to anon, authenticated;

revoke all on function public.es_admin() from public;
grant execute on function public.es_admin() to anon, authenticated;

revoke all on function public.mi_rol() from public;
grant execute on function public.mi_rol() to anon, authenticated;

-- ------------------------------------------------------------
-- 4. Row Level Security (RLS)
-- ------------------------------------------------------------

alter table public.propiedades enable row level security;
alter table public.mensajes    enable row level security;
alter table public.asesores    enable row level security;

-- Propiedades: lectura privada (solo el asesor o el propietario autenticado con su correo).
drop policy if exists "propiedades_lectura_publica" on public.propiedades;
drop policy if exists "propiedades_lectura_privada" on public.propiedades;
create policy "propiedades_lectura_privada"
  on public.propiedades
  for select
  to authenticated
  using (
    public.es_asesor()
    or (
      propietario_email <> ''
      and lower(propietario_email) = lower(coalesce(auth.jwt() ->> 'email', ''))
    )
  );

-- Propiedades: solo un asesor de la lista blanca puede crear/editar/borrar.
drop policy if exists "propiedades_escritura_asesor" on public.propiedades;
create policy "propiedades_escritura_asesor"
  on public.propiedades
  for all
  to authenticated
  using (public.es_asesor())
  with check (public.es_asesor());

-- Mensajes: lectura privada (solo el asesor o el propietario dueño de la propiedad).
drop policy if exists "mensajes_lectura_publica" on public.mensajes;
drop policy if exists "mensajes_lectura_privada" on public.mensajes;
create policy "mensajes_lectura_privada"
  on public.mensajes
  for select
  to authenticated
  using (
    public.es_asesor()
    or exists (
      select 1
      from public.propiedades p
      where p.id = mensajes.propiedad_id
        and p.propietario_email <> ''
        and lower(p.propietario_email) = lower(coalesce(auth.jwt() ->> 'email', ''))
    )
  );

-- Mensajes: el propietario autenticado solo puede escribir en su propia propiedad.
drop policy if exists "mensajes_envio_propietario" on public.mensajes;
create policy "mensajes_envio_propietario"
  on public.mensajes
  for insert
  to authenticated
  with check (
    de = 'propietario'
    and char_length(texto) between 1 and 1000
    and exists (
      select 1
      from public.propiedades p
      where p.id = mensajes.propiedad_id
        and p.propietario_email <> ''
        and lower(p.propietario_email) = lower(coalesce(auth.jwt() ->> 'email', ''))
    )
  );

-- Mensajes: el asesor escribe como "asesor".
drop policy if exists "mensajes_envio_asesor" on public.mensajes;
create policy "mensajes_envio_asesor"
  on public.mensajes
  for insert
  to authenticated
  with check (
    de = 'asesor'
    and public.es_asesor()
    and char_length(texto) between 1 and 1000
  );

-- Mensajes: el asesor puede moderar (editar/borrar).
drop policy if exists "mensajes_moderacion_asesor" on public.mensajes;
create policy "mensajes_moderacion_asesor"
  on public.mensajes
  for update
  to authenticated
  using (public.es_asesor())
  with check (public.es_asesor());

drop policy if exists "mensajes_borrado_asesor" on public.mensajes;
create policy "mensajes_borrado_asesor"
  on public.mensajes
  for delete
  to authenticated
  using (public.es_asesor());

-- Asesores: solo un administrador (rol = 'admin') puede ver y gestionar la lista de asesores.
drop policy if exists "asesores_gestion_admin" on public.asesores;
create policy "asesores_gestion_admin"
  on public.asesores
  for all
  to authenticated
  using (public.es_admin())
  with check (public.es_admin());

-- ------------------------------------------------------------
-- 5. Permisos de las tablas
-- ------------------------------------------------------------

grant usage on schema public to anon, authenticated;

revoke all on public.propiedades from anon;
revoke all on public.mensajes    from anon;
revoke all on public.asesores    from anon;

grant select on public.propiedades to authenticated;
grant insert, update, delete on public.propiedades to authenticated;

grant select, insert on public.mensajes to authenticated;
grant update, delete on public.mensajes to authenticated;

grant select, insert, update, delete on public.asesores to authenticated;

-- ------------------------------------------------------------
-- 6. Realtime (el portal se actualiza sin recargar)
-- ------------------------------------------------------------

-- "full" permite que Realtime entregue también los DELETE.
alter table public.propiedades replica identity full;
alter table public.mensajes    replica identity full;

do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = 'propiedades'
    ) then
      alter publication supabase_realtime add table public.propiedades;
    end if;

    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = 'mensajes'
    ) then
      alter publication supabase_realtime add table public.mensajes;
    end if;
  end if;
end;
$$;

-- ------------------------------------------------------------
-- 7. Correo del asesor
-- ------------------------------------------------------------
-- ⚠️ Debe coincidir con el correo del usuario que crearás en
-- Authentication → Users. Si usas otro, cambia esta línea.

insert into public.asesores (email, rol)
values ('cwinmobiliariasac@gmail.com', 'admin')
on conflict (email) do update set rol = 'admin';

-- Refresca la caché de PostgREST para que las tablas aparezcan de inmediato.
notify pgrst, 'reload schema';
