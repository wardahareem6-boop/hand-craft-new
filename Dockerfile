# syntax=docker/dockerfile:1
FROM node:24-bookworm-slim AS dependencies
WORKDIR /app
ENV NEXT_TELEMETRY_DISABLED=1
COPY package.json package-lock.json ./
RUN npm ci

FROM dependencies AS builder
ENV DOCKER_BUILD=true
COPY . .
RUN npm run build
RUN mkdir -p /app/.data && chown node:node /app/.data

# Maintenance tools retain the TypeScript runner for migration and optional demo bootstrap.
FROM builder AS tools
USER node
CMD ["npm", "run", "db:migrate"]

FROM node:24-bookworm-slim AS runner
WORKDIR /app
ENV NODE_ENV=production NEXT_TELEMETRY_DISABLED=1 HOSTNAME=0.0.0.0 PORT=3000
COPY --from=builder --chown=node:node /app/.next/standalone ./
COPY --from=builder --chown=node:node /app/.next/static ./.next/static
COPY --from=builder --chown=node:node /app/public ./public
COPY --from=builder --chown=node:node /app/drizzle ./drizzle
COPY --chown=node:node scripts/container-worker.mjs ./scripts/container-worker.mjs
RUN mkdir -p /app/.data/uploads && chown -R node:node /app/.data
USER node
EXPOSE 3000
HEALTHCHECK --interval=20s --timeout=10s --start-period=60s --retries=5 CMD node -e "fetch('http://127.0.0.1:3000/api/health').then(r=>{if(!r.ok)process.exit(1)}).catch(()=>process.exit(1))"
CMD ["node", "server.js"]
