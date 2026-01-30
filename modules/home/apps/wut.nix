{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.atelier.shell.wut;
in
{
  options.atelier.shell.wut = {
    enable = lib.mkEnableOption "wut - ephemeral Git worktree management";
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      pkgs.wut
    ];

    programs.zsh.initContent = ''
      # wut - Git worktree management shell integration
      eval "$(wut init)"
    '';
  };
}
