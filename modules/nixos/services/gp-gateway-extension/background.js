// GP Cookie Relay
// Grabs the single-use prelogin-cookie off the GlobalProtect SAML response and
// POSTs it to gp-receiver on the tailnet. Also polls the receiver's /status so
// the icon badge and popup reflect the real tunnel state.
const HOST = "http://prattle.forest-regulus.ts.net:8088";
const RELAY = HOST + "/cookie";
const STATUS = HOST + "/status";
const ACS = "https://globalprotect.cedarville.edu/SAML20/SP/ACS*";

const BADGE = {
  up: { text: "", color: "#3fb56b" }, // connected: clean icon, no clutter
  relaying: { text: "…", color: "#5a7fd6" },
  failed: { text: "!", color: "#d64f5a" },
  down: { text: "·", color: "#8a8397" },
};

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

async function pollStatus() {
  try {
    const r = await fetch(STATUS, { cache: "no-store" });
    const s = await r.json();
    await chrome.storage.local.set({ status: { ...s, at: Date.now(), reachable: true } });
    setBadge(s.state === "up" ? "up" : s.state === "failed" ? "failed" : "down");
  } catch (e) {
    await chrome.storage.local.set({ status: { reachable: false, at: Date.now(), error: String(e) } });
    setBadge("down");
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
        notify("GlobalProtect relay", msg);
        // Give the tunnel a moment to come up, then reflect real status.
        setTimeout(pollStatus, 4000);
      })
      .catch((e) => {
        chrome.storage.local.set({ relay: { state: "fail", detail: String(e), at: Date.now() } });
        setBadge("failed");
        notify("GlobalProtect relay failed", String(e));
      });
  },
  { urls: [ACS] },
  ["responseHeaders", "extraHeaders"],
);

// Popup asks us to start a login: open the receiver root, which mints a fresh
// SAMLRequest and 302s to Entra.
chrome.runtime.onMessage.addListener((msg, _s, send) => {
  if (msg === "login") {
    chrome.tabs.create({ url: HOST + "/" });
    send({ ok: true });
  } else if (msg === "poll") {
    pollStatus().then(() => send({ ok: true }));
  }
  return true;
});
