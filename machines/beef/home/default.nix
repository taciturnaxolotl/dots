{
  inputs,
  pkgs,
  osConfig,
  ...
}:
{
  imports = [
    (inputs.import-tree ../../../modules/home)
  ];

  home = {
    username = "kierank";
    homeDirectory = "/Users/kierank";
    packages = [
      inputs.nixvim.packages.${pkgs.stdenv.hostPlatform.system}.default
      pkgs.libiconv
    ];
    sessionVariables = {
      LIBRARY_PATH = "${pkgs.libiconv}/lib";
    };
  };

  atelier = {
    shell.enable = true;
    terminal.ghostty = {
      enable = true;
      windowDecoration = true;
    };
    apps.helix.enable = true;
    bore = {
      enable = true;
      authTokenFile = osConfig.age.secrets."bore/auth-token".path;
    };
    pbnj = {
      enable = true;
      host = "https://pbnj.dunkirk.sh";
      authKeyFile = osConfig.age.secrets.pbnj.path;
    };
    ssh = {
      enable = true;
      zmx = {
        enable = true;
        hosts = [
          "t.*"
          "p.*"
          "e.*"
        ];
      };
      hosts = {
        "t.*" = {
          hostname = "150.136.15.177";
        };
        "p.*" = {
          hostname = "100.105.247.54";
        };
        terebithia = {
          hostname = "150.136.15.177";
          zmx = true;
        };
        terebithia-raw = {
          hostname = "terebithia";
        };
        prattle = {
          hostname = "100.105.247.54";
          zmx = true;
        };
        herald = {
          hostname = "herald.dunkirk.sh";
          port = 2223;
        };
      };
      extraConfig = ''
        IdentityFile ~/.ssh/id_rsa
      '';
    };
  };

  programs.zsh.initContent = ''
    export PATH="$HOME/.cargo/bin:$PATH"
  '';

  home.stateVersion = "25.05";
}
