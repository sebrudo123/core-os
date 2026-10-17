# Core OS — imagen del Modo Demo Web (para self-hosting en cualquier VPS)
FROM node:20-alpine

WORKDIR /app

ENV NODE_ENV=production \
    PORT=3000

# Dependencias primero (mejor caché de capas)
COPY package*.json ./
RUN npm install --omit=dev --no-audit --no-fund && npm cache clean --force

# Código de la aplicación
COPY . .

EXPOSE 3000

# Healthcheck contra la propia API
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD node -e "fetch('http://127.0.0.1:'+(process.env.PORT||3000)+'/api/health').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"

CMD ["node", "server.js"]
