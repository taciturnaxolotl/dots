# This is your home-manager configuration file
# Use this to configure your home environment (it replaces ~/.config/nixpkgs/home.nix)
{
  inputs,
  lib,
  config,
  pkgs,
  ...
}: {
  # You can import other home-manager modules here
  imports = [
    # If you want to use home-manager modules from other flakes (such as nix-colors):
    # inputs.nix-colors.homeManagerModule

    # You can also split up your configuration and import pieces of it here:
    # ./nvim.nix
    
    # spicetify
    inputs.spicetify-nix.homeManagerModules.default
  ];

  nixpkgs = {
    # Configure your nixpkgs instance
    config = {
      # Disable if you don't want unfree packages
      allowUnfree = true;
      # Workaround for https://github.com/nix-community/home-manager/issues/2942
      allowUnfreePredicate = _: true;
    };
  };

  home = {
    username = "kierank";
    homeDirectory = "/home/kierank";
  };

  # Add stuff for your user as you see fit:
  # programs.neovim.enable = true;
  # home.packages = with pkgs; [ steam ];

  # Enable home-manager and git
  programs.home-manager.enable = true;

  # git config
  programs.git = {
    enable = true;
    userName = "Kieran Klukas";
    userEmail = "92754843+kcoderhtml@users.noreply.github.com";
    aliases = {
      c = "commit";
      p = "push";
      pl = "pull";
    };
    extraConfig = {
      commit.gpgsign = true;
      gpg.format = "ssh";
      gpg.ssh.allowedSignersFile = "~/.ssh/allowedSigners";
      user.signingKey = "~/.ssh/id_rsa.pub";
    };
  };

  programs.spicetify =
    let
      spicePkgs = inputs.spicetify-nix.legacyPackages.${pkgs.system};
    in
    {
      enable = true;
      enabledExtensions = with spicePkgs.extensions; [
        adblock
        hidePodcasts
        shuffle # shuffle+ (special characters are sanitized out of extension names)
      ];
      theme = spicePkgs.themes.catppuccin;
      colorScheme = "macchiato";
    };

  programs.starship = {
    enable = true;
    enableZshIntegration = true;
    # Configuration written to ~/.config/starship.toml
    settings = {
      add_newline = false;
      
      # Change command timeout from 500 to 1000 ms
      command_timeout = 1000;
      
      format = lib.concatStrings [
        "[](purple)$env_var"
        "$all$character"
      ];
      
      character = {
        success_symbol = "[](bold green)";
        error_symbol = "[](bold red)";
      };
      
      env_var.STARSHIP_DISTRO = {
        format = "[$env_value](bold green)";
        variable = "STARSHIP_DISTRO";
        disabled = false;
      };

      username = {
        style_user = "green";
        style_root = "red";
        format = "[$user]($style) ";
	disabled = false;
        show_always = true;
      };
      
      hostname = {
        ssh_only = false;
        format = "on [$hostname](bold yellow) ";
        disabled = false;
      };

      directory = {
        truncation_length = 1;
        truncation_symbol = "…/";
        home_symbol = " ~";
        read_only_style = "197";
        read_only = "  ";
        format = "at [$path]($style)[$read_only]($read_only_style) ";
      };

      git_branch = {
        symbol = "󰊢 ";
        format = "via [$symbol$branch]($style) ";
        truncation_length = 6;
        truncation_symbol = "…/";
        style = "bold green";
      };

      git_status = {
         format = "[\($all_status$ahead_behind\)]($style) ";
         style = "bold green";
         conflicted = "🏳";
         up_to_date = " ";
         untracked = " ";
         #ahead = "⇡";
         diverged = "⇕⇡⇣";
         #behind = "⇣";
         stashed = " ";
         modified = " ";
         staged = "[++\($count\)](green)";
         renamed = "襁 ";
         deleted = " ";
       };

       docker_context = {
         format = "via [ $context](bold blue) ";
         disabled = false;
       };

       python = {
         symbol = " ";
         python_binary = "python3";
         disabled = false;
       };

       nodejs = {
         format = "via [ $version](bold green) ";
         disabled = true;
       };

       ruby = {
         format = "via [ $version]($style) ";
         disabled = true;
       };
    };
  };

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    #autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    shellAliases = {
      ll = "ls -l";
      la = "ls -la";
      update = "sudo nixos-rebuild switch";
    };
    history = {
      size = 10000;
      path = "${config.xdg.dataHome}/zsh/history";
    };

    oh-my-zsh = {
      enable = true;
      plugins = [ "git" "sudo" "docker" "git" "command-not-found" "colored-man-pages" ];
    };

    plugins = [
      {
        # will source zsh-autosuggestions.plugin.zsh
        name = "zsh-autosuggestions";
        src = pkgs.fetchFromGitHub {
          owner = "zsh-users";
          repo = "zsh-autosuggestions";
          rev = "v0.7.0";
          sha256 = "sha256-KLUYpUu4DHRumQZ3w59m9aTW6TBKMCXl2UcKi4uMd7w=";
        };
      }
      {
        # will source zsh-sytax-highlighting
         name = "zsh-sytax-highlighting";
         src = pkgs.fetchFromGitHub {
          owner = "zsh-users";
          repo = "zsh-syntax-highlighting";
          rev = "0.8.0";
         sha256 = "sha256-iJdWopZwHpSyYl5/FQXEW7gl/SrKaYDEtTH9cGP7iPo=";
        };
      }
    ];
  };
  
  # Nicely reload system units when changing configs
  systemd.user.startServices = "sd-switch";

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  home.stateVersion = "23.05";
}
