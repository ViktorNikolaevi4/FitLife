import assert from "node:assert/strict";

// Run with: firebase emulators:exec --only firestore --project demo-fitlife-receipts "node scripts/test-chat-receipts.mjs"
const host = process.env.FIRESTORE_EMULATOR_HOST;
assert(host && /^(127\.0\.0\.1|localhost):\d+$/.test(host), "Local emulator required");
const project = "demo-fitlife-receipts";
const root = `projects/${project}/databases/(default)/documents`;
const url = `http://${host}/v1/${root}:commit`;
const string = value => ({ stringValue: value });
const timestamp = { timestampValue: "2026-01-01T00:00:00Z" };
function token(uid) {
  const now = Math.floor(Date.now() / 1000);
  const encode = value => Buffer.from(JSON.stringify(value)).toString("base64url");
  return `${encode({ alg: "none", typ: "JWT" })}.${encode({
    sub: uid, user_id: uid, aud: project, iss: `https://securetoken.google.com/${project}`,
    iat: now, exp: now + 3600, auth_time: now,
    firebase: { sign_in_provider: "custom", identities: {} }
  })}.`;
}
async function commit(writes, uid = null) {
  const response = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json", Authorization: `Bearer ${uid ? token(uid) : "owner"}` },
    body: JSON.stringify({ writes })
  });
  return { status: response.status, body: await response.text() };
}
const document = (path, fields) => ({ update: { name: `${root}/${path}`, fields } });
const message = (author, role) => ({
  clientId: string("client"), trainerId: string("trainer"),
  authorId: string(author), authorRole: string(role), message: string("Hello"),
  createdAt: timestamp, deliveredAt: timestamp, reactions: { mapValue: { fields: {} } }
});
async function expectStatus(label, result, expected) {
  assert.equal(result.status, expected, `${label}: ${result.body}`);
  console.log("PASS", label);
}
await expectStatus("seed isolated emulator", await commit([
  document("users/client", { role: string("client"), isActive: { booleanValue: true } }),
  document("users/trainer", { role: string("trainer"), isActive: { booleanValue: true } }),
  document("users/stranger", { role: string("client"), isActive: { booleanValue: true } }),
  document("trainer_client_links/trainer_client", { status: string("active") }),
  document("coaching_notes/from-client", message("client", "client")),
  document("coaching_notes/from-trainer", message("trainer", "trainer"))
]), 200);
const receipt = id => ({
  transform: { document: `${root}/coaching_notes/${id}`,
    fieldTransforms: [{ fieldPath: "readAt", setToServerValue: "REQUEST_TIME" }] }
});
await expectStatus("trainer reads client message", await commit([receipt("from-client")], "trainer"), 200);
await expectStatus("client reads trainer message", await commit([receipt("from-trainer")], "client"), 200);
await expectStatus("sender cannot forge read", await commit([receipt("from-client")], "client"), 403);
await expectStatus("stranger cannot mark read", await commit([receipt("from-client")], "stranger"), 403);
await expectStatus("cannot change text with receipt", await commit([{
  ...document("coaching_notes/from-client", { message: string("Changed") }),
  updateMask: { fieldPaths: ["message"] },
  updateTransforms: [{ fieldPath: "readAt", setToServerValue: "REQUEST_TIME" }]
}], "trainer"), 403);
await expectStatus("cannot create already-read message", await commit([
  document("coaching_notes/forged", { ...message("client", "client"), readAt: timestamp })
], "client"), 403);
const legacy = message("client", "client");
delete legacy.deliveredAt;
await expectStatus("legacy sender remains compatible", await commit([
  document("coaching_notes/legacy", legacy)
], "client"), 200);
await expectStatus("legacy message can be read", await commit([receipt("legacy")], "trainer"), 200);
