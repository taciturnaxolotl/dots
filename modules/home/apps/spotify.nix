{
  lib,
  pkgs,
  config,
  ...
}:
{
  options.atelier.apps.spotify.enable = lib.mkEnableOption "Enable Spotify config (spicetify)";
  config = lib.mkIf config.atelier.apps.spotify.enable {
    programs.spicetify = {
      enable = true;
      enabledExtensions = with pkgs.spicePkgs.extensions; [
        adblock
        hidePodcasts
        shuffle
      ];
      theme = pkgs.spicePkgs.themes.text;
      colorScheme = "CatppuccinMocha";
    };
  };
}
