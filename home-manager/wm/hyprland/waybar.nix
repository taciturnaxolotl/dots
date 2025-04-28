{
  outputs,
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  commonDeps = with pkgs; [coreutils gnugrep systemd];
  # Function to simplify making waybar outputs
  mkScript = {
    name ? "script",
    deps ? [],
    script ? "",
  }:
    lib.getExe (pkgs.writeShellApplication {
      inherit name;
      text = script;
      runtimeInputs = commonDeps ++ deps;
    });
  # Specialized for JSON outputs
  mkScriptJson = {
    name ? "script",
    deps ? [],
    pre ? "",
    text ? "",
    tooltip ? "",
    alt ? "",
    class ? "",
    percentage ? "",
  }:
    mkScript {
      inherit name;
      deps = [pkgs.jq] ++ deps;
      script = ''
        ${pre}
        jq -cn \
          --arg text "${text}" \
          --arg tooltip "${tooltip}" \
          --arg alt "${alt}" \
          --arg class "${class}" \
          --arg percentage "${percentage}" \
          '{text:$text,tooltip:$tooltip,alt:$alt,class:$class,percentage:$percentage}'
      '';
    };

  hyprlandCfg = config.wayland.windowManager.hyprland;
in {
  # Let it try to start a few more times
  systemd.user.services.waybar = {
    Unit.StartLimitBurst = 30;
  };
  programs.waybar = {
    enable = true;
    package = pkgs.waybar.overrideAttrs (oa: {
      mesonFlags = (oa.mesonFlags or []) ++ ["-Dexperimental=true"];
    });
    systemd.enable = true;
    settings = {
      primary = {
        exclusive = false;
        passthrough = false;
        height = 46;
        margin = "6";
        position = "top";
        modules-left =
          [
            "custom/menu"
            "custom/currentplayer"
            "custom/player"
            "hyprland/workspaces"
            "hyprland/submap"
          ];

        modules-center = [
          "cpu"
          "memory"
          "disk"
          "clock"
          "pulseaudio"
          "battery"
          "idle_inhibitor"
          # "custom/unread-mail"
        ];

        modules-right = [
          # "custom/gammastep" TODO: currently broken for some reason
          "network"
          "bluetooth"
          "tray"
          "privacy"
          "custom/webcam"
          "custom/hostname"
        ];

        clock = {
          interval = 1;
          format = "{:%d/%m %H:%M:%S}";
          format-alt = "{:%Y-%m-%d %H:%M:%S %z}";
          on-click-left = "mode";
          tooltip-format = ''
            <big>{:%Y %B}</big>
            <tt><small>{calendar}</small></tt>'';
        };

        cpu = {
          format = "  {usage}%";
        };
        
        memory = {
          format = "  {}%";
          interval = 5;
        };

        disk = {
          interval = 5;
          unit = "GB";
          format = "󰋊 {percentage_used}%";
        };

        pulseaudio = {
          format = "{icon}  {volume}%";
          format-muted = "   0%";
          format-icons = {
            headphone = "󰋋 ";
            headset = "󰋎 ";
            portable = " ";
            default = [
              " "
              " "
              " "
            ];
          };
          on-click = lib.getExe pkgs.pavucontrol;
        };

        idle_inhibitor = {
          format = "{icon}";
          format-icons = {
            activated = "󰅶 ";
            deactivated = "󰾫 ";
          };
          tooltip-format-activated =
            "Caffinated! device will not sleep.";
          tooltip-format-deactivated =
            "no caffeine :( device will sleep when not in use.";
        };

        battery = {
          interval = 5;
          bat = "BAT1";
          # full-at = 94;
          format = "{icon} {capacity}%";
          format-icons = [ "󰁺" "󰁻" "󰁼" "󰁽" "󰁾" "󰁿" "󰂀" "󰂁" "󰂂" "󰁹" ];
          states = {
            battery-10 = 10;
            battery-20 = 20;
            battery-30 = 30;
            battery-40 = 40;
            battery-50 = 50;
            battery-60 = 60;
            battery-70 = 70;
            battery-80 = 80;
            battery-90 = 90;
            battery-100 = 100;
          };
          # <https://github.com/Alexays/Waybar/issues/1938>
          # the wiki lies about this, does not match
          # /sys/class/power_supply/BAT0/status
          format-plugged = "󰚥 AC";
          format-charging-battery-10 = "󰢜 {capacity}%";
          format-charging-battery-20 = "󰂆 {capacity}%";
          format-charging-battery-30 = "󰂇 {capacity}%";
          format-charging-battery-40 = "󰂈 {capacity}%";
          format-charging-battery-50 = "󰢝 {capacity}%";
          format-charging-battery-60 = "󰂉 {capacity}%";
          format-charging-battery-70 = "󰢞 {capacity}%";
          format-charging-battery-80 = "󰂊 {capacity}%";
          format-charging-battery-90 = "󰂋 {capacity}%";
          format-charging-battery-100 = "󰂅 {capacity}%";
        };

        "hyprland/workspaces" = {
          format =  "{icon}   {windows}";
          window-rewrite-default =  " ";
          window-rewrite-seperator = "";
          window-rewrite = {
            "title<.*github.*>" = "󰊤 ";
            "title<.*youtube.*>" = " ";
            "title<*Gmail*>" = "󰊫 ";
            "class<firefox>" = " ";
            "obs" = " ";
            "alacritty" = " ";
            "class<com.mitchellh.ghostty>" = "󰊠 ";
            "foot" = " ";
            "code" = "󰨞 ";
            "slack" = "󰒱 ";
            "spotify" = "󰓇 ";
            "class<org.gnome.Nautilus>" = "󰉓 ";
            "class<kicad>" = " ";
            "class<dev.zed.Zed>" = " ";
            "class<chromium-browser>" = " ";
          };
        };

        network = {
          interval = 3;
          format-wifi = "{icon}   {essid}";
          format-icons = [ "󰤟" "󰤢" "󰤥" "󰤨" ];
          format-ethernet = "󰈁 Connected";
          format-disconnected = "󱐤 ";
          tooltip-format = ''
            {ifname}
            {ipaddr}/{cidr}
            Up: {bandwidthUpBits}
            Down: {bandwidthDownBits}'';
          on-click = mkScript {
            deps = [pkgs.wpa_supplicant pkgs.notify-desktop];
            script = ''wpa_cli reconnect; notify-desktop "reconnecting to wifi" -t 1200'';
          };
        };

        bluetooth = {
          format-on = "󰂯";
          format-off = "󰂲";
          format-disabled = "󰂲";
          format-connected = "󰂱 {num_connections}";
          format-connected-battery = "󰂱 {device_alias} ({device_battery_percentage}%) ({num_connections})";
          on-click = "overskride";
        };

        "custom/menu" = {
          interval = 1;
          return-type = "json";
          exec = mkScriptJson {
            deps = lib.optional hyprlandCfg.enable hyprlandCfg.package;
            text = " ";
            tooltip = ''$(grep PRETTY_NAME /etc/os-release | cut -d '"' -f2)'';
            class = let
              isFullScreen =
                if hyprlandCfg.enable
                then "hyprctl activewindow -j | jq -e '.fullscreen' &>/dev/null"
                else "false";
            in "$(if ${isFullScreen}; then echo fullscreen; fi)";
          };
        };

        "custom/hostname" = {
          exec = mkScript {script = ''echo "$USER@$HOSTNAME"'';};
          on-click = mkScript {script = "systemctl --user restart waybar";};
        };

        "custom/unread-mail" = {
          interval = 5;
          return-type = "json";
          exec = mkScriptJson {
            deps = [pkgs.findutils pkgs.procps];
            pre = ''
              count=$(find ~/Mail/*/Inbox/new -type f | wc -l)
              if pgrep mbsync &>/dev/null; then
                status="syncing"
              else
                if [ "$count" == "0" ]; then
                  status="read"
                else
                  status="unread"
                fi
              fi
            '';
            text = "$count";
            alt = "$status";
          };
          format = "{icon}  ({})";
          format-icons = {
            "read" = "󰇯";
            "unread" = "󰇮";
            "syncing" = "󰁪";
          };
        };

        "custom/currentplayer" = {
          interval = 2;
          return-type = "json";
          exec = mkScriptJson {
            deps = [pkgs.playerctl];
            pre = ''
              player="$(playerctl status -f "{{playerName}}" 2>/dev/null || echo "No player active" | cut -d '.' -f1)"
              count="$(playerctl -l 2>/dev/null | wc -l)"
              if ((count > 1)); then
                more=" +$((count - 1))"
              else
                more=""
              fi
            '';
            alt = "$player";
            tooltip = "$player ($count available)";
            text = "$more";
          };
          format = "{icon}{}";
          format-icons = {
            "No player active" = " ";
            "Celluloid" = "󰎁 ";
            "spotify" = "󰓇 ";
            "ncspot" = "󰓇 ";
            "qutebrowser" = "󰖟 ";
            "firefox" = " ";
            "discord" = " 󰙯 ";
            "sublimemusic" = " ";
            "kdeconnect" = "󰄡 ";
            "chromium" = " ";
          };
        };

        privacy = {
          "icon-spacing" = 0;
          "icon-size" = 18;
          "transition-duration" = 250;
          modules = [
            {
              type = "screenshare";
              tooltip = true;
              "tooltip-icon-size" = 24;
            }
            {
              type = "audio-out";
              tooltip = true;
              "tooltip-icon-size" = 24;
            }
            {
              type = "audio-in";
              tooltip = true;
              "tooltip-icon-size" = 24;
            }
          ];
        };

        "custom/webcam" = {
          return-type = "json";
          interval = 2;
          exec = mkScript {
            deps = [pkgs.jq pkgs.psmisc];
            script = ''
              # get programs using the video0 endpoint
              ps -eo user,pid,cmd -q "$(fuser /dev/video0 2>/dev/null | xargs)" |\
              # omit the column headings and the first line which is wireplumber
              sed -n "1,2!p" |\
              # just get the pid and program columns
              awk '{print $2 " " $3}' |\
              # filter out the program path
              awk -F "/" '{print "{\"tooltip\": \"" $1 " " $NF "\"}"}' |\
              jq -s 'if length > 0 then {text: "󰄀 ", tooltip: (map(.tooltip) | join("\r"))} else {text: "", tooltip: ""} end' |\
              jq --unbuffered --compact-output
            '';
          };
        };

        "custom/player" = {
          exec-if = mkScript {
            deps = [pkgs.playerctl];
            script = "playerctl status 2>/dev/null";
          };
          exec = let
            format = ''{"text": "{{title}} - {{artist}}", "alt": "{{status}}", "tooltip": "{{title}} - {{artist}} ({{album}})"}'';
          in
            mkScript {
              deps = [pkgs.playerctl];
              script = "playerctl metadata --format '${format}' 2>/dev/null";
            };
          return-type = "json";
          interval = 2;
          max-length = 30;
          format = "{icon} {}";
          format-icons = {
            "Playing" = "󰐊";
            "Paused" = "󰏤 ";
            "Stopped" = "󰓛";
          };
          on-click = mkScript {
            deps = [pkgs.playerctl];
            script = "playerctl play-pause";
          };
        };
      };
    };
    # Cheatsheet:
    # x -> all sides
    # x y -> vertical, horizontal
    # x y z -> top, horizontal, bottom
    # w x y z -> top, right, bottom, left
    style = let
      inherit (inputs.nix-colors.lib.conversions) hexToRGBString;
      inherit (config.colorscheme) colors;
      toRGBA = color: opacity: "rgba(${hexToRGBString "," (lib.removePrefix "#" color)},${opacity})";
    in
      /*
      css
      */
      ''
        * {
          font-family: Fira Sans, FiraCode Nerd Font;
          font-size: 12pt;
          padding: 0;
          margin: 0 0.4em;
        }

        window#waybar {
          padding: 0;
          border-radius: 0.5em;
          background-color: shade(@surface0, 0.7);
          color: @surface2
        }
        .modules-left {
          margin-left: -0.65em;
        }
        .modules-right {
          margin-right: -0.65em;
        }

        #workspaces button {
          background-color: @surface0;
          color: @surface2;
          padding-left: 0.2em;
          padding-right: 0.2em;
          margin-left: 0.25em;
          margin-right: 0.25em;
          margin-top: 0.4em;
          margin-bottom: 0.4em;
        }
        #workspaces button.hidden {
          background-color: @surface0;
          color: @surface2;
        }
        #workspaces button.focused,
        #workspaces button.active {
          background-color: shade(@blue, 0.7);
          color: @green;
        }

        #workspaces button:hover {
          background-color: @surface3;
          color: @surface1;
        }

        #privacy-item {
          margin-left: 0.1em;
          margin-right: 0.1em;
        }

        #clock {
          padding-right: 1em;
          padding-left: 1em;
          border-radius: 0.5em;
        }

        #custom-menu {
          background-color: @surface3;
          color: @blue;
          padding-right: 1.5em;
          padding-left: 1em;
          margin-right: 0;
          border-radius: 0.5em;
        }
        #custom-menu.fullscreen {
          background-color: @blue;
          color: @green;
        }
        #custom-hostname {
          background-color: @surface3;
          color: @blue;
          padding-right: 1em;
          padding-left: 1em;
          margin-left: 0;
          border-radius: 0.5em;
        }
        #custom-currentplayer {
          padding-right: 0;
        }
        #custom-gpu, #cpu, #memory {
          margin-left: 0.05em;
          margin-right: 0.55em;
        }
      '';
  };
}
