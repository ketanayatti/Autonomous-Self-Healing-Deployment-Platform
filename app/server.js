'use strict';

const path = require('path');

// ──────────────────────────────────────────────
//  Environment variables – read once at startup
// ──────────────────────────────────────────────
const APP_VERSION = process.env.APP_VERSION || 'v1';
const APP_ENV     = process.env.APP_ENV     || 'blue';   // "blue" | "green"
const PORT        = parseInt(process.env.PORT, 10) || 5000;

// FAILURE_MODE from env is the *initial* state; it can be toggled at
// runtime via /simulate-failure and /simulate-recovery.
let failureMode = (process.env.FAILURE_MODE || 'false').toLowerCase() === 'true';

// ──────────────────────────────────────────────
//  Bootstrap Fastify
// ──────────────────────────────────────────────
const fastify = require('fastify')({ logger: true });

// ──────────────────────────────────────────────
//  Serve static frontend from /public
// ──────────────────────────────────────────────
fastify.register(require('@fastify/static'), {
  root: path.join(__dirname, 'public'),
  prefix: '/',
});

// ──────────────────────────────────────────────
//  Routes
// ──────────────────────────────────────────────

/**
 * GET /
 * Welcome endpoint – returns a friendly message together with the
 * current version and deployment environment.
 */
fastify.get('/api', async (request, reply) => {
  return {
    message: 'Deployment platform test app',
    version: APP_VERSION,
    environment: APP_ENV,
  };
});

/**
 * GET /health
 * Health-check endpoint consumed by deployment scripts, load-balancers
 * and orchestrators to decide whether the instance is ready for traffic.
 *
 * • When the app is healthy  → HTTP 200  { status: "ok", version }
 * • When failure mode is on  → HTTP 500  { status: "failure" }
 */
fastify.get('/health', async (request, reply) => {
  if (failureMode) {
    reply.code(500);
    return { status: 'failure' };
  }
  return {
    status: 'ok',
    version: APP_VERSION,
  };
});

/**
 * GET /version
 * Simple metadata endpoint that exposes the running version and colour
 * (blue / green) of this instance.
 */
fastify.get('/version', async (request, reply) => {
  return {
    version: APP_VERSION,
    environment: APP_ENV,
  };
});

/**
 * GET /simulate-failure
 * Flips the in-memory failure flag ON so that subsequent calls to
 * /health will return HTTP 500.  Useful for testing rollback flows.
 */
fastify.get('/simulate-failure', async (request, reply) => {
  failureMode = true;
  return {
    message: 'Failure mode enabled – /health will now return HTTP 500',
    failureMode: true,
  };
});

/**
 * GET /simulate-recovery
 * Flips the in-memory failure flag OFF so that /health returns 200
 * again.  Useful for testing recovery / self-healing flows.
 */
fastify.get('/simulate-recovery', async (request, reply) => {
  failureMode = false;
  return {
    message: 'Recovery complete – /health will now return HTTP 200',
    failureMode: false,
  };
});

// ──────────────────────────────────────────────
//  Start the server
// ──────────────────────────────────────────────
const start = async () => {
  try {
    await fastify.listen({ port: PORT, host: '0.0.0.0' });
    // Structured startup log required by the spec
    console.log(`App starting | version=${APP_VERSION} | env=${APP_ENV} | port=${PORT}`);
  } catch (err) {
    fastify.log.error(err);
    process.exit(1);
  }
};

start();
