import assert from "node:assert/strict";
import type { AddressInfo } from "node:net";
import { after, before, test } from "node:test";
import { Secp256k1Keypair } from "@atproto/crypto";
import { createServiceJwt } from "@atproto/xrpc-server";
import { createHttpServer, REGISTER_METHOD, UNREGISTER_METHOD } from "../src/http.js";
import { DeviceStore } from "../src/store.js";

const SERVICE_DID = "did:web:push.example.com";
const USER_DID = "did:plc:user";
const TOKEN = "ab".repeat(32);

const store = new DeviceStore(":memory:");
let keypair: Secp256k1Keypair;
let baseUrl: string;
const server = createHttpServer({
  store,
  serviceDid: SERVICE_DID,
  getSigningKey: async (did) => {
    if (did !== USER_DID) throw new Error("unknown did");
    return keypair.did();
  },
});

before(async () => {
  keypair = await Secp256k1Keypair.create();
  await new Promise<void>((resolve) => server.listen(0, resolve));
  baseUrl = `http://127.0.0.1:${(server.address() as AddressInfo).port}`;
});
after(() => {
  server.close();
  store.close();
});

async function jwt(lxm: string, aud = SERVICE_DID) {
  return createServiceJwt({ iss: USER_DID, aud, lxm, keypair });
}

async function post(method: string, body: unknown, token?: string) {
  return fetch(`${baseUrl}/xrpc/${method}`, {
    method: "POST",
    headers: { "content-type": "application/json", ...(token ? { authorization: `Bearer ${token}` } : {}) },
    body: JSON.stringify(body),
  });
}

const registration = {
  token: TOKEN,
  environment: "sandbox",
  reasons: ["reply", "mention"],
  mutedDids: ["did:plc:muted"],
  muteWords: ["ネタバレ"],
};

test("正しい JWT で登録・解除できる", async () => {
  const res = await post(REGISTER_METHOD, registration, await jwt(REGISTER_METHOD));
  assert.equal(res.status, 200);
  assert.deepEqual(store.devicesFor(USER_DID), [{ did: USER_DID, ...registration }]);

  const unregister = await post(UNREGISTER_METHOD, { token: TOKEN }, await jwt(UNREGISTER_METHOD));
  assert.equal(unregister.status, 200);
  assert.equal(store.isWatched(USER_DID), false);
});

test("JWT がない・宛先違い・メソッド違いは 401", async () => {
  assert.equal((await post(REGISTER_METHOD, registration)).status, 401);
  assert.equal((await post(REGISTER_METHOD, registration, await jwt(REGISTER_METHOD, "did:web:evil"))).status, 401);
  assert.equal((await post(REGISTER_METHOD, registration, await jwt(UNREGISTER_METHOD))).status, 401);
  assert.equal(store.isWatched(USER_DID), false);
});

test("別の鍵で署名した JWT は 401", async () => {
  const forged = await createServiceJwt({
    iss: USER_DID,
    aud: SERVICE_DID,
    lxm: REGISTER_METHOD,
    keypair: await Secp256k1Keypair.create(),
  });
  assert.equal((await post(REGISTER_METHOD, registration, forged)).status, 401);
});

test("不正な本文は 400", async () => {
  const token = await jwt(REGISTER_METHOD);
  assert.equal((await post(REGISTER_METHOD, { ...registration, token: "zz" }, token)).status, 400);
  assert.equal((await post(REGISTER_METHOD, { ...registration, environment: "x" }, token)).status, 400);
  assert.equal((await post(REGISTER_METHOD, { ...registration, reasons: ["poke"] }, token)).status, 400);
});
