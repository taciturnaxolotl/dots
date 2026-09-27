# One Caddy rate_limit block, for use inside a vhost's extraConfig.
#
# key defaults to {client_ip}, which holds the visitor's address only because
# atelier.caddy.trustCloudflare names Cloudflare's edge as a trusted proxy.
# Without that, a proxied name sees an edge machine here and every visitor
# shares one bucket. Pass matcher to limit a subset of routes, and key when a
# single client spreads itself over several addresses.
{
  zone,
  events,
  window ? "1m",
  matcher ? "",
  key ? "{client_ip}",
}:
''
  rate_limit ${matcher} {
    zone ${zone} {
      key ${key}
      events ${toString events}
      window ${window}
    }
  }
''
