

# This is your system's configuration file.
# Use this to configure your system environment (it replaces /etc/nixos/configuration.nix)
{
  inputs,
  lib,
  config,
  pkgs,
  pkgs-unstable,
  ...
}: {
  # You can import other NixOS modules here
  imports = [
    # If you want to use modules from other flakes (such as nixos-hardware):
    inputs.hardware.nixosModules.framework-11th-gen-intel

    # Import your generated (nixos-generate-config) hardware configuration
    ./hardware-configuration.nix

    # Import home-manager's configuration
    ./home-manager.nix

    # Import disko's configuration
    ./disk-config.nix

    ./pam.nix

    # tuigreet
    ./greetd.nix
  ];

  nixpkgs = {
    # Configure your nixpkgs instance
    config = {
      # Disable if you don't want unfree packages
      allowUnfree = true;
    };
  };

  nix = let
    flakeInputs = lib.filterAttrs (_: lib.isType "flake") inputs;
  in {
    settings = {
      # Enable flakes and new 'nix' command
      experimental-features = "nix-command flakes";
      # Opinionated: disable global registry
      flake-registry = "";
      # Workaround for https://github.com/NixOS/nix/issues/9574
      nix-path = config.nix.nixPath;
    };
    # Opinionated: disable channels
    channel.enable = false;

    optimise.automatic = true;

    # Opinionated: make flake registry and nix path match flake inputs
    registry = lib.mapAttrs (_: flake: {inherit flake;}) flakeInputs;
    nixPath = lib.mapAttrsToList (n: _: "${n}=flake:${n}") flakeInputs;
  };

  time.timeZone = "America/New_York";

  environment.systemPackages = map lib.lowPrio [
    pkgs.curl
    pkgs.wget
    pkgs.dogdns
    inputs.agenix.packages.x86_64-linux.default
    pkgs.wpa_supplicant_gui
    pkgs.overskride
    pkgs.alacritty
    pkgs.zsh
    pkgs.starship
    pkgs.gh
    pkgs.swww
    pkgs.wluma
    pkgs.brightnessctl
    inputs.hyprland-contrib.packages.${pkgs.system}.grimblast
    pkgs.mako
    pkgs.unstable.hyprpicker
    pkgs.notify-desktop
    pkgs.bc
    pkgs.wl-clipboard
    pkgs.psmisc
    pkgs.jq
    pkgs.playerctl
    pkgs.firefox
    pkgs.slack
    pkgs.nautilus
    pkgs.totem
    pkgs.loupe
    pkgs.simple-scan
    pkgs.file-roller
    pkgs.polkit_gnome
    pkgs.fprintd
    pkgs.gitMinimal
    pkgs.udiskie
    pkgs.neofetch
    pkgs.cava
    pkgs.go
    pkgs.unstable.bun
    pkgs.pitivi
    pkgs.unstable.arduino-ide
    pkgs.unstable.arduino-cli
    pkgs.lazygit
    pkgs.vhs
    pkgs.video-trimmer
    pkgs.ffmpeg
    pkgs.ngrok
    pkgs.openssl
    pkgs.nodePackages_latest.prisma
    pkgs.nodejs_22
    pkgs.invoice
    pkgs.pop
    pkgs.gum
    pkgs.unstable.kicad-testing
    pkgs.unstable.mitmproxy
    pkgs.glow
    pkgs.gnome-online-accounts
    pkgs.gnome-online-accounts-gtk
    pkgs.zoom-us
    pkgs.mods
    (pkgs.chromium.override { enableWideVine = true; })
    pkgs.python3
    pkgs.qflipper
    pkgs.inkscape
    pkgs.jdk23
    pkgs.unstable.zed-editor
    pkgs.gnome-disk-utility
    pkgs.torrential
    pkgs.unstable.zola
    pkgs.unstable.deno
    pkgs.unstable.amberol
    pkgs.unstable.apktool
    pkgs.unstable.biome
    pkgs.gcc
    pkgs.love
    pkgs.unstable.aseprite
    pkgs.audacity
    pkgs.imagemagick
    pkgs.wtype
    pkgs.rustc
    pkgs.cargo
    pkgs.gobang
    pkgs.caido
    inputs.ghostty.packages.x86_64-linux.default
    pkgs.baobab
    pkgs.nix-prefetch
    inputs.frc-nix.packages.${pkgs.system}.elastic-dashboard
    inputs.frc-nix.packages.${pkgs.system}.pathplanner
    inputs.frc-nix.packages.${pkgs.system}.roborioteamnumbersetter
    inputs.frc-nix.packages.${pkgs.system}.sysid
    inputs.frc-nix.packages.${pkgs.system}.wpilib-utility
    inputs.frc-nix.packages.${pkgs.system}.advantagescope
    pkgs.hyprpaper
    pkgs.lxde.lxsession
    pkgs.godot_4
    pkgs.bambu-studio
    pkgs.unstable.orca-slicer
    pkgs.exiftool
    pkgs.zenity
    pkgs.iodine
    pkgs.libreoffice
    pkgs.blender
    pkgs.screen
    pkgs.font-manager
    pkgs.prismlauncher
    pkgs.openboardview
    pkgs.unstable.claude-code
    inputs.claude-desktop.packages.${pkgs.system}.claude-desktop-with-fhs
    pkgs.ruby
    pkgs.unstable.kikit
    pkgs.cmake
    pkgs.unstable.zotero
    pkgs.wl-screenrec
    pkgs.libnotify
    pkgs.coreutils
    pkgs.grim
    pkgs.jq
    pkgs.slurp
    pkgs.xdg-user-dirs
  ];

  programs.nh = {
    enable = true;
    clean.enable = true;
    clean.extraArgs = "--keep-since 4d --keep 3";
    flake = "/home/kierank/etc/nixos";
  };

  services.gnome.gnome-keyring.enable = true;
  programs.dconf.enable = true;

  systemd = {
    user.services.polkit-gnome-authentication-agent-1 = {
      description = "polkit-gnome-authentication-agent-1";
      wantedBy = [ "graphical-session.target" ];
      wants = [ "graphical-session.target" ];
      after = [ "graphical-session.target" ];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
        Restart = "on-failure";
        RestartSec = 1;
        TimeoutStopSec = 10;
      };
    };
  };

  fonts.packages = with pkgs; [
    nerdfonts
    fira
    comic-neue
  ];

  # import the secret
  age.identityPaths = [ "/home/kierank/.ssh/id_rsa" "/etc/ssh/id_rsa" "/mnt/etc/ssh/id_rsa" ];
  age.secrets = {
    wifi = {
      file = ../secrets/wifi.age;
      owner = "kierank";
    };
    resend = {
      file = ../secrets/resend.age;
      owner = "kierank";
    };
    wakatime = {
      file = ../secrets/wakatime.age;
      path = "/home/kierank/.wakatime.cfg";
      owner = "kierank";
    };
  };

  environment.sessionVariables = {
    XDG_CACHE_HOME  = "$HOME/.cache";
    XDG_CONFIG_HOME = "$HOME/.config";
    XDG_DATA_HOME   = "$HOME/.local/share";
    XDG_STATE_HOME  = "$HOME/.local/state";
    NIXOS_OZONE_WL = "1";
    PRISMA_QUERY_ENGINE_LIBRARY = "${pkgs.prisma-engines}/lib/libquery_engine.node";
    PRISMA_QUERY_ENGINE_BINARY = "${pkgs.prisma-engines}/bin/query-engine";
    PRISMA_SCHEMA_ENGINE_BINARY = "${pkgs.prisma-engines}/bin/schema-engine";
    RESEND_API_KEY = ''$(${pkgs.coreutils}/bin/cat ${config.age.secrets.resend.path})'';
    POP_FROM = "me@dunkirk.sh";
  };

  # setup the network
  networking = {
    hostName = "moonlark";
    nameservers = [ "1.1.1.1" "9.9.9.9" ];
    wireless = {
      secretsFile = config.age.secrets.wifi.path;
      userControlled.enable = true;
      enable = true;
      networks = {
        "KlukasNet".pskRaw = "ext:psk_home";
        "Everseen".pskRaw = "ext:psk_hotspot";
        "SAAC Sanctuary".pskRaw = "ext:psk_church";
        "MVNU-student" = {};
        "Status Solutions Guest".pskRaw = "ext:psk_robotics";
        "FRC-1317-CECE".psk = "digitalfusion";
        "1317-fortress-of-awesomeness" = {};
        "PAST PD".pskRaw = "ext:psk_past";
        "Heartland".psk = "beourguest";
        "WPL_Public_AccessII" = {};
        "Yowzaford".pskRaw = "ext:psk_rhoda";
      };
    };
  };

  virtualisation.waydroid.enable = true;

  programs.nix-ld.enable = true;

  programs.zsh.enable = true;

  # TODO: Configure your system-wide user settings (groups, etc), add more users as needed.
  users.users = {
    kierank = {
      # You can skip setting a root password by passing '--no-root-passwd' to nixos-install.
      # Be sure to change it (using passwd) after rebooting!
      initialPassword = "lolzthisaintsecure!";
      isNormalUser = true;
      shell = pkgs.zsh;
      openssh.authorizedKeys.keys = [
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCzEEjvbL/ttqmYoDjxYQmDIq36BabROJoXgQKeh9liBxApwp+2PmgxROzTg42UrRc9pyrkq5kVfxG5hvkqCinhL1fMiowCSEs2L2/Cwi40g5ZU+QwdcwI8a4969kkI46PyB19RHkxg54OUORiIiso/WHGmqQsP+5wbV0+4riSnxwn/JXN4pmnE//stnyAyoiEZkPvBtwJjKb3Ni9n3eNLNs6gnaXrCtaygEZdebikr9kS2g9mM696HvIFgM6cdR/wZ7DcLbG3IdTXuHN7PC3xxL+Y4ek5iMreQIPmuvs4qslbthPGYoYbYLUQiRa9XO5s/ksIj5Z14f7anHE6cuTQVpvNWdGDOigyIVS5qU+4ZF7j+rifzOXVL48gmcAvw/uV68m5Wl/p0qsC/d8vI3GYwEsWG/EzpAlc07l8BU2LxWgN+d7uwBFaJV9VtmUDs5dcslsh8IbzmtC9gq3OLGjklxTfIl6qPiL8U33oc/UwqzvZUrI2BlbagvIZYy6rP+q0= kierank@mockingjay"
      ];
      extraGroups = ["wheel" "networkmanager" "audio" "video" "docker" "plugdev" "input" "dialout" "docker"];
    };
    root.openssh.authorizedKeys.keys = [
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCzEEjvbL/ttqmYoDjxYQmDIq36BabROJoXgQKeh9liBxApwp+2PmgxROzTg42UrRc9pyrkq5kVfxG5hvkqCinhL1fMiowCSEs2L2/Cwi40g5ZU+QwdcwI8a4969kkI46PyB19RHkxg54OUORiIiso/WHGmqQsP+5wbV0+4riSnxwn/JXN4pmnE//stnyAyoiEZkPvBtwJjKb3Ni9n3eNLNs6gnaXrCtaygEZdebikr9kS2g9mM696HvIFgM6cdR/wZ7DcLbG3IdTXuHN7PC3xxL+Y4ek5iMreQIPmuvs4qslbthPGYoYbYLUQiRa9XO5s/ksIj5Z14f7anHE6cuTQVpvNWdGDOigyIVS5qU+4ZF7j+rifzOXVL48gmcAvw/uV68m5Wl/p0qsC/d8vI3GYwEsWG/EzpAlc07l8BU2LxWgN+d7uwBFaJV9VtmUDs5dcslsh8IbzmtC9gq3OLGjklxTfIl6qPiL8U33oc/UwqzvZUrI2BlbagvIZYy6rP+q0= kierank@mockingjay"
    ];
  };

  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
    dedicatedServer.openFirewall = true; # Open ports in the firewall for Source Dedicated Server
    localNetworkGameTransfers.openFirewall = true; # Open ports in the firewall for Steam Local Network Game Transfers
  };

  programs.hyprland.enable = true;
  services.hypridle.enable = true;

  programs.niri = {
    enable = true;
  };

  programs.xwayland.enable = lib.mkForce true;

  virtualisation.docker.enable = true;

  services.udev.packages = [ pkgs.qFlipper pkgs.via ];

  security.polkit.enable = true;

  # enable cups
  services.printing.enable = true;
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };

  # enable bluetooth
  hardware.bluetooth.enable = true;

  # enable pipewire
  # rtkit is optional but recommended
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    jack.enable = true;
  };

  # This setups a SSH server. Very important if you're setting up a headless system.
  # Feel free to remove if you don't need it.
  services.openssh = {
    enable = true;
    settings = {
      # Opinionated: forbid root login through SSH.
      PermitRootLogin = "no";
      # Opinionated: use keys only.
      # Remove if you want to SSH using passwords
      PasswordAuthentication = false;
    };
  };

  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 4455 51820 ];
    allowedUDPPorts = [ 4455 51820 ];
  };

  services.tailscale = {
    enable = true;
    useRoutingFeatures = "client";
  };

  services.devmon.enable = true;
  services.gvfs.enable = true;
  services.udisks2.enable = true;

  services.logind.extraConfig = ''
    # don't shutdown when power button is short-pressed
    HandlePowerKey=ignore
    HandlePowerKeyLongPress=poweroff
  '';

  # Requires at least 5.16 for working wi-fi and bluetooth.
  # https://community.frame.work/t/using-the-ax210-with-linux-on-the-framework-laptop/1844/89
  boot = {
    kernelPackages = lib.mkIf (lib.versionOlder pkgs.linux.version "5.16") (lib.mkDefault pkgs.linuxPackages_latest);
    loader.grub = {
      # no need to set devices, disko will add all devices that have a EF02 partition to the list already
      device = "nodev";
      efiSupport = true;
      efiInstallAsRemovable = true;
    };
    supportedFilesystems = [ "ntfs" ];
  };

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = "23.05";
}
