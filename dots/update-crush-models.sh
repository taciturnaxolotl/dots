#!/usr/bin/env bash

set -euo pipefail

# Configuration
COPILOT_TOKEN=$(bash ~/.config/crush/copilot.sh)
ANTHROPIC_TOKEN=$(bunx anthropic-api-key)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}Fetching latest models from APIs...${NC}"

# Fetch Copilot models
echo "  → Fetching Copilot models..."
COPILOT_MODELS=$(curl -s https://api.githubcopilot.com/models \
  -H "Authorization: Bearer $COPILOT_TOKEN" \
  -H "Editor-Version: CRUSH/1.0" \
  -H "Editor-Plugin-Version: CRUSH/1.0" \
  -H "Copilot-Integration-Id: vscode-chat")

# Fetch Anthropic models
echo "  → Fetching Anthropic models..."
ANTHROPIC_MODELS=$(curl -s https://api.anthropic.com/v1/models \
  -H "Authorization: Bearer $ANTHROPIC_TOKEN" \
  -H "anthropic-version: 2023-06-01" \
  -H "anthropic-beta: oauth-2025-04-20")

# Extract model-picker enabled Copilot models
echo -e "\n${GREEN}Copilot models (model_picker_enabled):${NC}"
echo "$COPILOT_MODELS" | jq -r '.data[] | select(.model_picker_enabled == true) | "  ✓ \(.id) - \(.name)"'

# Extract all Anthropic models
echo -e "\n${GREEN}Anthropic models:${NC}"
echo "$ANTHROPIC_MODELS" | jq -r '.data[] | "  ✓ \(.id) - \(.display_name)"'

# Generate Copilot models Nix config
generate_copilot_models() {
  echo "$COPILOT_MODELS" | jq -r '.data[] | select(.model_picker_enabled == true) |
    (if .capabilities.supports.tool_calls then true else false end) as $can_reason |
    (if .capabilities.supports.vision then true else false end) as $supports_attachments |
    "              {\n" +
    "                id = \"\(.id)\";\n" +
    "                name = \"Copilot: \(.name)\";\n" +
    "                cost_per_1m_in = 0;\n" +
    "                cost_per_1m_out = 0;\n" +
    "                cost_per_1m_in_cached = 0;\n" +
    "                cost_per_1m_out_cached = 0;\n" +
    "                context_window = \(.capabilities.limits.max_context_window_tokens);\n" +
    "                default_max_tokens = \(.capabilities.limits.max_output_tokens);\n" +
    "                can_reason = \($can_reason);\n" +
    "                has_reasoning_efforts = false;\n" +
    "                supports_attachments = \($supports_attachments);\n" +
    "              }"'
}

# Generate Anthropic models Nix config with pricing
generate_anthropic_models() {
  echo "$ANTHROPIC_MODELS" | jq -r '.data[] |
    # Determine pricing based on model family
    (if (.id | contains("opus-4")) then
      {in: 15.0, out: 75.0, in_cached: 1.5, out_cached: 75.0}
    elif (.id | contains("sonnet-4")) then
      {in: 3.0, out: 15.0, in_cached: 0.225, out_cached: 15.0}
    elif (.id | contains("3-7-sonnet")) then
      {in: 2.5, out: 12.0, in_cached: 0.187, out_cached: 12.0}
    elif (.id | contains("3-5-sonnet")) then
      {in: 3.0, out: 15.0, in_cached: 0.225, out_cached: 15.0}
    elif (.id | contains("3-5-haiku")) then
      {in: 0.8, out: 4.0, in_cached: 0.06, out_cached: 4.0}
    elif (.id | contains("3-haiku")) then
      {in: 0.25, out: 1.25, in_cached: 0.03, out_cached: 1.25}
    elif (.id | contains("3-opus")) then
      {in: 15.0, out: 75.0, in_cached: 1.5, out_cached: 75.0}
    else
      {in: 3.0, out: 15.0, in_cached: 0.225, out_cached: 15.0}
    end) as $pricing |

    # Determine context window and max tokens
    (if (.id | test("claude-sonnet-4-5"))
      then {context: 200000, max_tokens: 64000}
    elif (.id | test("claude-sonnet-4-"))
      then {context: 200000, max_tokens: 64000}
    elif (.id | test("claude-3-7-sonnet"))
      then {context: 200000, max_tokens: 64000}
    elif (.id | test("claude-opus-4-1"))
      then {context: 200000, max_tokens: 32000}
    elif (.id | test("claude-opus-4-"))
      then {context: 200000, max_tokens: 32000}
    elif (.id | test("claude-3-5-haiku"))
      then {context: 200000, max_tokens: 8192}
    elif (.id | test("claude-3-haiku"))
      then {context: 200000, max_tokens: 4096}
    else
      {context: 200000, max_tokens: 8192}
    end) as $limits |

    # Determine has_reasoning_efforts
    (if (.id | contains("opus-4")) then true else false end) as $has_reasoning |

    "              {\n" +
    "                id = \"\(.id)\";\n" +
    "                name = \"\(.display_name)\";\n" +
    "                cost_per_1m_in = \($pricing.in);\n" +
    "                cost_per_1m_out = \($pricing.out);\n" +
    "                cost_per_1m_in_cached = \($pricing.in_cached);\n" +
    "                cost_per_1m_out_cached = \($pricing.out_cached);\n" +
    "                context_window = \($limits.context);\n" +
    "                default_max_tokens = \($limits.max_tokens);\n" +
    "                can_reason = true;\n" +
    "                has_reasoning_efforts = \($has_reasoning);\n" +
    "                supports_attachments = true;\n" +
    "              }"'
}

# Generate formatted model arrays
COPILOT_MODELS_NIX=$(generate_copilot_models)
ANTHROPIC_MODELS_NIX=$(generate_anthropic_models)

# Output results
echo -e "\n${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}COPILOT MODELS${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "\nPaste this into your copilot.models array:\n"
echo "            models = ["
echo "$COPILOT_MODELS_NIX"
echo "            ];"

echo -e "\n${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}ANTHROPIC MODELS${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "\nPaste this into your claude-pro.models array:\n"
echo "            models = ["
echo "$ANTHROPIC_MODELS_NIX"
echo "            ];"

echo -e "\n${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "\n${GREEN}Summary:${NC}"
echo "  • Copilot models: $(echo "$COPILOT_MODELS" | jq '[.data[] | select(.model_picker_enabled == true)] | length')"
echo "  • Anthropic models: $(echo "$ANTHROPIC_MODELS" | jq '.data | length')"
