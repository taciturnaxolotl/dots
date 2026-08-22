# GP Cookie Relay extension

Grabs the single-use `prelogin-cookie` off the GlobalProtect SAML response and
POSTs it to `gp-receiver` on the tailnet, so reauth is one click instead of a
devtools copy-paste. Pairs with `atelier.services.gpGateway`.

## Use

1. Load: Chrome → `chrome://extensions` → Developer mode → Load unpacked → this
   dir. Unpacked extensions survive restarts on Chrome (Firefox release won't
   keep unsigned ones).
2. Bookmark `http://prattle.forest-regulus.ts.net:8088/`. Each click bounces you
   to a fresh Entra login; the receiver mints a new SAMLRequest every time so
   the bookmark never goes stale.
3. Click the bookmark → Duo → done. The extension catches the cookie off the ACS
   response and forwards it; a desktop notification confirms the relay.

## Note

`background.js` reads an auth cookie from a response header and forwards it,
which trips automated credential-exfiltration heuristics. It is legitimate here:
your own credential, to your own VM, over your own tailnet. If a scanner flags
it, that is the reason.
