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

  networking.hostName = "atalanta";

  atelier.machine = {
    enable = true;
    type = "client";
    tailscaleHost = "atalanta";
  };

  # Homebrew casks managed declaratively
  homebrew = {
    enable = true;
    casks = [
      "orbstack"
    ];
  };

  # Install packages
  environment.systemPackages = [
    # nix stuff
    pkgs.nixd
    pkgs.nil
    pkgs.nixfmt
    inputs.agenix.packages.aarch64-darwin.default
    # dev_langs
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
    pkgs.unstable.apktool
    pkgs.prisma
    pkgs.unstable.zola
    pkgs.mill
    pkgs.clang-tools
    pkgs.ninja
    # security
    pkgs.unstable.metasploit
    # tools
    pkgs.calc
    pkgs.nh
    pkgs.vhs
    inputs.soapdump.packages.${pkgs.stdenv.hostPlatform.system}.default
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

  # Regenerate sudoers entry with correct hash after every rebuild
  system.activationScripts.yabai-sudoers.text = ''
    YABAI="${pkgs.yabai}/bin/yabai"
    HASH=$(shasum -a 256 "$YABAI" | cut -d ' ' -f 1)
    echo "kierank ALL=(root) NOPASSWD: sha256:$HASH $YABAI --load-sa" > /private/etc/sudoers.d/yabai
    chmod 440 /private/etc/sudoers.d/yabai
  '';

  power.sleep = {
    computer = 1;
    display = 1;
    harddisk = 10;
  };

  system.stateVersion = 4;
}
