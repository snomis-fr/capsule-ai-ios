import "jsr:@supabase/functions-js/edge-runtime.d.ts"

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
}

const SYSTEM_PROMPT = `Tu es Capsule, un coach IA pour managers. Tu as accès aux notes de l'utilisateur. Aide-le à prioriser, synthétiser et prendre des décisions. Réponds en français, sois concis et actionnable. Ne fais jamais référence au fait que tu es une IA.`

async function callClaude(messages: { role: string; content: string }[], contextNotes: string): Promise<string> {
  const apiKey = Deno.env.get("ANTHROPIC_API_KEY")
  if (!apiKey) throw new Error("Clé API Anthropic non configurée")

  const contextBlock = contextNotes
    ? `\n\nContexte - notes de l'utilisateur (les 20 plus récentes, non privées) :\n${contextNotes}\n\n`
    : ""

  const systemContent = SYSTEM_PROMPT + contextBlock

  const controller = new AbortController()
  const timeout = setTimeout(() => controller.abort(), 60000)

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
        max_tokens: 2048,
        system: systemContent,
        messages: messages.map((m) => ({ role: m.role as "user" | "assistant", content: m.content })),
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
    return block?.text ?? ""
  } catch (e) {
    clearTimeout(timeout)
    if (e instanceof Error && e.name === "AbortError") {
      throw new Error("Délai d'attente dépassé")
    }
    throw e
  }
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

    const token = authHeader.replace("Bearer ", "")
    const { createClient } = await import("https://esm.sh/@supabase/supabase-js@2")
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      { global: { headers: { Authorization: authHeader } } }
    )

    const { data: { user }, error: authError } = await supabase.auth.getUser(token)
    if (authError || !user) {
      return new Response(
        JSON.stringify({ error: "Session invalide ou expirée" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    const body = (await req.json()) as {
      messages?: { role: string; content: string }[]
      contextNotes?: string
    }

    const messages = Array.isArray(body.messages) ? body.messages : []
    const contextNotes = typeof body.contextNotes === "string" ? body.contextNotes : ""

    if (messages.length === 0) {
      return new Response(
        JSON.stringify({ error: "Aucun message fourni" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    const reply = await callClaude(messages, contextNotes)

    return new Response(
      JSON.stringify({ reply }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    )
  } catch (err) {
    const msg = err instanceof Error ? err.message : "Erreur serveur"
    return new Response(
      JSON.stringify({ error: msg }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    )
  }
})
