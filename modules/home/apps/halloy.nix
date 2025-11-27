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
            nick_password = "Extrude1-Herbal-Map";
            realname = "kieran klukas";
            username = "taciturnaxolotl";
            server = "irc.hackclub.com";
            port = 6667;
            use_tls = false;
            chathistory = true;
            channels = [
              "#lounge"
              "#hq"
              "#krn-rambles"
              "#neon"
              "#neighborhood"
              "#meta"
              "#fraud-land"
            ];
            channel-keys = {
              fraud-land = "fraudpheus";
            };
          };
        };
      };
    };
  };
}
