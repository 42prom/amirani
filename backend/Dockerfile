# Stage 1: Build
FROM node:20-alpine AS builder

WORKDIR /app

COPY package*.json ./
COPY prisma ./prisma/
RUN npm ci

COPY . .
RUN npx prisma generate
RUN npm run build

# Stage 2: Runtime
FROM node:20-alpine

WORKDIR /app

ENV NODE_ENV=production

# Non-root user for container security
RUN addgroup -g 1001 -S nodejs && adduser -S nodejs -u 1001

RUN apk add --no-cache openssl libc6-compat

COPY --from=builder /app/package*.json ./
COPY --from=builder /app/dist         ./dist
COPY --from=builder /app/prisma       ./prisma
COPY --from=builder /app/node_modules ./node_modules
COPY docker-entrypoint.sh             /docker-entrypoint.sh

RUN chmod +x /docker-entrypoint.sh && chown -R nodejs:nodejs /app

USER nodejs

EXPOSE 3085

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget --quiet --tries=1 --spider http://localhost:3085/health || exit 1

ENTRYPOINT ["/docker-entrypoint.sh"]
