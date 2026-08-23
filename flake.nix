{
  description = "Kieran's opinionated (and probably slightly dumb) nix config";

  inputs = {
    # Nixpkgs
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-unstable-small.url = "github:nixos/nixpkgs/nixos-unstable-small";

    # NixOS hardware configuration
    hardware.url = "github:NixOS/nixos-hardware/master";

    # Home manager
    home-manager.url = "github:nix-community/home-manager/release-26.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # Nix-Darwin
    nix-darwin.url = "github:nix-darwin/nix-darwin/nix-darwin-26.05";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    nixos-facter-modules.url = "github:numtide/nixos-facter-modules";

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
      url = "github:hackclub/terminal-wakatime";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    ctfd-alerts = {
      url = "github:taciturnaxolotl/ctfd-alerts";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    pear = {
      url = "github:taciturnaxolotl/pear";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    potluck = {
      url = "github:taciturnaxolotl/potluck";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    lard = {
      url = "github:taciturnaxolotl/lard";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    flare = {
      url = "github:ByteAtATime/flare/feat/nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    herald = {
      url = "github:taciturnaxolotl/herald";
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

    deploy-rs = {
      url = "github:serokell/deploy-rs";
      inputs.nixpkgs.follows = "nixpkgs-unstable-small";
    };

    tangled = {
      url = "git+https://tangled.org/tangled.org/core?rev=1d379a324497da39a27e49453c72615607a9b199";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    zmx = {
      url = "github:neurosnap/zmx";
    };

    impure = {
      url = "github:taciturnaxolotl/impure";
    };

    tangle-of-trust = {
      url = "github:taciturnaxolotl/tangle-of-trust";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    nixarr = {
      url = "github:nix-media-server/nixarr";
      inputs.nixpkgs.follows = "nixpkgs";
    };

  };

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-unstable,
      nixpkgs-unstable-small,
      agenix,
      home-manager,
      nur,
      nix-darwin,
      deploy-rs,
      tangled,
      ...
    }@inputs:
    let
      outputs = inputs.self.outputs;

      unstable-overlays = {
        nixpkgs.overlays = [
          nur.overlays.default
          (final: prev: {
            unstable = import nixpkgs-unstable {
              system = final.stdenv.hostPlatform.system;
              config.allowUnfree = true;
            };

            # nix 2.34 aborts the daemon whenever a substituter is unreachable.
            # A failing narinfo worker sets the thread pool's quit flag, the
            # next worker logs its own error through TunnelLogger, and that
            # write throws Interrupted from inside a catch block, unwinding out
            # of the worker thread. The client just sees "Nix daemon
            # disconnected unexpectedly". NixOS/nix#3768 (open since 2020) and
            # NixOS/nix#12871. Drop this once upstream lands a fix.
            nixVersions = prev.nixVersions.extend (
              _finalNix: prevNix: {
                nixComponents_2_34 = prevNix.nixComponents_2_34.appendPatches [
                  ./patches/nix-2.34-daemon-no-interrupt-on-client-write.patch
                ];
              }
            );

            zmx-binary = prev.callPackage ./packages/zmx.nix { };
            bore-auth = prev.callPackage ./packages/bore-auth.nix { };
            pear = inputs.pear.packages.${prev.stdenv.hostPlatform.system}.default;
            herald = inputs.herald.packages.${prev.stdenv.hostPlatform.system}.default;
            potluck = inputs.potluck.packages.${prev.stdenv.hostPlatform.system}.default;
            lard = inputs.lard.packages.${prev.stdenv.hostPlatform.system}.default;
            tangle-of-trust = inputs.tangle-of-trust.packages.${prev.stdenv.hostPlatform.system}.default;
          })
        ];
      };

      # deploy-rs.lib.activate embeds the deploy-rs binary in each node's
      # activation closure. Taken straight from the flake input (whose nixpkgs
      # follows ours) that binary is in no cache and compiles from source — fine
      # under --remote-build (built once on the target), but a per-run source
      # build on the CI runner now that we build there. Swap in nixpkgs' cached
      # binary via deploy-rs's documented overlay, keeping its lib functions.
      deployRsLib =
        system:
        (import nixpkgs-unstable-small {
          inherit system;
          overlays = [
            deploy-rs.overlays.default
            (_final: prev: {
              deploy-rs = {
                inherit (nixpkgs-unstable-small.legacyPackages.${system}) deploy-rs;
                lib = prev.deploy-rs.lib;
              };
            })
          ];
        }).deploy-rs.lib;
    in
    {
      # NixOS configuration entrypoint
      # Available through 'nixos-rebuild --flake .#hostname'
      nixosConfigurations = {
        prattle = nixpkgs.lib.nixosSystem {
          specialArgs = { inherit inputs outputs; };
          modules = [
            inputs.disko.nixosModules.disko
            agenix.nixosModules.default
            inputs.nixos-facter-modules.nixosModules.facter
            inputs.nixarr.nixosModules.default
            { config.facter.reportPath = ./machines/prattle/facter.json; }
            unstable-overlays
            ./machines/prattle
          ];
        };

        terebithia = nixpkgs.lib.nixosSystem {
          specialArgs = { inherit inputs outputs; };
          modules = [
            inputs.disko.nixosModules.disko
            agenix.nixosModules.default
            inputs.nixos-facter-modules.nixosModules.facter
            { config.facter.reportPath = ./machines/terebithia/facter.json; }
            unstable-overlays
            ./machines/terebithia
          ];
        };

        iso-x86_64 = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit inputs outputs; };
          modules = [
            unstable-overlays
            ./machines/iso
          ];
        };

        iso-aarch64 = nixpkgs.lib.nixosSystem {
          system = "aarch64-linux";
          specialArgs = { inherit inputs outputs; };
          modules = [
            unstable-overlays
            ./machines/iso
          ];
        };
      };

      # Standalone home-manager configurations
      # Available through 'home-manager --flake .#hostname'
      homeConfigurations = {
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
            ./machines/atalanta
          ];
        };
        beef = nix-darwin.lib.darwinSystem {
          system = "aarch64-darwin";
          specialArgs = { inherit inputs outputs; };
          modules = [
            home-manager.darwinModules.home-manager
            agenix.darwinModules.default
            ./machines/beef
          ];
        };
      };

      # Service manifest for infra dashboard
      # Evaluate with: nix eval --json .#services-manifest
      services-manifest = import ./lib/services-manifest.nix {
        configSets = [
          self.nixosConfigurations
          self.darwinConfigurations
          self.homeConfigurations
        ];
        extraMachines = {
          everseen = {
            type = "client";
            tailscaleHost = "everseen";
          };
        };
        lib = nixpkgs.lib;
      };

      # Documentation site (mdBook + nixdoc + atelier options)
      # Build with: nix build .#docs
      # Serve with: nix run .#docs.serve
      packages =
        let
          mkDocs =
            system:
            let
              pkgs = nixpkgs.legacyPackages.${system};
            in
            pkgs.callPackage ./packages/docs.nix {
              servicesManifest = self.services-manifest;
              inherit self;
            };
        in
        {
          x86_64-linux.docs = mkDocs "x86_64-linux";
          aarch64-linux.docs = mkDocs "aarch64-linux";
          aarch64-darwin.docs = mkDocs "aarch64-darwin";
          aarch64-darwin.gp-menubar =
            nixpkgs.legacyPackages.aarch64-darwin.callPackage ./packages/gp-menubar.nix
              { };

          x86_64-linux.iso = self.nixosConfigurations.iso-x86_64.config.system.build.isoImage;
          aarch64-linux.iso = self.nixosConfigurations.iso-aarch64.config.system.build.isoImage;
        };

      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixfmt-tree;
      formatter.aarch64-darwin = nixpkgs.legacyPackages.aarch64-darwin.nixfmt-tree;

      # Use nixpkgs' own deploy-rs (Hydra-built, on cache.nixos.org) rather than
      # deploy-rs.packages.*, which — because the input's nixpkgs follows ours —
      # matches no binary cache and compiles from source (~14 min) every cold CI
      # run. The activate wrapper in deploy.nodes still uses the flake's lib, but
      # that binary builds once and persists in each target's store.
      devShells.aarch64-darwin.default = nixpkgs-unstable-small.legacyPackages.aarch64-darwin.mkShell {
        packages = [ nixpkgs-unstable-small.legacyPackages.aarch64-darwin.deploy-rs ];
      };
      devShells.x86_64-linux.default = nixpkgs-unstable-small.legacyPackages.x86_64-linux.mkShell {
        packages = [ nixpkgs-unstable-small.legacyPackages.x86_64-linux.deploy-rs ];
      };
      devShells.aarch64-linux.default = nixpkgs-unstable-small.legacyPackages.aarch64-linux.mkShell {
        packages = [ nixpkgs-unstable-small.legacyPackages.aarch64-linux.deploy-rs ];
      };

      # Deploy-rs configurations
      deploy.nodes = {
        # NixOS servers
        terebithia = {
          hostname = "100.105.182.50";
          profiles.system = {
            sshUser = "kierank";
            user = "root";
            path = (deployRsLib "aarch64-linux").activate.nixos self.nixosConfigurations.terebithia;
          };
        };
        prattle = {
          hostname = "prattle";
          profiles.system = {
            sshUser = "kierank";
            user = "root";
            path = (deployRsLib "x86_64-linux").activate.nixos self.nixosConfigurations.prattle;
          };
        };
      };

      # Validation checks
      checks = builtins.mapAttrs (system: deployLib: deployLib.deployChecks self.deploy) deploy-rs.lib;
    };
}
