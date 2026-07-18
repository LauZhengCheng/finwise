# ============================================
# Programmer    : Lau Zheng Cheng (TP071393)
# Program Name  : Dockerfile
# Description   : Container image for FinWise backend on Cloud Run.
#                 Installs production deps only, runs Express on the
#                 port Cloud Run injects via $PORT.
# First Written : 19-07-2026
# Edited on     : 19-07-2026
# ============================================

FROM node:22-slim

WORKDIR /app

# Install dependencies first (cached layer — rebuilds only when deps change)
COPY package*.json ./
RUN npm ci --omit=dev

# Copy application code
COPY . .

ENV NODE_ENV=production

CMD ["node", "server.js"]
