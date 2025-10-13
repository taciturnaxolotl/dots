{
  lib,
  config,
  pkgs,
  ...
}:
{
  options.atelier.apps.helix.enable = lib.mkEnableOption "Enable helix config";

  config = lib.mkIf config.atelier.apps.tofi.enable {
    programs.helix = {
      enable = true;
      settings = {
        editor = {
          line-number = "relative";
          mouse = true;
          rulers = [120];
          true-color = true;
          completion-replace = true;
          trim-trailing-whitespace = true;
          end-of-line-diagnostics = "hint";
          color-modes = true;
          rainbow-brackets = true;
          inline-diagnostics.cursor-line = "warning";
          file-picker.hidden = false;
          indent-guides = {
            render = true;
            character = "╎";
            skip-levels = 0;
          };
          soft-wrap.enable = false;
          auto-save = {
            focus-lost = true;
            after-delay = {
              enable = true;
              timeout = 300000;
            };
          };
        };
        cursor-shape = {
          normal = "block";
          insert = "bar";
          select = "underline";
        };
        statusline = {
          left = ["mode" "spinner" "version-control" "spacer" "separator" "file-name" "read-only-indicator" "file-modification-indicator"];
          center = [];
          right = ["diagnostics" "workspace-diagnostics" "position" "total-line-numbers" "position-percentage" "file-encoding" "file-line-ending" "file-type" "register" "selections"];
          separator = "│";
        };
        keys = {
          select = {
            "0" = "goto_line_start";
            "$" = "goto_line_end";
            "^" = "goto_first_nonwhitespace";
            "G" = "goto_file_end";
            "D" = ["extend_to_line_bounds" "delete_selection" "normal_mode"];
            "k" = ["extend_line_up" "extend_to_line_bounds"];
            "j" = ["extend_line_down" "extend_to_line_bounds"];
          };
          normal = {
            "D" = ["ensure_selections_forward" "extend_to_line_end" "delete_selection"];
            "0" = "goto_line_start";
            "$" = "goto_line_end"; 
            "^" = "goto_first_nonwhitespace";
            "G" = "goto_file_end";
            "V" = ["select_mode" "extend_to_line_bounds"];
            "esc" = ["collapse_selection" "keep_primary_selection"];
          };
        };
      };
      languages = {
        language-server.harper-ls = {
          command = "harper-ls";
          args = ["--stdio"];
          config.harper-ls = {
            diagnosticSeverity = "hint";
            linters = {
              SpellCheck = true;
              SpelledNumbers = false;
              AnA = true;
              SentenceCapitalization = true;
              UnclosedQuotes = true;
              WrongQuotes = false;
              LongSentences = true;
              RepeatedWords = true;
              Spaces = true;
              Matcher = true;
              CorrectNumberSuffix = true;
            };
          };
        };
        language = [
          {
            name = "nix";
            auto-format = true;
            formatter.command = "${pkgs.nixfmt}/bin/nixfmt";
            language-server.command = "${pkgs.nil}/bin/nil";
            language-servers = ["nil" "harper-ls"];
          }
          {
            name = "cpp";
            language-server.command = "${pkgs.clang-tools}/bin/clangd";
            language-servers = ["clangd" "harper-ls"];
          }
          {
            name = "typescript";
            language-server.command = "${pkgs.nodePackages.typescript-language-server}/bin/typescript-language-server";
            language-server.args = ["--stdio"];
            language-servers = ["typescript-language-server" "harper-ls"];
          }
          {
            name = "go";
            language-server.command = "${pkgs.gopls}/bin/gopls";
            language-servers = ["gopls" "harper-ls"];
          }
        ];
      };
    };
  };
}
