import "jsr:@supabase/functions-js/edge-runtime.d.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import * as jose from "npm:jose@5"

const BUNDLE_ID = "com.ippon.capsule"
const APNS_SANDBOX = "https://api.sandbox.push.apple.com"
const APNS_PRODUCTION = "https://api.push.apple.com"

interface NoteRecord {
  id: string
  workspace_id: string
  sub_space_id: string
  title: string
  created_by: string
  last_modified_by?: string | null
}

interface WebhookPayload {
  type: "INSERT" | "UPDATE" | "DELETE"
  table: string
  record: NoteRecord
  old_record: NoteRecord | null
  schema: string
}

async function signApnsJwt(): Promise<string> {
  const keyId = Deno.env.get("APNS_KEY_ID")
  const teamId = Deno.env.get("APNS_TEAM_ID")
  const keyP8 = Deno.env.get("APNS_KEY_P8")
  if (!keyId || !teamId || !keyP8) {
    throw new Error("APNS_KEY_ID, APNS_TEAM_ID, APNS_KEY_P8 requis")
  }
  const privateKey = await jose.importPKCS8(keyP8, "ES256")
  const jwt = await new jose.SignJWT({})
    .setProtectedHeader({ alg: "ES256", kid: keyId })
    .setIssuer(teamId)
    .setIssuedAt(Math.floor(Date.now() / 1000))
    .setExpirationTime("1h")
    .sign(privateKey)
  return jwt
}

async function sendApns(
  deviceToken: string,
  title: string,
  body: string,
  isProduction: boolean
): Promise<boolean> {
  const url = `${isProduction ? APNS_PRODUCTION : APNS_SANDBOX}/3/device/${deviceToken}`
  const jwt = await signApnsJwt()
  const res = await fetch(url, {
    method: "POST",
    headers: {
      "authorization": `bearer ${jwt}`,
      "apns-topic": BUNDLE_ID,
      "apns-push-type": "alert",
      "apns-priority": "10",
      "apns-expiration": "0",
      "content-type": "application/json",
    },
    body: JSON.stringify({
      aps: {
        alert: { title, body },
        sound: "default",
      },
    }),
  })
  if (!res.ok) {
    const text = await res.text()
    console.error(`APNs error ${res.status} for token ${deviceToken.slice(0, 16)}...: ${text}`)
    return false
  }
  return true
}

Deno.serve(async (req) => {
  try {
    const payload: WebhookPayload = await req.json()
    if (payload.table !== "notes" || (payload.type !== "INSERT" && payload.type !== "UPDATE")) {
      return new Response(JSON.stringify({ ok: true }), {
        headers: { "Content-Type": "application/json" },
      })
    }

    const note = payload.record
    const authorId = payload.type === "INSERT" ? note.created_by : (note.last_modified_by ?? note.created_by)

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    )

    const isProd = Deno.env.get("APNS_PRODUCTION") === "true"
    const verb = payload.type === "INSERT" ? "a créé" : "a modifié"

    const { data: workspace } = await supabase
      .from("workspaces")
      .select("manager_id")
      .eq("id", note.workspace_id)
      .single()

    const { data: collaborators } = await supabase
      .from("collaborator_access")
      .select("user_id")
      .eq("sub_space_id", note.sub_space_id)

    const recipientIds = new Set<string>()
    if (workspace?.manager_id) recipientIds.add(workspace.manager_id)
    for (const c of collaborators ?? []) recipientIds.add(c.user_id)
    recipientIds.delete(authorId)

    const { data: profiles } = await supabase
      .from("profiles")
      .select("id")
      .in("id", Array.from(recipientIds))
      .eq("notifications_enabled", true)

    const enabledIds = new Set((profiles ?? []).map((p) => p.id))
    if (enabledIds.size === 0) {
      return new Response(JSON.stringify({ ok: true }), {
        headers: { "Content-Type": "application/json" },
      })
    }

    const { data: tokens } = await supabase
      .from("device_tokens")
      .select("user_id, token")
      .in("user_id", Array.from(enabledIds))

    if (!tokens?.length) {
      return new Response(JSON.stringify({ ok: true }), {
        headers: { "Content-Type": "application/json" },
      })
    }

    const { data: authorProfile } = await supabase
      .from("profiles")
      .select("first_name, last_name")
      .eq("id", authorId)
      .single()

    const authorName = authorProfile
      ? [authorProfile.first_name, authorProfile.last_name].filter(Boolean).join(" ") || "Un collaborateur"
      : "Un collaborateur"
    const notifTitle = "Capsule"
    const notifBody = `${authorName} ${verb} une note : ${note.title}`

    for (const row of tokens) {
      await sendApns(row.token, notifTitle, notifBody, isProd)
    }

    return new Response(JSON.stringify({ ok: true }), {
      headers: { "Content-Type": "application/json" },
    })
  } catch (e) {
    console.error("note-notify error:", e)
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    })
  }
})
