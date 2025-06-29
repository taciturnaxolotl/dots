{
  ...
}: {
    # link the dots user.js into the folder
    home.file.".mozilla/firefox/default/user.js".source = ../dots/user.js;

    programs.firefox = {
        enable = true;
        profiles.default = {
            search = {
                force = true;
                default = "DuckDuckGo";
                privateDefault = "DuckDuckGo";
                order = ["DuckDuckGo"];
                engines = {
                    "Bing".metaData = {
                        hidden = true;
                        hideOneOffButton = true;
                    };
                    "Google".metaData = {
                        hidden = true;
                        hideOneOffButton = true;
                    };
                    "Wikipedia (en)".metaData = {
                        hidden = true;
                        hideOneOffButton = true;
                    };
                    "Amazon.com".metaData = {
                        hidden = true;
                        hideOneOffButton = true;
                    };
                    "eBay".metaData = {
                        hidden = true;
                        hideOneOffButton = true;
                    };
                    "Bookmarks".metaData = {
                        hidden = true;
                        hideOneOffButton = true;
                    };
                };
            };
            bookmarks = {};
        };
    };
}
