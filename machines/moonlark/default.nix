# This is your system's configuration file.
# Use this to configure your system environment (it replaces /etc/nixos/configuration.nix)
{
  inputs,
  lib,
  config,
  pkgs,
  ...
}:
{
  imports = [
    inputs.hardware.nixosModules.framework-11th-gen-intel

    ./hardware-configuration.nix
    ./home-manager.nix
    ./disk-config.nix

    (inputs.import-tree ../../modules/nixos)
  ];

  nixpkgs = {
    config = {
      allowUnfree = true;
    };
  };

  nix =
    let
      flakeInputs = lib.filterAttrs (_: lib.isType "flake") inputs;
    in
    {
      settings = {
        # Enable flakes and new 'nix' command
        experimental-features = "nix-command flakes";
        # Opinionated: disable global registry
        flake-registry = "";
        # Workaround for https://github.com/NixOS/nix/issues/9574
        nix-path = config.nix.nixPath;
        trusted-users = [
          "kierank"
        ];
      };
      # Opinionated: disable channels
      channel.enable = false;

      optimise.automatic = true;

      # Opinionated: make flake registry and nix path match flake inputs
      registry = lib.mapAttrs (_: flake: { inherit flake; }) flakeInputs;
      nixPath = lib.mapAttrsToList (n: _: "${n}=flake:${n}") flakeInputs;
    };

  time.timeZone = "America/New_York";

  # grouped for readability
  environment.systemPackages = [
    # core
    pkgs.coreutils
    pkgs.calc
    pkgs.screen
    pkgs.xdg-user-dirs
    pkgs.libnotify
    pkgs.notify-desktop
    pkgs.bc
    pkgs.jq
    pkgs.psmisc
    # terminals
    pkgs.alacritty
    pkgs.unstable.ghostty
    # cli_utils
    pkgs.glow
    pkgs.clipse
    pkgs.direnv
    pkgs.nix-output-monitor
    pkgs.nixpkgs-review
    pkgs.nix-prefetch
    pkgs.arduino-cli
    pkgs.zsh
    pkgs.gum
    # networking
    pkgs.xh
    pkgs.curl
    pkgs.wget
    pkgs.dogdns
    pkgs.inetutils
    pkgs.mosh
    pkgs.ngrok
    pkgs.networkmanagerapplet
    pkgs.networkmanager-iodine
    pkgs.iodine
    # nix_tools
    inputs.nixvim.packages.x86_64-linux.default
    pkgs.nixd
    pkgs.nil
    pkgs.nixfmt-rfc-style
    inputs.agenix.packages.x86_64-linux.default
    pkgs.lix
    # security
    pkgs.openssl
    pkgs.gpgme
    pkgs.gnupg
    pkgs.unstable.mitmproxy
    pkgs.caido
    # editors
    pkgs.unstable.zed-editor
    pkgs.arduino-ide
    # browsers
    pkgs.firefox
    (pkgs.chromium.override { enableWideVine = true; })
    # wayland
    pkgs.swww
    pkgs.wluma
    pkgs.brightnessctl
    pkgs.hyprpaper
    pkgs.hyprsunset
    pkgs.wl-clipboard
    pkgs.grim
    pkgs.slurp
    pkgs.wtype
    pkgs.mako
    pkgs.unstable.hyprpicker
    pkgs.wl-screenrec
    inputs.hyprland-contrib.packages.${pkgs.stdenv.hostPlatform.system}.grimblast
    pkgs.playerctl
    pkgs.libnotify
    pkgs.notify-desktop
    pkgs.lxde.lxsession
    # gnome
    pkgs.gnome-online-accounts
    pkgs.gnome-online-accounts-gtk
    pkgs.gnome-disk-utility
    pkgs.baobab
    pkgs.simple-scan
    pkgs.file-roller
    pkgs.font-manager
    pkgs.nautilus
    pkgs.loupe
    pkgs.totem
    pkgs.overskride
    # dev_langs
    pkgs.nodejs_22
    pkgs.unstable.bun
    pkgs.python3
    pkgs.go
    pkgs.gopls
    pkgs.gotools
    pkgs.go-tools
    pkgs.gcc
    pkgs.rustc
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
    # media
    pkgs.ffmpeg
    pkgs.video-trimmer
    pkgs.pitivi
    pkgs.audacity
    pkgs.unstable.amberol
    pkgs.zoom-us
    # graphics
    pkgs.imagemagick
    pkgs.inkscape
    pkgs.blender
    pkgs.exiftool
    pkgs.unstable.aseprite
    pkgs.godot_4
    pkgs.unstable.kikit
    pkgs.openboardview
    pkgs.qflipper
    # office
    pkgs.slack
    pkgs.libreoffice
    pkgs.unstable.zotero
    # gaming
    pkgs.prismlauncher
    pkgs.vesktop
    pkgs.cava
    pkgs.gobang
    pkgs.love
    #frc
    inputs.frc-nix.packages.${pkgs.stdenv.hostPlatform.system}.elastic-dashboard
    inputs.frc-nix.packages.${pkgs.stdenv.hostPlatform.system}.pathplanner
    inputs.frc-nix.packages.${pkgs.stdenv.hostPlatform.system}.roborioteamnumbersetter
    inputs.frc-nix.packages.${pkgs.stdenv.hostPlatform.system}.sysid
    inputs.frc-nix.packages.${pkgs.stdenv.hostPlatform.system}.wpilib-utility
    inputs.frc-nix.packages.${pkgs.stdenv.hostPlatform.system}.advantagescope
    # misc
    pkgs.invoice
    pkgs.pop
    pkgs.vhs
    pkgs.torrential
    inputs.flare.packages.x86_64-linux.default
    pkgs.unstable.ollama
    pkgs.unstable.claude-code
    pkgs.udiskie
    pkgs.neofetch
    pkgs.unstable.kicad-testing
    pkgs.zenity
    pkgs.atproto-goat
    inputs.cedarlogic.packages.${pkgs.stdenv.hostPlatform.system}.cedarlogic
    pkgs.unstable.betaflight-configurator
  ];

  programs.nh = {
    enable = true;
    clean.enable = true;
    clean.extraArgs = "--keep-since 4d --keep 3";
    flake = "/home/kierank/dots";
  };

  fonts.packages =
    with pkgs;
    [
      fira
      comic-neue
    ]
    ++ builtins.filter lib.attrsets.isDerivation (builtins.attrValues pkgs.nerd-fonts);

  # import the secret
  age.identityPaths = [
    "/home/kierank/.ssh/id_rsa"
    "/etc/ssh/id_rsa"
    "/mnt/etc/ssh/id_rsa"
  ];
  age.secrets = {
    wifi = {
      file = ../../secrets/wifi.age;
      owner = "kierank";
    };
    resend = {
      file = ../../secrets/resend.age;
      owner = "kierank";
    };
    wakatime = {
      file = ../../secrets/wakatime.age;
      path = "/home/kierank/.wakatime.cfg";
      owner = "kierank";
    };
    bluesky = {
      file = ../../secrets/bluesky.age;
      owner = "kierank";
    };
    iodine = {
      file = ../../secrets/iodine.age;
      owner = "kierank";
    };
  };

  environment.sessionVariables = {
    XDG_CACHE_HOME = "$HOME/.cache";
    XDG_CONFIG_HOME = "$HOME/.config";
    XDG_DATA_HOME = "$HOME/.local/share";
    XDG_STATE_HOME = "$HOME/.local/state";
    NIXOS_OZONE_WL = "1";
    PRISMA_QUERY_ENGINE_LIBRARY = "${pkgs.prisma-engines}/lib/libquery_engine.node";
    PRISMA_QUERY_ENGINE_BINARY = "${pkgs.prisma-engines}/bin/query-engine";
    PRISMA_SCHEMA_ENGINE_BINARY = "${pkgs.prisma-engines}/bin/schema-engine";
    RESEND_API_KEY = "$(${pkgs.coreutils}/bin/cat ${config.age.secrets.resend.path})";
    POP_FROM = "me@dunkirk.sh";
    EDITOR = "nvim";
    SYSTEMD_EDITOR = "nvim";
    VISUAL = "nvim";
  };

  atelier = {
    authentication.enable = true;
    apps.tuigreet = {
      enable = true;
      command = "Hyprland";
    };
    network.wifi = {
      enable = true;
      hostName = "moonlark";
      nameservers = [
        "1.1.1.1"
        "1.0.0.1"
        "8.8.8.8"
        "9.9.9.9"
      ];
      envFile = config.age.secrets.wifi.path;
      profiles = {
        "KlukasNet".pskVar = "psk_home";
        "Everseen".pskVar = "psk_hotspot";
        "SAAC Sanctuary".pskVar = "psk_church";
        "MVNU-student" = { };
        "Status Solutions Guest".pskVar = "psk_robotics";
        "FRC-1317-CECE".psk = "digitalfusion";
        "1317-fortress-of-awesomeness" = { };
        "PAST PD".pskVar = "psk_past";
        "Heartland".psk = "beourguest";
        "WPL_Public_AccessII" = { };
        "Yowzaford".pskVar = "psk_rhoda";
        "cu-events".psk = "freesmile82";
        "QargoCoffee-Guest".psk = "Lavazza@7";
        "Fulton".psk = "9064405930";
        "TP-LINK_ECF0".psk = "ad1066AD!";
        "eduroam" = {
          eduroam = true;
          identity = "kieranklukas@cedarville.edu";
          pskVar = "psk_cedarville";
        };
      };
    };
  };

  services.iodine.clients = {
    t1 = {
      server = "t1.dunkirk.sh";
      passwordFile = config.age.secrets.iodine.path;
    };
  };

  virtualisation = {
    libvirtd.enable = true;
    virtualbox = {
      host.enable = true;
      host.enableExtensionPack = true;
    };
    docker.enable = true;
  };

  programs.nix-ld.enable = true;

  programs.zsh.enable = true;

  programs.direnv.enable = true;

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
      extraGroups = [
        "wheel"
        "networkmanager"
        "audio"
        "video"
        "docker"
        "plugdev"
        "input"
        "dialout"
        "docker"
        "libvirtd"
        "vboxusers"
      ];
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

  programs.xwayland.enable = lib.mkForce true;

  services.udev.packages = [
    pkgs.qFlipper
    pkgs.via
  ];

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
    allowedTCPPorts = [
      4455
      51820
    ];
    allowedUDPPorts = [
      4455
      51820
    ];
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
    kernelPackages = lib.mkIf (lib.versionOlder pkgs.linux.version "5.16") (
      lib.mkDefault pkgs.linuxPackages_latest
    );
    loader.grub = {
      # no need to set devices, disko will add all devices that have a EF02 partition to the list already
      device = "nodev";
      efiSupport = true;
      efiInstallAsRemovable = true;
    };
    supportedFilesystems = [ "ntfs" ];
    extraModprobeConfig = ''
      options kvm_intel nested=1
      options kvm_intel emulate_invalid_guest_state=0
      options kvm ignore_msrs=1
    '';
  };

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = "23.05";
}
