# ── Stage: Production image ──────────────────────────────────
FROM node:18-alpine

# Security: run as non-root user
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

# Set working directory
WORKDIR /app

# Copy dependency manifests first (leverages Docker layer caching)
COPY package.json package-lock.json ./

# Install production dependencies only (skip devDependencies)
RUN npm ci --omit=dev --ignore-scripts && \
    npm cache clean --force

# Copy application source code
COPY . .

# Change ownership to non-root user
RUN chown -R appuser:appgroup /app

# Switch to non-root user
USER appuser

# Expose the application port
EXPOSE 5000

# Configure the default PORT environment variable
ENV PORT=5000 \
    NODE_ENV=production

# Start the Fastify server
CMD ["node", "server.js"]
