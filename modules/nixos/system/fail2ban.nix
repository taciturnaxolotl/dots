{
  lib,
  config,
  ...
}:
let
  cfg = config.atelier.security.fail2ban;
in
{
  options.atelier.security.fail2ban = {
    enable = lib.mkEnableOption ''
      fail2ban with an sshd jail.

      Worth enabling on any host with a public IP. It is not a substitute for
      key-only auth -- it cannot stop an attack that key-only auth already
      stops -- but it cuts the constant scanner traffic that otherwise fills
      the journal and burns CPU on doomed handshakes.
    '';

    ignoreIP = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "127.0.0.0/8"
        "::1"
        # Tailscale CGNAT. Never ban over the tailnet -- it is the way back in
        # if a ban ever goes wrong.
        "100.64.0.0/10"
        "fd7a:115c:a1e0::/48"
        # RFC1918, so a flapping LAN client cannot lock the host out.
        "10.0.0.0/8"
        "172.16.0.0/12"
        "192.168.0.0/16"
      ];
      description = "CIDRs fail2ban will never ban.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.fail2ban = {
      enable = true;
      inherit (cfg) ignoreIP;

      # Repeat offenders earn progressively longer bans, so the handful of
      # hosts responsible for most of the traffic drop off quickly.
      bantime = "1h";
      bantime-increment = {
        enable = true;
        formula = "ban.Time * math.exp(float(ban.Count+1)*banFactor)/math.exp(1*banFactor)";
        maxtime = "168h"; # one week ceiling
        overalljails = true;
      };

      jails.sshd.settings = {
        enabled = true;
        # Match sshd's real port. `mode = normal` catches invalid-user and
        # failed-auth lines, which is what scanners generate against a
        # key-only host.
        mode = "normal";
        port = "ssh";
        maxretry = 5;
        findtime = "10m";
      };
    };
  };
}
