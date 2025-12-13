# Bore

![screenshot](https://hc-cdn.hel1.your-objectstorage.com/s/v3/7652f29dacb8f76d_screenshot_2025-12-09_at_16.57.47.png)

Bore is a lightweight wrapper around `frp` which provides a dashboard and a nice `gum` based cli. If you would like to run this in your own nix flake then simplify vendor this folder and `./modules/home/bore` and import the folders into the appropriate home manager and nixos configurations.

```nix
atelier = {
    bore = {
        enable = true;
        authTokenFile = osConfig.age.secrets.bore.path
    };
}
```

and be sure to have a definition for your agenix secret in the osConfig as well:

```nix
age = {
    identityPaths = [
        "path/to/ssh/key"
    ];
    secrets = {
        bore = {
            file = ./path/to/bore.age;
            owner = "username";
        };
    };
}
```

The secret file is just a oneline file with the key in it. If you do end up deploying this feel free to email me and let me know! I would love to hear about your setup!
