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

  # A log file has to be pinned by the command, not by the sudo rule: sudo
  # matches argument words, so a rule ending in `*` would let any path through
  # as a trailing operand. Baking the path into a wrapper removes the choice.
  #
  # The wrapper takes no arguments but -f, and writes the whole file otherwise.
  # Passing tail's flags through would mean telling flags from their values
  # (the 2 in `-n 2` is not a path, but `/etc/shadow` is), and piping into head
  # or grep covers the same ground without the guesswork.
  logReader =
    name: path:
    pkgs.writeShellScriptBin "${name}-log" ''
      case "''${1-}" in
        "") exec ${pkgs.coreutils}/bin/cat ${lib.escapeShellArg path} ;;
        -f | --follow) [ $# -eq 1 ] && exec ${pkgs.coreutils}/bin/tail -n +1 -f ${lib.escapeShellArg path} ;;
      esac
      echo "usage: ${name}-log [-f]   (pipe it through grep, head or less)" >&2
      exit 2
    '';

  readersFor = admin: lib.mapAttrsToList logReader admin.logFiles;

  # The rule has to name the path the user's shell resolves, not the store
  # path, or sudo compares two different strings and refuses.
  readerPath = name: "/run/current-system/sw/bin/${name}-log";

  # sudo matches arguments exactly and a trailing "*" demands at least one more
  # word, so the bare journalctl needs its own entry alongside the wildcard.
  # Both spellings of the unit are listed because systemd accepts either and
  # typing the bare name is the obvious thing to do; without it `journalctl -u
  # botme` is refused and reads as having no access at all.
  commandsFor =
    unit:
    lib.concatMap
      (u: [
        (nopasswd "${systemctl} start ${u}")
        (nopasswd "${systemctl} stop ${u}")
        (nopasswd "${systemctl} restart ${u}")
        (nopasswd "${systemctl} status ${u}")
        (nopasswd "${journalctl} -u ${u}")
        (nopasswd "${journalctl} -u ${u} *")
      ])
      (lib.unique [
        unit
        (lib.removeSuffix ".service" unit)
      ]);

  rulesFor =
    user: admin:
    lib.optional (admin.units != [ ]) {
      users = [ user ];
      commands = lib.concatMap commandsFor admin.units;
    }
    ++ lib.optional (admin.logFiles != { }) {
      users = [ user ];
      commands = lib.concatMap (name: [
        (nopasswd (readerPath name))
        (nopasswd "${readerPath name} -f")
      ]) (lib.attrNames admin.logFiles);
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

          logFiles = lib.mkOption {
            type = lib.types.attrsOf lib.types.path;
            default = { };
            example = {
              botme-access = "/var/log/caddy/access-botme.idk.dunkirk.sh.log";
            };
            description = ''
              Log files this user may read, as name -> path. Each entry becomes
              a `<name>-log` command run through sudo, which writes the whole
              file, or follows it with -f. Use it for logs owned by a service
              account, which are otherwise unreadable without wheel.
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

    # The readers have to be on PATH for the sudo rules to name the same binary
    # the user types.
    environment.systemPackages = lib.concatMap readersFor (lib.attrValues cfg);

    security.sudo.extraRules = lib.concatLists (lib.mapAttrsToList rulesFor cfg);
  };
}
