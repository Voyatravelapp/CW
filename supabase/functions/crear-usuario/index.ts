// Edge Function de Supabase para crear usuarios (Admin, Asesor o Propietario)
// desde el Panel Admin sin cerrar la sesión del administrador.
//
// Despliegue:
//   supabase functions deploy crear-usuario --no-verify-jwt
// (La verificación del JWT y del rol admin se realiza explícitamente abajo).

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

    const authHeader = req.headers.get("Authorization") ?? "";
    if (!authHeader) {
      return json({ error: "Falta cabecera de autorización." }, 401);
    }

    // 1. Verificar que quien llama es un administrador autenticado.
    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });

    const { data: userData, error: userErr } = await userClient.auth.getUser();
    if (userErr || !userData?.user) {
      return json({ error: "Sesión inválida o expirada." }, 401);
    }

    const { data: isAdmin, error: adminErr } = await userClient.rpc("es_admin");
    if (adminErr || !isAdmin) {
      return json({ error: "Solo un administrador puede crear usuarios." }, 403);
    }

    // 2. Validar datos de entrada.
    const body = await req.json();
    const email = String(body.email ?? "").trim().toLowerCase();
    const password = String(body.password ?? "");
    const rol = String(body.rol ?? "propietario").toLowerCase();
    const propiedadId = body.propiedadId ? String(body.propiedadId).trim() : "";

    if (!email || !email.includes("@")) {
      return json({ error: "Ingresa un correo válido." }, 400);
    }
    if (password.length < 6) {
      return json({ error: "La contraseña debe tener al menos 6 caracteres." }, 400);
    }
    if (!["admin", "asesor", "propietario"].includes(rol)) {
      return json({ error: "Rol inválido." }, 400);
    }

    // 3. Crear el usuario en Supabase Auth con confirmación automática.
    const adminClient = createClient(supabaseUrl, serviceKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    });

    const { data: created, error: createErr } = await adminClient.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: { rol },
    });

    if (createErr) {
      return json({ error: createErr.message || "No se pudo crear el usuario." }, 400);
    }

    // 4. Registrar rol en asesores o vincular propiedad si corresponde.
    if (rol === "admin" || rol === "asesor") {
      const { error: aErr } = await adminClient
        .from("asesores")
        .upsert({ email, rol }, { onConflict: "email" });
      if (aErr) return json({ error: aErr.message }, 500);
    } else if (propiedadId) {
      const { error: pErr } = await adminClient
        .from("propiedades")
        .update({ propietario_email: email })
        .eq("id", propiedadId);
      if (pErr) return json({ error: pErr.message }, 500);
    }

    return json({
      ok: true,
      user: { id: created.user?.id, email, rol },
    }, 200);
  } catch (err) {
    return json({ error: String(err) }, 500);
  }
});

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
