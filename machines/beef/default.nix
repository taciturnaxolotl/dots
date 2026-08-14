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
  ];

  networking.hostName = "beef";

  atelier.machine = {
    enable = true;
    type = "client";
    tailscaleHost = "beef";
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
