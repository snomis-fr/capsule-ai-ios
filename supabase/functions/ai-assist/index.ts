import "jsr:@supabase/functions-js/edge-runtime.d.ts"

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
}

type Action = "summarize" | "structure" | "generate"

const SYSTEM_PROMPTS: Record<Action, string> = {
  summarize:
    `Tu es un assistant exécutif. Résume le texte en 3 points clés maximum, en français. Sois concis et actionnable.
IMPORTANT : Retourne UNIQUEMENT du HTML riche, sans préambule. Utilise des titres et listes pour un rendu visuel soigné.
Exemple de format attendu :
<h3>Résumé en 3 points</h3>
<ul>
<li><strong>Point 1 :</strong> Texte court et impactant</li>
<li><strong>Point 2 :</strong> Texte court et impactant</li>
<li><strong>Point 3 :</strong> Texte court et impactant</li>
</ul>`,
  structure:
    `Tu es un consultant senior. Restructure le texte en sections claires avec une mise en forme professionnelle. Garde tout le contenu original mais améliore la lisibilité.
IMPORTANT : Retourne UNIQUEMENT du HTML riche compatible Tiptap, sans préambule. Utilise : h2 pour les sections principales, h3 pour les sous-sections, p pour les paragraphes, ul/ol et li pour les listes, strong pour les mots clés, blockquote pour les citations éventuelles.`,
  generate:
    `Tu es un assistant de rédaction professionnel. À partir du contexte et du contenu, génère du contenu complémentaire pertinent en français. Propose des idées, développe les points clés, ajoute des recommandations.
IMPORTANT : Retourne UNIQUEMENT du HTML riche, sans préambule. Structure le contenu avec des titres (h2, h3), des paragraphes (p), des listes à puces ou numérotées (ul, ol, li), et du texte en gras (strong) pour les points importants.`,
}

async function callClaude(content: string, systemPrompt: string): Promise<string> {
  const apiKey = Deno.env.get("ANTHROPIC_API_KEY")
  if (!apiKey) {
    throw new Error("Clé API Anthropic non configurée")
  }

  const controller = new AbortController()
  const timeout = setTimeout(() => controller.abort(), 30000)

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
        max_tokens: 4096,
        system: systemPrompt,
        messages: [{ role: "user", content }],
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
    if (e instanceof Error) {
      if (e.name === "AbortError") throw new Error("Délai d'attente dépassé (30 s)")
      throw e
    }
    throw new Error("Erreur inconnue lors de l'appel à l'IA")
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

    const { createClient } = await import("https://esm.sh/@supabase/supabase-js@2")
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      { global: { headers: { Authorization: authHeader } } }
    )

    const token = authHeader.replace("Bearer ", "")
    const { data: { user }, error: authError } = await supabase.auth.getUser(token)

    if (authError || !user) {
      return new Response(
        JSON.stringify({ error: "Session invalide ou expirée" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    const body = (await req.json()) as {
      action?: string
      content?: string
      context?: string
    }

    const action = body.action as Action | undefined
    const content = typeof body.content === "string" ? body.content : ""
    const context = typeof body.context === "string" ? body.context : ""

    if (!action || !["summarize", "structure", "generate"].includes(action)) {
      return new Response(
        JSON.stringify({ error: "Action invalide. Utilisez summarize, structure ou generate." }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    const systemPrompt = SYSTEM_PROMPTS[action]
    let input = content
    if (action === "generate" && context) {
      input = `Contexte : ${context}\n\nContenu actuel :\n${content}`
    }

    let result: string
    try {
      result = await callClaude(input, systemPrompt)
    } catch (retryErr) {
      try {
        result = await callClaude(input, systemPrompt)
      } catch (e) {
        const msg = e instanceof Error ? e.message : "Erreur lors du traitement par l'IA"
        return new Response(
          JSON.stringify({ error: msg }),
          { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        )
      }
    }

    return new Response(JSON.stringify({ result }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json; charset=utf-8" },
    })
  } catch (err) {
    const msg = err instanceof Error ? err.message : "Erreur serveur"
    return new Response(
      JSON.stringify({ error: msg }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    )
  }
})
