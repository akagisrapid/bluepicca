import { createHash } from "node:crypto";
import type { ApnsClient, PushPayload } from "./apns.js";
import type { Match, Reason } from "./match.js";
import type { ProfileNames } from "./profiles.js";
import type { Device, DeviceStore } from "./store.js";

/**
 * 見出しの文言キー。アプリの Localizable.xcstrings のキーと同じにしてあり、
 * iOS が端末の言語に合わせて訳を当てる（キー自体が日本語の文言なので、訳がなくてもそのまま読める）
 */
const TITLE_KEYS: Record<Reason, string> = {
  reply: "%@さんが返信しました",
  mention: "%@さんがメンションしました",
  quote: "%@さんが引用しました",
  like: "%@さんがいいねしました",
  repost: "%@さんがリポストしました",
  follow: "%@さんにフォローされました",
};

const MAX_BODY_LENGTH = 500;

/** 端末の設定（通知する種類・ミュート中のユーザー・ミュートワード）で絞る */
export function shouldNotify(device: Device, match: Match): boolean {
  if (!device.reasons.includes(match.reason)) return false;
  if (device.mutedDids.includes(match.author)) return false;
  if (match.text) {
    const text = match.text.toLowerCase();
    if (device.muteWords.some((word) => text.includes(word.toLowerCase()))) return false;
  }
  return true;
}

export function buildPush(match: Match, authorName: string) {
  const payload: PushPayload = {
    aps: {
      alert: {
        "title-loc-key": TITLE_KEYS[match.reason],
        "title-loc-args": [authorName],
        ...(match.text ? { body: match.text.slice(0, MAX_BODY_LENGTH) } : {}),
      },
      sound: "default",
      "thread-id": match.reason,
    },
    uri: match.uri,
    reason: match.reason,
  };
  // 同じ投稿へのいいね・リポストは端末上で最新の 1 件に上書きする（バズったときに通知で埋まらないように）
  const collapseId = match.subjectUri
    ? `${match.reason}:${createHash("sha256").update(match.subjectUri).digest("base64url").slice(0, 40)}`
    : undefined;
  return { payload, collapseId };
}

export class Notifier {
  constructor(
    private store: DeviceStore,
    private apns: ApnsClient,
    private profiles: ProfileNames,
  ) {}

  async handle(match: Match): Promise<void> {
    const devices = this.store.devicesFor(match.target).filter((d) => shouldNotify(d, match));
    if (devices.length === 0) return;

    const { payload, collapseId } = buildPush(match, await this.profiles.name(match.author));
    await Promise.all(
      devices.map(async (device) => {
        const result = await this.apns.send(device.token, device.environment, payload, {
          collapseId,
        });
        if (result === "invalid-token") this.store.removeToken(device.token);
      }),
    );
  }
}
