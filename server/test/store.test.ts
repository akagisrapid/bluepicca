import assert from "node:assert/strict";
import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { test } from "node:test";
import { DeviceStore, type Device } from "../src/store.js";

const device = (token: string, did: string): Device => ({
  token,
  did,
  environment: "production",
  reasons: ["reply"],
  mutedDids: [],
  muteWords: [],
});

test("同じ端末を別アカウントで登録し直すと付け替わる", () => {
  const store = new DeviceStore(":memory:");
  store.register(device("t1", "did:plc:a"));
  store.register(device("t1", "did:plc:b"));
  assert.equal(store.isWatched("did:plc:a"), false);
  assert.deepEqual(store.devicesFor("did:plc:b").map((d) => d.token), ["t1"]);
  store.close();
});

test("他人の端末は解除できない", () => {
  const store = new DeviceStore(":memory:");
  store.register(device("t1", "did:plc:a"));
  store.unregister("t1", "did:plc:b");
  assert.equal(store.isWatched("did:plc:a"), true);
  store.close();
});

test("再起動しても登録と cursor が残る", () => {
  const dir = mkdtempSync(join(tmpdir(), "push-store-"));
  const path = join(dir, "db.sqlite");
  try {
    const store = new DeviceStore(path);
    store.register(device("t1", "did:plc:a"));
    store.setCursor(123);
    store.close();

    const reopened = new DeviceStore(path);
    assert.deepEqual(reopened.devicesFor("did:plc:a"), [device("t1", "did:plc:a")]);
    assert.equal(reopened.getCursor(), 123);
    reopened.close();
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});
