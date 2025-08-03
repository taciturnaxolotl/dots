{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.modules.network.wifi;
  mkProfile =
    name: p:
    let
      base = {
        connection = {
          id = name;
          type = "wifi";
        };
        ipv4.method = "auto";
        ipv6 = {
          addr-gen-mode = "stable-privacy";
          method = "auto";
        };
        wifi = {
          mode = "infrastructure";
          ssid = name;
        };
      };
      sec =
        if (p ? pskVar && p.pskVar != null) then
          {
            wifi-security = {
              key-mgmt = "wpa-psk";
              psk = "$${" + p.pskVar + "}";
            };
          }
        else if (p ? psk && p.psk != null) then
          {
            wifi-security = {
              key-mgmt = "wpa-psk";
              psk = p.psk;
            };
          }
        else if (p ? pskFile && p.pskFile != null) then
          {
            wifi-security = {
              key-mgmt = "wpa-psk";
              psk = "$(" + pkgs.coreutils + "/bin/cat " + p.pskFile + ")";
            };
          }
        else
          { };
    in
    base // sec;
in
{
  options.modules.network.wifi = {
    enable = lib.mkEnableOption "Enable NetworkManager with simplified Wi-Fi profiles";
    hostName = lib.mkOption {
      type = lib.types.str;
      default = config.networking.hostName or "";
    };
    nameservers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
    };
    envFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Single environment file with PSK variables (used once).";
    };

    profiles = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule (
          { name, ... }:
          {
            options = {
              pskVar = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                description = "Variable name in envFile providing PSK";
              };
              psk = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
              };
              pskFile = lib.mkOption {
                type = lib.types.nullOr lib.types.path;
                default = null;
              };
            };
          }
        )
      );
      default = { };
      description = "Map of SSID -> { pskVar | psk | pskFile }.";
    };
  };

  config = lib.mkIf cfg.enable {
    networking = {
      hostName = lib.mkIf (cfg.hostName != "") cfg.hostName;
      nameservers = lib.mkIf (cfg.nameservers != [ ]) cfg.nameservers;
      useDHCP = false;
      dhcpcd.enable = false;
      networkmanager = {
        enable = true;
        dns = "none";
        ensureProfiles = {
          environmentFiles = lib.optional (cfg.envFile != null) cfg.envFile;
          profiles = lib.mapAttrs mkProfile cfg.profiles;
        };
      };
    };
  };
}
