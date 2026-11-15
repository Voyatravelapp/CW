-- Vitrina: fotos reales de propiedades CW (noviembre 2026)
-- Ejecutar una vez en Supabase > SQL Editor.
-- Agrega las 3 propiedades con fotos reales al inicio de la vitrina
-- y oculta las 4 tarjetas que usaban flyers de Instagram.
-- Ocultar no borra: se pueden volver a mostrar desde el Panel Admin.

insert into public.vitrina_propiedades
  (id, titulo, distrito, etiqueta, descripcion, imagenes, usar_carrusel, orden, visible)
values
  ('vit_los_fresnos', 'Casa de un piso con cochera', 'Los Fresnos', 'EN VENTA',
   'Fachada amplia, jardín al frente y cochera con portón de madera.',
   '["assets/propiedades/casa-los-fresnos.webp"]'::jsonb, false, 1, true),
  ('vit_brisas_de_villa', 'Casa moderna con jardín', 'Brisas de Villa', 'RESERVADA',
   'Tres pisos, terraza y jardín de ingreso en condominio cerca a la playa.',
   '["assets/propiedades/casa-brisas-de-villa.webp"]'::jsonb, false, 2, true),
  ('vit_los_olivos_local', 'Local comercial con portón', 'Los Olivos', 'EN VENTA',
   'Terreno cercado con ingreso vehicular, en zona comercial de Los Olivos.',
   '["assets/propiedades/local-comercial-los-olivos.webp"]'::jsonb, false, 3, true)
on conflict (id) do update set
  titulo = excluded.titulo, distrito = excluded.distrito, etiqueta = excluded.etiqueta,
  descripcion = excluded.descripcion, imagenes = excluded.imagenes,
  orden = excluded.orden, visible = excluded.visible;

update public.vitrina_propiedades
   set visible = false
 where id in ('vit_la_molina', 'vit_san_borja', 'vit_surco', 'vit_pueblo_libre');
