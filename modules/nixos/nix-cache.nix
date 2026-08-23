{ ... }:
{
  # Pull custom-built packages (knot, herald, the tangled bits) from prattle's
  # tailnet-only attic cache instead of recompiling them on every deploy. The
  # cache is public, so no token is needed to pull — the tailscale0 firewall is
  # the gate.
  #
  # An unreachable prattle does NOT quietly fall back to cache.nixos.org, whatever
  # the extra-* keys suggest. Stock nix 2.34 aborts the daemon instead: a failing
  # narinfo worker sets the thread pool's quit flag, the next worker logs its own
  # error through TunnelLogger, and that write throws Interrupted from inside a
  # catch block and unwinds out of the thread. The client sees "Nix daemon
  # disconnected unexpectedly" and every host loses the ability to build anything.
  # download-attempts, connect-timeout and --fallback were all tried; none help.
  # NixOS/nix#3768 (open since 2020) and NixOS/nix#12871.
  #
  # The overlay in flake.nix patches that crash out, which is what makes this line
  # safe to keep. Removing one without the other brings the outage back.
  nix.settings = {
    extra-substituters = [ "http://prattle:8091/dots" ];
    extra-trusted-public-keys = [ "dots:Mgol9jjaoUcN6pfgLetO3fe/JAm/fVpKXYBZaQ1MhFM=" ];
  };
}
