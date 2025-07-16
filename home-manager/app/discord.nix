{
  ...
}:
{
  programs.vesktop = {
    settings = {
      minimizeToTray = true;
      discordBranch = "stable";
      arRPC = true;
      splashColor = "oklch(0.75 0 0)";
      splashBackground = "oklch(0.19 0 0)";
      disableSmoothScroll = false;
    };
    vencord = {
      settings = {
        autoUpdate = true;
        autoUpdateNotification = true;
        useQuickCss = true;
        themeLinks = [
          "https://refact0r.github.io/system24/build/system24.css"
        ];
        enabledThemes = [ ];
        plugins = {
          FakeNitro = {
            enabled = true;
            enableStickerBypass = true;
            enableStreamQualityBypass = true;
            enableEmojiBypass = true;
            transformEmojis = true;
            transformStickers = true;
          };
          MessageLogger = {
            enabled = true;
            collapseDeleted = false;
            deleteStyle = "text";
          };
          BetterFolders = {
            enabled = true;
            sidebar = true;
            showFolderIcon = 1;
          };
          SpotifyCrack.enabled = true;
          YoutubeAdblock.enabled = true;
          AlwaysTrust.enabled = true;
          NoTrack.enabled = true;
        };
      };
    };
  };
}
