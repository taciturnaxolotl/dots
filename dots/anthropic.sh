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

  local bearer_response=$(curl -s -X POST "https://console.anthropic.com/v1/oauth/token" \
    -H "Content-Type: application/json" \
    -H "User-Agent: CRUSH/1.0" \
    -d "{\"grant_type\":\"refresh_token\",\"refresh_token\":\"${refresh_token}\",\"client_id\":\"${CLIENT_ID}\"}")

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

  # Use the working endpoint
  local bearer_response=$(curl -s -X POST "https://console.anthropic.com/v1/oauth/token" \
    -H "Content-Type: application/json" \
    -H "User-Agent: CRUSH/1.0" \
    -d "{\"code\":\"${code}\",\"state\":\"${state}\",\"grant_type\":\"authorization_code\",\"client_id\":\"${CLIENT_ID}\",\"redirect_uri\":\"https://console.anthropic.com/oauth/code/callback\",\"code_verifier\":\"${verifier}\"}")

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

    echo "$access_token"
    return 0
  else
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
# Check if openssl is available for PKCE
if ! command -v openssl >/dev/null 2>&1; then
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

# Create a temporary HTML file with the authentication form
TEMP_HTML="/tmp/anthropic_auth_$$.html"
cat > "$TEMP_HTML" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Anthropic Authentication</title>
    <style>
        * {
            box-sizing: border-box;
            margin: 0;
            padding: 0;
        }

        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', system-ui, sans-serif;
            background: linear-gradient(135deg, #1a1a1a 0%, #2d1810 100%);
            color: #ffffff;
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 20px;
        }

        .container {
            background: rgba(40, 40, 40, 0.95);
            border: 1px solid #4a4a4a;
            border-radius: 16px;
            padding: 48px;
            max-width: 480px;
            width: 100%;
            text-align: center;
            backdrop-filter: blur(10px);
            box-shadow: 0 20px 40px rgba(0, 0, 0, 0.3);
        }

        .logo {
            width: 48px;
            height: 48px;
            margin: 0 auto 24px;
            background: linear-gradient(135deg, #ff6b35 0%, #ff8e53 100%);
            border-radius: 12px;
            display: flex;
            align-items: center;
            justify-content: center;
            font-weight: bold;
            font-size: 24px;
            color: white;
        }

        h1 {
            font-size: 28px;
            font-weight: 600;
            margin-bottom: 12px;
            color: #ffffff;
        }

        .subtitle {
            color: #a0a0a0;
            margin-bottom: 32px;
            font-size: 16px;
            line-height: 1.5;
        }

        .step {
            margin-bottom: 32px;
            text-align: left;
        }

        .step-number {
            display: inline-flex;
            align-items: center;
            justify-content: center;
            width: 24px;
            height: 24px;
            background: #ff6b35;
            color: white;
            border-radius: 50%;
            font-size: 14px;
            font-weight: 600;
            margin-right: 12px;
        }

        .step-title {
            font-weight: 600;
            margin-bottom: 8px;
            color: #ffffff;
        }

        .step-description {
            color: #a0a0a0;
            font-size: 14px;
            margin-left: 36px;
        }

        .button {
            display: inline-block;
            background: linear-gradient(135deg, #ff6b35 0%, #ff8e53 100%);
            color: white;
            padding: 16px 32px;
            text-decoration: none;
            border-radius: 12px;
            font-weight: 600;
            font-size: 16px;
            margin-bottom: 24px;
            transition: all 0.2s ease;
            box-shadow: 0 4px 12px rgba(255, 107, 53, 0.3);
        }

        .button:hover {
            transform: translateY(-2px);
            box-shadow: 0 8px 20px rgba(255, 107, 53, 0.4);
        }

        .input-group {
            margin-bottom: 24px;
            text-align: left;
        }

        label {
            display: block;
            margin-bottom: 8px;
            font-weight: 500;
            color: #ffffff;
        }

        textarea {
            width: 100%;
            background: #2a2a2a;
            border: 2px solid #4a4a4a;
            border-radius: 8px;
            padding: 16px;
            color: #ffffff;
            font-family: 'SF Mono', Monaco, 'Cascadia Code', monospace;
            font-size: 14px;
            line-height: 1.4;
            resize: vertical;
            min-height: 120px;
            transition: border-color 0.2s ease;
        }

        textarea:focus {
            outline: none;
            border-color: #ff6b35;
            box-shadow: 0 0 0 3px rgba(255, 107, 53, 0.1);
        }

        textarea::placeholder {
            color: #666;
        }

        .submit-btn {
            background: linear-gradient(135deg, #ff6b35 0%, #ff8e53 100%);
            color: white;
            border: none;
            padding: 16px 32px;
            border-radius: 12px;
            font-weight: 600;
            font-size: 16px;
            cursor: pointer;
            transition: all 0.2s ease;
            box-shadow: 0 4px 12px rgba(255, 107, 53, 0.3);
            width: 100%;
        }

        .submit-btn:hover {
            transform: translateY(-2px);
            box-shadow: 0 8px 20px rgba(255, 107, 53, 0.4);
        }

        .submit-btn:disabled {
            opacity: 0.6;
            cursor: not-allowed;
            transform: none;
        }

        .status {
            margin-top: 16px;
            padding: 12px;
            border-radius: 8px;
            font-size: 14px;
            display: none;
        }

        .status.success {
            background: rgba(52, 168, 83, 0.1);
            border: 1px solid rgba(52, 168, 83, 0.3);
            color: #34a853;
        }

        .status.error {
            background: rgba(234, 67, 53, 0.1);
            border: 1px solid rgba(234, 67, 53, 0.3);
            color: #ea4335;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="logo">A</div>
        <h1>Anthropic Authentication</h1>
        <p class="subtitle">Connect your Anthropic account to continue</p>

        <div class="step">
            <div class="step-title">
                <span class="step-number">1</span>
                Authorize with Anthropic
            </div>
            <div class="step-description">
                Click the button below to open the Anthropic authorization page
            </div>
        </div>

        <a href="$AUTH_URL" class="button" target="_blank">
            Open Anthropic Authorization
        </a>

        <div class="step">
            <div class="step-title">
                <span class="step-number">2</span>
                Paste your authorization token
            </div>
            <div class="step-description">
                After authorizing, copy the token and paste it below
            </div>
        </div>

        <form id="tokenForm">
          <div class="input-group">
            <label for="token">Authorization Token:</label>
            <textarea
                id="token"
                name="token"
                placeholder="Paste your token here..."
                required
            ></textarea>
          </div>
          <button type="submit" class="submit-btn" id="submitBtn">
              Complete Authentication
          </button>
        </form>

        <div id="status" class="status"></div>
    </div>

    <script>
        document.getElementById('tokenForm').addEventListener('submit', function(e) {
            e.preventDefault();

            const token = document.getElementById('token').value.trim();
            if (!token) {
                showStatus('Please paste your authorization token', 'error');
                return;
            }

            // Ensure token has content before creating file
            if (token.length > 0) {
                // Save the token as a downloadable file
                const blob = new Blob([token], { type: 'text/plain' });
                const a = document.createElement('a');
                a.href = URL.createObjectURL(blob);
                a.download = "anthropic_token.txt";
                document.body.appendChild(a); // Append to body to ensure it works in all browsers
                a.click();
                document.body.removeChild(a); // Clean up

                // Verify file creation
                console.log("Token file created with content length: " + token.length);
            } else {
                showStatus('Empty token detected, please provide a valid token', 'error');
                return;
            }

            document.getElementById('submitBtn').disabled = true;
            document.getElementById('submitBtn').textContent = "Token saved, you may close this tab.";
            showStatus('Token file downloaded! You can close this window.', 'success');

            // setTimeout(() => {
            //     window.close();
            // }, 2000);
        });

        function showStatus(message, type) {
            const status = document.getElementById('status');
            status.textContent = message;
            status.className = 'status ' + type;
            status.style.display = 'block';
        }

        // Auto-close after 10 minutes
        setTimeout(() => {
            window.close();
        }, 600000);
    </script>
</body>
</html>
EOF

# Open the HTML file
if command -v xdg-open >/dev/null 2>&1; then
  xdg-open "$TEMP_HTML" >/dev/null 2>&1 &
elif command -v open >/dev/null 2>&1; then
  open "$TEMP_HTML" >/dev/null 2>&1 &
elif command -v start >/dev/null 2>&1; then
  start "$TEMP_HTML" >/dev/null 2>&1 &
fi

# Wait for user to download the token file
TOKEN_FILE="$HOME/Downloads/anthropic_token.txt"

for i in $(seq 1 60); do
  if [ -f "$TOKEN_FILE" ]; then
    AUTH_CODE=$(cat "$TOKEN_FILE" | tr -d '\r\n')
    rm -f "$TOKEN_FILE"
    break
  fi
  sleep 2
done

# Clean up the temporary HTML file
rm -f "$TEMP_HTML"

if [ -z "$AUTH_CODE" ]; then
  exit 1
fi

# Exchange code for tokens
ACCESS_TOKEN=$(exchange_authorization_code "$AUTH_CODE" "$VERIFIER")
if [ -n "$ACCESS_TOKEN" ]; then
  echo "$ACCESS_TOKEN"
  exit 0
else
  exit 1
fi
