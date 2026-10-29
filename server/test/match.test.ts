import assert from "node:assert/strict";
import { test } from "node:test";
import { didOfAtUri, matchEvent, type CreateEvent } from "../src/match.js";

const ME = "did:plc:me";
const OTHER = "did:plc:other";
const watched = (did: string) => did === ME;

function event(collection: string, record: unknown, did = OTHER): CreateEvent {
  return { did, commit: { collection, rkey: "3k", record } };
}

const myPost = `at://${ME}/app.bsky.feed.post/1`;
const mention = (did: string) => ({
  index: { byteStart: 0, byteEnd: 3 },
  features: [{ $type: "app.bsky.richtext.facet#mention", did }],
});

test("didOfAtUri", () => {
  assert.equal(didOfAtUri(myPost), ME);
  assert.equal(didOfAtUri("https://example.com"), undefined);
  assert.equal(didOfAtUri(undefined), undefined);
});

test("自分の投稿への返信", () => {
  const matches = matchEvent(
    event("app.bsky.feed.post", { text: "hi", reply: { root: { uri: myPost }, parent: { uri: myPost } } }),
    watched,
  );
  assert.deepEqual(matches, [
    { target: ME, reason: "reply", author: OTHER, uri: `at://${OTHER}/app.bsky.feed.post/3k`, text: "hi" },
  ]);
});

test("スレッドの root が自分でも parent が他人なら返信にしない", () => {
  const otherPost = `at://did:plc:third/app.bsky.feed.post/2`;
  const matches = matchEvent(
    event("app.bsky.feed.post", { text: "hi", reply: { root: { uri: myPost }, parent: { uri: otherPost } } }),
    watched,
  );
  assert.deepEqual(matches, []);
});

test("メンション・引用", () => {
  const mentioned = matchEvent(event("app.bsky.feed.post", { text: "@me", facets: [mention(ME)] }), watched);
  assert.equal(mentioned[0]?.reason, "mention");

  const quoted = matchEvent(
    event("app.bsky.feed.post", { text: "q", embed: { $type: "app.bsky.embed.record", record: { uri: myPost } } }),
    watched,
  );
  assert.equal(quoted[0]?.reason, "quote");

  const quotedWithMedia = matchEvent(
    event("app.bsky.feed.post", {
      text: "q",
      embed: { $type: "app.bsky.embed.recordWithMedia", record: { record: { uri: myPost } }, media: {} },
    }),
    watched,
  );
  assert.equal(quotedWithMedia[0]?.reason, "quote");
});

test("返信かつメンションは返信 1 件にまとめる", () => {
  const matches = matchEvent(
    event("app.bsky.feed.post", { text: "@me", reply: { parent: { uri: myPost } }, facets: [mention(ME)] }),
    watched,
  );
  assert.deepEqual(matches.map((m) => m.reason), ["reply"]);
});

test("いいね・リポスト・フォロー", () => {
  const like = matchEvent(event("app.bsky.feed.like", { subject: { uri: myPost, cid: "c" } }), watched);
  assert.deepEqual(like.map((m) => [m.reason, m.subjectUri]), [["like", myPost]]);

  const repost = matchEvent(event("app.bsky.feed.repost", { subject: { uri: myPost, cid: "c" } }), watched);
  assert.equal(repost[0]?.reason, "repost");

  const follow = matchEvent(event("app.bsky.graph.follow", { subject: ME }), watched);
  assert.equal(follow[0]?.reason, "follow");
});

test("自分の操作と登録していない人宛ては拾わない", () => {
  assert.deepEqual(matchEvent(event("app.bsky.feed.like", { subject: { uri: myPost } }, ME), watched), []);
  const otherPost = `at://${OTHER}/app.bsky.feed.post/1`;
  assert.deepEqual(matchEvent(event("app.bsky.feed.like", { subject: { uri: otherPost } }, "did:plc:x"), watched), []);
});

test("壊れたレコードでも落ちない", () => {
  assert.deepEqual(matchEvent(event("app.bsky.feed.post", null), watched), []);
  assert.deepEqual(matchEvent(event("app.bsky.feed.like", { subject: 1 }), watched), []);
  assert.deepEqual(matchEvent(event("app.bsky.feed.post", { facets: [{ features: "x" }] }), watched), []);
});
