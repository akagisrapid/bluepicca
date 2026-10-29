import { Jetstream } from "@skyware/jetstream";
import { ApnsClient } from "./apns.js";
import { loadConfig } from "./config.js";
import { createHttpServer } from "./http.js";
import { matchEvent, WANTED_COLLECTIONS, type CreateEvent } from "./match.js";
import { Notifier } from "./notifier.js";
import { ProfileNames } from "./profiles.js";
import { DeviceStore } from "./store.js";

/** 止まっていた間の取りこぼしを拾うのはこの時間まで。古い通知を後からまとめて送らない */
const MAX_REPLAY_US = 10 * 60 * 1_000_000;
const CURSOR_SAVE_INTERVAL_MS = 10_000;

const config = loadConfig();
const store = new DeviceStore(config.dbPath);
const apns = new ApnsClient(config.apns);
const notifier = new Notifier(store, apns, new ProfileNames());

const savedCursor = store.getCursor();
const nowUs = Date.now() * 1000;
const cursor = savedCursor && nowUs - savedCursor < MAX_REPLAY_US ? savedCursor : undefined;

const jetstream = new Jetstream({
  endpoint: config.jetstreamUrl,
  wantedCollections: [...WANTED_COLLECTIONS],
  cursor,
});

for (const collection of WANTED_COLLECTIONS) {
  jetstream.onCreate(collection, (event) => {
    const matches = matchEvent(event as unknown as CreateEvent, (did) => store.isWatched(did));
    for (const match of matches) {
      notifier.handle(match).catch((error) => console.error("notify failed", error));
    }
  });
}
jetstream.on("open", () => console.log(`Jetstream connected (cursor: ${cursor ?? "live"})`));
jetstream.on("close", () => console.warn("Jetstream disconnected, reconnecting"));
jetstream.on("error", (error) => console.error("Jetstream error", error));
jetstream.start();

const cursorTimer = setInterval(() => {
  if (jetstream.cursor) store.setCursor(jetstream.cursor);
}, CURSOR_SAVE_INTERVAL_MS);

const server = createHttpServer({ store, serviceDid: config.serviceDid });
server.listen(config.port, () => {
  console.log(`Listening on :${config.port} (${store.deviceCount} devices)`);
});

function shutdown() {
  clearInterval(cursorTimer);
  if (jetstream.cursor) store.setCursor(jetstream.cursor);
  jetstream.close();
  server.close();
  apns.close();
  store.close();
  process.exit(0);
}
process.on("SIGINT", shutdown);
process.on("SIGTERM", shutdown);
