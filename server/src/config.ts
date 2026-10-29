import { readFileSync } from "node:fs";

function required(name: string): string {
  const value = process.env[name];
  if (!value) throw new Error(`環境変数 ${name} が設定されていません`);
  return value;
}

/** 起動時に一度だけ読む設定。README の「環境変数」と揃える */
export function loadConfig() {
  const apnsKey = process.env.APNS_KEY ?? readFileSync(required("APNS_KEY_PATH"), "utf8");
  return {
    port: Number(process.env.PORT ?? 8080),
    /** 前段に Caddy などを置くときは 127.0.0.1 にして外から直接つながらないようにする */
    host: process.env.HOST,
    /** アプリが getServiceAuth の aud に指定する DID（例: did:web:push.example.com） */
    serviceDid: required("SERVICE_DID"),
    dbPath: process.env.DB_PATH ?? "bluepicca-push.sqlite",
    jetstreamUrl:
      process.env.JETSTREAM_URL ?? "wss://jetstream2.us-east.bsky.network/subscribe",
    apns: {
      key: apnsKey,
      keyId: required("APNS_KEY_ID"),
      teamId: required("APNS_TEAM_ID"),
      topic: process.env.APNS_TOPIC ?? "lapipearpopo.bskyapp",
    },
  };
}

export type Config = ReturnType<typeof loadConfig>;
