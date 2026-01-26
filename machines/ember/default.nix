{
  inputs,
  pkgs,
  ...
}:
{
  imports = [
    (inputs.import-tree ../../modules/home)
    ../../modules/home/system/nixpkgs.nix.disabled
  ];

  nixpkgs.enable = true;

  home = {
    username = "kierank";
    homeDirectory = "/home/kierank";

    sessionPath = [
      "$HOME/.npm-global/bin"
      "$HOME/.local/share/pnpm"
    ];

    packages = with pkgs; [
      # apps
      iodine
      mosh
      browsh
      firefox

      # langs
      go
    ];
  };

  atelier = {
    shell.enable = true;
    apps = {
      helix.enable = true;
    };
    pbnj = {
      enable = true;
      host = "https://pbnj.dunkirk.sh";
    };
    ssh = {
      enable = true;
      zmx.enable = true;
    };
  };

  # Enable home-manager
  programs.home-manager.enable = true;

  # Nicely reload system units when changing configs
  systemd.user.startServices = "sd-switch";

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  home.stateVersion = "23.05";
}
