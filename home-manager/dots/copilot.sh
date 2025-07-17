#!/bin/sh

# GitHub Copilot client ID
CLIENT_ID="Iv1.b507a08c87ecfe98"

# Token cache file location
CACHE_DIR="${HOME}/.config/crush/github-copilot"
CACHE_FILE="${CACHE_DIR}/bearer_token"
GITHUB_TOKEN_FILE="${CACHE_DIR}/github_token"
GITHUB_COPILOT_APPS_FILE="${HOME}/.config/github-copilot/apps.json"

# Function to extract OAuth token from GitHub Copilot apps.json
extract_oauth_token() {
  local client_id="$1"
  if [ -f "$GITHUB_COPILOT_APPS_FILE" ]; then
    # Extract the oauth_token for our client ID (key format is "github.com:CLIENT_ID")
    local oauth_token=$(grep -o "\"github.com:${client_id}\":{[^}]*\"oauth_token\":\"[^\"]*" "$GITHUB_COPILOT_APPS_FILE" | grep -o '"oauth_token":"[^"]*' | cut -d'"' -f4)
    echo "$oauth_token"
  fi
}

# Function to extract expiration from token
extract_expiration() {
  local token="$1"
  echo "$token" | grep -o 'exp=[0-9]*' | cut -d'=' -f2
}

# Function to check if token is valid
is_token_valid() {
  local token="$1"
  local exp=$(extract_expiration "$token")

  if [ -z "$exp" ]; then
    return 1
  fi

  local current_time=$(date +%s)
  # Add 60 second buffer before expiration
  local buffer_time=$((exp - 60))

  if [ "$current_time" -lt "$buffer_time" ]; then
    return 0
  else
    return 1
  fi
}

# Function to exchange GitHub token for bearer token
exchange_github_token() {
  local github_token="$1"
  local bearer_response=$(curl -s -X GET "https://api.github.com/copilot_internal/v2/token" \
    -H "Authorization: Token ${github_token}" \
    -H "User-Agent: CRUSH/1.0")

  local bearer_token=$(echo "$bearer_response" | grep -o '"token":"[^"]*' | cut -d'"' -f4)
  echo "$bearer_token"
}

# Check for cached bearer token
if [ -f "$CACHE_FILE" ]; then
  CACHED_TOKEN=$(cat "$CACHE_FILE")
  if is_token_valid "$CACHED_TOKEN"; then
    # Token is still valid, output and exit
    echo "$CACHED_TOKEN"
    exit 0
  fi
fi

# Bearer token is expired/missing, try to use cached GitHub token
if [ -f "$GITHUB_TOKEN_FILE" ]; then
  GITHUB_TOKEN=$(cat "$GITHUB_TOKEN_FILE")
  if [ -n "$GITHUB_TOKEN" ]; then
    # Try to exchange GitHub token for new bearer token
    BEARER_TOKEN=$(exchange_github_token "$GITHUB_TOKEN")
    if [ -n "$BEARER_TOKEN" ]; then
      # Successfully got new bearer token, cache it
      echo "$BEARER_TOKEN" > "$CACHE_FILE"
      chmod 600 "$CACHE_FILE"
      echo "$BEARER_TOKEN"
      exit 0
    fi
  fi
fi

# Try to get OAuth token from GitHub Copilot apps.json
OAUTH_TOKEN=$(extract_oauth_token "$CLIENT_ID")
if [ -n "$OAUTH_TOKEN" ]; then
  # Try to exchange OAuth token for new bearer token
  BEARER_TOKEN=$(exchange_github_token "$OAUTH_TOKEN")
  if [ -n "$BEARER_TOKEN" ]; then
    # Successfully got new bearer token, cache it
    mkdir -p "$CACHE_DIR"
    echo "$BEARER_TOKEN" > "$CACHE_FILE"
    chmod 600 "$CACHE_FILE"
    echo "$OAUTH_TOKEN" > "$GITHUB_TOKEN_FILE"
    chmod 600 "$GITHUB_TOKEN_FILE"
    echo "$BEARER_TOKEN"
    exit 0
  fi
fi

# Step 1: Get device code
DEVICE_RESPONSE=$(curl -s -X POST "https://github.com/login/device/code" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -H "User-Agent: CRUSH/1.0" \
  -H "Accept: application/json" \
  -d "client_id=${CLIENT_ID}&scope=user:email read:user copilot")

# Extract values from response
DEVICE_CODE=$(echo "$DEVICE_RESPONSE" | grep -o '"device_code":"[^"]*' | cut -d'"' -f4)
USER_CODE=$(echo "$DEVICE_RESPONSE" | grep -o '"user_code":"[^"]*' | cut -d'"' -f4)
VERIFICATION_URI=$(echo "$DEVICE_RESPONSE" | grep -o '"verification_uri":"[^"]*' | cut -d'"' -f4)
INTERVAL=$(echo "$DEVICE_RESPONSE" | grep -o '"interval":[0-9]*' | cut -d':' -f2)
EXPIRES_IN=$(echo "$DEVICE_RESPONSE" | grep -o '"expires_in":[0-9]*' | cut -d':' -f2)

