{
  inputs,
  pkgs,
  ...
}:
{
  imports = [
    ./home-manager.nix
  ];

  # Set host platform for Apple Silicon
  nixpkgs = {
    hostPlatform = "aarch64-darwin";
    config = {
      allowUnfree = true;
    };
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
    pkgs.rustc
    pkgs.cargo
    pkgs.jdk23
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
    pkgs.rustscan
    pkgs.vhs
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
    crush = {
      file = ../../secrets/crush.age;
      owner = "kierank";
    };
  };

  environment.variables = {
    EDITOR = "nvim";
    SYSTEMD_EDITOR = "nvim";
    VISUAL = "nvim";
  };

  # Used for backwards compatibility, please read the changelog before changing
  system.stateVersion = 4;
}
