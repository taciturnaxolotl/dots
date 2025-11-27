{
  description = "Kieran's opinionated (and probably slightly dumb) nix config";

  inputs = {
    # Nixpkgs
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    # NixOS hardware configuration
    hardware.url = "github:NixOS/nixos-hardware/master";

    # Home manager
    home-manager.url = "github:nix-community/home-manager/release-25.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # Nix-Darwin
    nix-darwin.url = "github:nix-darwin/nix-darwin/nix-darwin-25.05";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    # agenix
    agenix.url = "github:ryantm/agenix";

    spicetify-nix = {
      url = "github:Gerg-L/spicetify-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    catppuccin = {
      url = "github:catppuccin/nix?rev=f518f96a60aceda4cd487437b25eaa48d0f1b97d";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    catppuccin-vsc = {
      url = "github:catppuccin/vscode";
    };

    nix-vscode-extensions.url = "github:nix-community/nix-vscode-extensions";

    frc-nix = {
      url = "github:frc4451/frc-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    claude-desktop = {
      url = "github:k3d3/claude-desktop-linux-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hyprland-contrib = {
      url = "github:hyprwm/contrib";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixvim.url = "github:taciturnaxolotl/nixvim";

    terminal-wakatime = {
      url = "github:taciturnaxolotl/terminal-wakatime";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    ctfd-alerts = {
      url = "github:taciturnaxolotl/ctfd-alerts";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    flare = {
      url = "github:ByteAtATime/flare/feat/nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    import-tree.url = "github:vic/import-tree";

    nur = {
      url = "github:nix-community/NUR";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    cedarlogic = {
      url = "github:taciturnaxolotl/CedarLogic";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    soapdump = {
      url = "github:taciturnaxolotl/soapdump";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    wakatime-ls = {
      url = "github:mrnossiom/wakatime-ls";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-unstable,
      agenix,
      home-manager,
      nur,
      nix-darwin,
      ...
    }@inputs:
    let
      outputs = inputs.self.outputs;
      unstable-overlays = {
        nixpkgs.overlays = [
          (final: prev: {
            unstable = import nixpkgs-unstable {
              system = final.system;
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
      # Available through 'nixos-rebuild --flake .#hostname'
      nixosConfigurations = {
        moonlark = nixpkgs.lib.nixosSystem {
          specialArgs = { inherit inputs outputs; };
          modules = [
            inputs.disko.nixosModules.disko
            { disko.devices.disk.disk1.device = "/dev/vda"; }
            agenix.nixosModules.default
            unstable-overlays
            ./machines/moonlark
            nur.modules.nixos.default
          ];
        };

        prattle = nixpkgs.lib.nixosSystem {
          specialArgs = { inherit inputs outputs; };
          modules = [
            inputs.disko.nixosModules.disko
            agenix.nixosModules.default
            unstable-overlays
            ./machines/prattle
            nur.modules.nixos.default
          ];
        };

        terebithia = nixpkgs.lib.nixosSystem {
          specialArgs = { inherit inputs outputs; };
          modules = [
            inputs.disko.nixosModules.disko
            agenix.nixosModules.default
            unstable-overlays
            ./machines/terebithia
            nur.modules.nixos.default
          ];
        };
      };

      # Standalone home-manager configurations
      # Available through 'home-manager --flake .#hostname'
      homeConfigurations = {
        "tacyon" = home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.aarch64-linux;
          extraSpecialArgs = {
            inherit inputs outputs;
            nixpkgs-unstable = nixpkgs-unstable;
          };
          modules = [
            ./machines/tacyon
            unstable-overlays
          ];
        };

        "nest" = home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
          extraSpecialArgs = {
            inherit inputs outputs;
            nixpkgs-unstable = nixpkgs-unstable;
            system = "x86_64-linux";
          };
          modules = [
            ./machines/nest
            unstable-overlays
          ];
        };

        "ember" = home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
          extraSpecialArgs = {
            inherit inputs outputs;
            nixpkgs-unstable = nixpkgs-unstable;
          };
          modules = [
            ./machines/ember
            unstable-overlays
          ];

        };
        "john" = home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
          extraSpecialArgs = {
            inherit inputs outputs;
            nixpkgs-unstable = nixpkgs-unstable;
            system = "x86_64-linux";
          };
          modules = [
            ./machines/john
            unstable-overlays
          ];
        };
      };

      # Darwin configurations
      # Available through 'darwin-rebuild switch --flake .#hostname'
      darwinConfigurations = {
        atalanta = nix-darwin.lib.darwinSystem {
          system = "aarch64-darwin";
          specialArgs = { inherit inputs outputs; };
          modules = [
            home-manager.darwinModules.home-manager
            agenix.darwinModules.default
            unstable-overlays
            ./machines/atalanta
          ];
        };
      };

      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixfmt-tree;
      formatter.aarch64-darwin = nixpkgs.legacyPackages.aarch64-darwin.nixfmt-tree;
    };
}
