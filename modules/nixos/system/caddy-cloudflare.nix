# Teaches Caddy which peers are allowed to name the real client.
#
# Cloudflare terminates TLS for the proxied vhosts, so without this {client_ip}
# is an edge machine and every rate limit keyed on it counts the whole internet
# as one client. Caddy ignores these headers from a peer outside the ranges, so
# the vhosts that are still DNS-only keep using the socket's address.

{ config, lib, ... }:

let
  # https://api.cloudflare.com/client/v4/ips
  ranges = [
    "173.245.48.0/20"
    "103.21.244.0/22"
    "103.22.200.0/22"
    "103.31.4.0/22"
    "141.101.64.0/18"
    "108.162.192.0/18"
    "190.93.240.0/20"
    "188.114.96.0/20"
    "197.234.240.0/22"
    "198.41.128.0/17"
    "162.158.0.0/15"
    "104.16.0.0/13"
    "104.24.0.0/14"
    "172.64.0.0/13"
    "131.0.72.0/22"
    "2400:cb00::/32"
    "2606:4700::/32"
    "2803:f800::/32"
    "2405:b500::/32"
    "2405:8100::/32"
    "2a06:98c0::/29"
    "2c0f:f248::/32"
  ];
in
{
  options.atelier.caddy.trustCloudflare = lib.mkEnableOption ''
    trusting Cloudflare's edge to report the client address. Enable on a host
    whose vhosts are proxied; a new Cloudflare range means traffic from it is
    silently attributed to the edge until the list above is refreshed
  '';

  config = lib.mkIf config.atelier.caddy.trustCloudflare {
    # Cf-Connecting-IP first: Cloudflare overwrites it with the one real client,
    # while X-Forwarded-For is a list the client can prepend to.
    services.caddy.globalConfig = ''
      servers {
        client_ip_headers Cf-Connecting-IP X-Forwarded-For
        trusted_proxies static ${lib.concatStringsSep " " ranges}
      }
    '';
  };
}
