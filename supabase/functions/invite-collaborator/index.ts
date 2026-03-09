import "jsr:@supabase/functions-js/edge-runtime.d.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
}

function randomPassword(): string {
  const chars = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789!@#$%"
  let s = ""
  for (let i = 0; i < 24; i++) s += chars.charAt(Math.floor(Math.random() * chars.length))
  return s
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  try {
    const supabaseClient = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      {
        global: { headers: { Authorization: req.headers.get("Authorization")! } },
      }
    )
    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    )

    const body = await req.json()
    const {
      email,
      workspace_id,
      sub_space_id,
      first_name,
      last_name,
      title,
      city,
      status,
    } = body as {
      email?: string
      workspace_id?: string
      sub_space_id?: string
      first_name?: string
      last_name?: string
      title?: string
      city?: string
      status?: string
    }

    if (!email || !workspace_id || !sub_space_id) {
      return new Response(
        JSON.stringify({ error: "email, workspace_id et sub_space_id requis" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    const { data: { user } } = await supabaseClient.auth.getUser()
    if (!user) {
      return new Response(
        JSON.stringify({ error: "Non authentifié" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    const { data: workspace } = await supabaseAdmin
      .from("workspaces")
      .select("id")
      .eq("id", workspace_id)
      .eq("manager_id", user.id)
      .single()

    if (!workspace) {
      return new Response(
        JSON.stringify({ error: "Workspace non trouvé ou vous n'êtes pas le manager" }),
        { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    const { data: count } = await supabaseAdmin
      .from("collaborator_access")
      .select("user_id")
      .eq("workspace_id", workspace_id)
    const unique = new Set(count?.map((r: { user_id: string }) => r.user_id) ?? [])
    if (unique.size >= 7) {
      return new Response(
        JSON.stringify({ error: "Maximum 7 collaborateurs atteint" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    const { data: existingProfile } = await supabaseAdmin
      .from("profiles")
      .select("id")
      .eq("email", email.toLowerCase())
      .single()

    if (existingProfile) {
      // Utilisateur déjà inscrit : mise à jour profil puis ajout à collaborator_access
      const profileUpdate: Record<string, unknown> = {
        workspace_id,
        role: "collaborator",
      }
      if (first_name != null) profileUpdate.first_name = first_name || null
      if (last_name != null) profileUpdate.last_name = last_name || null
      if (title != null) profileUpdate.title = title || null
      if (city != null) profileUpdate.city = city || null
      if (status != null && ["none", "available", "vacation", "sick"].includes(status)) {
        profileUpdate.status = status
      }

      await supabaseAdmin
        .from("profiles")
        .update(profileUpdate)
        .eq("id", existingProfile.id)
        .select()
        .single()

      const { data: existingAccess } = await supabaseAdmin
        .from("collaborator_access")
        .select("user_id")
        .eq("workspace_id", workspace_id)
        .eq("user_id", existingProfile.id)
        .single()

      if (!existingAccess) {
        await supabaseAdmin.from("collaborator_access").insert({
          workspace_id,
          user_id: existingProfile.id,
          sub_space_id,
          can_read: true,
          can_write: true,
        })
      } else {
        await supabaseAdmin
          .from("collaborator_access")
          .update({ sub_space_id })
          .eq("workspace_id", workspace_id)
          .eq("user_id", existingProfile.id)
      }

      return new Response(
        JSON.stringify({ success: true, message: "Collaborateur ajouté" }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    // Nouvel utilisateur : création directe par le manager (sans invitation email)
    const password = randomPassword()
    const { data: newUser, error: createError } = await supabaseAdmin.auth.admin.createUser({
      email: email.toLowerCase(),
      password,
      email_confirm: true,
      user_metadata: {
        given_name: first_name ?? "",
        family_name: last_name ?? "",
      },
    })

    if (createError || !newUser.user) {
      return new Response(
        JSON.stringify({ error: createError?.message ?? "Erreur lors de la création de l'utilisateur" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    // handle_new_user crée le profil ; on met à jour avec les champs complémentaires
    const profileUpdate: Record<string, unknown> = {
      first_name: first_name ?? null,
      last_name: last_name ?? null,
      title: title ?? null,
      city: city ?? null,
      status: status && ["none", "available", "vacation", "sick"].includes(status) ? status : "none",
      workspace_id,
      role: "collaborator",
    }

    await supabaseAdmin
      .from("profiles")
      .update(profileUpdate)
      .eq("id", newUser.user.id)
      .select()
      .single()

    await supabaseAdmin.from("collaborator_access").insert({
      workspace_id,
      user_id: newUser.user.id,
      sub_space_id,
      can_read: true,
      can_write: true,
    })

    return new Response(
      JSON.stringify({ success: true, message: "Collaborateur créé" }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    )
  } catch (err) {
    return new Response(
      JSON.stringify({ error: String(err) }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    )
  }
})
