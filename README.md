# CW Inmobiliaria · Web + Portal del propietario

Sitio estático (HTML/CSS/JS, sin build) con dos pantallas:

| Archivo | Qué es |
|---|---|
| `index.html` | Web de captación de propiedades. El formulario arma el mensaje y abre WhatsApp. |
| `portal.html` | Portal del propietario: panel del asesor + vista del propietario. |
| `config.js` | URL y publishable key de Supabase. Si está vacío, el portal usa el modo demostración. |
| `supabase/schema.sql` | Tablas, permisos, RLS y Realtime para Supabase. |
| `scripts/dev-server.mjs` | Servidor local sin dependencias. |
| `assets/` | Logo e imágenes. |

## Estado actual

- La web de captación está completa y es responsive.
- El portal tiene el flujo completo: crear propiedad, editar etapa, visitas, resumen, documentos, chat, enlace personal del propietario y vista en tiempo real.
- **La capa de datos fue migrada de Firebase a Supabase.** El código ya escribe y escucha cambios con `supabase-js`.
- La base de Supabase del proyecto está vacía: falta ejecutar `supabase/schema.sql` y crear el usuario asesor.
- Hasta que hagas esos dos pasos, puedes ver el portal con datos de ejemplo usando `?demo=1`.

## Correr en local

No necesita `npm install` (no hay dependencias).

```bash
cd /home/mp/Escritorio/CW
npm run dev
```

Abre:

- Web: <http://localhost:5173/>
- Portal: <http://localhost:5173/portal.html>
- Portal en modo demostración (sin Supabase): <http://localhost:5173/portal.html?demo=1>

También puedes usar `python3 -m http.server 5173` si prefieres.

## Conectar Supabase (una sola vez)

La URL y la publishable key ya están en `config.js`:

```js
window.CW_SUPABASE_CONFIG = {
  url: "https://ydchxlitxphyqfpieeou.supabase.co",
  anonKey: "sb_publishable_..."
};
```

La publishable key es pública por diseño; la seguridad la aplican las políticas RLS del SQL.

### 1. Crear las tablas

1. Entra al proyecto en <https://supabase.com/dashboard>.
2. **SQL Editor** → **New query**.
3. Pega todo el contenido de `supabase/schema.sql`.
4. Pulsa **Run**.

El script crea:

- `propiedades`: una fila por propiedad (etapa, visitas, resumen, documentos, etc.).
- `mensajes`: chat asesor ↔ propietario.
- `asesores`: lista blanca de correos que pueden administrar el portal.
- Políticas RLS, índices, trigger de `actualizado` y Realtime.

Es idempotente: puedes volver a ejecutarlo sin romper nada.

### 2. Crear el usuario asesor

1. **Authentication** → **Users** → **Add user** → **Create new user**.
2. Usa el correo que está en `supabase/schema.sql`:
   `cwinmobiliariasac@gmail.com`
3. Define una contraseña y marca **Auto Confirm User**
   (si no, el usuario no podrá iniciar sesión hasta confirmar el correo).

Si quieres usar otro correo, haz dos cosas:

1. Crea el usuario con ese correo en Authentication.
2. En el SQL Editor ejecuta:

```sql
insert into public.asesores (email)
values ('tu-correo@gmail.com')
on conflict (email) do nothing;
```

El correo del usuario de Authentication y el de `asesores` deben coincidir.

### 3. Probar

1. Abre <http://localhost:5173/portal.html#asesor>.
2. Inicia sesión con el usuario asesor.
3. Crea una propiedad (o usa **Crear propiedad de ejemplo**).
4. Pulsa **Copiar enlace del propietario** y ábrelo en una ventana incógnita.
5. Cambia la etapa o envía un mensaje: la vista del propietario se actualiza sin recargar.

> Si ves el aviso de que faltan tablas, vuelve al paso 1. Si al guardar dice "solo lectura", revisa que el correo del usuario esté en `public.asesores`.

## Cómo está protegido

- **Asesor:** inicia sesión con Supabase Auth. Solo los correos de `public.asesores` pueden crear, editar o borrar propiedades y moderar mensajes.
- **Propietario:** entra con su enlace personal (`portal.html#propietario-<id>`), sin cuenta. Puede leer su propiedad y escribir mensajes como `propietario`.
- **IDs aleatorios:** los enlaces usan un UUID aleatorio, no un contador predecible.
- **RLS:** aunque alguien tenga la publishable key, no puede escribir sin ser asesor de la lista blanca.

Limitación conocida del MVP: la lectura es pública para que el enlace del propietario funcione sin login. Alguien con la publishable key y conocimientos técnicos podría listar propiedades o mensajes por API. Para una versión final se recomienda dar a cada propietario su propia cuenta (Supabase Auth) y cambiar las políticas de lectura a "solo el dueño de la propiedad o un asesor".

## Publicar en Netlify

1. Entra a <https://app.netlify.com> → **Add new site** → **Deploy manually**.
2. Arrastra la carpeta completa del proyecto.
3. Para actualizar, arrastra de nuevo la carpeta en **Deploys**.

No hay build. `config.js` ya lleva la configuración de Supabase.

## Próximos pasos sugeridos

- Guardar las solicitudes de tasación de `index.html` en una tabla `solicitudes` y mostrarlas en el panel del asesor.
- Dar cuentas propias a los propietarios y cerrar la lectura pública.
- Subir documentos a Supabase Storage en lugar de pegar enlaces externos.
- Notificaciones por correo o WhatsApp cuando cambie la etapa.
