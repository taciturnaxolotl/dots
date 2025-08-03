{
  lib,
  config,
  inputs,
  ...
}:
{
  imports = [
    inputs.crush.homeManagerModules.default
  ];

  options.dots.apps.crush.enable = lib.mkEnableOption "Enable Crush config";
  config = lib.mkIf config.dots.apps.crush.enable {
    programs.crush = {
      enable = true;
      settings = {
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
            type = "openai";
            base_url = "https://api.githubcopilot.com";
            api_key = "$(bash ~/.config/crush/copilot.sh)";
            extra_headers = {
              "Editor-Version" = "CRUSH/1.0";
              "Editor-Plugin-Version" = "CRUSH/1.0";
              "Copilot-Integration-Id" = "vscode-chat";
            };
            models = [
              {
                id = "gpt-4.1";
                model = "Copilot: GPT 4.1";
                cost_per_1m_in = 0;
                cost_per_1m_out = 0;
                cost_per_1m_in_cached = 0;
                cost_per_1m_out_cached = 0;
                context_window = 128000;
                default_max_tokens = 30000;
                can_reason = false;
                has_reasoning_efforts = false;
                supports_attachments = false;
              }
              {
                id = "gpt-4o";
                model = "Copilot: GPT 4o";
                cost_per_1m_in = 0;
                cost_per_1m_out = 0;
                cost_per_1m_in_cached = 0;
                cost_per_1m_out_cached = 0;
                context_window = 128000;
                default_max_tokens = 32000;
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
              {
                id = "gemini-2.5-pro";
                model = "Gemini 2.5 Pro";
                cost_per_1m_in = 0;
                cost_per_1m_out = 0;
                cost_per_1m_in_cached = 0;
                cost_per_1m_out_cached = 0;
                context_window = 100000;
                default_max_tokens = 30000;
                can_reason = true;
                has_reasoning_efforts = false;
                supports_attachments = true;
              }
            ];
          };
          claude-pro = {
            name = "Claude Pro";
            type = "anthropic";
            base_url = "https://api.anthropic.com/v1";
            api_key = "Bearer $(bunx anthropic-api-key)";
            extra_headers = {
              "anthropic-version" = "2023-06-01";
              "anthropic-beta" = "oauth-2025-04-20";
            };
            models = [
              {
                id = "claude-opus-4-20250514";
                model = "Claude Opus 4";
                cost_per_1m_in = 15000;
                cost_per_1m_out = 75000;
                cost_per_1m_in_cached = 1125;
                cost_per_1m_out_cached = 75000;
                context_window = 200000;
                default_max_tokens = 50000;
                can_reason = true;
                has_reasoning_efforts = true;
                supports_attachments = true;
              }
              {
                id = "claude-sonnet-4-20250514";
                model = "Claude Sonnet 4";
                cost_per_1m_in = 3000;
                cost_per_1m_out = 15000;
                cost_per_1m_in_cached = 225;
                cost_per_1m_out_cached = 15000;
                context_window = 200000;
                default_max_tokens = 50000;
                can_reason = true;
                has_reasoning_efforts = false;
                supports_attachments = true;
              }
              {
                id = "claude-3-7-sonnet-20250219";
                model = "Claude 3.7 Sonnet";
                cost_per_1m_in = 2500;
                cost_per_1m_out = 12000;
                cost_per_1m_in_cached = 187;
                cost_per_1m_out_cached = 12000;
                context_window = 200000;
                default_max_tokens = 128000;
                can_reason = true;
                has_reasoning_efforts = false;
                supports_attachments = true;
              }
              {
                id = "claude-3-5-sonnet-20241022";
                model = "Claude 3.5 Sonnet (Latest)";
                cost_per_1m_in = 3000;
                cost_per_1m_out = 15000;
                cost_per_1m_in_cached = 225;
                cost_per_1m_out_cached = 15000;
                context_window = 200000;
                default_max_tokens = 8192;
                can_reason = false;
                has_reasoning_efforts = false;
                supports_attachments = true;
              }
              {
                id = "claude-3-5-haiku-20241022";
                model = "Claude 3.5 Haiku";
                cost_per_1m_in = 800;
                cost_per_1m_out = 4000;
                cost_per_1m_in_cached = 60;
                cost_per_1m_out_cached = 4000;
                context_window = 200000;
                default_max_tokens = 8192;
                can_reason = false;
                has_reasoning_efforts = false;
                supports_attachments = true;
              }
            ];
          };
        };
      };
    };

    xdg.configFile."crush/copilot.sh".source = ../../dots/copilot.sh;
    xdg.configFile."crush/anthropic.sh".source = ../../dots/anthropic.sh;
  };
}
