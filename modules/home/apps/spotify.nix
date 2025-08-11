{
  lib,
  pkgs,
  config,
  inputs,
  ...
}:
{
  imports = [
    inputs.spicetify-nix.homeManagerModules.default
  ];

  options.atelier.apps.spotify.enable = lib.mkEnableOption "Enable Spotify config (spicetify)";
  config = lib.mkIf config.atelier.apps.spotify.enable {
    programs.spicetify =
      let
        spicePkgs = inputs.spicetify-nix.legacyPackages.${pkgs.system};
      in
      {
        enable = true;
        enabledExtensions = with spicePkgs.extensions; [
          adblock
          hidePodcasts
          shuffle
        ];
        theme = spicePkgs.themes.text;
        colorScheme = "CatppuccinMocha";
      };
  };
}
