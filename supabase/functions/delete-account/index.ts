import { createClient } from "npm:@supabase/supabase-js@2.99.1";

Deno.serve(async (request: Request) => {
  if (request.method !== "POST") return new Response(null, { status: 405 });
  const token = request.headers.get("Authorization")?.replace(/^Bearer /i, "");
  if (!token) return new Response(null, { status: 401 });
  const url = Deno.env.get("SUPABASE_URL")!;
  const admin = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: { user }, error } = await admin.auth.getUser(token);
  if (error || !user) return new Response(null, { status: 401 });
  const signedIn = Date.parse(user.last_sign_in_at ?? "");
  if (!Number.isFinite(signedIn) || Date.now() - signedIn > 10 * 60 * 1000) {
    return Response.json({ error: "recent_login_required" }, { status: 403 });
  }
  const client = createClient(url, Deno.env.get("SUPABASE_ANON_KEY")!, {
    global: { headers: { Authorization: `Bearer ${token}` } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  // Block new writes first; failed deletions remain retryable using the same account.
  const begun = await client.rpc("begin_account_deletion");
  if (begun.error) {
    return Response.json({ error: "deletion_failed" }, { status: 503 });
  }
  const bucket = admin.storage.from("vault-attachments");
  while (true) {
    const listed = await bucket.list(user.id, { limit: 1000 });
    if (listed.error) {
      return Response.json({ error: "deletion_failed" }, { status: 503 });
    }
    if (!listed.data.length) break;
    const removed = await bucket.remove(
      listed.data.map((file) => `${user.id}/${file.name}`),
    );
    if (removed.error) {
      return Response.json({ error: "deletion_failed" }, { status: 503 });
    }
  }
  const deleted = await admin.auth.admin.deleteUser(user.id);
  if (deleted.error) {
    return Response.json({ error: "deletion_failed" }, { status: 503 });
  }
  return Response.json({ deleted: true });
});
