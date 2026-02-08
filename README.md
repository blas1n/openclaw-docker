# OpenClaw Docker Setup with Tailscale Security

Secure Docker-based OpenClaw deployment with Tailscale sidecar network isolation and Ollama local LLM.

## 🔒 Security Architecture

- **Tailscale Sidecar**: Docker container joins Tailscale network directly
- **Tailscale HTTPS**: Automatic TLS certificates via Tailscale Serve
- **Network Namespace Isolation**: OpenClaw uses Tailscale's network namespace via `network_mode: "service:tailscale"`
- **No Port Exposure**: Zero port mappings in docker-compose.yml - not accessible from host LAN
- **Zero Trust Access**: Only accessible via Tailscale VPN (`tailnet` binding)
- **CVE-2026-25253 Protection**: Latest OpenClaw version (v2026.2.3+)
- **Container Hardening**: Read-only filesystem, no-new-privileges, dropped capabilities
- **Token Authentication**: Required for all connections
- **Tool Restrictions**: Dangerous tools (exec, browser, process) disabled
- **Local LLM**: Ollama integration for privacy

**Why `tailnet` binding is secure:**
- OpenClaw binds only to the Tailscale IP within the shared network namespace
- No ports mapped to host machine (no `-p` flags in docker-compose.yml)
- Only accessible through Tailscale VPN - completely isolated from LAN/internet
- Even if someone accesses your physical network, they cannot reach OpenClaw
- HTTPS provided by Tailscale Serve with automatic certificate management
- `allowTailscale` enables identity verification via Tailscale daemon

## 📋 Prerequisites

- Docker installed
- Tailscale account and installed on at least one client device
- Ollama installed on host machine (for local LLM)
- macOS or Linux system

## 🚀 Quick Start

### 1. Generate Tailscale Auth Key

Visit: https://login.tailscale.com/admin/settings/keys

