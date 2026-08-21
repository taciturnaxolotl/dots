{ ... }:
{
  # Pull custom-built packages (knot, herald, the tangled bits) from prattle's
  # tailnet-only attic cache instead of recompiling them on every deploy. The
  # cache is public, so no token is needed to pull — the tailscale0 firewall is
  # the gate. These are extra-* keys, so cache.nixos.org is still tried first and
  # an unreachable prattle just falls back to it.
  nix.settings = {
    extra-substituters = [ "http://prattle:8091/dots" ];
    extra-trusted-public-keys = [ "dots:Mgol9jjaoUcN6pfgLetO3fe/JAm/fVpKXYBZaQ1MhFM=" ];
  };
}
