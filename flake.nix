{
  description = "Kieran's opinionated (and probably slightly dumb) nix config";

  inputs = {
    # Nixpkgs
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    # Lix
    lix-module = {
      url = "https://git.lix.systems/lix-project/nixos-module/archive/2.93.0.tar.gz";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # NixOS hardware configuration
    hardware.url = "github:NixOS/nixos-hardware/master";

    # Home manager
    home-manager.url = "github:nix-community/home-manager/release-25.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    # agenix
    agenix.url = "github:ryantm/agenix";

    spicetify-nix = {
      url = "github:Gerg-L/spicetify-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # catppuccin
    catppuccin.url = "github:catppuccin/nix";
    catppuccin-vsc.url = "https://flakehub.com/f/catppuccin/vscode/\*.tar.gz";

    nix-vscode-extensions.url = "github:nix-community/nix-vscode-extensions";

    nix-flatpak.url = "github:gmodena/nix-flatpak";

    ghostty = {
      url = "github:ghostty-org/ghostty";
    };

    frc-nix = {
      url = "github:frc4451/frc-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    claude-desktop = {
      url = "github:taciturnaxolotl/claude-desktop-linux-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hyprland-contrib = {
      url = "github:hyprwm/contrib";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixvim.url = "github:taciturnaxolotl/nixvim";

    zed = {
      url = "github:oscilococcinum/zen-browser-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    terminal-wakatime = {
      url = "github:taciturnaxolotl/terminal-wakatime";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-unstable,
      lix-module,
      nix-flatpak,
      cursor,
      agenix,
      home-manager,
      nixos-hardware,
      hyprland-contrib,
      ghostty,
      frc-nix,
      nixvim,
      zed,
      terminal-wakatime,
      ...
    }@inputs:
    let
      inherit (self) outputs;
      system = "x86_64-linux";
      unstable-overlays = {
        nixpkgs.overlays = [
          (final: prev: {
            unstable = import nixpkgs-unstable {
              inherit system;
              config.allowUnfree = true;
            };

            bambu-studio = prev.bambu-studio.overrideAttrs (oldAttrs: {
              version = "01.00.01.50";
              src = prev.fetchFromGitHub {
                owner = "bambulab";
                repo = "BambuStudio";
                rev = "v01.00.01.50";
                hash = "sha256-7mkrPl2CQSfc1lRjl1ilwxdYcK5iRU//QGKmdCicK30=";
              };
            });

          })
        ];
      };
    in
    {
      # NixOS configuration entrypoint
      # Available through 'nixos-rebuild --flake .#your-hostname'
      nixosConfigurations = {
        moonlark = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";

          specialArgs = { inherit inputs outputs; };

          # > Our main nixos configuration file <
          modules = [
            lix-module.nixosModules.default
            nix-flatpak.nixosModules.nix-flatpak
            inputs.disko.nixosModules.disko
            { disko.devices.disk.disk1.device = "/dev/vda"; }
            agenix.nixosModules.default
            ./moonlark/configuration.nix
            unstable-overlays
          ];
        };
      };

      # Standalone home-manager configurations
      # Available through 'home-manager --flake .#username@hostname'
      homeConfigurations = {
        "pi@tacyon" = home-manager.lib.homeManagerConfiguration {
          pkgs = import nixpkgs {
            system = "aarch64-linux";
            config.allowUnfree = true;
          };
          extraSpecialArgs = {
            inherit inputs outputs;
            nixpkgs-unstable = nixpkgs-unstable;
          };
          modules = [
            ./home-manager/machines/tacyon
            unstable-overlays
          ];
        };
      };
    };
}
