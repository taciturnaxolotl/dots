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
const RENEW_BEFORE_MS = 60 * 60 * 1000; // renew when under an hour remains
const NEEDS_HUMAN_MS = 25 * 1000; // no cookie by now => interaction required

const BADGE = {
  up: { text: "", color: "#3fb56b" },
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
    // Still no cookie: the chain wants a human. Surface the tab rather than
    // leaving a silent failure.
    if (authTabId === null) return;
    const id = authTabId;
    authTabId = null;
    try {
      await chrome.tabs.update(id, { active: true });
      await chrome.windows.update((await chrome.tabs.get(id)).windowId, { focused: true });
      notify("GlobalProtect", "Reauth needs you — finish the login in the open tab.");
    } catch (_) {
      /* tab already gone */
    }
  }, NEEDS_HUMAN_MS);
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
    setBadge(s.state === "up" ? "up" : s.state === "failed" ? "failed" : "down");
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
        setTimeout(pollStatus, 4000);
      })
      .catch((e) => {
        chrome.storage.local.set({ relay: { state: "fail", detail: String(e), at: Date.now() } });
        setBadge("failed");
        finishLogin(details.tabId);
        notify("GlobalProtect relay failed", String(e));
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
