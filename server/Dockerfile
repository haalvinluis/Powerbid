# Multi-stage production Dockerfile for PowerBid Game Server
# Stage 1: Build TypeScript to JavaScript
FROM node:20-alpine AS builder

WORKDIR /app

# Copy root and server package files if any, then server package.json
COPY package*.json ./
COPY tsconfig.json ./
COPY src/ ./src/
COPY ../shared/ ../shared/

RUN npm ci
RUN npm run build

# Stage 2: Production Runtime
FROM node:20-alpine AS runner

WORKDIR /app
ENV NODE_ENV=production
ENV PORT=3000

# Install production dependencies only
COPY package*.json ./
RUN npm ci --only=production

# Copy compiled JavaScript output
COPY --from=builder /app/dist ./dist
COPY migrations/ ./migrations/

# Non-root user for security hardening
USER node

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:3000/health || exit 1

CMD ["node", "dist/index.js"]