- Create a new auth key
- Set it to **Reusable** (optional)
- Add tag: `tag:openclaw` (create if doesn't exist)
- Copy the key (starts with `tskey-auth-...`)

### 2. Create Environment File

```bash
cd ~/openclaw-docker
cp .env.example .env
```

Edit `.env` and add your Tailscale auth key:

```env
TS_AUTHKEY=tskey-auth-xxx-your-auth-key-here
```

### 3. Review Configuration

The `openclaw.json` file contains OpenClaw settings:
- Gateway binding: `tailnet` (Tailscale IP only)
- Gateway port: 18789
- Authentication: token + Tailscale identity (`allowTailscale`)
- Tailscale Serve reverse proxy support (`trustedProxies`, `controlUi`)
- Security policies

### 4. Start Services

```bash
./start.sh
```

The script will:
- Start Tailscale and OpenClaw containers
- Enable Tailscale HTTPS automatically
- Display both HTTPS and HTTP access URLs

Or manually:

```bash
docker-compose up -d
# Tailscale Serve uses the container's Tailscale IP (not localhost)
TS_IP=$(docker exec openclaw-tailscale tailscale ip -4)
docker exec openclaw-tailscale tailscale serve --https 443 --bg "http://${TS_IP}:18789"
```

### 5. Find Your Tailscale URLs

**HTTPS URL (Recommended):**
```bash
docker exec openclaw-tailscale tailscale serve status
```

**IP Address:**
```bash
docker exec openclaw-tailscale tailscale ip -4
```

Or check Tailscale admin console for device named `openclaw`.

### 6. Access OpenClaw

From any device on your Tailscale network:

**HTTPS (Recommended):**
```
https://openclaw.<your-tailnet>.ts.net/
```

**HTTP (Alternative):**
```
http://<openclaw-tailscale-ip>:18789
```

Authentication token is in `openclaw.json`.

**Note:** The Web UI requires HTTPS or localhost for security. Tailscale automatically provides HTTPS via the `.ts.net` domain.

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────┐
│ Your Tailscale Network (Encrypted VPN)                  │
│                                                          │
│  ┌──────────────┐              ┌──────────────────────┐ │
│  │ Your Device  │─────────────▶│  Docker Container    │ │
│  │ (Client)     │   Encrypted  │                      │ │
│  └──────────────┘      VPN     │  ┌────────────────┐  │ │
│                                │  │  Tailscale     │  │ │
│                                │  │  Sidecar       │  │ │
│                                │  │  (Routing)     │  │ │
│                                │  └────────┬───────┘  │ │
│                                │           │          │ │
│                                │  ┌────────▼───────┐  │ │
│                                │  │  OpenClaw      │  │ │
│                                │  │  Tailscale IP  │  │ │
│                                │  │  :18789        │  │ │
│                                │  │  (tailnet)     │  │ │
│                                │  └────────┬───────┘  │ │
│                                └───────────┼──────────┘ │
└────────────────────────────────────────────┼────────────┘
                                             │
                                  ┌──────────▼─────────┐
                                  │ Host Machine       │
                                  │                    │
                                  │ ┌────────────────┐ │
                                  │ │ Ollama         │ │
                                  │ │ :11434         │ │
                                  │ │ (Local LLM)    │ │
                                  │ └────────────────┘ │
                                  └────────────────────┘
```

**Key Security Benefits:**
- OpenClaw never exposed to LAN or internet
- All traffic encrypted via Tailscale
- No port forwarding needed
- No firewall configuration needed

## 🛠️ Management Commands

### Start
```bash
./start.sh
# or
docker-compose up -d
```

### Stop
```bash
./stop.sh
# or
docker-compose down
```

### Restart
```bash
docker-compose restart
```

### View Logs
```bash
# OpenClaw logs
docker-compose logs -f openclaw

# Tailscale logs
docker-compose logs -f tailscale

# Both
docker-compose logs -f
```

### Update
```bash
docker-compose pull
docker-compose up -d
```

### Check Tailscale Status
```bash
docker exec openclaw-tailscale tailscale status
```

### Get Tailscale IP
```bash
docker exec openclaw-tailscale tailscale ip -4
```

### Enable/Disable HTTPS
```bash
# Enable HTTPS (use container's Tailscale IP)
TS_IP=$(docker exec openclaw-tailscale tailscale ip -4)
docker exec openclaw-tailscale tailscale serve --https 443 --bg "http://${TS_IP}:18789"

# Check HTTPS status
docker exec openclaw-tailscale tailscale serve status

# Disable HTTPS
docker exec openclaw-tailscale tailscale serve --https=443 off
```

## 🔧 Configuration

### openclaw.json

Main configuration file for OpenClaw:

| Section | Setting | Description |
|---------|---------|-------------|
| Section | Setting | Description |
|---------|---------|-------------|
| `gateway.bind` | `tailnet` | Binds to Tailscale IP only |
| `gateway.port` | `18789` | Gateway port |
| `gateway.auth.token` | Token | Authentication token |
| `gateway.auth.allowTailscale` | `true` | Tailscale identity verification |
| `gateway.trustedProxies` | `["127.0.0.1"]` | Trusted reverse proxy addresses |
| `gateway.controlUi.allowInsecureAuth` | `true` | Allow token auth behind TLS proxy |
| `models.providers.ollama.baseUrl` | URL | Ollama endpoint |
| `agents.defaults.model.primary` | Model | Default LLM model |
| `tools.deny` | Array | Blocked tools |
| `session.dmScope` | Scope | Session isolation mode |

**Gateway Bind Options with Tailscale Sidecar:**
- `tailnet` (Tailscale IP) - **Recommended** - Binds only to Tailscale IP. Most restrictive and secure.
- `lan` (0.0.0.0) - Binds to all interfaces within Tailscale network namespace. Secure because the container has NO port mappings and uses `network_mode: "service:tailscale"`.
- `loopback` (127.0.0.1) - Not usable - Blocks all external access including Tailscale

### .env

Sensitive configuration:

```env
TS_AUTHKEY=tskey-auth-xxx  # Tailscale auth key
```

### Ollama Models

List installed models:
```bash
ollama list
```

Change model in [openclaw.json](openclaw.json):
```json
"agents": {
  "defaults": {
    "model": {
      "primary": "ollama/your-model-name"
    }
  }
}
```

## 🔐 Security Best Practices

### 1. Tailscale ACLs (Highly Recommended)

Configure Tailscale ACLs to restrict who can access OpenClaw:

**Personal Use (Recommended):**
```json
{
  "tagOwners": {
    "tag:openclaw": ["your@email.com"]
  },
  "acls": [
    {
      "action": "accept",
      "src": ["your@email.com"],
      "dst": ["tag:openclaw:18789"]
    }
  ]
}
```

**How to Apply:**
1. Visit: https://login.tailscale.com/admin/acls
2. Click "Edit policy"
3. Add the ACL configuration above
4. Replace `your@email.com` with your Tailscale login email
5. Click "Save"

**Verify:**
```bash
# From allowed device - should work
curl http://<openclaw-tailscale-ip>:18789

# Check Tailscale logs
# Admin console → Logs → Access logs
```

2. **Rotate Tokens**: Regenerate auth tokens periodically
   ```bash
   openssl rand -hex 32
   ```
   Update in `openclaw.json`

3. **Monitor Logs**: Check for suspicious activity
   ```bash
   docker-compose logs -f openclaw | grep -i "error\|warn\|fail"
   ```

4. **Update Regularly**: Keep OpenClaw and Tailscale updated
   ```bash
   docker-compose pull && docker-compose up -d
   ```

5. **Backup Configuration**: Regular backups
   ```bash
   ./backup.sh
   ```

## 🐛 Troubleshooting

### Tailscale container won't start

```bash
# Check logs
docker-compose logs tailscale

# Verify auth key
cat .env | grep TS_AUTHKEY

# Regenerate auth key if expired
```

### Can't connect to OpenClaw

```bash
# 1. Check if containers are running
docker-compose ps

# 2. Get Tailscale IP
docker exec openclaw-tailscale tailscale ip -4

# 3. Verify Tailscale status
docker exec openclaw-tailscale tailscale status

# 4. Check OpenClaw logs
docker-compose logs openclaw
```

### Ollama connection fails

```bash
# 1. Verify Ollama is running on host
ollama list

# 2. Check if host.docker.internal is accessible
docker exec openclaw ping -c 3 host.docker.internal

# 3. Test Ollama endpoint
docker exec openclaw wget -O- http://host.docker.internal:11434/api/tags
```

### Permission errors

```bash
# Reset volumes
docker-compose down -v
docker-compose up -d
```

## 📚 References

- [Tailscale Docker Guide](https://tailscale.com/blog/docker-tailscale-guide)
- [OpenClaw Documentation](https://docs.openclaw.ai)
- [OpenClaw Security](https://docs.openclaw.ai/gateway/security)