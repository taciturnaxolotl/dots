# simple network manager
#
# This module provides a simpler way to declare wifi profiles with network manager.
# - you can pass the PSK via environment variable, direct value, or file.
# - profiles are defined in `atelier.network.wifi.profiles`.
#
# Example usage:
#   atelier.network.wifi = {
#     enable = true;
#     profiles = {
#       "MySSID" = { psk = "supersecret"; };
#     };
#   };

{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.atelier.network.wifi;
  mkProfile =
    name:
    {
      pskVar ? null,
      psk ? null,
      pskFile ? null,
    }:
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
        if pskVar != null then
          {
            wifi-security = {
              key-mgmt = "wpa-psk";
              psk = "$" + pskVar;
            };
          }
        else if psk != null then
          {
            wifi-security = {
              key-mgmt = "wpa-psk";
              psk = psk;
            };
          }
        else if pskFile != null then
          {
            wifi-security = {
              key-mgmt = "wpa-psk";
              psk = "$(" + pkgs.coreutils + "/bin/cat " + pskFile + ")";
            };
          }
        else
          { };
    in
    base // sec;
in
{
  options.atelier.network.wifi = {
    enable = lib.mkEnableOption "Enable NetworkManager with simplified Wi-Fi profiles";
    hostName = lib.mkOption {
      type = lib.types.str;
      default = lib.mkDefault (config.networking.hostName or "nixos");
    };
    nameservers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = lib.mkDefault [ ];
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
