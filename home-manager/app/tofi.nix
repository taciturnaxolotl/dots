{
  ...
}:
{
  catppuccin.tofi.enable = false;

  # tofi config
  programs.tofi = {
    enable = true;
    settings = {
      font = "Fira Sans";
      font-size = 24;

      prompt-text = ''">  "'';
      placeholder-text = "search for something";
      hide-cursor = true;

      corner-radius = 10;
      outline-width = 3;
      border-width = 0;
      padding-left = "4%";
      padding-top = "2%";
      padding-right = 0;
      padding-bottom = 0;

      outline-color = "#1E2030";
      text-color = "#cad3f5";
      prompt-color = "#ed8796";
      placeholder-color = "#8087A2";
      selection-color = "#eed49f";
      background-color = "#24273a";

      width = "35%";
      height = "15%";
    };
  };
}
