{
  config,
  lib,
  pkgs,
  ...
}:
{
  # Deploys reach these boxes over Tailscale SSH, so tailscaled is both the
  # transport and the ssh server. When activation restarts it, it severs the
  # deploy's own connection, and deploy-rs then sits in "Waiting for
  # confirmation event..." until the socket gives up. Twice on 2026-08-23 that
  # cost a 2h20m CI run and a rollback of a deploy that had already succeeded.
  #
  # So keep tailscaled out of the switch, and hand its restart to a timer that
  # fires once the deploy has let go. restartTriggers restarts the scheduler
  # unit exactly when the tailscale package changes; arming the timer takes
  # milliseconds, so activation is never blocked.
  config = lib.mkIf config.services.tailscale.enable {
    systemd.services.tailscaled.restartIfChanged = false;

    systemd.services.tailscaled-deferred-restart = {
      description = "Restart tailscaled once the deploy has let go of the connection";
      wantedBy = [ "multi-user.target" ];
      after = [ "tailscaled.service" ];
      restartTriggers = [ config.services.tailscale.package ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      path = [ pkgs.systemd ];
      script = ''
        pid=$(systemctl show -p MainPID --value tailscaled.service)
        running=$(readlink "/proc/$pid/exe" 2>/dev/null || true)
        want=${config.services.tailscale.package}/bin/.tailscaled-wrapped

        # At boot the two already agree, so this is a no-op and no timer is armed.
        [ "$running" = "$want" ] && exit 0

        systemd-run --on-active=120 --description="deferred tailscaled restart" \
          systemctl restart tailscaled.service
      '';
    };
  };
}
