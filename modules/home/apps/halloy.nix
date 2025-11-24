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
        servers = {
          liberachat = {
            nickname = "taciturnaxolotl";
            realname = "kieran klukas";
            username = "kierank";
            server = "irc.libera.chat";
            channels = ["#tangled" "#halloy"];
          };
          hackclub = {
            nickname = "krn";
            realname = "kieran klukas";
            username = "taciturnaxolotl";
            server = "irc.hackclub.com";
            port = 6667;
            use_tls = false;
            channels = ["#lounge"];
          };
        };
      };
    };
  };
}
