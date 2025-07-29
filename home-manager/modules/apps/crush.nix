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
        };
      };
    };

    xdg.configFile."crush/copilot.sh".source = ../../dots/copilot.sh;
    xdg.configFile."crush/anthropic.sh".source = ../../dots/anthropic.sh;
  };
}
