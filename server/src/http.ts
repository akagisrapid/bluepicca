import { createServer, type IncomingMessage, type ServerResponse } from "node:http";
import { IdResolver, MemoryCache } from "@atproto/identity";
import { verifyJwt } from "@atproto/xrpc-server";
import { REASONS, type Reason } from "./match.js";
import type { ApnsEnvironment, DeviceStore } from "./store.js";

/** アプリが getServiceAuth の lxm に指定するメソッド名。パスもこれに揃える */
export const REGISTER_METHOD = "lapipearpopo.bskyapp.push.register";
export const UNREGISTER_METHOD = "lapipearpopo.bskyapp.push.unregister";

const MAX_BODY_BYTES = 256 * 1024;
const MAX_MUTED_DIDS = 10_000;
const MAX_MUTE_WORDS = 1_000;
const MAX_MUTE_WORD_LENGTH = 100;

class HttpError extends Error {
  constructor(
    readonly status: number,
    message: string,
  ) {
    super(message);
  }
}

export function createHttpServer(options: {
  store: DeviceStore;
  serviceDid: string;
  /** DID から署名鍵（did:key）を引く。テストで差し替える */
  getSigningKey?: (did: string, forceRefresh: boolean) => Promise<string>;
}) {
  const { store, serviceDid } = options;
  const idResolver = new IdResolver({ didCache: new MemoryCache() });
  const getSigningKey =
    options.getSigningKey ??
    ((did: string, forceRefresh: boolean) => idResolver.did.resolveAtprotoKey(did, forceRefresh));

  /**
   * 本人確認。アプリは自分の PDS の com.atproto.server.getServiceAuth で、
   * aud = このサーバーの DID、lxm = 呼ぶメソッド名の短命 JWT を発行してもらって送る。
   * 署名を送り主の DID ドキュメントの鍵で検証するので、他人の DID では登録できない
   */
  async function authenticate(req: IncomingMessage, method: string): Promise<string> {
    const header = req.headers.authorization ?? "";
    if (!header.startsWith("Bearer ")) throw new HttpError(401, "missing bearer token");
    try {
      const payload = await verifyJwt(
        header.slice("Bearer ".length),
        serviceDid,
        method,
        getSigningKey,
      );
      // 他のサービスからの呼び出し（did#service）は受けない
      if (payload.iss.includes("#")) throw new Error("service issuer is not allowed");
      return payload.iss;
    } catch (error) {
      throw new HttpError(401, error instanceof Error ? error.message : "invalid token");
    }
  }

  async function handle(req: IncomingMessage, res: ServerResponse) {
    const path = new URL(req.url ?? "/", "http://localhost").pathname;

    if (req.method === "GET" && path === "/health") {
      return json(res, 200, {
        ok: true,
        devices: store.deviceCount,
        environments: store.environmentCounts(),
      });
    }
    if (req.method !== "POST") throw new HttpError(404, "not found");

    if (path === `/xrpc/${REGISTER_METHOD}`) {
      const did = await authenticate(req, REGISTER_METHOD);
      const body = await readJson(req);
      store.register({ did, ...parseRegistration(body) });
      return json(res, 200, {});
    }
    if (path === `/xrpc/${UNREGISTER_METHOD}`) {
      const did = await authenticate(req, UNREGISTER_METHOD);
      const body = await readJson(req);
      store.unregister(parseToken(body), did);
      return json(res, 200, {});
    }
    throw new HttpError(404, "not found");
  }

  return createServer((req, res) => {
    handle(req, res).catch((error) => {
      if (error instanceof HttpError) return json(res, error.status, { error: error.message });
      console.error(error);
      json(res, 500, { error: "internal error" });
    });
  });
}

function json(res: ServerResponse, status: number, body: unknown) {
  res.writeHead(status, { "content-type": "application/json" });
  res.end(JSON.stringify(body));
}

async function readJson(req: IncomingMessage): Promise<Record<string, unknown>> {
  const chunks: Buffer[] = [];
  let size = 0;
  for await (const chunk of req) {
    size += (chunk as Buffer).length;
    if (size > MAX_BODY_BYTES) throw new HttpError(413, "body too large");
    chunks.push(chunk as Buffer);
  }
  try {
    const value = JSON.parse(Buffer.concat(chunks).toString("utf8"));
    if (typeof value !== "object" || value === null || Array.isArray(value)) throw new Error();
    return value;
  } catch {
    throw new HttpError(400, "invalid json");
  }
}

function parseToken(body: Record<string, unknown>): string {
  const { token } = body;
  if (typeof token !== "string" || !/^[0-9a-f]{64,200}$/i.test(token)) {
    throw new HttpError(400, "invalid token");
  }
  return token.toLowerCase();
}

function stringArray(value: unknown, name: string, max: number): string[] {
  if (value === undefined) return [];
  if (!Array.isArray(value) || value.length > max || value.some((v) => typeof v !== "string")) {
    throw new HttpError(400, `invalid ${name}`);
  }
  return value as string[];
}

/** 登録内容の検証。登録する DID は本文ではなく JWT から取る */
export function parseRegistration(body: Record<string, unknown>) {
  const environment = body.environment;
  if (environment !== "sandbox" && environment !== "production") {
    throw new HttpError(400, "invalid environment");
  }
  const reasons = stringArray(body.reasons, "reasons", REASONS.length);
  if (!reasons.every((r) => (REASONS as readonly string[]).includes(r))) {
    throw new HttpError(400, "invalid reasons");
  }
  const mutedDids = stringArray(body.mutedDids, "mutedDids", MAX_MUTED_DIDS);
  if (!mutedDids.every((d) => d.startsWith("did:"))) throw new HttpError(400, "invalid mutedDids");
  const muteWords = stringArray(body.muteWords, "muteWords", MAX_MUTE_WORDS).filter(
    (w) => w.length > 0,
  );
  if (muteWords.some((w) => w.length > MAX_MUTE_WORD_LENGTH)) {
    throw new HttpError(400, "invalid muteWords");
  }
  return {
    token: parseToken(body),
    environment: environment as ApnsEnvironment,
    reasons: [...new Set(reasons)] as Reason[],
    mutedDids,
    muteWords,
  };
}
