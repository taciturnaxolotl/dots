/** Service utility functions for the atelier infrastructure.

  These functions operate on NixOS configurations to extract
  service metadata for dashboards, monitoring, and documentation.
*/
{ lib }:

{
  /**
    Check whether an atelier service config value has the standard
    mkService shape (has `enable`, `domain`, `port`, `_description`).

    # Arguments

    - `cfg` — an attribute set from `config.atelier.services.<name>`

    # Type

    ```
    AttrSet -> Bool
    ```

    # Example

    ```nix
    isMkService config.atelier.services.cachet
    => true
    ```
  */
  isMkService = cfg:
    (cfg.enable or false)
    && (cfg ? domain)
    && (cfg ? port)
    && (cfg ? _description);

  /**
    Convert a single mkService config into a manifest entry.

    # Arguments

    - `name` — the service name (attribute key)
    - `cfg` — the service config attrset

    # Type

    ```
    String -> AttrSet -> AttrSet
    ```

    # Example

    ```nix
    mkServiceEntry "cachet" config.atelier.services.cachet
    => { name = "cachet"; domain = "cachet.dunkirk.sh"; ... }
    ```
  */
  mkServiceEntry = name: cfg: {
    inherit name;
    description = cfg._description or "${name} service";
    domain = cfg.domain;
    port = cfg.port;
    runtime = cfg._runtime or "unknown";
    repository = cfg.repository or null;
    health_url = cfg.healthUrl or null;
    data = {
      sqlite = cfg.data.sqlite or null;
      postgres = cfg.data.postgres or null;
      files = cfg.data.files or [];
    };
  };

  /**
    Build a services manifest from an evaluated NixOS config.

    Discovers all enabled mkService-based services plus emojibot
    instances. Returns a sorted list of service entries suitable
    for JSON serialisation.

    # Arguments

    - `config` — the fully evaluated NixOS configuration

    # Type

    ```
    AttrSet -> [ AttrSet ]
    ```

    # Example

    ```nix
    mkManifest config
    => [ { name = "cachet"; domain = "cachet.dunkirk.sh"; ... } ... ]
    ```
  */
  mkManifest = config:
    let
      allServices = config.atelier.services;

      isMkSvc = _: v:
        (v.enable or false)
        && (v ? domain)
        && (v ? port)
        && (v ? _description);

      standardServices = lib.filterAttrs isMkSvc allServices;

      mkEntry = name: cfg: {
        inherit name;
        description = cfg._description or "${name} service";
        domain = cfg.domain;
        port = cfg.port;
        runtime = cfg._runtime or "unknown";
        repository = cfg.repository or null;
        health_url = cfg.healthUrl or null;
        data = {
          sqlite = cfg.data.sqlite or null;
          postgres = cfg.data.postgres or null;
          files = cfg.data.files or [];
        };
      };

      emojibotInstances =
        let
          instances = allServices.emojibot.instances or {};
          enabled = lib.filterAttrs (_: v: v.enable or false) instances;
        in
        lib.mapAttrsToList (name: inst: {
          name = "emojibot-${name}";
          description = "Emojibot for ${inst.workspace or name}";
          domain = inst.domain;
          port = inst.port;
          runtime = "bun";
          repository = inst.repository or null;
          health_url = inst.healthUrl or null;
          data = { sqlite = null; postgres = null; files = []; };
        }) enabled;

      serviceList = (lib.mapAttrsToList mkEntry standardServices) ++ emojibotInstances;
    in
    lib.sort (a: b: a.name < b.name) serviceList;

  /**
    Build a manifest of all machines and their services.

    Takes one or more attrsets of system configurations (NixOS, Darwin,
    or home-manager) and returns an attrset keyed by machine name.
    Only machines with `atelier.machine.enable = true` are included.

    # Arguments

    - `configSets` — list of attrsets of system configurations

    # Type

    ```
    [ AttrSet ] -> AttrSet
    ```

    # Example

    ```nix
    mkMachinesManifest [ self.nixosConfigurations self.darwinConfigurations ]
    => { terebithia = { hostname = "terebithia"; services = [ ... ]; }; }
    ```
  */
  mkMachinesManifest = configSets:
    let
      self = import ./services.nix { inherit lib; };
      merged = lib.foldl (acc: cs: acc // cs) {} configSets;
      enabled = lib.filterAttrs (_: sys:
        sys.config.atelier.machine.enable or false
      ) merged;
      mkMachineEntry = name: sys:
        let
          config = sys.config;
          hasAtelierServices = config ? atelier && config.atelier ? services;
          services = if hasAtelierServices then self.mkManifest config else [];
        in {
          hostname = config.networking.hostName or name;
          type = config.atelier.machine.type or "server";
          tailscale_host = config.atelier.machine.tailscaleHost or null;
          triage_url = config.atelier.machine.triageUrl or null;
          services = services;
        };
    in
    lib.mapAttrs mkMachineEntry enabled;
}
