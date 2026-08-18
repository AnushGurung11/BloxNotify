# ---- deps: install production dependencies ----
FROM node:22-alpine AS deps
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev

# ---- runtime ----
FROM node:22-alpine
ENV NODE_ENV=production
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .

# The state file (data/last-known-stock.json) is written at runtime; the
# directory is writable by default. Mount a volume here to persist across
# redeploys if you want the "last stock" to survive restarts.
EXPOSE 3000
CMD ["node", "src/index.js"]