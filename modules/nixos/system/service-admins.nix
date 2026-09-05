# Operator accounts scoped to a few services instead of wheel.

{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.atelier.serviceAdmins;

  systemctl = "/run/current-system/sw/bin/systemctl";
  journalctl = "/run/current-system/sw/bin/journalctl";

  nopasswd = command: {
    inherit command;
    options = [ "NOPASSWD" ];
  };

  # sudo matches arguments exactly and a trailing "*" demands at least one more
  # word, so the bare journalctl needs its own entry alongside the wildcard.
  commandsFor = unit: [
    (nopasswd "${systemctl} start ${unit}")
    (nopasswd "${systemctl} stop ${unit}")
    (nopasswd "${systemctl} restart ${unit}")
    (nopasswd "${systemctl} status ${unit}")
    (nopasswd "${journalctl} -u ${unit}")
    (nopasswd "${journalctl} -u ${unit} *")
  ];

  rulesFor =
    user: admin:
    lib.optional (admin.units != [ ]) {
      users = [ user ];
      commands = lib.concatMap commandsFor admin.units;
    }
    ++ map (account: {
      users = [ user ];
      runAs = account;
      commands = [ (nopasswd "ALL") ];
    }) admin.accounts;
in
{
  options.atelier.serviceAdmins = lib.mkOption {
    default = { };
    description = ''
      Users who may operate a few services without being in wheel. Declares the
      account and narrows passwordless sudo to the listed units and accounts.
    '';
    example = lib.literalExpression ''
      {
        duncan = {
          keys = [ "ssh-ed25519 AAAA..." ];
          units = [
            "botme.service"
            "docker-cap.service"
          ];
          accounts = [ "botme" ];
        };
      }
    '';
    type = lib.types.attrsOf (
      lib.types.submodule {
        options = {
          keys = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = "SSH public keys authorized for the account.";
          };

          units = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = ''
              Units this user may start, stop, restart, and read the journal of.
              These are unit names, so the .service suffix is part of them.
            '';
          };

          accounts = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = ''
              Service accounts this user may become, with `sudo -iu <account>`.
              Everything that account can reach comes with it, including any
              deploy key in its home.
            '';
          };
        };
      }
    );
  };

  config = {
    users.users = lib.mapAttrs (_: admin: {
      isNormalUser = true;
      shell = pkgs.zsh;
      openssh.authorizedKeys.keys = admin.keys;
    }) cfg;

    security.sudo.extraRules = lib.concatLists (lib.mapAttrsToList rulesFor cfg);
  };
}
