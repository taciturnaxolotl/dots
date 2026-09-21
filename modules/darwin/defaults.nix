{
  inputs,
  pkgs,
  lib,
  config,
  ...
}:
let
  flakeInputs = lib.filterAttrs (_: lib.isType "flake") inputs;
in
{
  # Common nix-darwin settings for all macOS machines

  nixpkgs = {
    hostPlatform = "aarch64-darwin";
    config.allowUnfree = true;
    overlays = [
      inputs.nur.overlays.default
      # Same overlay the NixOS hosts get; see overlays/default.nix.
      (import ../../overlays {
        inherit inputs;
        inherit (inputs.nixpkgs) lib;
      })
    ];
  };

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # disable channels if we arent using them
  nix.registry = lib.mapAttrs (_: flake: { inherit flake; }) flakeInputs;
  nix.nixPath = lib.mapAttrsToList (n: _: "${n}=flake:${n}") flakeInputs;
  nix.channel.enable = lib.mkIf config.nix.enable false;
  nix.settings.flake-registry = "";
  nix.settings.nix-path = config.nix.nixPath;

  # Nix installation management (only when nix-darwin manages nix)
  # Machines using Determinate Nix should set nix.enable = false
  nix.package = lib.mkIf config.nix.enable pkgs.lixPackageSets.latest.lix;

  nix.gc = lib.mkIf config.nix.enable {
    automatic = true;
    interval = {
      Weekday = 0;
      Hour = 2;
      Minute = 0;
    };
    options = "--delete-older-than 14d";
  };
  nix.optimise.automatic = lib.mkIf config.nix.enable true;

  users.users.kierank = {
    name = "kierank";
    home = "/Users/kierank";
  };

  system.primaryUser = "kierank";

  ids.gids.nixbld = 350;

  programs.direnv.enable = true;

  # Disable system /etc/zshrc to avoid double compinit.
  # Home-manager handles history, direnv, completion, and keybindings.
  environment.etc."zshrc".enable = false;

  age.identityPaths = [
    "/Users/kierank/.ssh/id_rsa"
  ];

  environment.variables = {
    EDITOR = "nvim";
    SYSTEMD_EDITOR = "nvim";
    VISUAL = "nvim";
  };

  # Allow using Apple Watch or Touch ID for sudo
  security.pam.services.sudo_local.touchIdAuth = true;
  security.pam.services.sudo_local.watchIdAuth = true;

  # Common macOS defaults
  system.defaults = {
    dock = {
      persistent-apps = [ ];
      tilesize = 47;
      mru-spaces = false;
      show-recents = false;
      autohide = true;
      showhidden = true;
      autohide-delay = 0.0;
      autohide-time-modifier = 0.0;
      magnification = true;
      largesize = 52;
    };

    finder = {
      FXPreferredViewStyle = "Nlsv";
      AppleShowAllExtensions = true;
      ShowPathbar = true;
      ShowStatusBar = false;
      FXDefaultSearchScope = "SCcf";
      _FXShowPosixPathInTitle = true;
      FXEnableExtensionChangeWarning = false;
    };

    trackpad = {
      Clicking = true;
      TrackpadRightClick = true;
    };

    NSGlobalDomain = {
      NSNavPanelExpandedStateForSaveMode = true;
      NSNavPanelExpandedStateForSaveMode2 = true;
      "com.apple.trackpad.scaling" = 0.875;
      AppleInterfaceStyle = "Dark";
      NSAutomaticCapitalizationEnabled = false;
      NSAutomaticDashSubstitutionEnabled = false;
      NSAutomaticPeriodSubstitutionEnabled = false;
      NSAutomaticQuoteSubstitutionEnabled = false;
      NSAutomaticSpellingCorrectionEnabled = false;
      ApplePressAndHoldEnabled = false;
    };

    LaunchServices.LSQuarantine = false;
    loginwindow.GuestEnabled = false;

    CustomSystemPreferences = {
      "com.apple.DiskArbitration.diskarbitrationd" = {
        DADisableEjectNotification = true;
      };
    };

    CustomUserPreferences = {
      "com.apple.ImageCapture" = {
        disableHotPlug = true;
      };
      "com.apple.menuextra.clock" = {
        FlashDateSeparators = false;
        ShowDate = 0;
        ShowDayOfWeek = true;
      };
      "NSGlobalDomain" = {
        AppleIconAppearanceCustomTintColor = "0.358236 0.479976 0.941252 0.780139";
        AppleIconAppearanceTintColor = "Other";
        NSColorSimulateHardwareAccent = 1;
        NSColorSimulatedHardwareEnclosureNumber = 7;
        NSStatusItemSpacing = 12;
        NSStatusItemSelectionPadding = 12;
      };
      "com.apple.screencapture" = {
        disable-shadow = true;
        location = "~/Downloads";
        type = "png";
      };
      "com.apple.finder" = {
        SidebarShowingiCloudDesktop = false;
        ShowRecentTags = false;
        ShowExternalHardDrivesOnDesktop = true;
        ShowHardDrivesOnDesktop = false;
        ShowRemovableMediaOnDesktop = true;
        NewWindowTarget = "PfHm";
      };
      "com.apple.driver.AppleBluetoothMultitouch.mouse" = {
        MouseButtonMode = "TwoButton";
      };
      "com.apple.WindowManager" = {
        EnableTiledWindowMargins = false;
      };
      "com.apple.desktopservices" = {
        DSDontWriteNetworkStores = true;
        DSDontWriteUSBStores = true;
      };
      "com.apple.AdLib" = {
        allowApplePersonalizedAdvertising = false;
      };
      "com.apple.SoftwareUpdate" = {
        AutomaticCheckEnabled = true;
        ScheduleFrequency = 1;
        AutomaticDownload = 1;
        CriticalUpdateInstall = 1;
      };
      "com.apple.symbolichotkeys" = {
        AppleSymbolicHotKeys = {
          "30" = {
            enabled = true;
            value = {
              parameters = [
                52
                21
                1703936
              ];
              type = "standard";
            };
          };
          "31" = {
            enabled = true;
            value = {
              parameters = [
                52
                21
                1179648
              ];
              type = "standard";
            };
          };
          "28" = {
            enabled = true;
            value = {
              parameters = [
                51
                20
                1703936
              ];
              type = "standard";
            };
          };
          "29" = {
            enabled = true;
            value = {
              parameters = [
                51
                20
                1179648
              ];
              type = "standard";
            };
          };
          "64" = {
            enabled = false;
            value = {
              parameters = [
                32
                49
                1048576
              ];
              type = "standard";
            };
          };
          "65" = {
            enabled = false;
            value = {
              parameters = [
                32
                49
                1572864
              ];
              type = "standard";
            };
          };
        };
      };
    };
  };
}
