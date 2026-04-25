{
  inputs,
  pkgs,
  ...
}:
{
  imports = [
    ./home-manager.nix
    ../../modules/shared/machine.nix
  ];

  # Set host platform for Apple Silicon
  nixpkgs = {
    hostPlatform = "aarch64-darwin";
    config = {
      allowUnfree = true;
    };
    overlays = [
      inputs.nur.overlays.default
      (final: prev: {
        unstable = import inputs.nixpkgs-unstable {
          system = final.stdenv.hostPlatform.system;
          config.allowUnfree = true;
        };

        zmx-binary = prev.callPackage ../../packages/zmx.nix { };

        # direnv fish tests are killed (SIGKILL) in the Nix sandbox on Darwin
        # since the libarchive 3.8.4->3.8.6 bump; skip until upstream fixes it.
        # https://github.com/NixOS/nixpkgs/issues/507531
        direnv = prev.direnv.overrideAttrs (_: {
          doCheck = false;
        });
      })
    ];
  };

  # Enable nix-darwin
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # switch to lix
  nix.package = pkgs.lixPackageSets.stable.lix;

  # Set hostname
  networking.hostName = "atalanta";

  atelier.machine = {
    enable = true;
    type = "client";
    tailscaleHost = "atalanta";
  };

  # Define user
  users.users.kierank = {
    name = "kierank";
    home = "/Users/kierank";
  };

  system.primaryUser = "kierank";

  ids.gids.nixbld = 350;

  # Install packages
  environment.systemPackages = [
    # nix stuff
    pkgs.nixd
    pkgs.nil
    pkgs.nixfmt-rfc-style
    inputs.agenix.packages.aarch64-darwin.default
    # dev_langs
    pkgs.nodejs_22
    pkgs.unstable.bun
    pkgs.python3
    pkgs.go
    pkgs.gopls
    pkgs.gotools
    pkgs.go-tools
    pkgs.gcc
    pkgs.cargo
    pkgs.jdk
    pkgs.ruby
    pkgs.cmake
    pkgs.unstable.biome
    pkgs.unstable.apktool
    pkgs.nodePackages_latest.prisma
    pkgs.unstable.zola
    pkgs.mill
    pkgs.clang
    pkgs.clang-tools
    pkgs.ninja
    # tools
    pkgs.calc
    pkgs.nh
    pkgs.vhs
    inputs.soapdump.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];

  programs.direnv.enable = true;

  # import the secret
  age.identityPaths = [
    "/Users/kierank/.ssh/id_rsa"
  ];
  age.secrets = {
    wakatime = {
      file = ../../secrets/wakatime.age;
      path = "/Users/kierank/.wakatime.cfg";
      owner = "kierank";
    };
    bluesky = {
      file = ../../secrets/bluesky.age;
      owner = "kierank";
    };

    "bore/auth-token" = {
      file = ../../secrets/bore/auth-token.age;
      owner = "kierank";
    };
    pbnj = {
      file = ../../secrets/pbnj.age;
      owner = "kierank";
    };
    tangled-session = {
      file = ../../secrets/tangled-session.age;
      owner = "kierank";
    };
  };

  environment.variables = {
    EDITOR = "nvim";
    SYSTEMD_EDITOR = "nvim";
    VISUAL = "nvim";
  };

  # nothing but finder in the doc
  system.defaults.dock = {
    persistent-apps = [ ];

    tilesize = 47;
    show-recents = false;
    autohide = true;
    showhidden = true;
    autohide-delay = 0.0;
    autohide-time-modifier = 0.0;
    magnification = true;
    largesize = 52;
  };

  power.sleep = {
    computer = 1;
    display = 1;
    harddisk = 10;
  };

  # allow using apple watch or touch id for sudo
  security.pam.services.sudo_local.touchIdAuth = true;
  security.pam.services.sudo_local.watchIdAuth = true;

  system.defaults = {
    finder.FXPreferredViewStyle = "Nlsv";
    finder.AppleShowAllExtensions = true;
    finder.ShowPathbar = true;
    finder.ShowStatusBar = false;
    finder.FXDefaultSearchScope = "SCcf";
    finder._FXShowPosixPathInTitle = true;
    finder.FXEnableExtensionChangeWarning = false;
    trackpad.Clicking = true;
    trackpad.TrackpadRightClick = true;
    # expand the save dialogs
    NSGlobalDomain.NSNavPanelExpandedStateForSaveMode = true;
    NSGlobalDomain.NSNavPanelExpandedStateForSaveMode2 = true;
    LaunchServices.LSQuarantine = false; # disables "Are you sure?" for new apps
    loginwindow.GuestEnabled = false;

    NSGlobalDomain."com.apple.trackpad.scaling" = 0.875;
    NSGlobalDomain.AppleInterfaceStyle = "Dark";
    NSGlobalDomain.NSAutomaticCapitalizationEnabled = false;
    NSGlobalDomain.NSAutomaticDashSubstitutionEnabled = false;
    NSGlobalDomain.NSAutomaticPeriodSubstitutionEnabled = false;
    NSGlobalDomain.NSAutomaticQuoteSubstitutionEnabled = false;
    NSGlobalDomain.NSAutomaticSpellingCorrectionEnabled = false;
    NSGlobalDomain.ApplePressAndHoldEnabled = false;

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
        # old imac purple tint
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
        # Avoid creating .DS_Store files on network or USB volumes
        DSDontWriteNetworkStores = true;
        DSDontWriteUSBStores = true;
      };
      "com.apple.AdLib" = {
        allowApplePersonalizedAdvertising = false;
      };
      "com.apple.SoftwareUpdate" = {
        AutomaticCheckEnabled = true;
        # Check for software updates daily, not just once per week
        ScheduleFrequency = 1;
        # Download newly available updates in background
        AutomaticDownload = 1;
        # Install System data files & security updates
        CriticalUpdateInstall = 1;
      };
      # keybindings
      # Script to export symbolic hotkey configs from MacOS
      # https://gist.github.com/sawadashota/8e7ce32234e0f07a03e955f22ec4c0f9
      # Screenshot selected area to file with Cmd+Option+Shift+4
      "com.apple.symbolichotkeys" = {
        AppleSymbolicHotKeys = {
          # Screenshot selected area with Option+Cmd+Shift+4
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
          # Screenshot selected area to clipboard with Cmd+Shift+4
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
          # Fullscreen screenshot Option+Cmd+Shift+3
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
          # Fullscreen screenshot to clipboard Cmd+Shift+3
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
          # Spotlight - Cmd+Space (disabled for Raycast)
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
          # Finder search - Option+Cmd+Space (disabled for Raycast)
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

  # Used for backwards compatibility, please read the changelog before changing
  system.stateVersion = 4;
}
