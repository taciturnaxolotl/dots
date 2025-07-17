{
  lib,
  ...
}:
{
  home.file.".config/crush/crush.json" = {
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
          model = "claude-3.7-sonnet";
          provider = "copilot";
        };
        small = {
          model = "gemini-2.0-flash-001";
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
              id = "claude-3.7-sonnet";
              model = "Copilot: Claude 3.7 Sonnet";
              cost_per_1m_in = 0;
              cost_per_1m_out = 0;
              cost_per_1m_in_cached = 0;
              cost_per_1m_out_cached = 0;
              context_window = 200000;
              default_max_tokens = 8000;
              can_reason = false;
              has_reasoning_efforts = false;
              supports_attachments = true;
            }
            {
              id = "o3-mini";
              model = "Copilot: o3-mini";
              cost_per_1m_in = 0;
              cost_per_1m_out = 0;
              cost_per_1m_in_cached = 0;
              cost_per_1m_out_cached = 0;
              context_window = 200000;
              default_max_tokens = 50000;
              can_reason = true;
              has_reasoning_efforts = false;
              supports_attachments = false;
            }
            {
              id = "gemini-2.0-flash-001";
              model = "Copilot: Gemini 2.0 Flash";
              cost_per_1m_in = 0;
              cost_per_1m_out = 0;
              cost_per_1m_in_cached = 0;
              cost_per_1m_out_cached = 0;
              context_window = 1000000;
              default_max_tokens = 8000;
              can_reason = false;
              has_reasoning_efforts = false;
              supports_attachments = true;
            }
          ];
        };
      };
    };
  };

  home.file.".config/crush/copilot.sh" = {
    source = ../dots/copilot.sh;
    executable = true;
  };
}
