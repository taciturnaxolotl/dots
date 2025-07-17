{
  lib,
  ...
}:
{
  home.file.".config/crush/config.json" = {
    text = lib.strings.toJSON {
      lsp = {
        go = {
          command = "gopls";
        };
        typescript = {
          command = "typescript-language-server";
          args = [ "--stdio" ];
        };
        nix = {
          command = "nil";
        };
      };
      mcp = {
        context7 = {
          url = "https://mcp.context7.com/mcp";
          type = "http";
        };
        sequential-thinking = {
          command = "bunx";
          args = [
            "-y"
            "@modelcontextprotocol/server-sequential-thinking"
          ];
        };
      };
      models = {
        large = {
          model = "claude-sonnet-4";
          provider = "copilot";
        };
        small = {
          model = "gpt-4o-mini";
          provider = "copilot";
        };
      };
      providers = {
        copilot = {
          name = "Copilot";
          provider_type = "openai";
          base_url = "https://api.githubcopilot.com";
          api_key = "$(bash ~/.config/crush/copilot.sh)";
          extra_headers = {
            "Editor-Version" = "CRUSH/1.0";
            "Editor-Plugin-Version" = "CRUSH/1.0";
            "Copilot-Integration-Id" = "vscode-chat";
          };
          models = [
            {
              id = "gpt-4o-mini";
              model = "Copilot: GPT 4o Mini";
              cost_per_1m_in = 0;
              cost_per_1m_out = 0;
              cost_per_1m_in_cached = 0;
              cost_per_1m_out_cached = 0;
              context_window = 128000;
              default_max_tokens = 2000;
              can_reason = false;
              has_reasoning_efforts = false;
              supports_attachments = false;
            }
            {
              id = "claude-sonnet-4";
              model = "Copilot: Claude Sonnet 4";
              cost_per_1m_in = 0;
              cost_per_1m_out = 0;
              cost_per_1m_in_cached = 0;
              cost_per_1m_out_cached = 0;
              context_window = 200000;
              default_max_tokens = 50000;
              can_reason = true;
              has_reasoning_efforts = false;
              supports_attachments = true;
            }
          ];
        };
      };
    };
  };

  home.file.".config/crush/copilot.sh".source = ../dots/copilot.sh;
}
