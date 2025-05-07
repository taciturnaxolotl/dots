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

> ~~I have absolutely no idea how to install this~~ I kinda understand now?
>   
> ⚠️ These installation instructions are being actively worked on as I test installation on a friend's computer  

Install NixOS via the [official guide](https://nixos.org/download.html)

Connect to wifi

```bash 
wpa_passphrase your-ESSID your-passphrase | sudo tee /etc/wpa_supplicant.conf 
sudo systemctl restart wpa_supplicant
```

Check with `ping 1.1.1.1` if that doesn't work then use `wpa_cli`

```bash 
wpa_cli

add_network 0 ssid "put your ssid here"

add_network 0 psk "put your password here"

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
curl https://github.com/taciturnaxolotl/dots/raw/master/moonlark/disk-config.nix -o /tmp/disk-config.nix
nix --experimental-features "nix-command flakes" run github:nix-community/disko -- --mode disko /tmp/disk-config.nix
```

Mount disk with and cd into it

```bash
mount | grep /mnt
cd /mnt/etc/nixos
```

Clone this repo to your `/mnt/etc/nixos` folder

```bash
git clone https://github.com/taciturnaxolotl/dots.git .
```

Add your ssh private key to `/mtn/etc/ssh/id_rsa` 

install the flake, and umount the filesystem, and then reboot 

```bash
nixos-install --flake .#moonlark --no-root-passwd
umount /mnt
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
