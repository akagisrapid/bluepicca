/** 通知の種類。アプリの NotificationReason（listNotifications の reason）と同じ値 */
export const REASONS = ["reply", "mention", "quote", "like", "repost", "follow"] as const;
export type Reason = (typeof REASONS)[number];

export const WANTED_COLLECTIONS = [
  "app.bsky.feed.post",
  "app.bsky.feed.like",
  "app.bsky.feed.repost",
  "app.bsky.graph.follow",
] as const;

/** Jetstream の create イベントのうち、ここで使う部分 */
export interface CreateEvent {
  did: string;
  commit: { collection: string; rkey: string; record: unknown };
}

/** 登録ユーザー（target）宛てと判定したイベント */
export interface Match {
  target: string;
  reason: Reason;
  /** 操作した人の DID */
  author: string;
  /** 作られたレコードの at:// URI */
  uri: string;
  /** いいね・リポストされた投稿の URI */
  subjectUri?: string;
  /** 返信・メンション・引用の本文 */
  text?: string;
}

function field(value: unknown, ...path: string[]): unknown {
  let current = value;
  for (const key of path) {
    if (typeof current !== "object" || current === null) return undefined;
    current = (current as Record<string, unknown>)[key];
  }
  return current;
}

/** at://did:plc:xxx/collection/rkey から DID を取り出す */
export function didOfAtUri(uri: unknown): string | undefined {
  if (typeof uri !== "string" || !uri.startsWith("at://")) return undefined;
  const did = uri.slice("at://".length).split("/")[0];
  return did?.startsWith("did:") ? did : undefined;
}

function quotedUri(record: unknown): unknown {
  const embed = field(record, "embed");
  switch (field(embed, "$type")) {
    case "app.bsky.embed.record":
      return field(embed, "record", "uri");
    case "app.bsky.embed.recordWithMedia":
      return field(embed, "record", "record", "uri");
    default:
      return undefined;
  }
}

function mentionedDids(record: unknown): string[] {
  const facets = field(record, "facets");
  if (!Array.isArray(facets)) return [];
  return facets.flatMap((facet) => {
    const features = field(facet, "features");
    if (!Array.isArray(features)) return [];
    return features
      .filter((f) => field(f, "$type") === "app.bsky.richtext.facet#mention")
      .map((f) => field(f, "did"))
      .filter((did): did is string => typeof did === "string");
  });
}

/**
 * イベントが登録ユーザー宛てなら、宛先ごとに 1 件ずつ返す。
 * 1 つの投稿が返信かつメンションのように重なるときは 返信 > 引用 > メンション の順で 1 つにまとめる
 */
export function matchEvent(event: CreateEvent, isWatched: (did: string) => boolean): Match[] {
  const { did: author, commit } = event;
  const { record } = commit;
  const uri = `at://${author}/${commit.collection}/${commit.rkey}`;
  const matches = new Map<string, Match>();
  const add = (target: string | undefined, reason: Reason, extra: Partial<Match> = {}) => {
    if (!target || target === author || matches.has(target) || !isWatched(target)) return;
    matches.set(target, { target, reason, author, uri, ...extra });
  };

  switch (commit.collection) {
    case "app.bsky.feed.post": {
      const text = field(record, "text");
      const extra = typeof text === "string" ? { text } : {};
      // 返信はスレッド内の他人宛ての返信を除くため、直接の返信先（parent）だけを見る
      add(didOfAtUri(field(record, "reply", "parent", "uri")), "reply", extra);
      add(didOfAtUri(quotedUri(record)), "quote", extra);
      for (const did of mentionedDids(record)) add(did, "mention", extra);
      break;
    }
    case "app.bsky.feed.like":
    case "app.bsky.feed.repost": {
      const subjectUri = field(record, "subject", "uri");
      if (typeof subjectUri !== "string") break;
      const reason = commit.collection === "app.bsky.feed.like" ? "like" : "repost";
      add(didOfAtUri(subjectUri), reason, { subjectUri });
      break;
    }
    case "app.bsky.graph.follow": {
      const subject = field(record, "subject");
      if (typeof subject === "string") add(subject, "follow");
      break;
    }
  }
  return [...matches.values()];
}
