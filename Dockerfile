# Production Dockerfile for SwagPay on Fly.io
FROM node:20-alpine

WORKDIR /app

# Install production dependencies
COPY package*.json ./
RUN npm ci --omit=dev || npm install --omit=dev

# Copy server, database schema, and Flutter Web release build
COPY server.js ./
COPY database/ ./database/
COPY build/web/ ./build/web/

ENV NODE_ENV=production
ENV PORT=8080

EXPOSE 8080

CMD ["node", "server.js"]
