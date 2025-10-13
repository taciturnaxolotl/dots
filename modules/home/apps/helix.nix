{
  lib,
  config,
  pkgs,
  ...
}:
{
  options.atelier.apps.helix.enable = lib.mkEnableOption "Enable helix config";

  config = lib.mkIf config.atelier.apps.helix.enable {
    programs.helix = {
      enable = true;
      package = pkgs.evil-helix;
      extraPackages = with pkgs; [
        clang-tools # clangd
        cmake-language-server # neocmakelsp
        omnisharp-roslyn # OmniSharp
        gopls
        jdt-language-server # jdtls
        typescript-language-server
        biome
        lua-language-server
        nil # nix
        nodePackages.intelephense
        python313Packages.python-lsp-server # pylsp
        ruby-lsp
        rust-analyzer
        nodePackages.bash-language-server
        sourcekit-lsp
        taplo
        vscode-langservers-extracted
        kotlin-language-server
        harper
      ];
      settings = {
        theme = "catppuccin_macchiato";
        editor = {
          line-number = "relative";
          mouse = true;
          rulers = [ 120 ];
          true-color = true;
          completion-replace = true;
          end-of-line-diagnostics = "hint";
          color-modes = true;
          # rainbow-brackets = true; enable next release
          inline-diagnostics.cursor-line = "warning";
          file-picker.hidden = false;
          indent-guides = {
            render = true;
            character = "╎";
            skip-levels = 0;
          };
          soft-wrap.enable = false;
          auto-save = {
            idle-timeout = 300000;
          };
          cursor-shape = {
            normal = "block";
            insert = "bar";
            select = "underline";
          };
          statusline = {
            left = [
              "mode"
              "spinner"
              "version-control"
              "spacer"
              "separator"
              "file-name"
              "read-only-indicator"
              "file-modification-indicator"
            ];
            center = [ ];
            right = [
              "diagnostics"
              "workspace-diagnostics"
              "position"
              "total-line-numbers"
              "position-percentage"
              "file-encoding"
              "file-line-ending"
              "file-type"
              "register"
              "selections"
            ];
            separator = "│";
          };
        };
      };
      languages = {
        language-server = {
          harper-ls = {
            command = "${pkgs.harper}/bin/harper-ls";
            args = [ "--stdio" ];
          };
          biome = {
            command = "${pkgs.biome}/bin/biome";
            args = [ "lsp-proxy" ];
          };
        };
        language = [
          {
            name = "c";
            language-servers = [
              "clangd"
              "harper-ls"
            ];
          }
          {
            name = "cmake";
            language-servers = [
              "neocmakelsp"
              "harper-ls"
            ];
          }
          {
            name = "cpp";
            language-servers = [
              "clangd"
              "harper-ls"
            ];
          }
          {
            name = "c-sharp";
            language-servers = [
              "OmniSharp"
              "harper-ls"
            ];
          }
          {
            name = "go";
            language-servers = [
              "gopls"
              "harper-ls"
            ];
          }
          {
            name = "java";
            language-servers = [
              "jdtls"
              "harper-ls"
            ];
          }
          {
            name = "javascript";
            language-servers = [
              {
                name = "typescript-language-server";
                except-features = [ "format" ];
              }
              "biome"
              "harper-ls"
            ];
            auto-format = true;
          }
          {
            name = "jsx";
            language-servers = [
              {
                name = "typescript-language-server";
                except-features = [ "format" ];
              }
              "biome"
              "harper-ls"
            ];
            auto-format = true;
          }
          {
            name = "lua";
            language-servers = [
              "lua-language-server"
              "harper-ls"
            ];
          }
          {
            name = "nix";
            language-servers = [
              "nil"
              "harper-ls"
            ];
          }
          {
            name = "php";
            language-servers = [
              "intelephense"
              "harper-ls"
            ];
          }
          {
            name = "python";
            language-servers = [
              "pylsp"
              "harper-ls"
            ];
          }
          {
            name = "ruby";
            language-servers = [
              "ruby-lsp"
              "harper-ls"
            ];
          }
          {
            name = "rust";
            language-servers = [
              "rust-analyzer"
              "harper-ls"
            ];
          }
          {
            name = "bash";
            language-servers = [
              "bash-language-server"
              "harper-ls"
            ];
          }
          {
            name = "swift";
            language-servers = [
              "sourcekit-lsp"
              "harper-ls"
            ];
          }
          {
            name = "toml";
            language-servers = [
              "taplo"
              "harper-ls"
            ];
          }
          {
            name = "typescript";
            language-servers = [
              {
                name = "typescript-language-server";
                except-features = [ "format" ];
              }
              "biome"
              "harper-ls"
            ];
            auto-format = true;
          }
          {
            name = "tsx";
            language-servers = [
              {
                name = "typescript-language-server";
                except-features = [ "format" ];
              }
              "biome"
              "harper-ls"
            ];
            auto-format = true;
          }
          {
            name = "json";
            language-servers = [
              {
                name = "vscode-json-language-server";
                except-features = [ "format" ];
              }
              "biome"
            ];
          }
          {
            name = "kotlin";
            language-servers = [
              "kotlin-language-server"
              "harper-ls"
            ];
          }
        ];
      };
    };
  };
}
