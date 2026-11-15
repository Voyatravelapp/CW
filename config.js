// Configuración de Supabase para el Portal del propietario.
//
// La "publishable key" (antes llamada anon key) está diseñada para usarse en
// el navegador: es pública. La seguridad real la ponen las políticas RLS
// incluidas en supabase/schema.sql.
//
// Si dejas los valores vacíos, el portal arranca en MODO DEMOSTRACIÓN y
// guarda los datos solo en este navegador (localStorage).
window.CW_SUPABASE_CONFIG = {
  url: "https://ydchxlitxphyqfpieeou.supabase.co",
  anonKey: "sb_publishable_lKt51F6VmrkRMvj9zyMwhA_X-qLPs6X"
};
