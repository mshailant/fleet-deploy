# FleetOps — Guía de Deploy

Backend NestJS + React + PostgreSQL + Cloudflare Tunnel.
Sin puertos abiertos. Sin certbot. SSL incluido por Cloudflare.

---

## Estructura del repo

```
fleetops-deploy/
├── docker-compose.yml          ← producción
├── docker-compose.local.yml    ← desarrollo local
├── backend.Dockerfile          ← copiar como backend/Dockerfile
├── .env.example                ← template de variables
├── .env.local                  ← valores pre-llenados para local
├── Makefile                    ← atajos de comandos
├── cloudflared/
│   ├── config.yml              ← producción (usa containers Docker)
│   └── config.local.yml        ← dev local (usa localhost)
└── nginx/
    └── fleetops.conf           ← config nginx interno (web container)
```

---

## Arquitectura

```
[Browser / Agentes]
       │ HTTPS / WSS
       ▼
[Cloudflare] ──Tunnel──► [cloudflared container]
                                  │
                    ┌─────────────┴─────────────┐
                    ▼                           ▼
              [api:3000]                   [web:80]
              NestJS API                React + Nginx
                    │
              [postgres:5432]
```

---

## PASO 1 — Clonar el repo en el VPS

```bash
ssh usuario@IP_VPS
cd /opt
git clone https://github.com/nexosoluciones/cinexo-fleet-panel.git fleetops
cd fleetops
```

---

## PASO 2 — Configurar variables de entorno

```bash
cp .env.example .env
nano .env
```

Completar cada valor:

```env
DOMAIN=panel.monitoreocinexo.com.ar

PGPASSWORD=una_password_muy_segura

# openssl rand -hex 32
JWT_SECRET=xxxx...

# openssl rand -hex 16  →  da exactamente 32 chars hex
ENC_KEY=xxxx...

ADMIN_PASSWORD=tu_password_admin

CLOUDFLARE_TUNNEL_TOKEN=eyJhIjo...  # del paso 3
```

Generar los secrets de una vez:
```bash
echo "JWT_SECRET=$(openssl rand -hex 32)"
echo "ENC_KEY=$(openssl rand -hex 16)"
```

---

## PASO 3 — Cloudflare Tunnel

### Crear el túnel (una sola vez, desde cualquier máquina)

```bash
# Instalar cloudflared
curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 \
  -o cloudflared && chmod +x cloudflared && sudo mv cloudflared /usr/local/bin/

# Login (abre browser)
cloudflared tunnel login

# Crear túnel
cloudflared tunnel create fleetops

# Crear DNS
cloudflared tunnel route dns fleetops panel.monitoreocinexo.com.ar

# Obtener token
cloudflared tunnel token fleetops
```

Pegar el token en `CLOUDFLARE_TUNNEL_TOKEN` del `.env`.

### Activar WebSockets en Cloudflare (obligatorio)

**dash.cloudflare.com → monitoreocinexo.com.ar → Network → WebSockets → ON**

Sin esto el terminal SSH y los agentes no conectan.

---

## PASO 4 — Levantar

```bash
make up
# o: docker compose up -d --build
```

Verificar:
```bash
make status
make logs-tunnel   # debe decir: "Registered tunnel connection"
make logs-api      # debe decir: "FleetOps API → http://0.0.0.0:3000"
```

Acceder: **https://panel.monitoreocinexo.com.ar**
- Usuario: `admin`
- Password: el `ADMIN_PASSWORD` del `.env`

---

## Desarrollo local

```bash
# Terminal 1 — panel
make dev

# Terminal 2 — túnel (opcional, para probar con agentes reales)
make tunnel
```

Panel disponible en http://localhost:5173 sin túnel.
Con túnel: https://panel.monitoreocinexo.com.ar apunta a tu localhost.

---

## Instalar agente en un cliente

En el servidor del cliente, agregar al `.env`:

```env
FLEET_PANEL_URL=wss://panel.monitoreocinexo.com.ar/ws/agent
FLEET_CLIENT_ID=c_xxxx      # del tab Info del cliente en el panel
FLEET_TOKEN=tok-xxxx        # del tab Info del cliente en el panel
```

Agregar al `docker-compose.yml` del cliente:

```yaml
fleet-agent:
  image: nexosoluciones/fleet-agent:latest
  restart: unless-stopped
  environment:
    PANEL_WS_URL: ${FLEET_PANEL_URL}
    CLIENT_ID:    ${FLEET_CLIENT_ID}
    AGENT_TOKEN:  ${FLEET_TOKEN}
    COMPOSE_FILE: /opt/app/docker-compose.yml
  volumes:
    - /var/run/docker.sock:/var/run/docker.sock
    - ./docker-compose.yml:/opt/app/docker-compose.yml:ro
```

```bash
docker compose up -d fleet-agent
docker compose logs -f fleet-agent
# debe decir: [agent] Conectado al panel ✓
```

---

## Comandos útiles

```bash
make status          # estado de todos los contenedores
make logs            # logs en vivo de todo
make logs-api        # logs solo del backend
make restart-api     # reiniciar solo el backend
make backup-db       # backup manual de la DB del panel
make psql            # consola psql
make update          # git pull + rebuild
```

---

## Solución de problemas

**530 — túnel no conectado**
```bash
make logs-tunnel
# Si no dice "Registered tunnel connection":
# Verificar CLOUDFLARE_TUNNEL_TOKEN en .env
```

**400 en WebSocket de agentes**
- Verificar WebSockets ON en Cloudflare Dashboard
- Verificar que `config.yml` tiene las rutas `/ws/agent` y `/ws/ssh`

**API no arranca**
```bash
make logs-api
# "Cannot connect to database" → PostgreSQL no está listo todavía
# Esperar 10s y: make restart-api
```

**Frontend muestra pantalla en blanco**
```bash
# VITE_API_URL se inyecta en build time
# Si cambiás DOMAIN hay que rebuildar el frontend:
make build-web
```
