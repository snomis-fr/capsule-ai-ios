import "jsr:@supabase/functions-js/edge-runtime.d.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
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
      user_id,
      workspace_id,
      first_name,
      last_name,
      title,
      city,
      status,
      avatar_base64,
      sub_space_ids,
    } = body as {
      user_id?: string
      workspace_id?: string
      first_name?: string
      last_name?: string
      title?: string
      city?: string
      status?: string
      avatar_base64?: string
      sub_space_ids?: string[]
    }

    if (!user_id) {
      return new Response(
        JSON.stringify({ error: "user_id requis" }),
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

    const { data: collabProfile } = await supabaseAdmin
      .from("profiles")
      .select("workspace_id")
      .eq("id", user_id)
      .single()

    if (!collabProfile?.workspace_id) {
      return new Response(
        JSON.stringify({ error: "Collaborateur ou workspace non trouvé" }),
        { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    const wsId = workspace_id ?? collabProfile.workspace_id

    const { data: workspace } = await supabaseAdmin
      .from("workspaces")
      .select("id")
      .eq("id", wsId)
      .eq("manager_id", user.id)
      .single()

    if (!workspace) {
      return new Response(
        JSON.stringify({ error: "Vous n'êtes pas le manager de ce collaborateur" }),
        { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    // Avatar : upload si fourni
    if (avatar_base64) {
      const path = `${user_id.toLowerCase()}/avatar.jpg`
      const buf = Uint8Array.from(atob(avatar_base64), (c) => c.charCodeAt(0))
      const { error: uploadErr } = await supabaseAdmin.storage
        .from("avatars")
        .upload(path, buf, { contentType: "image/jpeg", upsert: true })
      if (uploadErr) {
        return new Response(
          JSON.stringify({ error: "Erreur upload avatar: " + uploadErr.message }),
          { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        )
      }
      const { data: urlData } = supabaseAdmin.storage.from("avatars").getPublicUrl(path)
      await supabaseAdmin.from("profiles").update({ avatar_url: urlData.publicUrl }).eq("id", user_id).select().single()
    }

    // Profil
    const profileUpdate: Record<string, unknown> = {}
    if (first_name !== undefined) profileUpdate.first_name = first_name || null
    if (last_name !== undefined) profileUpdate.last_name = last_name || null
    if (title !== undefined) profileUpdate.title = title || null
    if (city !== undefined) profileUpdate.city = city || null
    if (status !== undefined && ["none", "available", "vacation", "sick"].includes(status)) {
      profileUpdate.status = status
    }

    if (Object.keys(profileUpdate).length > 0) {
      await supabaseAdmin.from("profiles").update(profileUpdate).eq("id", user_id).select().single()
    }

    // Droits d'accès : remplacement complet si sub_space_ids fourni
    if (Array.isArray(sub_space_ids)) {
      await supabaseAdmin.from("collaborator_access").delete().eq("workspace_id", wsId).eq("user_id", user_id)
      for (const subId of sub_space_ids) {
        if (!subId) continue
        await supabaseAdmin.from("collaborator_access").insert({
          workspace_id: wsId,
          user_id,
          sub_space_id: subId,
          can_read: true,
          can_write: true,
        })
      }
    }

    return new Response(
      JSON.stringify({ success: true, message: "Profil mis à jour" }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    )
  } catch (err) {
    return new Response(
      JSON.stringify({ error: String(err) }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    )
  }
})
