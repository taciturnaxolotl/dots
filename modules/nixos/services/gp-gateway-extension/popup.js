const $ = (id) => document.getElementById(id);

function ago(ts) {
  if (!ts) return "";
  const s = Math.round((Date.now() - ts) / 1000);
  if (s < 60) return `${s}s ago`;
  if (s < 3600) return `${Math.round(s / 60)}m ago`;
  return `${Math.round(s / 3600)}h ago`;
}

// "Sun, 23 Aug 2026 14:17:49 EDT" -> "in 23h" / "in 45m"
function until(str) {
  if (!str) return "—";
  const t = Date.parse(str);
  if (isNaN(t)) return str;
  const s = Math.round((t - Date.now()) / 1000);
  if (s <= 0) return "expired";
  if (s < 3600) return `in ${Math.round(s / 60)}m`;
  return `in ${Math.round(s / 3600)}h`;
}

function render({ status, relay }) {
  const s = status || {};
  const state = !s.reachable ? "unreachable" : s.state || "down";
  $("dot").className = "dot " + state;
  $("state").textContent =
    state === "up" ? "connected"
    : state === "unreachable" ? "receiver offline"
    : state === "failed" ? "auth failed"
    : state;
  $("addr").textContent = s.address || "—";
  $("exp").textContent = s.expires ? until(s.expires) : "—";
  $("poll").textContent = s.at ? ago(s.at) : "";

  if (relay) {
    const label =
      relay.state === "ok" ? "relayed"
      : relay.state === "relaying" ? "relaying…"
      : relay.state === "fail" ? "relay failed" : relay.state;
    $("relay").textContent = `${label}${relay.user ? " · " + relay.user : ""} · ${ago(relay.at)}`;
  }
}

async function refresh() {
  render(await chrome.storage.local.get(["status", "relay"]));
}

chrome.storage.onChanged.addListener(refresh);
chrome.runtime.sendMessage("poll"); // force a fresh status on open
refresh();

$("login").addEventListener("click", () => {
  chrome.runtime.sendMessage("login");
  window.close();
});
