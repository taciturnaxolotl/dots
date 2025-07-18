#!/bin/sh

# Anthropic OAuth client ID
CLIENT_ID="9d1c250a-e61b-44d9-88ed-5944d1962f5e"

# Token cache file location
CACHE_DIR="${HOME}/.config/crush/anthropic"
CACHE_FILE="${CACHE_DIR}/bearer_token"
REFRESH_TOKEN_FILE="${CACHE_DIR}/refresh_token"

# Function to extract expiration from cached token file
extract_expiration() {
  if [ -f "${CACHE_FILE}.expires" ]; then
    cat "${CACHE_FILE}.expires"
  fi
}

# Function to check if token is valid
is_token_valid() {
  local expires="$1"

  if [ -z "$expires" ]; then
    return 1
  fi

  local current_time=$(date +%s)
  # Add 60 second buffer before expiration
  local buffer_time=$((expires - 60))

  if [ "$current_time" -lt "$buffer_time" ]; then
    return 0
  else
    return 1
  fi
}

# Function to generate PKCE challenge (requires openssl)
generate_pkce() {
  # Generate 32 random bytes, base64url encode
  local verifier=$(openssl rand -base64 32 | tr -d "=" | tr "/" "_" | tr "+" "-" | tr -d "\n")
  # Create SHA256 hash of verifier, base64url encode
  local challenge=$(printf '%s' "$verifier" | openssl dgst -sha256 -binary | openssl base64 | tr -d "=" | tr "/" "_" | tr "+" "-" | tr -d "\n")

  echo "$verifier|$challenge"
}

