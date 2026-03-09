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

      # Custom services that don't use mkService but should appear in the manifest
      customServices = let
        noData = { sqlite = null; postgres = null; files = []; };
        mkCustom = name: attrs: { inherit name; data = noData; } // attrs;
      in lib.concatLists [
        (lib.optional ((allServices.herald.enable or false) && (allServices.herald ? domain)) (mkCustom "herald" {
          description = "RSS-to-Email via SSH";
          domain = allServices.herald.domain;
          port = allServices.herald.httpPort or 8085;
          runtime = "go";
          repository = null;
          health_url = "https://${allServices.herald.domain}";
        }))
        (lib.optional ((allServices.triage-agent.enable or false) && (allServices.triage-agent ? domain)) (mkCustom "triage-agent" {
          description = "AI-powered service triage webhook";
          domain = allServices.triage-agent.domain;
          port = allServices.triage-agent.port or 3200;
          runtime = "bun";
          repository = null;
          health_url = "https://${allServices.triage-agent.domain}/health";
        }))
        (lib.optional ((allServices.frps.enable or false) && (allServices.frps ? domain)) (mkCustom "bore" {
          description = "HTTP/TCP/UDP tunnel proxy";
          domain = allServices.frps.domain;
          port = allServices.frps.vhostHTTPPort or 7080;
          runtime = "go";
          repository = null;
          health_url = "https://${allServices.frps.domain}";
        }))
        (lib.optional (config.services.tangled.knot.enable or false) (mkCustom "knot" {
          description = "Tangled git hosting";
          domain = config.services.tangled.knot.server.hostname or "knot.dunkirk.sh";
          port = 5555;
          runtime = "go";
          repository = null;
          health_url = "https://${config.services.tangled.knot.server.hostname or "knot.dunkirk.sh"}";
        }))
        (lib.optional (config.services.tangled.spindle.enable or false) (mkCustom "spindle" {
          description = "Tangled CI";
          domain = config.services.tangled.spindle.server.hostname or "spindle.dunkirk.sh";
          port = 6555;
          runtime = "go";
          repository = null;
          health_url = "https://${config.services.tangled.spindle.server.hostname or "spindle.dunkirk.sh"}";
        }))
        (lib.optional (config.services.n8n.enable or false) (mkCustom "n8n" {
          description = "Workflow automation";
          domain = config.services.n8n.environment.N8N_HOST or "n8n.dunkirk.sh";
          port = 5678;
          runtime = "node";
          repository = null;
          health_url = "https://${config.services.n8n.environment.N8N_HOST or "n8n.dunkirk.sh"}/healthz";
        }))
      ];

      serviceList = (lib.mapAttrsToList mkEntry standardServices) ++ emojibotInstances ++ customServices;
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
