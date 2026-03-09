import "jsr:@supabase/functions-js/edge-runtime.d.ts"

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  try {
    const authHeader = req.headers.get("Authorization")
    if (!authHeader?.startsWith("Bearer ")) {
      return new Response(
        JSON.stringify({ error: "Authentification requise" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    const { createClient } = await import("https://esm.sh/@supabase/supabase-js@2")
    const supabaseUser = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      { global: { headers: { Authorization: authHeader } } }
    )

    const token = authHeader.replace("Bearer ", "")
    const { data: { user }, error: authError } = await supabaseUser.auth.getUser(token)

    if (authError || !user) {
      return new Response(
        JSON.stringify({ error: "Session invalide ou expirée" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    const body = (await req.json()) as { noteId?: string; title?: string; content?: string }
    const noteId = body.noteId
    const title = typeof body.title === "string" ? body.title : ""
    const content = typeof body.content === "string" ? body.content : ""

    if (!noteId) {
      return new Response(
        JSON.stringify({ error: "noteId requis" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    const apiKey = Deno.env.get("ANTHROPIC_API_KEY")
    if (!apiKey) {
      return new Response(
        JSON.stringify({ error: "Configuration IA manquante" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    const input = [title, content].filter(Boolean).join("\n\n")
    if (!input.trim()) {
      await createClient(
        Deno.env.get("SUPABASE_URL") ?? "",
        Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
      )
        .from("notes")
        .update({ ai_summary: null })
        .eq("id", noteId)
        .execute()
      return new Response(
        JSON.stringify({ summary: null }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json; charset=utf-8" } }
      )
    }

    const controller = new AbortController()
    const timeout = setTimeout(() => controller.abort(), 15000)

    try {
      const response = await fetch("https://api.anthropic.com/v1/messages", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "x-api-key": apiKey,
          "anthropic-version": "2023-06-01",
        },
        body: JSON.stringify({
          model: "claude-sonnet-4-20250514",
          max_tokens: 200,
          system:
            "Tu es un assistant qui résume des notes professionnelles. Génère un résumé concis de 2-3 lignes maximum, en français. Sois factuel et actionnable. Réponds UNIQUEMENT avec le résumé, sans préambule ni guillemets.",
          messages: [{ role: "user", content: input }],
        }),
        signal: controller.signal,
      })

      clearTimeout(timeout)

      if (!response.ok) {
        const err = await response.text()
        throw new Error(`API Anthropic : ${response.status} - ${err}`)
      }

      const data = await response.json()
      const block = data.content?.find((b: { type: string }) => b.type === "text")
      const summary = (block?.text ?? "").trim()

      const supabaseAdmin = createClient(
        Deno.env.get("SUPABASE_URL") ?? "",
        Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
      )

      await supabaseAdmin
        .from("notes")
        .update({ ai_summary: summary || null })
        .eq("id", noteId)
        .execute()

      return new Response(
        JSON.stringify({ summary }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json; charset=utf-8" } }
      )
    } catch (e) {
      clearTimeout(timeout)
      const msg = e instanceof Error ? e.message : "Erreur lors de la génération du résumé"
      return new Response(
        JSON.stringify({ error: msg }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }
  } catch (err) {
    const msg = err instanceof Error ? err.message : "Erreur serveur"
    return new Response(
      JSON.stringify({ error: msg }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    )
  }
})
