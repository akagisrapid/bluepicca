import assert from "node:assert/strict";
import { test } from "node:test";
import type { Match } from "../src/match.js";
import { buildPush, shouldNotify } from "../src/notifier.js";
import type { Device } from "../src/store.js";

const device: Device = {
  token: "a".repeat(64),
  did: "did:plc:me",
  environment: "production",
  reasons: ["reply", "like"],
  mutedDids: ["did:plc:muted"],
  muteWords: ["ネタバレ", "Spoiler"],
};

const match = (overrides: Partial<Match> = {}): Match => ({
  target: "did:plc:me",
  reason: "reply",
  author: "did:plc:other",
  uri: "at://did:plc:other/app.bsky.feed.post/1",
  text: "こんにちは",
  ...overrides,
});

test("選んだ種類だけ通知する", () => {
  assert.equal(shouldNotify(device, match()), true);
  assert.equal(shouldNotify(device, match({ reason: "mention" })), false);
});

test("ミュート中のユーザーとミュートワードは通知しない", () => {
  assert.equal(shouldNotify(device, match({ author: "did:plc:muted" })), false);
  assert.equal(shouldNotify(device, match({ text: "今日のネタバレ" })), false);
  assert.equal(shouldNotify(device, match({ text: "big SPOILER here" })), false);
});

test("見出しはアプリの文言キーを使う", () => {
  const { payload, collapseId } = buildPush(match(), "Alice");
  assert.deepEqual(payload.aps.alert, {
    "title-loc-key": "%@さんが返信しました",
    "title-loc-args": ["Alice"],
    body: "こんにちは",
  });
  assert.equal(payload.aps["thread-id"], "reply");
  assert.equal(collapseId, undefined);
});

test("同じ投稿へのいいねは同じ collapse ID になる", () => {
  const subjectUri = "at://did:plc:me/app.bsky.feed.post/1";
  const a = buildPush(match({ reason: "like", text: undefined, subjectUri }), "A");
  const b = buildPush(match({ reason: "like", text: undefined, subjectUri, author: "did:plc:b" }), "B");
  assert.ok(a.collapseId);
  assert.equal(a.collapseId, b.collapseId);
  assert.ok(Buffer.byteLength(a.collapseId!) <= 64);
  assert.equal(a.payload.aps.alert.body, undefined);
});
