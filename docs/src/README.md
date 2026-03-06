# dunkirk.sh

Kieran's opinionated NixOS infrastructure — declarative server config, self-hosted services, and automated deployments.

## Layout

```
~/dots
├── .github/workflows  # CI/CD (deploy-rs + per-service reusable workflow)
├── dots               # config files symlinked by home-manager
│   └── wallpapers
├── machines
│   ├── atalanta       # macOS M4 (nix-darwin)
│   ├── ember          # dell r210 server (basement)
│   ├── moonlark       # framework 13 (dead)
│   ├── nest           # shared tilde server (home-manager only)
│   ├── prattle        # oracle cloud x86_64
│   ├── tacyon         # rpi 5
│   └── terebithia     # oracle cloud aarch64 (main server)
├── modules
│   ├── lib
│   │   └── mkService.nix  # service factory (see Deployment section)
│   ├── home           # home-manager modules
│   │   ├── aesthetics # theming and wallpapers
│   │   ├── apps       # app configs (ghostty, helix, git, ssh, etc.)
│   │   ├── system     # shell, environment
│   │   └── wm/hyprland
│   └── nixos          # nixos modules
│       ├── apps       # system-level app configs
│       ├── services   # self-hosted services (mkService-based + custom)
│       │   ├── restic # backup system with CLI
│       │   └── bore   # tunnel proxy
│       └── system     # pam, wifi
├── packages           # custom nix packages
└── secrets            # agenix-encrypted secrets
```

## Machines

| Name | Platform | Role |
|------|----------|------|
| **terebithia** | Oracle Cloud aarch64 | Main server — runs all services |
| **prattle** | Oracle Cloud x86_64 | Secondary server |
| **atalanta** | macOS M4 | Development laptop (nix-darwin) |
| **ember** | Dell R210 | Basement server |
| **tacyon** | Raspberry Pi 5 | Edge device |
| **nest** | Shared tilde | Home-manager only |
