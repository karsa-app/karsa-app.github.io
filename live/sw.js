/*
 * Karsa's service worker: push only (spec_01M4NH5F6QM5 decisions 8–9). No fetch
 * handler and no cache: the app always loads from the server.
 *
 * A push is Declarative Web Push's JSON, which Safari 18.4+ shows by itself; here it
 * is shown for every other browser:
 *   {"web_push": 8030, "notification": {"title", "body", "navigate", "app_badge"}}
 * Every push shows a notification (WebKit revokes the permission after three that
 * don't). A tap focuses an open Karsa and tells it where to go, or opens one there.
 */
self.addEventListener("install", () => self.skipWaiting());
self.addEventListener("activate", (event) => event.waitUntil(self.clients.claim()));

self.addEventListener("push", (event) => {
  let n = {};
  try {
    const data = event.data ? event.data.json() : {};
    n = (data && data.notification) || data || {};
  } catch {
    n = { title: "Karsa", body: event.data ? event.data.text() : "" };
  }
  const title = typeof n.title === "string" && n.title ? n.title : "Karsa";
  const navigate = typeof n.navigate === "string" ? n.navigate : "/";
  const shown = self.registration.showNotification(title, {
    body: typeof n.body === "string" ? n.body : "",
    icon: "/icons/karsa-192.png",
    badge: "/icons/karsa-maskable-192.png",
    data: { navigate },
    // One notification per page: a newer one about the same chat replaces it.
    tag: navigate,
  });
  const badge = typeof n.app_badge === "number" && "setAppBadge" in self.navigator
    ? self.navigator.setAppBadge(n.app_badge).catch(() => {})
    : Promise.resolve();
  event.waitUntil(Promise.all([shown, badge]));
});

self.addEventListener("notificationclick", (event) => {
  event.notification.close();
  const target = new URL((event.notification.data && event.notification.data.navigate) || "/", self.location.origin);
  event.waitUntil((async () => {
    const windows = await self.clients.matchAll({ type: "window", includeUncontrolled: true });
    const same = windows.filter((w) => new URL(w.url).origin === target.origin);
    // An open Karsa: bring it forward and let its router go there (no reload).
    const open = same.find((w) => w.focused) || same[0];
    if (open) {
      await open.focus().catch(() => {});
      open.postMessage({ type: "karsa-navigate", path: target.pathname + target.search + target.hash });
      return;
    }
    await self.clients.openWindow(target.href);
  })());
});
