const p = new URLSearchParams(location.search);
const reason = p.get("reason") || "unknown";
const detail = p.get("detail") || "";

const COPY = {
  relay: {
    title: "Couldn't reach the gateway",
    blurb:
      "The login worked and a cookie came back, but prattle didn't accept it. " +
      "Usually that means the receiver is down or off the tailnet.",
    hint: "Check that prattle is up and gp-receiver is running.",
  },
  receiver: {
    title: "The gateway couldn't start a login",
    blurb:
      "prattle couldn't mint a login URL. That normally means it can't resolve " +
      "the GlobalProtect portal, so DNS on prattle is likely wedged.",
    hint: "Check dnsmasq and /run/gp-dns/servers.conf on prattle.",
  },
  unknown: {
    title: "Couldn't reconnect",
    blurb: "The reauth didn't complete.",
    hint: "",
  },
};

const c = COPY[reason] || COPY.unknown;
document.getElementById("title").textContent = c.title;
document.getElementById("blurb").textContent = c.blurb;
document.getElementById("hint").textContent = c.hint;

const pre = document.getElementById("detail");
if (detail) pre.textContent = detail;
else pre.remove();

document.getElementById("retry").addEventListener("click", () => {
  chrome.runtime.sendMessage("login");
  window.close();
});
document.getElementById("close").addEventListener("click", () => window.close());
