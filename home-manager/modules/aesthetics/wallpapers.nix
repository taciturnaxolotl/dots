{ lib, config, ... }:
{
  options.dots.wallpapers.enable = lib.mkEnableOption "symlink a bunch of wallpapers";
  config = lib.mkIf config.dots.wallpapers.enable {
    xdg.configFile."wallpapers/randomize.sh".source = ../../dots/randomize-wallpaper.sh;
    xdg.configFile."wallpapers/acon-pier.jpg".source = ../../dots/wallpapers/acon-pier.jpg;
    xdg.configFile."wallpapers/acon-forest.jpg".source = ../../dots/wallpapers/acon-forest.jpg;
    xdg.configFile."wallpapers/acon-gradient-clouds.jpg".source =
      ../../dots/wallpapers/acon-gradient-clouds.jpg;
    xdg.configFile."wallpapers/acon-fsh.jpg".source = ../../dots/wallpapers/acon-fsh.jpg;
    xdg.configFile."wallpapers/tongyu-waves.jpg".source = ../../dots/wallpapers/tongyu-waves.jpg;
    xdg.configFile."wallpapers/acon-rocks.jpg".source = ../../dots/wallpapers/acon-rocks.jpg;
    xdg.configFile."wallpapers/kailing-comet.jpg".source = ../../dots/wallpapers/kailing-comet.jpg;
    xdg.configFile."wallpapers/acon-star.jpg".source = ../../dots/wallpapers/acon-star.jpg;
    xdg.configFile."wallpapers/kailing-canyon.jpg".source = ../../dots/wallpapers/kailing-canyon.jpg;
    xdg.configFile."wallpapers/kailing-swirls.jpg".source = ../../dots/wallpapers/kailing-swirls.jpg;
    xdg.configFile."wallpapers/highway.jpg".source = ../../dots/wallpapers/highway.jpg;
    xdg.configFile."wallpapers/kailing-shooting-star.jpg".source =
      ../../dots/wallpapers/kailing-shooting-star.jpg;
    xdg.configFile."wallpapers/yessa-cat.jpg".source = ../../dots/wallpapers/yessa-cat.jpg;
    xdg.configFile."wallpapers/annie-athena.jpg".source = ../../dots/wallpapers/annie-athena.jpg;
    xdg.configFile."wallpapers/candy-stained-glass.jpg".source =
      ../../dots/wallpapers/candy-stained-glass.jpg;
    xdg.configFile."wallpapers/tongyu-catcat.jpg".source = ../../dots/wallpapers/tongyu-catcat.jpg;
  };
}
