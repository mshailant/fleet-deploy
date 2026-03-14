# ════════════════════════════════════════════════════════════════════
#  FleetOps — Makefile
#  Atajos para los comandos más comunes
# ════════════════════════════════════════════════════════════════════

.PHONY: up down build logs restart status tunnel backup-db

# ── Producción ───────────────────────────────────────────────────────

## Levantar todo en producción
up:
	docker compose up -d --build

## Bajar todo
down:
	docker compose down

## Rebuild solo el backend
build-api:
	docker compose build api && docker compose up -d api

## Rebuild solo el frontend
build-web:
	docker compose build web && docker compose up -d web

## Ver logs en vivo
logs:
	docker compose logs -f

## Logs solo del backend
logs-api:
	docker compose logs -f api

## Logs del túnel
logs-tunnel:
	docker compose logs -f cloudflared

## Estado de los contenedores
status:
	docker compose ps

## Reiniciar solo el backend
restart-api:
	docker compose restart api

# ── Desarrollo local ─────────────────────────────────────────────────

## Levantar en modo desarrollo
dev:
	docker compose -f docker-compose.local.yml up -d --build

## Bajar modo desarrollo
dev-down:
	docker compose -f docker-compose.local.yml down

## Logs en desarrollo
dev-logs:
	docker compose -f docker-compose.local.yml logs -f

## Instalar deps del backend dentro del contenedor local
dev-install:
	docker compose -f docker-compose.local.yml exec api npm install

# ── Cloudflare Tunnel (dev local) ────────────────────────────────────

## Levantar túnel apuntando al localhost
tunnel:
	cloudflared tunnel --config cloudflared/config.local.yml run fleetops

# ── Base de datos ────────────────────────────────────────────────────

## Backup manual de la DB del panel
backup-db:
	docker compose exec postgres pg_dump -U fleetops fleetops > backup_$$(date +%Y%m%d_%H%M%S).sql
	@echo "✓ Backup guardado"

## Conectarse a psql del panel
psql:
	docker compose exec postgres psql -U fleetops fleetops

# ── Actualizaciones ──────────────────────────────────────────────────

## Actualizar a la última versión (git pull + rebuild)
update:
	git pull
	docker compose up -d --build api web
	@echo "✓ Panel actualizado"