# Ensure minimum interval
if [ "$INTERVAL" -lt 5 ]; then
  INTERVAL=5
fi

# Step 2: Create a temporary HTML file with the code
TEMP_HTML="/tmp/copilot_auth_$$.html"
cat > "$TEMP_HTML" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>GitHub Copilot Authentication</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Helvetica, Arial, sans-serif;
            display: flex;
            justify-content: center;
            align-items: center;
            height: 100vh;
            margin: 0;
            background-color: #f6f8fa;
        }
        .container {
            text-align: center;
            background: white;
            padding: 40px;
            border-radius: 8px;
            box-shadow: 0 2px 8px rgba(0,0,0,0.1);
            max-width: 400px;
        }
        .code {
            font-size: 32px;
            font-weight: bold;
            font-family: monospace;
            background: #f3f4f6;
            padding: 20px;
            border-radius: 6px;
            margin: 20px 0;
            user-select: all;
            cursor: pointer;
        }
        .button {
            display: inline-block;
            background: #2ea44f;
            color: white;
            padding: 12px 24px;
            text-decoration: none;
            border-radius: 6px;
            font-weight: 500;
            margin-top: 20px;
        }
        .button:hover {
            background: #2c974b;
        }
        .info {
            color: #586069;
            margin-top: 20px;
            font-size: 14px;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>GitHub Copilot Authentication</h1>
        <p>Copy this code:</p>
        <div class="code" onclick="navigator.clipboard.writeText('$USER_CODE')">$USER_CODE</div>
        <a href="$VERIFICATION_URI" class="button" target="_blank" onclick="navigator.clipboard.writeText('$USER_CODE')">Copy Code & Continue to GitHub</a>
        <p class="info">Click the button to copy the code and go to GitHub</p>
    </div>
    <script>
        // Auto-close after 2 minutes
        setTimeout(() => window.close(), 120000);
    </script>
</body>
</html>
EOF

# Open the HTML file (suppress all output to avoid issues in POSIX shell)
if command -v xdg-open >/dev/null 2>&1; then
  xdg-open "$TEMP_HTML" >/dev/null 2>&1 &
elif command -v open >/dev/null 2>&1; then
  open "$TEMP_HTML" >/dev/null 2>&1 &
elif command -v start >/dev/null 2>&1; then
  start "$TEMP_HTML" >/dev/null 2>&1 &
fi

# Step 3: Poll for token
POLL_COUNT=0
MAX_POLLS=60
GITHUB_TOKEN=""

# Initial delay
sleep 2

while [ $POLL_COUNT -lt $MAX_POLLS ] && [ -z "$GITHUB_TOKEN" ]; do
  TOKEN_RESPONSE=$(curl -s -X POST "https://github.com/login/oauth/access_token" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -H "User-Agent: CRUSH/1.0" \
    -H "Accept: application/json" \
    -d "client_id=${CLIENT_ID}&device_code=${DEVICE_CODE}&grant_type=urn:ietf:params:oauth:grant-type:device_code")

  # Check for access token
  ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | grep -o '"access_token":"[^"]*' | cut -d'"' -f4)

  if [ -n "$ACCESS_TOKEN" ]; then
    GITHUB_TOKEN="$ACCESS_TOKEN"
    break
  fi

  # Check for errors
  ERROR=$(echo "$TOKEN_RESPONSE" | grep -o '"error":"[^"]*' | cut -d'"' -f4)

  case "$ERROR" in
    "authorization_pending")
      # Still waiting, continue
      ;;
    "slow_down")
      # Rate limiting
      exit 1
      ;;
    "expired_token")
      # Token expired
      exit 1
      ;;
    *)
      if [ -n "$ERROR" ]; then
        exit 1
      fi
      ;;
  esac

  POLL_COUNT=$((POLL_COUNT + 1))
  sleep $INTERVAL
done

if [ -z "$GITHUB_TOKEN" ]; then
  exit 1
fi

# Step 4: Exchange GitHub token for Copilot bearer token
BEARER_TOKEN=$(exchange_github_token "$GITHUB_TOKEN")

if [ -z "$BEARER_TOKEN" ]; then
  exit 1
fi

# Create cache directory if it doesn't exist
mkdir -p "$CACHE_DIR"

# Cache both tokens
echo "$BEARER_TOKEN" > "$CACHE_FILE"
chmod 600 "$CACHE_FILE"
echo "$GITHUB_TOKEN" > "$GITHUB_TOKEN_FILE"
chmod 600 "$GITHUB_TOKEN_FILE"

# Output only the bearer token to stdout
echo "$BEARER_TOKEN"
