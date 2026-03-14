# ── Stage: dev (hot reload con ts-node-dev) ──────────────────────────
FROM node:20-alpine AS dev
WORKDIR /app
COPY package*.json tsconfig.json nest-cli.json ./
RUN npm ci
COPY src/ ./src/
CMD ["npm", "run", "watch"]

# ── Stage: builder (compilar TypeScript) ─────────────────────────────
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json tsconfig.json nest-cli.json ./
RUN npm ci
COPY src/ ./src/
RUN npm run build

# ── Stage: prod (imagen final liviana) ───────────────────────────────
FROM node:20-alpine AS prod
WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev
COPY --from=builder /app/dist ./dist
EXPOSE 3000
CMD ["node", "dist/main"]
