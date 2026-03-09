# Triage Agent - AI-powered service triage webhook
#
# Receives webhook calls when a service goes down, runs Claude
# to analyze logs, and posts a triage report back via callback.
# Requires claude-code to be available on PATH.

{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.atelier.services.triage-agent;

  triageFilterScript = pkgs.writeShellScriptBin "triage-filter" ''
    SERVICE="$1"

    echo "---SYSTEMD STATUS---"
    ${pkgs.systemd}/bin/systemctl status "''${SERVICE}.service" --no-pager 2>&1 || true

    echo ""
    echo "---RECENT LOGS (last 15 min, last 150 lines)---"
    ${pkgs.systemd}/bin/journalctl -u "''${SERVICE}.service" --since "15 minutes ago" --no-pager -o short-iso \
      | ${pkgs.coreutils}/bin/tail -150
  '';

  triageRunScript = pkgs.writeShellScriptBin "run-triage" ''
    set -euo pipefail

    SERVICE_NAME="$1"
    INCIDENT_ID="$2"
    CALLBACK_URL="$3"

    echo "[triage] Starting triage for service=$SERVICE_NAME incident=$INCIDENT_ID"

    # Collect filtered logs
    FILTERED_LOGS=$(${triageFilterScript}/bin/triage-filter "$SERVICE_NAME" 2>&1 || true)

    if [ -z "$FILTERED_LOGS" ]; then
      FILTERED_LOGS="No relevant log lines found in the last 10 minutes."
    fi

    LOG_LINES=$(echo "$FILTERED_LOGS" | ${pkgs.coreutils}/bin/wc -l)
    echo "[triage] Log collection done: $LOG_LINES lines"

    # Run Claude headless for triage
    export HOME="/var/lib/triage-agent"
    echo "[triage] Invoking Claude for analysis..."
    RAW_OUTPUT=$(${cfg.claudePath} -p \
      --model sonnet \
      --max-turns 10 \
      --allowedTools "Bash(journalctl:*) Bash(systemctl:*) Bash(curl:*) Bash(ss:*) Bash(df:*) Bash(free:*) Bash(ps:*) Bash(cat:/etc/*) Bash(ls:*) Bash(stat:*)" \
      "You are a service triage agent investigating why a service is down. You have access to tools for deeper investigation.

Your output MUST follow this exact format:
SUMMARY: <one sentence describing the root cause>
---
<full triage report in markdown, max 500 words, with: 1) What failed 2) Likely root cause 3) Suggested fix>

The SUMMARY line must be a single sentence. Do not speculate beyond what the evidence shows.

Service '$SERVICE_NAME' is down. Here are the filtered logs from the last 10 minutes:

$FILTERED_LOGS

Investigate further if the logs aren't conclusive — check disk space, memory, open ports, config files, or related service logs. Then write your response in the format above." 2>&1 || echo "SUMMARY: Triage agent failed to produce a report.
---
Triage agent failed to produce a report.")

    echo "[triage] Report generated: ''${#RAW_OUTPUT} chars"

    # Split output into summary and full report
    SUMMARY=$(echo "$RAW_OUTPUT" | ${pkgs.gnused}/bin/sed -n 's/^SUMMARY: //p' | ${pkgs.coreutils}/bin/head -1)
    REPORT=$(echo "$RAW_OUTPUT" | ${pkgs.gnused}/bin/sed '1,/^---$/d')

    # Fallback if parsing fails
    if [ -z "$SUMMARY" ]; then
      SUMMARY="Triage completed for $SERVICE_NAME"
    fi
    if [ -z "$REPORT" ]; then
      REPORT="$RAW_OUTPUT"
    fi

    # Callback to status worker
    echo "[triage] Posting report to $CALLBACK_URL"
    CALLBACK_RESULT=$(${pkgs.curl}/bin/curl -sf -X PATCH "$CALLBACK_URL" \
      -H "Authorization: Bearer $TRIAGE_AUTH_TOKEN" \
      -H "Content-Type: application/json" \
      -d "$(${pkgs.jq}/bin/jq -n --arg report "$REPORT" --arg summary "$SUMMARY" '{triage_report: $report, status: "identified", summary: $summary}')" \
      -w "%{http_code}" -o /dev/null \
      || echo "FAILED")
    echo "[triage] Callback result: $CALLBACK_RESULT"
  '';

  webhookServer = pkgs.writeText "triage-webhook.ts" ''
    const TRIAGE_AUTH_TOKEN = process.env.TRIAGE_AUTH_TOKEN ?? "";
    const PORT = parseInt(process.env.PORT ?? "3200");

    Bun.serve({
      port: PORT,
      async fetch(req) {
        const url = new URL(req.url);

        if (req.method === "GET" && url.pathname === "/health") {
          return Response.json({ status: "ok" });
        }

        if (req.method !== "POST") {
          return new Response("method not allowed", { status: 405 });
        }

        const auth = req.headers.get("authorization");
        if (auth !== `Bearer ''${TRIAGE_AUTH_TOKEN}`) {
          return new Response("unauthorized", { status: 401 });
        }

        const body = await req.json() as {
          incident_id: number;
          service_id: string;
          service_name: string;
          health_url: string;
          callback_url: string;
        };

        if (!body.service_id || !body.incident_id || !body.callback_url) {
          return new Response("missing fields", { status: 400 });
        }

        console.log(`[webhook] Received triage request: service=''${body.service_name} incident=''${body.incident_id}`);

        // Spawn triage in background and respond immediately
        Bun.spawn(["${triageRunScript}/bin/run-triage", body.service_name, String(body.incident_id), body.callback_url], {
          env: { ...process.env },
          stdout: "inherit",
          stderr: "inherit",
        });

        return new Response(JSON.stringify({ ok: true, incident_id: body.incident_id }), {
          status: 202,
          headers: { "Content-Type": "application/json" },
        });
      },
    });

    console.log(`Triage webhook listening on port ''${PORT}`);
  '';
