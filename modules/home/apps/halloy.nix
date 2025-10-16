{lib, config, ...}:
{
  options.atelier.apps.halloy.enable = lib.mkEnableOption "Enable halloy config";
  config = lib.mkIf config.atelier.apps.halloy.enable {
    programs.halloy = {
      enable = true;
      settings = {
        theme = "ferra";
        buffer.channel.topic = {
          enabled = true;
        };
        servers.liberachat = {
          nickname = "taciturnaxolotl";
          realname = "kieran klukas";
          username = "kierank";
          server = "irc.libera.chat";
          channels = ["#tangled" "#halloy"];
        };
      };
    };
  };
}
