# CW Inmobiliaria · Web + Portal del propietario

## Archivos

| Archivo | Qué es |
|---|---|
| `index.html` | Web de captación de propiedades. Incluye la sección "Mi portal" y enlaces al portal. |
| `portal.html` | Portal del propietario (MVP 2): panel del asesor y vista del propietario. |
| `config.js` | Configuración de Firebase. Vacía = modo demostración. |
| `firestore.rules` | Reglas de seguridad para la base de datos de Firebase. |
| `assets/` | Logo e imágenes. |

## Cómo funciona

- **Web:** `index.html`. En el menú y en el pie de página hay enlaces a "Mi portal" y "Acceso asesores".
- **Asesor:** entra a `portal.html#asesor`, crea las propiedades, actualiza la etapa, visitas, resumen y documentos, y copia el enlace personal de cada propietario.
- **Propietario:** abre su enlace `portal.html#propietario-XXXX` y ve solo su propiedad, en tiempo real.

## Modo demostración (sin configurar nada)

Si `config.js` está vacío, el portal guarda los datos en el navegador (localStorage).
Sirve para presentar el MVP, pero el asesor y el propietario solo verán los mismos datos
si usan el mismo navegador.

## Conectarlo de verdad con Firebase (gratis)

1. Entra a https://console.firebase.google.com y crea un proyecto, por ejemplo `cw-portal`.
2. **Firestore Database** → Crear base de datos → modo producción → región `southamerica-east1`.
3. En Firestore → pestaña **Reglas**, pega el contenido de `firestore.rules` y publica.
4. **Authentication** → Comenzar → habilita **Correo electrónico/contraseña**.
   En la pestaña Usuarios, agrega la cuenta del asesor (correo y contraseña).
5. **Configuración del proyecto** (ícono de engranaje) → Tus apps → agrega una app **Web** (`</>`).
   Copia el objeto `firebaseConfig` y pega sus valores en `config.js`.
6. Authentication → Configuración → **Dominios autorizados**: agrega tu dominio de Netlify
   (por ejemplo `cw-inmobiliaria.netlify.app`).

## Publicar en Netlify

1. Entra a https://app.netlify.com → Add new site → **Deploy manually**.
2. Arrastra la carpeta completa (la que contiene `index.html`).
3. Para actualizar, arrastra de nuevo la carpeta en la pestaña **Deploys**.

## Notas de seguridad del MVP

- El enlace de cada propietario lleva un código aleatorio difícil de adivinar; quien tenga el enlace puede ver esa propiedad.
- Solo el asesor con sesión iniciada puede editar o ver la lista completa de propiedades.
- Para una versión final se recomienda dar a cada propietario su propia cuenta de acceso.
