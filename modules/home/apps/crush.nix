{
  lib,
  config,
  ...
}:
{
  options.atelier.apps.crush.enable = lib.mkEnableOption "Enable Crush config";
  config = lib.mkIf config.atelier.apps.crush.enable {
    programs.crush = {
      enable = true;
      settings = {
        mcp = {
          context7 = {
            type = "sse";
            url = "https://mcp.context7.com/sse";
          };
          sequential-thinking = {
            command = "bunx";
            args = [
              "-y"
              "@modelcontextprotocol/server-sequential-thinking"
            ];
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
                name = "Copilot: GPT-4.1";
                cost_per_1m_in = 0;
                cost_per_1m_out = 0;
                cost_per_1m_in_cached = 0;
                cost_per_1m_out_cached = 0;
                context_window = 128000;
                default_max_tokens = 16384;
                can_reason = true;
                has_reasoning_efforts = false;
                supports_attachments = true;
              }
              {
                id = "gpt-5-mini";
                name = "Copilot: GPT-5 mini";
                cost_per_1m_in = 0;
                cost_per_1m_out = 0;
                cost_per_1m_in_cached = 0;
                cost_per_1m_out_cached = 0;
                context_window = 264000;
                default_max_tokens = 64000;
                can_reason = true;
                has_reasoning_efforts = false;
                supports_attachments = true;
              }
              {
                id = "gpt-5";
                name = "Copilot: GPT-5";
                cost_per_1m_in = 0;
                cost_per_1m_out = 0;
                cost_per_1m_in_cached = 0;
                cost_per_1m_out_cached = 0;
                context_window = 264000;
                default_max_tokens = 64000;
                can_reason = true;
                has_reasoning_efforts = false;
                supports_attachments = true;
              }
              {
                id = "gpt-4o";
                name = "Copilot: GPT-4o";
                cost_per_1m_in = 0;
                cost_per_1m_out = 0;
                cost_per_1m_in_cached = 0;
                cost_per_1m_out_cached = 0;
                context_window = 128000;
                default_max_tokens = 4096;
                can_reason = true;
                has_reasoning_efforts = false;
                supports_attachments = true;
              }
              {
                id = "o3-mini";
                name = "Copilot: o3-mini";
                cost_per_1m_in = 0;
                cost_per_1m_out = 0;
                cost_per_1m_in_cached = 0;
                cost_per_1m_out_cached = 0;
                context_window = 200000;
                default_max_tokens = 100000;
                can_reason = true;
                has_reasoning_efforts = false;
                supports_attachments = false;
              }
              {
                id = "grok-code-fast-1";
                name = "Copilot: Grok Code Fast 1 (Preview)";
                cost_per_1m_in = 0;
                cost_per_1m_out = 0;
                cost_per_1m_in_cached = 0;
                cost_per_1m_out_cached = 0;
                context_window = 128000;
                default_max_tokens = 64000;
                can_reason = true;
                has_reasoning_efforts = false;
                supports_attachments = false;
              }
              {
                id = "gpt-5-codex";
                name = "Copilot: GPT-5-Codex (Preview)";
                cost_per_1m_in = 0;
                cost_per_1m_out = 0;
                cost_per_1m_in_cached = 0;
                cost_per_1m_out_cached = 0;
                context_window = 200000;
                default_max_tokens = 64000;
                can_reason = true;
                has_reasoning_efforts = false;
                supports_attachments = true;
              }
              {
                id = "claude-3.5-sonnet";
                name = "Copilot: Claude Sonnet 3.5";
                cost_per_1m_in = 0;
                cost_per_1m_out = 0;
                cost_per_1m_in_cached = 0;
                cost_per_1m_out_cached = 0;
                context_window = 90000;
                default_max_tokens = 8192;
                can_reason = true;
                has_reasoning_efforts = false;
                supports_attachments = true;
              }
              {
                id = "claude-3.7-sonnet";
                name = "Copilot: Claude Sonnet 3.7";
                cost_per_1m_in = 0;
                cost_per_1m_out = 0;
                cost_per_1m_in_cached = 0;
                cost_per_1m_out_cached = 0;
                context_window = 200000;
                default_max_tokens = 16384;
                can_reason = true;
                has_reasoning_efforts = false;
                supports_attachments = true;
              }
              {
                id = "claude-3.7-sonnet-thought";
                name = "Copilot: Claude Sonnet 3.7 Thinking";
                cost_per_1m_in = 0;
                cost_per_1m_out = 0;
                cost_per_1m_in_cached = 0;
                cost_per_1m_out_cached = 0;
                context_window = 200000;
                default_max_tokens = 16384;
                can_reason = false;
                has_reasoning_efforts = false;
                supports_attachments = true;
              }
              {
                id = "claude-sonnet-4";
                name = "Copilot: Claude Sonnet 4";
                cost_per_1m_in = 0;
                cost_per_1m_out = 0;
                cost_per_1m_in_cached = 0;
                cost_per_1m_out_cached = 0;
                context_window = 216000;
                default_max_tokens = 16000;
                can_reason = true;
                has_reasoning_efforts = false;
                supports_attachments = true;
              }
              {
                id = "claude-sonnet-4.5";
                name = "Copilot: Claude Sonnet 4.5 (Preview)";
                cost_per_1m_in = 0;
                cost_per_1m_out = 0;
                cost_per_1m_in_cached = 0;
                cost_per_1m_out_cached = 0;
                context_window = 144000;
                default_max_tokens = 16000;
                can_reason = true;
                has_reasoning_efforts = false;
                supports_attachments = true;
              }
              {
                id = "gemini-2.0-flash-001";
                name = "Copilot: Gemini 2.0 Flash";
                cost_per_1m_in = 0;
                cost_per_1m_out = 0;
                cost_per_1m_in_cached = 0;
                cost_per_1m_out_cached = 0;
                context_window = 1000000;
                default_max_tokens = 8192;
                can_reason = false;
                has_reasoning_efforts = false;
                supports_attachments = true;
              }
              {
                id = "gemini-2.5-pro";
                name = "Copilot: Gemini 2.5 Pro";
                cost_per_1m_in = 0;
                cost_per_1m_out = 0;
                cost_per_1m_in_cached = 0;
                cost_per_1m_out_cached = 0;
                context_window = 128000;
                default_max_tokens = 64000;
                can_reason = true;
                has_reasoning_efforts = false;
                supports_attachments = true;
              }
              {
                id = "o4-mini";
                name = "Copilot: o4-mini (Preview)";
                cost_per_1m_in = 0;
                cost_per_1m_out = 0;
                cost_per_1m_in_cached = 0;
                cost_per_1m_out_cached = 0;
                context_window = 128000;
                default_max_tokens = 16384;
                can_reason = true;
                has_reasoning_efforts = false;
                supports_attachments = true;
              }
            ];
          };
          hyper = {
            name = "Charm Hyper";
            base_url = "https://hyper.charm.sh/api/v1/openai/";
            api_key = "$(cat /run/agenix/crush)";
            type = "openai";
            models = [
              {
                name = "Qwen 3 Coder";
                id = "qwen3_coder";
                context_window = 118000;
                default_max_tokens = 20000;
              }
            ];
          };
          claude-pro = {
            name = "Claude Pro";
            type = "anthropic";
            base_url = "https://api.anthropic.com";
            api_key = "Bearer $(bunx anthropic-api-key)";
            system_prompt_prefix = "You are Claude Code, Anthropic's official CLI for Claude.";
            extra_headers = {
              "anthropic-version" = "2023-06-01";
              "anthropic-beta" = "oauth-2025-04-20";
            };
            models = [
              {
                id = "claude-sonnet-4-5-20250929";
                name = "Claude Sonnet 4.5";
                cost_per_1m_in = 3.0;
                cost_per_1m_out = 15.0;
                cost_per_1m_in_cached = 0.225;
                cost_per_1m_out_cached = 15.0;
                context_window = 200000;
                default_max_tokens = 50000;
                can_reason = true;
                has_reasoning_efforts = false;
                supports_attachments = true;
              }
              {
                id = "claude-opus-4-1-20250805";
                name = "Claude Opus 4.1";
                cost_per_1m_in = 15.0;
                cost_per_1m_out = 75.0;
                cost_per_1m_in_cached = 1.5;
                cost_per_1m_out_cached = 75.0;
                context_window = 200000;
                default_max_tokens = 32000;
                can_reason = true;
                has_reasoning_efforts = true;
                supports_attachments = true;
              }
              {
                id = "claude-opus-4-20250514";
                name = "Claude Opus 4";
                cost_per_1m_in = 15.0;
                cost_per_1m_out = 75.0;
                cost_per_1m_in_cached = 1.5;
                cost_per_1m_out_cached = 75.0;
                context_window = 200000;
                default_max_tokens = 32000;
                can_reason = true;
                has_reasoning_efforts = true;
                supports_attachments = true;
              }
              {
                id = "claude-sonnet-4-20250514";
                name = "Claude Sonnet 4";
                cost_per_1m_in = 3.0;
                cost_per_1m_out = 15.0;
                cost_per_1m_in_cached = 0.225;
                cost_per_1m_out_cached = 15.0;
                context_window = 200000;
                default_max_tokens = 50000;
                can_reason = true;
                has_reasoning_efforts = false;
                supports_attachments = true;
              }
              {
                id = "claude-3-7-sonnet-20250219";
                name = "Claude Sonnet 3.7";
                cost_per_1m_in = 2.5;
                cost_per_1m_out = 12.0;
                cost_per_1m_in_cached = 0.187;
                cost_per_1m_out_cached = 12.0;
                context_window = 200000;
                default_max_tokens = 50000;
                can_reason = true;
                has_reasoning_efforts = false;
                supports_attachments = true;
              }
              {
                id = "claude-3-5-sonnet-20241022";
                name = "Claude Sonnet 3.5 (New)";
                cost_per_1m_in = 3.0;
                cost_per_1m_out = 15.0;
                cost_per_1m_in_cached = 0.225;
                cost_per_1m_out_cached = 15.0;
                context_window = 200000;
                default_max_tokens = 8192;
                can_reason = true;
                has_reasoning_efforts = false;
                supports_attachments = true;
              }
              {
                id = "claude-3-5-haiku-20241022";
                name = "Claude Haiku 3.5";
                cost_per_1m_in = 0.8;
                cost_per_1m_out = 4.0;
                cost_per_1m_in_cached = 0.06;
                cost_per_1m_out_cached = 4.0;
                context_window = 200000;
                default_max_tokens = 8192;
                can_reason = true;
                has_reasoning_efforts = false;
                supports_attachments = true;
              }
              {
                id = "claude-3-5-sonnet-20240620";
                name = "Claude Sonnet 3.5 (Old)";
                cost_per_1m_in = 3.0;
                cost_per_1m_out = 15.0;
                cost_per_1m_in_cached = 0.225;
                cost_per_1m_out_cached = 15.0;
                context_window = 200000;
                default_max_tokens = 8192;
                can_reason = true;
                has_reasoning_efforts = false;
                supports_attachments = true;
              }
              {
                id = "claude-3-haiku-20240307";
                name = "Claude Haiku 3";
                cost_per_1m_in = 0.25;
                cost_per_1m_out = 1.25;
                cost_per_1m_in_cached = 0.03;
                cost_per_1m_out_cached = 1.25;
                context_window = 200000;
                default_max_tokens = 4096;
                can_reason = true;
                has_reasoning_efforts = false;
                supports_attachments = true;
              }
              {
                id = "claude-3-opus-20240229";
                name = "Claude Opus 3";
                cost_per_1m_in = 15.0;
                cost_per_1m_out = 75.0;
                cost_per_1m_in_cached = 1.5;
                cost_per_1m_out_cached = 75.0;
                context_window = 200000;
                default_max_tokens = 4096;
                can_reason = true;
                has_reasoning_efforts = false;
                supports_attachments = true;
              }
            ];
          };
        };
      };
    };

    xdg.configFile."crush/copilot.sh".source = ../../../dots/copilot.sh;
  };
}
