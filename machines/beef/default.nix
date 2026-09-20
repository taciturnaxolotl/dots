{
  inputs,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ./home-manager.nix
    ../../modules/shared/machine.nix
    ../../modules/darwin/defaults.nix
  ];

  networking.hostName = "beef";

  # Determinate Nix manages its own daemon; disable nix-darwin nix management
  nix.enable = false;

  atelier.machine = {
    enable = true;
    type = "server";
    tailscaleHost = "beef";
  };

  # macOS updates may download, but beef must not install one and reboot on its
  # own: it runs long jobs unattended, and a restart part way through loses
  # hours of work with no indication of why beyond a gap in a log.
  system.defaults.SoftwareUpdate.AutomaticallyInstallMacOSUpdates = false;

  # Sustained compute on an M3 Max: high power mode keeps the performance cores
  # from being wound down under long load. nix-darwin has no option for it, and
  # the setting is per-power-source, so it is applied directly.
  system.activationScripts.postActivation.text = ''
    echo "beef: high power mode on AC" >&2
    /usr/bin/pmset -c powermode 2 || true
  '';

  # beef is headless and expected to be reachable at all times, so it should
  # never sleep and should bring itself back without a keyboard. These were set
  # by hand on the machine and so would drift on any restore or major update;
  # declaring them keeps them.
  power = {
    restartAfterPowerFailure = true;
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
