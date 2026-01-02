{ pkgs, lib, mailchannelsApiKey }:

pkgs.writeShellScriptBin "mailchannels-sendmail" ''
  # Sendmail-compatible wrapper for MailChannels API
  # Reads email from stdin and sends via MailChannels
  
  set -euo pipefail
  
  # Read the email from stdin
  EMAIL_CONTENT=$(cat)
  
  # Extract headers and body
  FROM=$(echo "$EMAIL_CONTENT" | grep -i "^From:" | head -1 | sed 's/^From: //')
  TO=$(echo "$EMAIL_CONTENT" | grep -i "^To:" | head -1 | sed 's/^To: //')
  SUBJECT=$(echo "$EMAIL_CONTENT" | grep -i "^Subject:" | head -1 | sed 's/^Subject: //')
  BODY=$(echo "$EMAIL_CONTENT" | sed -n '/^$/,$p' | tail -n +2)
  
  # Send via MailChannels API
  ${pkgs.curl}/bin/curl -X POST https://api.mailchannels.net/tx/v1/send \
    -H "Content-Type: application/json" \
    -H "X-API-Key: ${mailchannelsApiKey}" \
    -d @- <<EOF
  {
    "personalizations": [{
      "to": [{"email": "$TO"}]
    }],
    "from": {"email": "$FROM"},
    "subject": "$SUBJECT",
    "content": [{
      "type": "text/plain",
      "value": "$BODY"
    }]
  }
  EOF
''
