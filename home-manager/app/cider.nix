{
  inputs,
  lib,
  config,
  pkgs,
  ...
}: {
  imports = [
    inputs.cider.homeManagerModules.x86_64-linux.default
    inputs.agenix.homeManagerModules.default
  ];

  age.secretsDir = "/run/agenix";
  age.secrets.cider.file = ../../secrets/cider.age;

  programs.cider = {
    enable = true;
    path = builtins.fetchurl {
      url = "https://cloud-9fsgrdai8-hack-club-bot.vercel.app/0cider-linux-x64.appimage";
      sha256 = "0zwyin85knvlbkbilm2sdf5k2h12z5f624lb3bfyy2sbxvc9dp2x";
    };
  };
}
