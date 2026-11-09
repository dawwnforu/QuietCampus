import assert from "node:assert/strict";

let handler: (r: Request) => Promise<Response>;
const serve = Deno.serve;
Deno.serve = ((fn: typeof handler) => {
  handler = fn;
  return {};
}) as unknown as typeof Deno.serve;
await import("./index.ts");
Deno.serve = serve;

const owner = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa";
const request = () =>
  new Request("https://local.test/delete-account", {
    method: "POST",
    headers: { Authorization: "Bearer test-token" },
  });

Deno.test("delete-account: verifies caller, blocks writes and removes files before the user", async () => {
  const previousFetch = globalThis.fetch;
  const names = [
    "SUPABASE_URL",
    "SUPABASE_SERVICE_ROLE_KEY",
    "SUPABASE_ANON_KEY",
  ];
  const values = names.map((n) => Deno.env.get(n));
  Deno.env.set(names[0], "https://backend.test");
  Deno.env.set(names[1], "server-test-key");
  Deno.env.set(names[2], "client-test-key");
  const events: string[] = [];
  let invalid = false, stale = false, failStorage = false, listed = false;
  globalThis.fetch =
    (async (input: RequestInfo | URL, options?: RequestInit) => {
      const url = new URL(
        input instanceof Request ? input.url : input.toString(),
      );
      const json = (body: unknown, status = 200) =>
        Response.json(body, { status });
      if (url.pathname === "/auth/v1/user") {
        if (invalid) return json({ msg: "invalid token" }, 401);
        return json({
          id: owner,
          last_sign_in_at: new Date(Date.now() - (stale ? 3600000 : 0))
            .toISOString(),
        });
      }
      if (url.pathname === "/rest/v1/rpc/begin_account_deletion") {
        events.push("block-writes");
        return json(null);
      }
      if (url.pathname === "/storage/v1/object/list/vault-attachments") {
        events.push("list-files");
        assert.equal(JSON.parse(options!.body as string).prefix, owner);
        if (failStorage) return json({ message: "unavailable" }, 503);
        if (listed) return json([]);
        listed = true;
        return json([{ id: "file", name: "proof.bin" }]);
      }
      if (
        url.pathname === "/storage/v1/object/vault-attachments" &&
        options?.method === "DELETE"
      ) {
        events.push("delete-files");
        assert.deepEqual(JSON.parse(options.body as string).prefixes, [
          `${owner}/proof.bin`,
        ]);
        return json([]);
      }
      if (
        url.pathname === `/auth/v1/admin/users/${owner}` &&
        options?.method === "DELETE"
      ) {
        events.push("delete-user");
        return json({ id: owner });
      }
      throw Error(`Unexpected test request: ${url.pathname}`);
    }) as typeof fetch;
  try {
    assert.equal(
      (await handler(new Request("https://local.test"))).status,
      405,
    );
    assert.equal(
      (await handler(new Request("https://local.test", { method: "POST" })))
        .status,
      401,
    );
    invalid = true;
    assert.equal((await handler(request())).status, 401);
    invalid = false;
    stale = true;
    assert.equal((await handler(request())).status, 403);
    assert.deepEqual(events, []);
    stale = false;
    assert.equal((await handler(request())).status, 200);
    assert.deepEqual(events, [
      "block-writes",
      "list-files",
      "delete-files",
      "list-files",
      "delete-user",
    ]);
    events.length = 0;
    listed = false;
    failStorage = true;
    assert.equal((await handler(request())).status, 503);
    assert.deepEqual(events, ["block-writes", "list-files"]);
  } finally {
    globalThis.fetch = previousFetch;
    names.forEach((name, i) =>
      values[i] == null ? Deno.env.delete(name) : Deno.env.set(name, values[i]!)
    );
  }
});
