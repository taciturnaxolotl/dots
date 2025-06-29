# Kieran's Dots

![nix rebuild with flake update](.github/images/nix-update.webp)

> [!CAUTION]
> These dots are highly prone to change / breakage.
>
> ~I am not a nix os expert (this is my first time touching nix), so I'm not sure if this will work or not. I'm just trying to get my dots up on github.~
>
> After `284` successful days of these dots being in constant operation, many many rebuilds, and `364` commits these dots have been rock solid and I have no complaints.

## The layout

```bash
/etc/nixos
├── home-manager - all the config's that use home manager and stored centraly here
│   ├── app - any apps that have home manager configs like neovim get a file here
│   ├── dots - any config files that need to be symlinked go here eg my hyprland config
│   ├── machines - the different machines by hostname
│   │   └── moonlark - my framework laptop
│   └── wm - window manager config; honestly it could probly be moved to app/hyprland
│       └── hyprland - hyprland config
├── moonlark - the files pertaining to my moonlark machine that aren't home manager related
└── secrets - any secrets that are encrypted with agenix go here

10 directories
```

## Installation

You could either install a NixOS machine (rn there is just `moonlark`) or you can use the home-manager instructions

### Home Manager

Install nix via the determinate systems installer

```bash
curl -fsSL https://install.determinate.systems/nix | sh -s -- install --determinate
```

then copy ssh keys and chmod them

```bash
scp .ssh/id_rsa* nest:/home/kierank/.ssh/
ssh nest chmod 600 ~/.ssh/id_rsa*
```

and then clone the repo

```bash
git clone git@github.com/taciturnaxolotl/dots
cd dots
```

and execute the machine profile

```bash
home-manager switch --flake .#kierank@nest
```

### NixOS

> These instructions have been validated by installing on my friend's machine ([`Nat2-Dev/dots`](https://github.com/Nat2-Dev/dots))

You have two options for installation: either the full guide as follows or the install script below and instructions in [INSTALL_GUIDE.md](/INSTALL_GUIDE.md)

```bash
curl -L https://raw.githubusercontent.com/taciturnaxolotl/dots/main/nixos/install.sh -o install.sh
chmod +x install.sh
./install.sh
```

#### The manual way

Install NixOS via the [official guide](https://nixos.org/download.html)

Connect to wifi

```bash
wpa_passphrase your-ESSID your-passphrase | sudo tee /etc/wpa_supplicant.conf
sudo systemctl restart wpa_supplicant
```

Check with `ping 1.1.1.1` if that doesn't work then use `wpa_cli`

```bash
sudo systemctl start wpa_supplicant
wpa_cli

add_network 0

set_network 0 ssid "put your ssid here"

set_network 0 psk "put your password here"

enable network 0

exit
```

Aquire root permissions while keeping your current context with

```bash
sudo -i
```

Enable git and rebuild your flake with the following

```bash
sed -i 's/^{$/{\n  programs.git.enable = true;/' /etc/nixos/configuration.nix
nixos-rebuild switch
```

Download the disk configuration and run it

```bash
curl -L https://github.com/taciturnaxolotl/dots/raw/main/moonlark/disk-config.nix -o /tmp/disk-config.nix
nix --experimental-features "nix-command flakes" run github:nix-community/disko -- --mode destroy,format,mount /tmp/disk-config.nix
```

Run nixos generate config and cd into it

```bash
nixos-generate-config --root /mnt
cd /mnt/etc/nixos
```

Clone this repo to your `/mnt/etc/nixos` folder

```bash
rm *
git clone https://github.com/taciturnaxolotl/dots.git .
```

Add your ssh private key to `/mnt/etc/ssh/id_rsa`

install the flake, and umount the filesystem, and then reboot

```bash
nixos-install --flake .#moonlark --no-root-passwd
reboot
```

Pray to the nix gods that it works 🙏

If it worked then you should be able to login with the user `kierank` and the password `lolzthisaintsecure!`

You should immediately change the password

```bash
passwd kierank
```

Move the config to your local directory, link to `/etc/nixos`, and change permissions

```bash
mkdir ~/etc; sudo mv /etc/nixos ~/etc
sudo ln -s ~/etc/nixos /etc
sudo chown -R $(id -un):users ~/etc/nixos
sudo chown kierank -R ~/etc/nixos
sudo chown kierank -R ~/etc/nixos/.*
```

17. Setup the fingerprint reader and verify it works (you may need to swipe your finger across the fingerprint sensor instead of simply laying it there)

```bash
sudo fprintd-enroll -f right-index-finger kierank
sudo fprintd-verify kierank
```

Finally enable [atuin](https://atuin.sh/)

```bash
atuin login
atuin sync
```

## Screenshots

<details>
    <summary>I've stuck the rest of the screenshots in a spoiler to preserve space</summary>
<br/>
  
**Last updated: 2024-12-27**

![the github page of this repo](https://github.com/kcoderhtml/dots/raw/master/.github/images/github.webp)
![nautilus file manager](https://github.com/kcoderhtml/dots/raw/master/.github/images/nautilus.webp)
![neofetch](https://github.com/kcoderhtml/dots/raw/master/.github/images/neofetch.webp)
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

## 📜 License

The code is licensed under `MIT`! That means MIT allows for free use, modification, and distribution of the software, requiring only that the original copyright notice and disclaimer are included in copies. All artwork and images are copyright reserved but may be used with proper attribution to the authors.

<p align="center">
        <img src="https://raw.githubusercontent.com/taciturnaxolotl/carriage/master/.github/images/line-break.svg" />
</p>

<p align="center">
        <i><code>&copy 2025-present <a href="https://github.com/taciturnaxolotl">Kieran Klukas</a></code></i>
</p>

<p align="center">
        <a href="https://github.com/taciturnaxolotl/dots/blob/master/LICENSE.md"><img src="https://img.shields.io/static/v1.svg?style=for-the-badge&label=License&message=MIT&logoColor=d9e0ee&colorA=363a4f&colorB=b7bdf8"/></a>
</p>
