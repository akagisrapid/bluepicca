import { DatabaseSync } from "node:sqlite";
import type { Reason } from "./match.js";

export type ApnsEnvironment = "sandbox" | "production";

/** アプリが登録する端末。ミュート設定は Jetstream から見えないので、アプリから受け取って持つ */
export interface Device {
  token: string;
  did: string;
  environment: ApnsEnvironment;
  reasons: Reason[];
  mutedDids: string[];
  muteWords: string[];
}

/**
 * 端末の登録と Jetstream の cursor を SQLite に保存する。
 * イベントごとに DB を引かないよう、登録内容はメモリにも DID ごとに持つ
 */
export class DeviceStore {
  private db: DatabaseSync;
  private byDid = new Map<string, Map<string, Device>>();

  constructor(path: string) {
    this.db = new DatabaseSync(path);
    this.db.exec(`
      CREATE TABLE IF NOT EXISTS devices (
        token TEXT PRIMARY KEY,
        did TEXT NOT NULL,
        environment TEXT NOT NULL,
        reasons TEXT NOT NULL,
        muted_dids TEXT NOT NULL,
        mute_words TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      );
      CREATE INDEX IF NOT EXISTS devices_did ON devices (did);
      CREATE TABLE IF NOT EXISTS state (key TEXT PRIMARY KEY, value TEXT NOT NULL);
    `);
    const rows = this.db.prepare("SELECT * FROM devices").all() as Record<string, string>[];
    for (const row of rows) {
      this.cache({
        token: row.token!,
        did: row.did!,
        environment: row.environment as ApnsEnvironment,
        reasons: JSON.parse(row.reasons!),
        mutedDids: JSON.parse(row.muted_dids!),
        muteWords: JSON.parse(row.mute_words!),
      });
    }
  }

  get deviceCount(): number {
    let count = 0;
    for (const devices of this.byDid.values()) count += devices.size;
    return count;
  }

  isWatched(did: string): boolean {
    return this.byDid.has(did);
  }

  devicesFor(did: string): Device[] {
    return [...(this.byDid.get(did)?.values() ?? [])];
  }

  /** 同じ端末トークンが別の DID で登録されていたら付け替える（端末でアカウントを切り替えたとき） */
  register(device: Device): void {
    this.removeToken(device.token);
    this.db
      .prepare(
        `INSERT INTO devices (token, did, environment, reasons, muted_dids, mute_words, updated_at)
         VALUES (?, ?, ?, ?, ?, ?, ?)`,
      )
      .run(
        device.token,
        device.did,
        device.environment,
        JSON.stringify(device.reasons),
        JSON.stringify(device.mutedDids),
        JSON.stringify(device.muteWords),
        Date.now(),
      );
    this.cache(device);
  }

  /** 本人の端末だけを消す */
  unregister(token: string, did: string): void {
    if (!this.byDid.get(did)?.has(token)) return;
    this.removeToken(token);
  }

  /** APNs に無効と言われたトークンを消す */
  removeToken(token: string): void {
    const row = this.db.prepare("SELECT did FROM devices WHERE token = ?").get(token) as
      | { did: string }
      | undefined;
    if (!row) return;
    this.db.prepare("DELETE FROM devices WHERE token = ?").run(token);
    const devices = this.byDid.get(row.did);
    devices?.delete(token);
    if (devices?.size === 0) this.byDid.delete(row.did);
  }

  getCursor(): number | undefined {
    const row = this.db.prepare("SELECT value FROM state WHERE key = 'cursor'").get() as
      | { value: string }
      | undefined;
    return row ? Number(row.value) : undefined;
  }

  setCursor(cursor: number): void {
    this.db
      .prepare("INSERT INTO state (key, value) VALUES ('cursor', ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value")
      .run(String(cursor));
  }

  close(): void {
    this.db.close();
  }

  private cache(device: Device): void {
    let devices = this.byDid.get(device.did);
    if (!devices) {
      devices = new Map();
      this.byDid.set(device.did, devices);
    }
    devices.set(device.token, device);
  }
}
