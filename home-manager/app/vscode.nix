{
  inputs,
  lib,
  config,
  pkgs,
  ...
}: {
  # vscode config
  programs.vscode = {
    enable = true;
    package = pkgs.unstable.vscode;
    extensions = with pkgs.vscode-marketplace; [
      ms-vscode.live-server
      formulahendry.auto-rename-tag
      edwinkofler.vscode-assorted-languages
      golang.go
      catppuccin.catppuccin-vsc-icons
      eamodio.gitlens
      yzhang.markdown-all-in-one
      github.vscode-github-actions
      yoavbls.pretty-ts-errors
      esbenp.prettier-vscode
      ms-vscode.vscode-serial-monitor
      prisma.prisma
      ms-azuretools.vscode-docker
      astro-build.astro-vscode
      github.copilot
      github.copilot-chat
      dotjoshjohnson.xml
      mikestead.dotenv
      bradlc.vscode-tailwindcss
      mechatroner.rainbow-csv
      wakatime.vscode-wakatime
      paulober.pico-w-go
      ms-python.python
      karunamurti.tera
      biomejs.biome
      bschulte.love
      sumneko.lua
      yinfei.luahelper
      tamasfe.even-better-toml
      fill-labs.dependi
      rust-lang.rust-analyzer
      dustypomerleau.rust-syntax
    ]
    ++ [(pkgs.catppuccin-vsc.override {
      accent = "blue";
    })]
    ++ [inputs.frc-nix.packages.${pkgs.system}.vscode-wpilib];

    userSettings = {
      "editor.semanticHighlighting.enabled" = true;
      "terminal.integrated.minimumContrastRatio" = 1;
      "window.titleBarStyle" = "custom";

      "gopls" = {
        "ui.semanticTokens" = true;
      };
      "workbench.colorTheme" = "Catppuccin Macchiato";
      "workbench.iconTheme" = "catppuccin-macchiato";
      "catppuccin.accentColor" = "blue";
      "editor.fontFamily" = "'FiraCode Nerd Font', 'monospace', monospace";
      "git.autofetch" = true;
      "git.confirmSync" = false;
      "github.copilot.editor.enableAutoCompletions" = false;
      
      "editor.formatOnSave" = true;

      "editor.defaultFormatter" = "biomejs.biome";
      "[go]" = {
        "editor.defaultFormatter" = "golang.go";
      };
      "[yaml]" = {
        "editor.defaultFormatter" = "esbenp.prettier-vscode";
      };
      "[lua]" = {
        "editor.defaultFormatter" = "yinfei.luahelper";
      };
      "[html]" = {
        "editor.defaultFormatter" = "esbenp.prettier-vscode";
      };

      "editor.linkedEditing" = true;
    };
  };
}
