# Deploying with Cloudflare Tunnel

This project already includes a `cloudflared` service in `docker-compose.yml` under the `tunnel` profile.

Two recommended approaches to run the tunnel:

1) Long-term (recommended): create a Cloudflare Tunnel and store the credentials on disk
   - On Cloudflare for Teams / Zero Trust, create a tunnel and download the credentials (usually a `cert.pem` file and a folder)
   - Put the credentials folder under `backend/cloudflared/` (it will be mounted into the container)
   - Start the tunnel with the profile so the `cloudflared` service runs:

```powershell
cd backend
docker compose --profile tunnel up -d cloudflared
```

2) Short-term / CI (token-based): use a single `TUNNEL_TOKEN`
   - Create a tunnel and use `cloudflared tunnel create NAME` on a machine, then get a token from Cloudflare or use `cloudflared access` flow.
   - Put `TUNNEL_TOKEN=...` into `backend/.env` (never commit the token)
   - Start cloudflared (it reads `.env` in compose):

```powershell
cd backend
docker compose --profile tunnel up -d cloudflared
```

Verification
  - Check logs to find the public URL (ephemeral or permanent):

```powershell
docker compose -f backend/docker-compose.yml logs -f cloudflared
```

Notes
  - The `api` service listens on internal port `5050` and is not directly exposed when you omit the tunnel profile.
  - Make sure `backend/instance` and `backend/static/photos` are writable by Docker and backed up.
  - For production, prefer mounting the credentials (`./cloudflared`) and running with the profile; token is simpler for quick setups.
