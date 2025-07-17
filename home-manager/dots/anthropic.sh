#!/bin/sh

# OpenCode auth file location
AUTH_FILE="${HOME}/.local/share/opencode/auth.json"

# Function to extract field from JSON (simple grep-based parser for POSIX compatibility)
extract_json_field() {
  local file="$1"
  local field="$2"
  grep -o "\"${field}\":[^,}]*" "$file" | cut -d':' -f2- | sed 's/^[[:space:]]*"\([^"]*\)".*/\1/'
}

# Function to check if token is valid
is_token_valid() {
  local expires="$1"

  if [ -z "$expires" ]; then
    return 1
  fi

  local current_time=$(date +%s)
  local expires_seconds=$((expires / 1000))  # Convert from milliseconds to seconds
  local buffer_time=$((expires_seconds - 60))  # 60 second buffer before expiration

  if [ "$current_time" -lt "$buffer_time" ]; then
    return 0
  else
    return 1
  fi
}

# Function to refresh access token using refresh token
refresh_access_token() {
  local refresh_token="$1"

  # Make request to Anthropic's token refresh endpoint
  local response=$(curl -s -X POST "https://auth.anthropic.com/oauth/token" \
    -H "Content-Type: application/json" \
    -H "User-Agent: OpenCode/1.0" \
    -d "{\"grant_type\":\"refresh_token\",\"refresh_token\":\"${refresh_token}\"}")

  # Extract new access token from response
  local new_access_token=$(echo "$response" | grep -o '"access_token":"[^"]*' | cut -d'"' -f4)
  local new_expires=$(echo "$response" | grep -o '"expires_in":[0-9]*' | cut -d':' -f2)

  if [ -n "$new_access_token" ] && [ -n "$new_expires" ]; then
    # Calculate expiration timestamp (current time + expires_in seconds, in milliseconds)
    local current_time=$(date +%s)
    local expires_timestamp=$(((current_time + new_expires) * 1000))

    # Update the auth file with new tokens
    # Create a temporary file for atomic update
    local temp_file=$(mktemp)
    cat > "$temp_file" << EOF
{
  "anthropic": {
    "type": "oauth",
    "refresh": "${refresh_token}",
    "access": "${new_access_token}",
    "expires": ${expires_timestamp}
  }
}
EOF

    # Atomically replace the auth file
    mv "$temp_file" "$AUTH_FILE"
    chmod 600 "$AUTH_FILE"

    echo "$new_access_token"
    return 0
  fi

  return 1
}

# Check if auth file exists
if [ ! -f "$AUTH_FILE" ]; then
  echo "Error: OpenCode auth file not found at $AUTH_FILE" >&2
  echo "Please run 'opencode auth' to authenticate first" >&2
  exit 1
fi

# Extract tokens from auth file
ACCESS_TOKEN=$(extract_json_field "$AUTH_FILE" "access")
REFRESH_TOKEN=$(extract_json_field "$AUTH_FILE" "refresh")
EXPIRES=$(extract_json_field "$AUTH_FILE" "expires")

# Check if required fields are present
if [ -z "$ACCESS_TOKEN" ] || [ -z "$REFRESH_TOKEN" ] || [ -z "$EXPIRES" ]; then
  echo "Error: Invalid auth file format" >&2
  exit 1
fi

# Check if current access token is still valid
if is_token_valid "$EXPIRES"; then
  # Token is still valid, output and exit
  echo "$ACCESS_TOKEN"
  exit 0
fi

# Token is expired, try to refresh
NEW_ACCESS_TOKEN=$(refresh_access_token "$REFRESH_TOKEN")
if [ -n "$NEW_ACCESS_TOKEN" ]; then
  echo "$NEW_ACCESS_TOKEN"
  exit 0
fi

# If we get here, refresh failed
echo "Error: Failed to refresh access token" >&2
echo "Please run 'opencode auth' to re-authenticate" >&2
exit 1
