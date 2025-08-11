{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
{
  imports = [
    inputs.nur.modules.homeManager.default
  ];

  options.programs.crush = {
    enable = lib.mkEnableOption "Enable crush";
    settings = import ./_crush-options.nix { inherit lib; };
  };

  config = lib.mkIf config.programs.crush.enable {
    home.packages = [ pkgs.nur.repos.charmbracelet.crush ];
    home.file.".config/crush/crush.json" = lib.mkIf (config.programs.crush.settings != { }) {
      text = builtins.toJSON config.programs.crush.settings;
    };
  };
}
