{
  inputs,
  pkgs,
  ...
}:
{
  imports = [
    ./home-manager.nix
    ../../modules/shared/machine.nix
    ../../modules/darwin/defaults.nix
    ../../modules/darwin/nix-cache.nix
  ];

  networking.hostName = "beef";

  # Determinate Nix manages its own daemon; disable nix-darwin nix management
  nix.enable = false;

  atelier.machine = {
    enable = true;
    type = "server";
    tailscaleHost = "beef";
  };

  system.defaults.SoftwareUpdate.AutomaticallyInstallMacOSUpdates = false;

  # Sustained compute on an M3 Max: high power mode keeps the performance cores
  # from being wound down under long load. nix-darwin has no option for it, and
  # the setting is per-power-source, so it is applied directly.
  system.activationScripts.postActivation.text = ''
    echo "beef: high power mode on AC" >&2
    /usr/bin/pmset -c powermode 2 || true
  '';

  # caffeinate so the lid can be shut
  launchd.daemons.stay-awake = {
    serviceConfig = {
      Label = "org.nixos.stay-awake";
      ProgramArguments = [
        "/usr/bin/caffeinate"
        "-s"
      ];
      RunAtLoad = true;
      KeepAlive = true;
    };
  };

  power = {
    restartAfterFreeze = true;
    sleep = {
      computer = "never";
      display = "never";
      harddisk = "never";
    };
  };

  environment.systemPackages = [
    pkgs.nixd
    pkgs.nil
    pkgs.nixfmt
    inputs.agenix.packages.aarch64-darwin.default
    pkgs.nodejs_22
    pkgs.unstable.bun
    pkgs.python3
    pkgs.go
    pkgs.gopls
    pkgs.gotools
    pkgs.go-tools
    pkgs.cargo
    pkgs.jdk
    pkgs.ruby
    pkgs.cmake
    pkgs.unstable.biome
    pkgs.unstable.zola
    pkgs.mill
    pkgs.clang-tools
    pkgs.ninja
    pkgs.calc
    pkgs.nh
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
  };

  system.stateVersion = 6;
}
