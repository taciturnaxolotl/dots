# dunkirk.sh

Kieran's opinionated NixOS infrastructure. Declarative server config, self-hosted services, automated deployments.

For machine inventory, apply commands, repo layout, and conventions see [AGENTS.md](https://github.com/taciturnaxolotl/dots/blob/main/AGENTS.md).

- [Installation](./installation.md) — getting started on macOS, NixOS, or home-manager
- [Deployment](./deployment.md) — CI/CD workflows for infrastructure and application code
- [Services](./services/README.md) — architecture overview and service documentation
- [Secrets](./secrets.md) — agenix workflow
- [mkService](./mkservice.md) — the service factory reference
- [Modules](./modules/README.md) — custom NixOS and home-manager modules

Live status at [infra.dunkirk.sh](https://infra.dunkirk.sh). Machine manifest: `nix eval --json .#services-manifest`.
