// GP Cookie Relay
// Grabs the single-use prelogin-cookie off the GlobalProtect SAML response and
// POSTs it to gp-receiver on the tailnet. Also polls the receiver's /status so
// the icon badge and popup reflect the real tunnel state.
//
// Reauth is normally silent: Duo remembers the device for 31 days and Entra
// keeps a session, so the SAML chain is pure redirects. We walk it in a
// background tab and close it, which makes the daily relogin zero-click. If the
// chain actually needs a human (Duo prompt, expired Entra session) the tab is
// surfaced instead.
const HOST = "http://prattle.forest-regulus.ts.net:8088";
const RELAY = HOST + "/cookie";
const STATUS = HOST + "/status";
const ACS = "https://globalprotect.cedarville.edu/SAML20/SP/ACS*";

const AUTO_MIN_GAP_MS = 5 * 60 * 1000; // never retry harder than every 5 min
// Renew with half a day still on the clock. The chain is silent and cheap, so
// keeping a wide margin means a lapse can never land in the middle of a
// working day just because the last login happened to be at an awkward hour.
const RENEW_BEFORE_MS = 12 * 60 * 60 * 1000;
const NEEDS_HUMAN_MS = 25 * 1000; // no cookie by now => interaction required

const BADGE = {
  up: { text: "", color: "#3fb56b" },
  connecting: { text: "…", color: "#5a7fd6" },
  relaying: { text: "…", color: "#5a7fd6" },
  failed: { text: "!", color: "#d64f5a" },
  down: { text: "·", color: "#8a8397" },
};

let authTabId = null;
let authTimer = null;
let lastAutoAttempt = 0;

function setBadge(state) {
  const b = BADGE[state] || BADGE.down;
  chrome.action.setBadgeText({ text: b.text });
  chrome.action.setBadgeBackgroundColor({ color: b.color });
}

function notify(title, message) {
  chrome.notifications.create({
    type: "basic",
    iconUrl: "icon-128.png",
    title,
    message,
  });
}

// Open the receiver root, which mints a fresh SAMLRequest and 302s to Entra.
// background=true keeps it out of the way; we close it once the cookie lands.
async function startLogin({ background }) {
  if (authTabId !== null) return; // one login in flight at a time
  const tab = await chrome.tabs.create({ url: HOST + "/", active: !background });
  authTabId = tab.id;
  clearTimeout(authTimer);
  authTimer = setTimeout(async () => {
    if (authTabId === null) return;
    const id = authTabId;
    authTabId = null;
    try {
      const t = await chrome.tabs.get(id);
      // Never left the receiver: it failed to mint a login URL (usually DNS on
      // prattle). That is broken, not waiting on a human, so explain it.
      if (t.url && t.url.startsWith(HOST)) {
        await chrome.tabs.remove(id).catch(() => {});
        openFailurePage("receiver", t.url);
        notify("GlobalProtect", "Gateway couldn't start a login.");
        return;
      }
      // Otherwise we are parked at the IdP: a human needs to finish it.
      await chrome.tabs.update(id, { active: true });
      await chrome.windows.update(t.windowId, { focused: true });
      notify("GlobalProtect", "Reauth needs you — finish the login in the open tab.");
    } catch (_) {
      /* tab already gone */
    }
  }, NEEDS_HUMAN_MS);
}

function openFailurePage(reason, detail) {
  const u = new URL(chrome.runtime.getURL("failed.html"));
  u.searchParams.set("reason", reason);
  if (detail) u.searchParams.set("detail", String(detail).slice(0, 500));
  chrome.tabs.create({ url: u.toString(), active: true });
}

function finishLogin(tabId) {
  clearTimeout(authTimer);
  if (authTabId !== null && (tabId === undefined || tabId === authTabId)) {
    chrome.tabs.remove(authTabId).catch(() => {});
  }
  authTabId = null;
}

function shouldAutoReauth(s) {
  if (Date.now() - lastAutoAttempt < AUTO_MIN_GAP_MS) return false;
  if (!s || s.reachable === false) return false; // receiver down, nothing to do
  if (s.state === "connecting") return false; // handshake in flight, let it land
  if (s.state !== "up") return true; // tunnel down or auth failed
  if (s.expires) {
    const t = Date.parse(s.expires);
    if (!isNaN(t) && t - Date.now() < RENEW_BEFORE_MS) return true;
  }
  return false;
}

async function pollStatus() {
  let s;
  try {
    const r = await fetch(STATUS, { cache: "no-store" });
    s = { ...(await r.json()), at: Date.now(), reachable: true };
    setBadge(BADGE[s.state] ? s.state : "down");
  } catch (e) {
    s = { reachable: false, at: Date.now(), error: String(e) };
    setBadge("down");
  }
  await chrome.storage.local.set({ status: s });

  const { autoReauth = true } = await chrome.storage.local.get("autoReauth");
  if (autoReauth && shouldAutoReauth(s)) {
    lastAutoAttempt = Date.now();
    startLogin({ background: true });
  }
}

chrome.runtime.onInstalled.addListener(() => {
  chrome.alarms.create("poll", { periodInMinutes: 0.5 });
  pollStatus();
});
chrome.runtime.onStartup.addListener(pollStatus);
chrome.alarms.onAlarm.addListener((a) => {
  if (a.name === "poll") pollStatus();
});

chrome.tabs.onRemoved.addListener((id) => {
  if (id === authTabId) {
    clearTimeout(authTimer);
    authTabId = null;
  }
});

chrome.webRequest.onHeadersReceived.addListener(
  (details) => {
    let cookie = null;
    let user = null;
    for (const h of details.responseHeaders || []) {
      const n = h.name.toLowerCase();
      if (n === "prelogin-cookie") cookie = h.value;
      if (n === "saml-username") user = h.value;
    }
    if (!cookie) return;

    setBadge("relaying");
    chrome.storage.local.set({ relay: { state: "relaying", user, at: Date.now() } });
    fetch(RELAY, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ user, cookie }),
    })
      .then((r) => r.text())
      .then((t) => {
        const msg = t.trim().slice(0, 200);
        chrome.storage.local.set({ relay: { state: "ok", user, detail: msg, at: Date.now() } });
        finishLogin(details.tabId);
        // The gateway handshake takes a few seconds, so one poll would catch
        // the tunnel mid-connect and leave the popup showing no address.
        // Keep checking until it settles.
        for (const ms of [3000, 8000, 15000, 30000, 60000]) setTimeout(pollStatus, ms);
      })
      .catch((e) => {
        chrome.storage.local.set({ relay: { state: "fail", detail: String(e), at: Date.now() } });
        setBadge("failed");
        finishLogin(details.tabId);
        openFailurePage("relay", e);
      });
  },
  { urls: [ACS] },
  ["responseHeaders", "extraHeaders"],
);

chrome.runtime.onMessage.addListener((msg, _s, send) => {
  if (msg === "login") {
    startLogin({ background: false });
    send({ ok: true });
  } else if (msg === "poll") {
    pollStatus().then(() => send({ ok: true }));
  }
  return true;
});
