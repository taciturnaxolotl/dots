# NixOS Service Modules

This directory contains reusable NixOS service modules for deploying applications.

## Architecture

Each service module follows a common pattern for deploying TypeScript/Bun applications:

### Directory Structure
- **Data Directory**: `/var/lib/<service-name>/`
  - `app/` - Git repository clone
  - `data/` - Application data (databases, uploads, etc.)

### Systemd Service Pattern

1. **ExecStartPre** (runs as root with `+` prefix):
   - Creates data directories
   - Sets ownership to service user
   - Ensures proper permissions

2. **preStart** (runs as service user):
   - Clones git repository if needed
   - Pulls latest changes (if `autoUpdate` enabled)
   - Runs `bun install`
   - Initializes database if needed

3. **ExecStart** (runs as service user):
   - Starts the application with `bun start`

### Common Options

All service modules support:

```nix
atelier.services.<service-name> = {
  enable = true;                    # Enable the service
  domain = "app.example.com";       # Domain for Caddy reverse proxy
  port = 3000;                      # Port the app listens on
  dataDir = "/var/lib/<service>";   # Data storage location
  secretsFile = path;               # agenix secrets file
  repository = "https://...";       # Git repository URL
  autoUpdate = true;                # Git pull on service restart
};
```

### Secrets Management

Secrets are managed using [agenix](https://github.com/ryantm/agenix):

1. Add secret to `secrets/secrets.nix`:
   ```nix
   "service-name.age".publicKeys = [ kierank ];
   ```

2. Create and encrypt the secret:
   ```bash
   agenix -e secrets/service-name.age
   ```

3. Add environment variables (one per line):
   ```
   DATABASE_URL=postgres://...
   API_KEY=xxxxx
   SECRET_TOKEN=yyyyy
   ```

4. Reference in machine config:
   ```nix
   age.secrets.service-name = {
     file = ../../secrets/service-name.age;
     owner = "service-name";
   };
   
   atelier.services.service-name = {
     secretsFile = config.age.secrets.service-name.path;
   };
   ```

### Reverse Proxy (Caddy)

Each service automatically configures a Caddy virtual host with:
- Cloudflare DNS challenge for TLS
- Reverse proxy to the application port

## GitHub Actions Deployment

Services can be deployed via GitHub Actions using SSH over Tailscale.

### Prerequisites

1. **Tailscale OAuth Client**:
   - Create at https://login.tailscale.com/admin/settings/oauth
   - Required scope: `auth_keys` (to authenticate ephemeral nodes)
   - Add to GitHub repo secrets:
     - `TS_OAUTH_CLIENT_ID`
     - `TS_OAUTH_SECRET`

2. **SSH Access**:
   - Add the service user to Tailscale SSH ACLs
   - Example in `tailscale.com/admin/acls`:
     ```json
     "ssh": [
       {
         "action": "accept",
         "src": ["tag:ci"],
         "dst": ["tag:server"],
         "users": ["cachet", "hn-alerts", "root"]
       }
     ]
     ```

### Workflow Template

Create `.github/workflows/deploy-<service>.yaml`:

```yaml
name: Deploy <Service Name>

on:
  push:
    branches:
      - main
  workflow_dispatch:

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Tailscale
        uses: tailscale/github-action@v3
        with:
          oauth-client-id: ${{ secrets.TS_OAUTH_CLIENT_ID }}
          oauth-secret: ${{ secrets.TS_OAUTH_SECRET }}
          tags: tag:ci
          use-cache: "true"
      
      - name: Configure SSH
        run: |
          mkdir -p ~/.ssh
          echo "StrictHostKeyChecking no" >> ~/.ssh/config
      
      - name: Deploy to server
        run: |
          ssh <service-user>@<hostname> << 'EOF'
            cd /var/lib/<service>/app
            git fetch --all
            git reset --hard origin/main
            bun install
            sudo /run/current-system/sw/bin/systemctl restart <service>.service
          EOF
      
      - name: Wait for service to start
        run: sleep 10
      
      - name: Health check
        run: |
          HEALTH_URL="https://<domain>/health"
          MAX_RETRIES=6
          RETRY_DELAY=5
          
          for i in $(seq 1 $MAX_RETRIES); do
            echo "Health check attempt $i/$MAX_RETRIES..."
            
            RESPONSE=$(curl -s -w "\n%{http_code}" "$HEALTH_URL" || echo "000")
            HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
            BODY=$(echo "$RESPONSE" | sed '$d')
            
            if [ "$HTTP_CODE" = "200" ]; then
              echo "✅ Service is healthy"
              echo "$BODY"
              exit 0
            fi
            
            echo "❌ Health check failed with HTTP $HTTP_CODE"
            echo "$BODY"
            
            if [ $i -lt $MAX_RETRIES ]; then
              echo "Retrying in ${RETRY_DELAY}s..."
              sleep $RETRY_DELAY
            fi
          done
          
          echo "❌ Health check failed after $MAX_RETRIES attempts"
          exit 1
```

### Deployment Flow

1. Push to `main` branch triggers workflow
2. GitHub Actions runner joins Tailscale network
3. SSH to service user on target server
4. Git pull latest changes
5. Install dependencies
6. Restart systemd service
7. Verify health check endpoint

## Creating a New Service Module

1. Copy an existing module (e.g., `cachet.nix` or `hn-alerts.nix`)
2. Update service name, user, and group
3. Adjust environment variables as needed
4. Add database initialization if required
5. Configure secrets in `secrets/secrets.nix`
6. Import in machine config
7. Create GitHub Actions workflow (if needed)

## Example Services

- **cachet** - Slack emoji/profile cache
- **hn-alerts** - Hacker News monitoring and alerts
