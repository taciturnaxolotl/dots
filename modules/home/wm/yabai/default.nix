{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.atelier.wm.yabai;
  yabaiExe = lib.getExe cfg.package;

  mkConfigLine =
    setting: value:
    if value == true then "yabai -m config ${setting} on"
    else if value == false then "yabai -m config ${setting} off"
    else "yabai -m config ${setting} ${toString value}";

  globalSettings = lib.filterAttrs (_: v: v != null) cfg.config.global;
  spaceSettings = lib.filterAttrs (_: v: v != null) cfg.config.space;

  globalLines = lib.mapAttrsToList mkConfigLine globalSettings;
  spaceLines = lib.mapAttrsToList (setting: value: ''
    yabai -m config --space $SPACE ${setting} ${toString value}
  '') spaceSettings;

  ruleLines = map (r: "yabai -m rule --add ${r}") cfg.config.rules;

  scriptContent = ''
    #!/usr/bin/env sh

    # Re-load scripting addition after dock restarts
    yabai -m signal --add event=dock_did_restart action="sudo ${yabaiExe} --load-sa"
    sudo ${yabaiExe} --load-sa

    # Global settings
    ${lib.concatStringsSep "\n" globalLines}

    # Space settings (only for spaces that exist)
    SPACE_COUNT=$(yabai -m query --spaces 2>/dev/null | ${lib.getExe pkgs.jq} 'length' 2>/dev/null)
    if [ -z "$SPACE_COUNT" ] || [ "$SPACE_COUNT" -lt 1 ]; then
      SPACE_COUNT=1
    fi
    for SPACE in $(seq 1 "$SPACE_COUNT"); do
      ${lib.concatStringsSep "\n    " spaceLines}
    done

    # Rules
    ${lib.concatStringsSep "\n" ruleLines}

    ${cfg.extraConfig}
  '';

  skhdrcContent = cfg.skhdConfig + "\n" + cfg.extraSkhdConfig;
in
{
  options.atelier.wm.yabai = {
    enable = lib.mkEnableOption "Enable yabai window manager and skhd hotkey daemon";

    package = lib.mkPackageOption pkgs "yabai" { };

    skhdPackage = lib.mkPackageOption pkgs "skhd" { };

    config = {
      global = lib.mkOption {
        type = lib.types.submodule {
          freeformType = with lib.types; attrsOf (oneOf [ bool int float str ]);
          options = {
            mouse_follows_focus = lib.mkOption {
              type = lib.types.nullOr lib.types.bool;
              default = true;
            };
            focus_follows_mouse = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = "autofocus";
            };
            window_placement = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = "second_child";
            };
            layout = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = "bsp";
            };
            split_type = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = "auto";
            };
            split_ratio = lib.mkOption {
              type = lib.types.nullOr (lib.types.oneOf [ lib.types.float lib.types.str ]);
              default = 0.50;
            };
            auto_balance = lib.mkOption {
              type = lib.types.nullOr lib.types.bool;
              default = false;
            };
            mouse_modifier = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = "alt";
            };
            mouse_action1 = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = "move";
            };
            mouse_action2 = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = "resize";
            };
          };
        };
        default = { };
        description = "Global yabai settings (mouse, layout, etc.)";
      };

      space = lib.mkOption {
        type = lib.types.submodule {
          freeformType = with lib.types; attrsOf (oneOf [ bool int float str ]);
          options = {
            layout = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = "bsp";
            };
            split_type = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = "auto";
            };
            top_padding = lib.mkOption {
              type = lib.types.nullOr lib.types.int;
              default = 8;
            };
            bottom_padding = lib.mkOption {
              type = lib.types.nullOr lib.types.int;
              default = 8;
            };
            left_padding = lib.mkOption {
              type = lib.types.nullOr lib.types.int;
              default = 8;
            };
            right_padding = lib.mkOption {
              type = lib.types.nullOr lib.types.int;
              default = 8;
            };
            window_gap = lib.mkOption {
              type = lib.types.nullOr lib.types.int;
              default = 6;
            };
          };
        };
        default = { };
        description = "Per-space yabai settings (padding, gap, layout)";
      };

      rules = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "yabai rules (e.g. app=\"^Dia$\" space=1, app=\"^UTM$\" manage=off)";
      };
    };

    extraConfig = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Extra raw lines appended to ~/.yabairc";
    };

    skhdConfig = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "skhd configuration (same format as ~/.skhdrc)";
    };

    extraSkhdConfig = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Extra raw lines appended to skhdrc";
    };

    borders = lib.mkOption {
      type = with lib.types; attrsOf anything;
      default = {
        style = "round";
        width = 5.0;
        hidpi = "on";
        active_color = "0xff394E9A";
        inactive_color = "0x33394E9A";
      };
      description = "JankyBorders settings (passed directly to bordersrc)";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package ];

    home.file.".yabairc" = {
      executable = true;
      text = scriptContent;
      onChange = ''
        ${config.home.homeDirectory}/.yabairc
      '';
    };

    launchd.agents.yabai = {
      enable = true;
      config = {
        ProgramArguments = [
          yabaiExe
          "-c"
          "${config.home.homeDirectory}/.yabairc"
        ];
        ProcessType = "Interactive";
        KeepAlive = true;
        RunAtLoad = true;
      };
    };

    services.skhd = {
      enable = true;
      package = cfg.skhdPackage;
      config = skhdrcContent;
    };

    services.jankyborders = {
      enable = true;
      settings = cfg.borders;
    };
  };
}