# Function to exchange refresh token for new access token
exchange_refresh_token() {
  local refresh_token="$1"

  [ -n "$DEBUG" ] && echo "Using refresh token: ${refresh_token:0:20}..." >&2
  local bearer_response=$(curl -s -X POST "https://console.anthropic.com/v1/oauth/token" \
    -H "Content-Type: application/json" \
    -H "User-Agent: CRUSH/1.0" \
    -d "{\"grant_type\":\"refresh_token\",\"refresh_token\":\"${refresh_token}\",\"client_id\":\"${CLIENT_ID}\"}")

  [ -n "$DEBUG" ] && echo "Refresh response: $bearer_response" >&2

  # Parse JSON response - try jq first, fallback to sed
  local access_token=""
  local new_refresh_token=""
  local expires_in=""

  if command -v jq >/dev/null 2>&1; then
    access_token=$(echo "$bearer_response" | jq -r '.access_token // empty')
    new_refresh_token=$(echo "$bearer_response" | jq -r '.refresh_token // empty')
    expires_in=$(echo "$bearer_response" | jq -r '.expires_in // empty')
  else
    # Fallback to sed parsing
    access_token=$(echo "$bearer_response" | sed -n 's/.*"access_token"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
    new_refresh_token=$(echo "$bearer_response" | sed -n 's/.*"refresh_token"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
    expires_in=$(echo "$bearer_response" | sed -n 's/.*"expires_in"[[:space:]]*:[[:space:]]*\([0-9]*\).*/\1/p')
  fi

  if [ -n "$access_token" ] && [ -n "$expires_in" ]; then
    # Calculate expiration timestamp
    local current_time=$(date +%s)
    local expires_timestamp=$((current_time + expires_in))

    # Cache the new tokens
    mkdir -p "$CACHE_DIR"
    echo "$access_token" > "$CACHE_FILE"
    chmod 600 "$CACHE_FILE"

    if [ -n "$new_refresh_token" ]; then
      echo "$new_refresh_token" > "$REFRESH_TOKEN_FILE"
      chmod 600 "$REFRESH_TOKEN_FILE"
    fi

    # Store expiration for future reference
    echo "$expires_timestamp" > "${CACHE_FILE}.expires"
    chmod 600 "${CACHE_FILE}.expires"

    echo "$access_token"
    return 0
  fi

  return 1
}

# Function to exchange authorization code for tokens
exchange_authorization_code() {
  local auth_code="$1"
  local verifier="$2"

  # Split code if it contains state (format: code#state)
  local code=$(echo "$auth_code" | cut -d'#' -f1)
  local state=""
  if echo "$auth_code" | grep -q '#'; then
    state=$(echo "$auth_code" | cut -d'#' -f2)
  fi

  if [ -n "$DEBUG" ]; then
    echo "Code: $code" >&2
    echo "State: $state" >&2
    echo "Verifier: $verifier" >&2
  fi

  # Use the working endpoint
  local bearer_response=$(curl -s -X POST "https://console.anthropic.com/v1/oauth/token" \
    -H "Content-Type: application/json" \
    -H "User-Agent: CRUSH/1.0" \
    -d "{\"code\":\"${code}\",\"state\":\"${state}\",\"grant_type\":\"authorization_code\",\"client_id\":\"${CLIENT_ID}\",\"redirect_uri\":\"https://console.anthropic.com/oauth/code/callback\",\"code_verifier\":\"${verifier}\"}")

  [ -n "$DEBUG" ] && echo "Response: $bearer_response" >&2

  # Parse JSON response - try jq first, fallback to sed
  local access_token=""
  local refresh_token=""
  local expires_in=""

  if command -v jq >/dev/null 2>&1; then
    access_token=$(echo "$bearer_response" | jq -r '.access_token // empty')
    refresh_token=$(echo "$bearer_response" | jq -r '.refresh_token // empty')
    expires_in=$(echo "$bearer_response" | jq -r '.expires_in // empty')
  else
    # Fallback to sed parsing
    access_token=$(echo "$bearer_response" | sed -n 's/.*"access_token"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
    refresh_token=$(echo "$bearer_response" | sed -n 's/.*"refresh_token"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
    expires_in=$(echo "$bearer_response" | sed -n 's/.*"expires_in"[[:space:]]*:[[:space:]]*\([0-9]*\).*/\1/p')
  fi

  if [ -n "$DEBUG" ]; then
    echo "Extracted access_token: ${access_token:0:20}..." >&2
    echo "Extracted refresh_token: ${refresh_token:0:20}..." >&2
    echo "Extracted expires_in: $expires_in" >&2
  fi

  if [ -n "$access_token" ] && [ -n "$refresh_token" ] && [ -n "$expires_in" ]; then
    # Calculate expiration timestamp
    local current_time=$(date +%s)
    local expires_timestamp=$((current_time + expires_in))

    # Cache the tokens
    mkdir -p "$CACHE_DIR"
    echo "$access_token" > "$CACHE_FILE"
    echo "$refresh_token" > "$REFRESH_TOKEN_FILE"
    echo "$expires_timestamp" > "${CACHE_FILE}.expires"
    chmod 600 "$CACHE_FILE" "$REFRESH_TOKEN_FILE" "${CACHE_FILE}.expires"

    [ -n "$DEBUG" ] && echo "Successfully cached tokens" >&2
    echo "$access_token"
    return 0
  else
    [ -n "$DEBUG" ] && echo "Failed to extract required tokens from response" >&2
    return 1
  fi
}

# Check for cached bearer token
if [ -f "$CACHE_FILE" ] && [ -f "${CACHE_FILE}.expires" ]; then
  CACHED_TOKEN=$(cat "$CACHE_FILE")
  CACHED_EXPIRES=$(cat "${CACHE_FILE}.expires")
  if is_token_valid "$CACHED_EXPIRES"; then
    # Token is still valid, output and exit
    echo "$CACHED_TOKEN"
    exit 0
  fi
fi

# Bearer token is expired/missing, try to use cached refresh token
if [ -f "$REFRESH_TOKEN_FILE" ]; then
  REFRESH_TOKEN=$(cat "$REFRESH_TOKEN_FILE")
  if [ -n "$REFRESH_TOKEN" ]; then
    # Try to exchange refresh token for new bearer token
    BEARER_TOKEN=$(exchange_refresh_token "$REFRESH_TOKEN")
    if [ -n "$BEARER_TOKEN" ]; then
      # Successfully got new bearer token, output and exit
      echo "$BEARER_TOKEN"
      exit 0
    fi
  fi
fi

# No valid tokens found, start OAuth flow
echo "No valid Anthropic token found. Starting OAuth authentication..." >&2

# Check if openssl is available for PKCE
if ! command -v openssl >/dev/null 2>&1; then
  echo "Error: openssl is required for OAuth authentication but not found" >&2
  echo "Please install openssl to continue" >&2
  exit 1
fi

# Generate PKCE challenge
PKCE_DATA=$(generate_pkce)
VERIFIER=$(echo "$PKCE_DATA" | cut -d'|' -f1)
CHALLENGE=$(echo "$PKCE_DATA" | cut -d'|' -f2)

# Build OAuth URL
AUTH_URL="https://claude.ai/oauth/authorize"
AUTH_URL="${AUTH_URL}?response_type=code"
AUTH_URL="${AUTH_URL}&client_id=${CLIENT_ID}"
AUTH_URL="${AUTH_URL}&redirect_uri=https://console.anthropic.com/oauth/code/callback"
AUTH_URL="${AUTH_URL}&scope=org:create_api_key%20user:profile%20user:inference"
AUTH_URL="${AUTH_URL}&code_challenge=${CHALLENGE}"
AUTH_URL="${AUTH_URL}&code_challenge_method=S256"
AUTH_URL="${AUTH_URL}&state=${VERIFIER}"

# Open browser directly to OAuth page (suppress all output to avoid issues in POSIX shell)
if command -v xdg-open >/dev/null 2>&1; then
  xdg-open "$AUTH_URL" >/dev/null 2>&1 &
elif command -v open >/dev/null 2>&1; then
  open "$AUTH_URL" >/dev/null 2>&1 &
elif command -v start >/dev/null 2>&1; then
  start "$AUTH_URL" >/dev/null 2>&1 &
fi

# Prompt user for authorization token
echo "" >&2
echo "A browser window should have opened for authentication." >&2
echo "After authorizing, you'll be given a token to copy." >&2
echo "The token will look like: 20Vcn8tNFasV4LlIzj2RmhHUalznE8kktywgjbIj17pAzqOM#R8R1GJXz_bw6bf25jovg2S8vI7oQUPtVrmVQINzpC3o" >&2
echo "" >&2
printf "Please paste the token: " >&2
read -r AUTH_CODE

# Exchange code for tokens
if [ -n "$AUTH_CODE" ]; then
  ACCESS_TOKEN=$(exchange_authorization_code "$AUTH_CODE" "$VERIFIER")
  if [ -n "$ACCESS_TOKEN" ]; then
    echo
    echo "perfect! you can use crush now"
    exit 0
  else
    echo "Error: Failed to exchange authorization code for access token" >&2
    exit 1
  fi
else
  echo "Error: No authorization code provided" >&2
  exit 1
fi
