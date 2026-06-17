# Kieran's Dots

![fastfetch on my main systems](https://l4.dunkirk.sh/i/O3-dLGix6Cd9.webp)

> [!CAUTION]
> These dots are highly prone to change / breakage.
>
> ~I am not a nix os expert (this is my first time touching nix), so I'm not sure if this will work or not. I'm just trying to get my dots up on github :3
>
> After `591` days of these dots being in constant operation, many many rebuilds, and `776` commits these dots have been rock solid and I have no complaints.

## Documentation

Semi up-to-date documentation lives in the [mdbook](https://dots.dunkirk.sh) but the most reliable docs are just the config itself. Uptime stats are served at [infra.dunkirk.sh](https://infra.dunkirk.sh).

### Quick start

```bash
# macOS
darwin-rebuild switch --flake .#atalanta

# NixOS (local)
nixos-rebuild switch --flake .#terebithia

# Remote deploy (from dev shell)
nix develop
deploy .#terebithia
```

> [!WARNING]
> This configuration will **not** work without changing the [secrets](./secrets) since they are encrypted with agenix.

## Screenshots

<details>
    <summary>I've stuck the rest of the screenshots in a spoiler to preserve space</summary>
<br/>

**Last updated: 2024-12-27**

![nix rebuild with flake update](.github/images/nix-update.webp)
![the github page of this repo](.github/images/github.webp)
![nautilus file manager](.github/images/nautilus.webp)
![neofetch](.github/images/neofetch.webp)
![spotify with cava next to it](.github/images/spotify.webp)
![zed with the hyprland config open](.github/images/zed.webp)
![cool-retro-term with neofetch](.github/images/cool-retro-term.webp)

</details>

## Credits

Thanks a bunch to the following people for their dots, configs, and general inspiration which i've shamelessly stolen from:

- [NixOS/nixos-hardware](https://github.com/NixOS/nixos-hardware)
- [hyprland-community/hyprnix](https://github.com/hyprland-community/hyprnix)
- [spikespaz/dotfiles](https://github.com/spikespaz/dotfiles)
- [Misterio77/nix-starter-configs](https://github.com/Misterio77/nix-starter-configs)
- [mccd.space install guide](https://mccd.space/posts/git-to-deploy/)
- [disco docs](https://github.com/nix-community/disko/blob/master/docs/quickstart.md)
- [XDG_CONFIG_HOME setting](https://github.com/NixOS/nixpkgs/issues/224525)
- [Daru-san/spicetify-nix](https://github.com/Daru-san/spicetify-nix)
- [agenix](https://nixos.wiki/wiki/Agenix)
- [wpa_supplicant env file docs](https://search.nixos.org/options?show=networking.wireless.environmentFile&from=0&size=50&sort=relevance&type=packages&query=networking.wireless)
- [escaping nix variables](https://www.reddit.com/r/NixOS/comments/jmlohf/escaping_interpolation_in_bash_string/)
- [nerd fonts cheat sheet](https://www.nerdfonts.com/cheat-sheet)
- [setting the default shell in nix](https://www.reddit.com/r/NixOS/comments/z16mt8/cant_seem_to_set_default_shell_using_homemanager/)
- [hyprwm/contrib](https://github.com/hyprwm/contrib)
- [gtk with home manager](https://hoverbear.org/blog/declarative-gnome-configuration-in-nixos/)
- [setting up the proper portals](https://github.com/NixOS/nixpkgs/issues/274554)
- [tuigreet setup](https://github.com/sjcobb2022/nixos-config/blob/29077cee1fc82c5296908f0594e28276dacbe0b0/hosts/common/optional/greetd.nix)

## License

The code is licensed under `MIT`! That means MIT allows for free use, modification, and distribution of the software, requiring only that the original copyright notice and disclaimer are included in copies. All artwork and images are copyright reserved but may be used with proper attribution to the authors.

<p align="center">
        <img src="https://raw.githubusercontent.com/taciturnaxolotl/carriage/master/.github/images/line-break.svg" />
</p>

<p align="center">
        <i><code>&copy 2025-present <a href="https://github.com/taciturnaxolotl">Kieran Klukas</a></code></i>
</p>

<p align="center">
        <a href="https://infra.dunkirk.sh"><img src="https://infra.dunkirk.sh/badge?style=for-the-badge&colorA=363a4f&colorB=b7bdf8"/></a>
        <a href="https://github.com/taciturnaxolotl/dots/blob/master/LICENSE.md"><img src="https://img.shields.io/static/v1.svg?style=for-the-badge&label=License&message=MIT&logoColor=d9e0ee&colorA=363a4f&colorB=b7bdf8"/></a>
</p>
