{ config, lib, ... }:
let
  # `_ports` is empty for a disabled service, so this covers only what runs.
  claimed = lib.flatten (
    lib.mapAttrsToList (
      name: svc: map (port: { inherit name port; }) (svc._ports or [ ])
    ) config.atelier.services
  );

  collisions = lib.filter (group: lib.length group > 1) (
    lib.mapAttrsToList (_: group: group) (lib.groupBy (c: toString c.port) claimed)
  );

  describe =
    group: "${toString (lib.head group).port}: ${lib.concatMapStringsSep ", " (c: c.name) group}";
in
{
  # One check for the whole fleet. Keying on `_ports` rather than a single
  # `port` catches the websocket and cursor listeners, and the per-workspace
  # emojibot instances, which a scan of `port` alone never saw.
  assertions = [
    {
      assertion = collisions == [ ];
      message = ''
        Port conflicts between atelier services:
          ${lib.concatMapStringsSep "\n  " describe collisions}
      '';
    }
  ];
}
