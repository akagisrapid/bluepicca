import { connect, type ClientHttp2Session } from "node:http2";
import { createPrivateKey, sign, type KeyObject } from "node:crypto";
import type { ApnsEnvironment } from "./store.js";

const HOSTS: Record<ApnsEnvironment, string> = {
  production: "https://api.push.apple.com",
  sandbox: "https://api.sandbox.push.apple.com",
};

/** Apple はプロバイダトークンを 20〜60 分ごとに作り直すよう求めている */
const TOKEN_LIFETIME_MS = 50 * 60 * 1000;

export interface ApnsAlert {
  title?: string;
  "title-loc-key"?: string;
  "title-loc-args"?: string[];
  body?: string;
}

export interface PushPayload {
  aps: { alert: ApnsAlert; sound?: string; "thread-id"?: string };
  [key: string]: unknown;
}

/** invalid-token のときは登録を消す */
export type SendResult = "ok" | "invalid-token" | "error";

/** APNs への HTTP/2 送信。トークン認証（.p8 キー）を使う */
export class ApnsClient {
  private key: KeyObject;
  private sessions = new Map<ApnsEnvironment, ClientHttp2Session>();
  private providerToken?: { value: string; issuedAt: number };

  constructor(private config: { key: string; keyId: string; teamId: string; topic: string }) {
    this.key = createPrivateKey(config.key);
  }

  async send(
    deviceToken: string,
    environment: ApnsEnvironment,
    payload: PushPayload,
    options: { collapseId?: string } = {},
  ): Promise<SendResult> {
    const headers: Record<string, string> = {
      ":method": "POST",
      ":path": `/3/device/${deviceToken}`,
      authorization: `bearer ${this.token()}`,
      "apns-topic": this.config.topic,
      "apns-push-type": "alert",
      "apns-priority": "10",
    };
    // 同じ ID の通知は端末上で上書きされる（同じ投稿へのいいねを 1 件にまとめる）
    if (options.collapseId) headers["apns-collapse-id"] = options.collapseId.slice(0, 64);

    try {
      const { status, body } = await this.request(environment, headers, JSON.stringify(payload));
      if (status === 200) return "ok";
      const reason = parseReason(body);
      if (status === 410 || reason === "BadDeviceToken" || reason === "DeviceTokenNotForTopic") {
        return "invalid-token";
      }
      if (reason === "ExpiredProviderToken") this.providerToken = undefined;
      console.warn(`APNs ${status} ${reason ?? body}`);
      return "error";
    } catch (error) {
      console.warn("APNs request failed", error);
      return "error";
    }
  }

  close(): void {
    for (const session of this.sessions.values()) session.close();
    this.sessions.clear();
  }

  private token(): string {
    const now = Date.now();
    if (this.providerToken && now - this.providerToken.issuedAt < TOKEN_LIFETIME_MS) {
      return this.providerToken.value;
    }
    const header = base64url({ alg: "ES256", kid: this.config.keyId });
    const claims = base64url({ iss: this.config.teamId, iat: Math.floor(now / 1000) });
    const signature = sign("sha256", Buffer.from(`${header}.${claims}`), {
      key: this.key,
      dsaEncoding: "ieee-p1363",
    }).toString("base64url");
    const value = `${header}.${claims}.${signature}`;
    this.providerToken = { value, issuedAt: now };
    return value;
  }

  private session(environment: ApnsEnvironment): ClientHttp2Session {
    const existing = this.sessions.get(environment);
    if (existing && !existing.closed && !existing.destroyed) return existing;
    const session = connect(HOSTS[environment]);
    const forget = () => {
      if (this.sessions.get(environment) === session) this.sessions.delete(environment);
    };
    session.on("close", forget);
    session.on("error", (error) => {
      console.warn("APNs connection error", error);
      forget();
    });
    session.on("goaway", forget);
    this.sessions.set(environment, session);
    return session;
  }

  private request(
    environment: ApnsEnvironment,
    headers: Record<string, string>,
    body: string,
  ): Promise<{ status: number; body: string }> {
    return new Promise((resolve, reject) => {
      const stream = this.session(environment).request(headers);
      let status = 0;
      let data = "";
      stream.setEncoding("utf8");
      stream.setTimeout(10_000, () => stream.close());
      stream.on("response", (responseHeaders) => {
        status = Number(responseHeaders[":status"]);
      });
      stream.on("data", (chunk: string) => (data += chunk));
      stream.on("end", () => resolve({ status, body: data }));
      stream.on("error", reject);
      // タイムアウトなどで end の前に閉じたとき（resolve 済みなら何も起きない）
      stream.on("close", () => reject(new Error("APNs stream closed")));
      stream.end(body);
    });
  }
}

function base64url(value: object): string {
  return Buffer.from(JSON.stringify(value)).toString("base64url");
}

function parseReason(body: string): string | undefined {
  try {
    return (JSON.parse(body) as { reason?: string }).reason;
  } catch {
    return undefined;
  }
}
