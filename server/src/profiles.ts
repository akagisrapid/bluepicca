const PROFILE_URL = "https://public.api.bsky.app/xrpc/app.bsky.actor.getProfile";
const TTL_MS = 60 * 60 * 1000;
const MAX_ENTRIES = 10_000;

/** 通知に出す送り主の名前。Jetstream には DID しか載らないので公開 API で引いてキャッシュする */
export class ProfileNames {
  private cache = new Map<string, { name: string; fetchedAt: number }>();

  async name(did: string): Promise<string> {
    const cached = this.cache.get(did);
    if (cached && Date.now() - cached.fetchedAt < TTL_MS) return cached.name;

    let name = did;
    try {
      const response = await fetch(`${PROFILE_URL}?actor=${encodeURIComponent(did)}`, {
        signal: AbortSignal.timeout(3_000),
      });
      if (response.ok) {
        const profile = (await response.json()) as { displayName?: string; handle?: string };
        name = profile.displayName?.trim() || profile.handle || did;
      }
    } catch (error) {
      console.warn(`getProfile failed for ${did}`, error);
      // 取れなかったときは DID のまま出し、キャッシュしない
      return name;
    }

    // Map は挿入順なので、先頭から消せば古いものから捨てられる
    this.cache.delete(did);
    this.cache.set(did, { name, fetchedAt: Date.now() });
    if (this.cache.size > MAX_ENTRIES) {
      const oldest = this.cache.keys().next().value;
      if (oldest) this.cache.delete(oldest);
    }
    return name;
  }
}
