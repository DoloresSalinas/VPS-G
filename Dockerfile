FROM node:18-alpine

# Directorio de trabajo dentro del contenedor
WORKDIR /usr/src/app

# Copia package.json y package-lock.json si existen
COPY PWA-server/package*.json ./

# Instala dependencias (si hay package.json)
RUN npm ci --only=production

# Copia todo el contenido de tu proyecto
COPY PWA-server/. .

# Define puerto
ENV PORT=3001
EXPOSE 3001

# Comando de inicio apuntando al index.js correcto
CMD ["node", "src/index.js"]
