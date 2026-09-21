{
  lib,
  config,
  pkgs,
  inputs,
  ...
}:
{
  options.atelier.apps.helix = {
    enable = lib.mkEnableOption "Enable helix config";
    swift = lib.mkEnableOption "Enable Swift support";
  };

  config = lib.mkIf config.atelier.apps.helix.enable {
    # Build the local tree-sitter grammars as nix derivations so helix doesn't
    # need `hx --grammar build` after every rebuild.
    xdg.configFile =
      let
        tree-sitter-cdl-grammar = pkgs.stdenv.mkDerivation {
          name = "tree-sitter-cdl";
          src = ../../../packages/tree-sitter-cdl;
          buildPhase = ''
            $CC -shared -fPIC -O2 -o cdl.so src/parser.c -I src
          '';
          installPhase = ''
            mkdir -p $out
            cp cdl.so $out/
          '';
        };

        # Objective-C++. Unlike cdl this one ships an external scanner, which
        # the inherited C++ grammar needs for raw string literals.
        tree-sitter-objcpp-grammar = pkgs.stdenv.mkDerivation {
          name = "tree-sitter-objcpp";
          src = ../../../packages/tree-sitter-objcpp;
          buildPhase = ''
            $CC -shared -fPIC -O2 -o objcpp.so src/parser.c src/scanner.c -I src
          '';
          installPhase = ''
            mkdir -p $out
            cp objcpp.so $out/
          '';
        };
      in
      {
        "helix/runtime/grammars/cdl.so".source = "${tree-sitter-cdl-grammar}/cdl.so";
        "helix/runtime/queries/cdl/highlights.scm".source =
          ../../../packages/tree-sitter-cdl/queries/highlights.scm;

        "helix/runtime/grammars/objcpp.so".source = "${tree-sitter-objcpp-grammar}/objcpp.so";
        "helix/runtime/queries/objcpp/highlights.scm".source =
          ../../../packages/tree-sitter-objcpp/queries/highlights.scm;
        "helix/runtime/queries/objcpp/indents.scm".source =
          ../../../packages/tree-sitter-objcpp/queries/indents.scm;
        "helix/runtime/queries/objcpp/injections.scm".source =
          ../../../packages/tree-sitter-objcpp/queries/injections.scm;
        "helix/runtime/queries/objcpp/locals.scm".source =
          ../../../packages/tree-sitter-objcpp/queries/locals.scm;
        "helix/runtime/queries/objcpp/textobjects.scm".source =
          ../../../packages/tree-sitter-objcpp/queries/textobjects.scm;
      };

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
        unstable.biome
        lua-language-server
        nil # nix
        intelephense
        python313Packages.python-lsp-server # pylsp
        ruby-lsp
        rust-analyzer
        bash-language-server
        svelte-language-server
        taplo
        vscode-langservers-extracted
        kotlin-language-server
        harper
        inputs.wakatime-ls.packages.${pkgs.stdenv.hostPlatform.system}.default
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
          inline-diagnostics.cursor-line = "warning";
          file-picker.hidden = false;
          indent-guides = {
            render = true;
            character = "╎";
            skip-levels = 0;
          };
          soft-wrap.enable = true;
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
            command = "${pkgs.unstable.biome}/bin/biome";
            args = [ "lsp-proxy" ];
          };
          wakatime = {
            command = "wakatime-ls";
          };
        };
        language = [
          {
            name = "c";
            language-servers = [
              "clangd"
              "harper-ls"
              "wakatime"
            ];
          }
          {
            name = "cmake";
            language-servers = [
              "neocmakelsp"
              "harper-ls"
              "wakatime"
            ];
          }
          {
            name = "cpp";
            language-servers = [
              "clangd"
              "harper-ls"
              "wakatime"
            ];
          }
          {
            name = "c-sharp";
            language-servers = [
              "OmniSharp"
              "harper-ls"
              "wakatime"
            ];
          }
          {
            name = "go";
            language-servers = [
              "gopls"
              "harper-ls"
              "wakatime"
            ];
          }
          {
            name = "java";
            language-servers = [
              "jdtls"
              "harper-ls"
              "wakatime"
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
              "wakatime"
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
              "wakatime"
            ];
            auto-format = true;
          }
          {
            name = "lua";
            language-servers = [
              "lua-language-server"
              "harper-ls"
              "wakatime"
            ];
          }
          {
            name = "nix";
            language-servers = [
              "nil"
              "harper-ls"
              "wakatime"
            ];
          }
          {
            name = "php";
            language-servers = [
              "intelephense"
              "harper-ls"
              "wakatime"
            ];
          }
          {
            name = "python";
            language-servers = [
              "pylsp"
              "harper-ls"
              "wakatime"
            ];
          }
          {
            name = "ruby";
            language-servers = [
              "ruby-lsp"
              "harper-ls"
              "wakatime"
            ];
          }
          {
            name = "rust";
            language-servers = [
              "rust-analyzer"
              "harper-ls"
              "wakatime"
            ];
          }
          {
            name = "bash";
            language-servers = [
              "bash-language-server"
              "harper-ls"
              "wakatime"
            ];
          }
          {
            name = "toml";
            language-servers = [
              "taplo"
              "harper-ls"
              "wakatime"
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
              "wakatime"
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
              "wakatime"
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
              "wakatime"
            ];
          }
          {
            name = "kotlin";
            language-servers = [
              "kotlin-language-server"
              "harper-ls"
              "wakatime"
            ];
          }
          {
            name = "markdown";
            file-types = [
              { glob = "*.md.tpl"; }
              { glob = "*.md"; }
            ];
            text-width = 120;
            soft-wrap.wrap-at-text-width = true;
          }
          {
            name = "latex";
            text-width = 120;
            soft-wrap.wrap-at-text-width = true;
          }
          {
            name = "svelte";
            language-servers = [
              "svelte-language-server"
              "harper-ls"
              "wakatime"
            ];
            auto-format = true;
          }
          {
            name = "cdl";
            scope = "source.cdl";
            file-types = [ "cdl" ];
            grammar = "cdl";
          }
          {
            # Helix resolves a file extension through a hash map keyed on the
            # extension, so the last language to claim one wins. Upstream gives
            # `.m` to matlab and `.mm` to metamath, which would otherwise race
            # objcpp for both depending on merge order. Dropping their claims
            # settles it. Both languages remain available through
            # `:set-language`; only auto-detection changes.
            # `scope` is mandatory on every entry, including an override, or
            # helix rejects the whole user language config.
            name = "matlab";
            scope = "source.m";
            file-types = [ ];
          }
          {
            name = "metamath";
            scope = "source.mm";
            file-types = [ ];
          }
          {
            # Objective-C++. `.h` is deliberately left to c/cpp: an Objective-C
            # project's headers end in .h, but so does every C project's, and
            # claiming it here would mis-highlight far more files than it fixed.
            name = "objcpp";
            scope = "source.objcpp";
            file-types = [
              "mm"
              "m"
            ];
            grammar = "objcpp";
            comment-token = "//";
            block-comment-tokens = {
              start = "/*";
              end = "*/";
            };
            indent = {
              tab-width = 4;
              unit = "    ";
            };
            language-servers = [
              "clangd"
              "harper-ls"
              "wakatime"
            ];
          }
        ]
        ++ lib.optionals config.atelier.apps.helix.swift [
          {
            name = "swift";
            language-servers = [
              "sourcekit-lsp"
              "harper-ls"
              "wakatime"
            ];
          }
        ];
      };
    };
  };
}