in
{
  options.atelier.services.triage-agent = {
    enable = lib.mkEnableOption "triage agent webhook service";

    port = lib.mkOption {
      type = lib.types.port;
      default = 3200;
      description = "Port for the triage webhook server";
    };

    domain = lib.mkOption {
      type = lib.types.str;
      default = "triage.dunkirk.sh";
      description = "Domain for the triage webhook endpoint";
    };

    secretsFile = lib.mkOption {
      type = lib.types.path;
      description = "Path to environment file containing TRIAGE_AUTH_TOKEN and CLAUDE_CODE_OAUTH_TOKEN";
    };

    claudePath = lib.mkOption {
      type = lib.types.str;
      default = "claude";
      description = "Path to the claude-code CLI binary";
    };
  };

  config = lib.mkIf cfg.enable {
    services.caddy.virtualHosts.${cfg.domain} = {
      extraConfig = ''
        tls {
          dns cloudflare {env.CLOUDFLARE_API_TOKEN}
        }
        reverse_proxy localhost:${toString cfg.port}
      '';
    };

    users.users.triage-agent = {
      isSystemUser = true;
      group = "triage-agent";
      extraGroups = [ "systemd-journal" ];
    };
    users.groups.triage-agent = {};

    systemd.services.triage-agent = {
      description = "Triage Agent Webhook Service";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];

      environment = {
        PORT = toString cfg.port;
        HOME = "/var/lib/triage-agent";
      };

      path = [
        pkgs.systemd
        pkgs.coreutils
        pkgs.gnugrep
        pkgs.gnused
        pkgs.curl
        pkgs.jq
        pkgs.nodejs_22
      ];

      preStart = ''
        # Install claude-code if not present
        if ! command -v claude &>/dev/null && [ "${cfg.claudePath}" = "claude" ]; then
          ${pkgs.nodejs_22}/bin/npm install -g @anthropic-ai/claude-code --prefix /var/lib/triage-agent/.npm-global 2>/dev/null || true
        fi
      '';

      serviceConfig = {
        Type = "exec";
        User = "triage-agent";
        Group = "triage-agent";
        ExecStart = "${pkgs.unstable.bun}/bin/bun run ${webhookServer}";
        EnvironmentFile = cfg.secretsFile;
        Environment = [
          "PATH=/var/lib/triage-agent/.npm-global/bin:${lib.makeBinPath [ pkgs.systemd pkgs.coreutils pkgs.gnugrep pkgs.gnused pkgs.curl pkgs.jq pkgs.nodejs_22 ]}"
        ];
        Restart = "on-failure";
        RestartSec = "10s";

        StateDirectory = "triage-agent";
        WorkingDirectory = "/var/lib/triage-agent";

        # Security hardening
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        ReadWritePaths = [ "/var/lib/triage-agent" ];
      };
    };
  };
}
