# wifi

Declarative Wi-Fi profile manager using NetworkManager. Supports three ways to supply passwords and has built-in eduroam (WPA-EAP) support.

## Options

All options under `atelier.network.wifi`:

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | `false` | Enable Wi-Fi management |
| `hostName` | string | — | Sets `networking.hostName` |
| `nameservers` | list of strings | `[]` | Custom DNS servers |
| `envFile` | path | — | Environment file providing PSK variables for all profiles |

### Profiles

Defined under `atelier.network.wifi.profiles.<ssid>`:

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `psk` | string or null | `null` | Literal WPA-PSK passphrase |
| `pskVar` | string or null | `null` | Environment variable name containing the PSK (from `envFile`) |
| `pskFile` | path or null | `null` | Path to file containing the PSK |
| `eduroam` | bool | `false` | Use WPA-EAP with MSCHAPV2 (for eduroam networks) |
| `identity` | string or null | `null` | EAP identity (required when `eduroam = true`) |

Only one of `psk`, `pskVar`, or `pskFile` should be set per profile.

## Example

```nix
atelier.network.wifi = {
  enable = true;
  hostName = "moonlark";
  nameservers = [ "1.1.1.1" "8.8.8.8" ];
  envFile = config.age.secrets.wifi.path;

  profiles = {
    "Home Network" = {
      pskVar = "HOME_PSK";  # read from envFile
    };
    "eduroam" = {
      eduroam = true;
      identity = "user@university.edu";
      pskVar = "EDUROAM_PSK";
    };
    "Phone Hotspot" = {
      pskFile = config.age.secrets.hotspot.path;
    };
  };
};
```
