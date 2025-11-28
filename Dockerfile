FROM node:18-alpine

# Instalar curl para health checks
RUN apk add --no-cache curl

WORKDIR /usr/src/app

# Copiar package.json e instalar dependencias
COPY PWA-server/package*.json ./
RUN npm ci --only=production

# Copiar aplicación
COPY PWA-server/. .

# Crear usuario no-root para seguridad
RUN addgroup -g 1001 -S nodejs
RUN adduser -S nextjs -u 1001
RUN chown -R nextjs:nodejs /usr/src/app
USER nextjs

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:3001/health || exit 1

EXPOSE 3001

CMD ["node", "src/index.js"]