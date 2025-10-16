{
  inputs,
  pkgs,
  ...
}:
{
  imports = [
    (inputs.import-tree ../../../modules/home)
  ];

  nixpkgs.enable = true;

  home = {
    username = "kierank";
    homeDirectory = "/Users/kierank";
    packages = with pkgs; [
      inputs.nixvim.packages.${system}.default
      vesktop
    ];
  };

  atelier = {
    shell = {
      enable = true;
    };
    terminal = {
      ghostty = {
        enable = true;
        windowDecoration = true;
      };
    };
    apps = {
      halloy.enable = true;
      spotify.enable = true;
      crush.enable = true;
      helix.enable = true;
    };
  };

  programs.zsh.initContent = ''
    eval "$(/usr/libexec/path_helper)"
  '';

  # Let Home Manager install and manage itself
  programs.home-manager.enable = true;

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  home.stateVersion = "23.05";
}
