# DevOps Deployment Test App

> A lightweight **Fastify** application purpose-built for **validating DevOps deployment pipelines** — blue/green switching, health-check probes, failure simulation, and rollback verification. Includes a **real-time DevOps Dashboard** for visual monitoring and control.

---

## Table of Contents

1. [Why This App Exists](#1-why-this-app-exists)
2. [How It Works — Internal Workflow](#2-how-it-works--internal-workflow)
3. [Project Structure](#3-project-structure)
4. [Environment Variables](#4-environment-variables)
5. [Getting Started](#5-getting-started)
6. [Dashboard — Real-Time Monitoring UI](#6-dashboard--real-time-monitoring-ui)
7. [API Reference](#7-api-reference)
8. [Deployment Scenarios — Where & When](#8-deployment-scenarios--where--when)
9. [Step-by-Step Walkthrough](#9-step-by-step-walkthrough)
10. [Architecture Diagram](#10-architecture-diagram)

---

## 1. Why This App Exists

When you build a deployment platform — whether it uses **blue/green**, **canary**, or **rolling** strategies — you need a **controllable test application** that lets you:

| Need | How this app addresses it |
|---|---|
| Verify traffic is routed to the correct environment | `GET /api` and `GET /version` return the colour (`blue` / `green`) and version |
| Test health-check integration | `GET /health` responds with `200 OK` or `500 Internal Server Error` based on the app's failure state |
| Simulate a bad deployment | `GET /simulate-failure` flips the health-check to failing mode **in memory** |
| Verify rollback / recovery | `GET /simulate-recovery` restores the health-check to healthy mode |
| Confirm the correct version is deployed | Every response includes the `APP_VERSION` value |
| Visually monitor deployment health | Real-time dashboard at `GET /` shows status, version, environment, and activity log |

Without a controllable app like this, you would have to **intentionally break real application code** to test your deployment platform — which is risky and hard to reproduce.

---

## 2. How It Works — Internal Workflow

```
┌─────────────────────────────────────────────────────────────────┐
│                        server.js  (startup)                     │
│                                                                 │
│  1. Read environment variables:                                 │
│        APP_VERSION, APP_ENV, PORT, FAILURE_MODE                 │
│                                                                 │
│  2. Initialise an in-memory boolean: `failureMode`              │
│        (seeded from FAILURE_MODE env var, default = false)      │
│                                                                 │
│  3. Create Fastify instance with built-in logger                │
│                                                                 │
│  4. Register @fastify/static to serve public/ directory on /    │
│                                                                 │
│  5. Register five API route handlers (see §7)                   │
│                                                                 │
│  6. Call `fastify.listen()` on PORT, binding 0.0.0.0            │
│                                                                 │
│  7. Print structured startup log:                               │
│        "App starting | version=v1 | env=blue | port=5000"       │
└─────────────────────────────────────────────────────────────────┘
```

### Request flow

```
Client ──▶ GET /health
               │
               ▼
        ┌──────────────┐
        │ failureMode? │
        └──────┬───────┘
          false │         true
               ▼              ▼
         HTTP 200          HTTP 500
     { status: "ok" }   { status: "failure" }
```

### Failure toggle flow

```
GET /simulate-failure
        │
        ▼
  failureMode = true   ──▶  /health now returns 500
        │
        │  (later)
        ▼
GET /simulate-recovery
        │
        ▼
  failureMode = false  ──▶  /health now returns 200
```

The toggle is **in-memory only** — restarting the process resets the state back to whatever `FAILURE_MODE` env var says. This is deliberate: in a real pipeline, the orchestrator restarts containers, so the toggle should not persist.

---

## 3. Project Structure

```
devops/
├── server.js           # Application entry point (API routes + static file serving)
├── package.json        # NPM manifest (fastify + @fastify/static dependencies)
├── package-lock.json
├── public/
│   └── index.html      # Real-time DevOps Dashboard (single-page frontend)
└── README.md           # This file
```

**Why this structure?**  
This app is a **deployment target**, not a production service. Keeping the backend in a single file and the frontend in a single HTML file makes it:
- Easy to read and audit in CI logs
- Simple to containerise (`COPY server.js . && COPY public/ ./public/`)
- Quick to modify during pipeline experiments
- Self-contained — the dashboard requires **no build step** or external assets (aside from Google Fonts)

---

## 4. Environment Variables

| Variable | Type | Default | Description |
|---|---|---|---|
| `APP_VERSION` | `string` | `v1` | Semantic or arbitrary version tag shown in responses |
| `APP_ENV` | `string` | `blue` | Deployment colour — typically `blue` or `green` |
| `PORT` | `number` | `5000` | TCP port the server listens on |
| `FAILURE_MODE` | `boolean string` | `false` | If `"true"`, the app boots into failing state (`/health → 500`) |

### How the variables are consumed

```
process.env.APP_VERSION  ──▶  const APP_VERSION  (string, used in responses)
process.env.APP_ENV      ──▶  const APP_ENV      (string, used in responses)
process.env.PORT         ──▶  parseInt(...)       (number, passed to fastify.listen)
process.env.FAILURE_MODE ──▶  let failureMode    (boolean, controls /health behaviour)
```

> **Note:** `APP_VERSION` and `APP_ENV` are **immutable constants** once the process starts. Only `failureMode` can change at runtime (via `/simulate-failure` and `/simulate-recovery`).

---

## 5. Getting Started

### Prerequisites

- **Node.js** ≥ 18 (LTS recommended)
- **npm** ≥ 9

### Install dependencies

```bash
npm install
```

### Run with defaults

```bash
npm start
```

The server starts on `http://localhost:5000` with `version=v1`, `env=blue`, `failureMode=false`.  
Open **http://localhost:5000** in your browser to access the **DevOps Dashboard**.

### Run with custom environment

```bash
# PowerShell
$env:APP_VERSION="v2"; $env:APP_ENV="green"; $env:PORT="3000"; $env:FAILURE_MODE="false"; node server.js

# Bash / Linux / macOS
APP_VERSION=v2 APP_ENV=green PORT=3000 FAILURE_MODE=false node server.js
```

### Quick smoke test

```bash
curl http://localhost:5000/api             # welcome + version info
curl http://localhost:5000/health
curl http://localhost:5000/version
curl http://localhost:5000/simulate-failure
curl http://localhost:5000/health           # now returns 500
curl http://localhost:5000/simulate-recovery
curl http://localhost:5000/health           # back to 200
```

---

## 6. Dashboard — Real-Time Monitoring UI

When you open `http://localhost:5000` in a browser, you are served the **DevOps Dashboard** — a single-page frontend (`public/index.html`) that provides:

| Feature | Description |
|---|---|
| **Status Banner** | Large, colour-coded indicator showing whether the service is healthy, degraded, or connecting |
| **Info Cards** | At-a-glance cards for Status, Version, Environment (blue/green tag), and Uptime Checks (with success rate) |
| **Action Buttons** | One-click buttons to Simulate Failure, Simulate Recovery, Manual Health Check, and Fetch Version Info |
| **Auto-Refresh** | Configurable polling toggle (3s / 5s / 10s / 30s intervals) for continuous health monitoring |
| **Activity Log** | Timestamped event log with colour-coded indicators (ok / error / warn / info) and HTTP status badges |

The dashboard is **entirely self-contained** in a single HTML file with inline CSS and JavaScript — no build step required. It communicates with the backend API endpoints (`/health`, `/version`, `/simulate-failure`, `/simulate-recovery`) via `fetch()` calls.

> **Note:** The dashboard uses **Inter** and **JetBrains Mono** from Google Fonts for typography. An internet connection is required on first load to fetch these fonts.

---

## 7. API Reference

### `GET /` (Dashboard)

**Purpose:** Serves the static DevOps Dashboard frontend from `public/index.html`.

| Field | Value |
|---|---|
| Status | `200 OK` |
| Content-Type | `text/html` |

---

### `GET /api`

**Purpose:** Welcome / root API endpoint — confirms the app is reachable and identifies itself.

| Field | Value |
|---|---|
| Status | `200 OK` |
| Content-Type | `application/json` |

**Response body:**

```json
{
  "message": "Deployment platform test app",
  "version": "v1",
  "environment": "blue"
}
```

---

### `GET /health`  

**Purpose:** Health probe consumed by load balancers, Kubernetes liveness/readiness probes, or custom deployment scripts.

**When healthy** (`failureMode === false`):

| Field | Value |
|---|---|
| Status | `200 OK` |

```json
{
  "status": "ok",
  "version": "v1"
}
```

**When failing** (`failureMode === true`):

| Field | Value |
|---|---|
| Status | `500 Internal Server Error` |

```json
{
  "status": "failure"
}
```

**Why this matters:**  
Deployment scripts typically poll `/health` after spinning up a new container. If the response is not `200` within a timeout, the deployment is rolled back.

---

### `GET /version`

**Purpose:** Returns the version and environment metadata — useful for scripted assertions in CI.

| Field | Value |
|---|---|
| Status | `200 OK` |

```json
{
  "version": "v1",
  "environment": "blue"
}
```

---

### `GET /simulate-failure`

**Purpose:** Toggles `failureMode = true` so that `/health` starts returning `500`.

| Field | Value |
|---|---|
| Status | `200 OK` |

```json
{
  "message": "Failure mode enabled – /health will now return HTTP 500",
  "failureMode": true
}
```

**When to use:**  
Call this endpoint **during a deployment test** to simulate a bad release. Your deployment platform should detect the failing health check and automatically roll back.

---

### `GET /simulate-recovery`

**Purpose:** Toggles `failureMode = false` so that `/health` returns `200` again.

| Field | Value |
|---|---|
| Status | `200 OK` |

```json
{
  "message": "Recovery complete – /health will now return HTTP 200",
  "failureMode": false
}
```

**When to use:**  
After testing a failure scenario, call this to restore the app to a healthy state without restarting the container.

---

## 8. Deployment Scenarios — Where & When

### Scenario 1: Blue/Green Deployment Validation

```
 ┌───────────┐       ┌───────────┐
 │  BLUE     │       │  GREEN    │
 │  v1       │       │  v2       │
 │  port 5000│       │  port 5001│
 └─────┬─────┘       └─────┬─────┘
       │                    │
       └──────┬─────────────┘
              │
        ┌─────▼─────┐
        │  LOAD     │
        │  BALANCER │
        └───────────┘
```

1. **Deploy GREEN** with `APP_VERSION=v2 APP_ENV=green PORT=5001`.
2. **Health-check GREEN** — `curl http://green:5001/health` → `200`.
3. **Switch traffic** from BLUE to GREEN at the load balancer.
4. **Verify** — `curl http://lb/version` → should return `v2 / green`.
5. **Simulate failure** — `curl http://green:5001/simulate-failure`.
6. **Observe rollback** — deployment script detects `500` and switches back to BLUE.

### Scenario 2: Kubernetes Readiness Probe

```yaml
# In your Kubernetes deployment manifest
readinessProbe:
  httpGet:
    path: /health
    port: 5000
  initialDelaySeconds: 5
  periodSeconds: 10
```

Kubernetes will automatically stop routing traffic to the pod if `/health` returns a non-2xx status.

### Scenario 3: Docker Compose Local Testing

```yaml
services:
  blue:
    build: .
    environment:
      - APP_VERSION=v1
      - APP_ENV=blue
      - PORT=5000
      - FAILURE_MODE=false
    ports:
      - "5000:5000"

  green:
    build: .
    environment:
      - APP_VERSION=v2
      - APP_ENV=green
      - PORT=5001
      - FAILURE_MODE=false
    ports:
      - "5001:5001"
```

---

## 9. Step-by-Step Walkthrough

This section traces what happens **from `node server.js` to a response being served**.

### Step 1 — Process starts

Node.js loads `server.js`. The top of the file immediately reads four environment variables and stores them as module-level constants/variables:

```
APP_VERSION  →  const (immutable for the lifetime of the process)
APP_ENV      →  const (immutable)
PORT         →  const (parsed to integer)
failureMode  →  let   (mutable – can be toggled by API calls)
```

### Step 2 — Fastify is instantiated

```js
const fastify = require('fastify')({ logger: true });
```

- `logger: true` enables Fastify's built-in **Pino** logger, which outputs structured JSON logs to stdout. These are ideal for log aggregation tools (ELK, CloudWatch, Datadog, etc.).

### Step 3 — Static file serving is registered

```js
fastify.register(require('@fastify/static'), {
  root: path.join(__dirname, 'public'),
  prefix: '/',
});
```

This serves the `public/` directory at the root path. When a browser visits `/`, it receives `public/index.html` — the DevOps Dashboard.

### Step 4 — API routes are registered

Five `fastify.get(...)` calls register the API handler functions (`/api`, `/health`, `/version`, `/simulate-failure`, `/simulate-recovery`). At this point **no HTTP server is listening yet** — Fastify is just building its internal routing tree.

### Step 5 — Server starts listening

```js
await fastify.listen({ port: PORT, host: '0.0.0.0' });
```

- `host: '0.0.0.0'` ensures the server is reachable **from outside the container** (Docker, Kubernetes, etc.). Without this, Fastify defaults to `127.0.0.1`, which is only reachable from inside the container.

### Step 6 — Startup log is printed

```
App starting | version=v1 | env=blue | port=5000
```

This line is consumed by deployment scripts that `docker logs` or `kubectl logs` the container to confirm it started correctly.

### Step 7 — Requests are served

Every incoming request is matched against the route tree. Static file requests (e.g. `/`, `/index.html`) are handled by `@fastify/static`; API requests are matched by Fastify's radix-tree router — O(log n), extremely fast even under load.

### Step 8 — Failure simulation (optional)

A `GET /simulate-failure` request flips `failureMode = true`. From this point on, every `GET /health` request returns `500`. The deployment platform detects this and triggers its rollback procedure. The dashboard detects this automatically via its polling loop and updates the UI in real time.

### Step 9 — Recovery (optional)

A `GET /simulate-recovery` request flips `failureMode = false`. Health checks pass again. The dashboard reflects the healthy state on the next polling cycle.

---

## 10. Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                            server.js                                    │
│                                                                         │
│  ┌──────────────────────┐    ┌──────────────────────────────────────┐   │
│  │  Environment Vars    │    │  In-Memory State                    │   │
│  │                      │    │                                      │   │
│  │  APP_VERSION (const) │    │  failureMode (let)                  │   │
│  │  APP_ENV     (const) │    │    ▲           ▲                    │   │
│  │  PORT        (const) │    │    │           │                    │   │
│  └──────────┬───────────┘    │  /simulate  /simulate               │   │
│             │                │  -failure   -recovery                │   │
│             ▼                └──────────────────────────────────────┘   │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │               @fastify/static (plugin)                           │   │
│  │                                                                  │   │
│  │   GET /   → serves public/index.html  (DevOps Dashboard)        │   │
│  └──────────────────────────────────────────────────────────────────┘   │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │                    Fastify Router (API)                          │   │
│  │                                                                  │   │
│  │   GET /api               → welcome + version + env              │   │
│  │   GET /health            → 200 or 500 (reads failureMode)      │   │
│  │   GET /version           → version + env                       │   │
│  │   GET /simulate-failure  → sets failureMode = true             │   │
│  │   GET /simulate-recovery → sets failureMode = false            │   │
│  │                                                                  │   │
│  └──────────────────────────────────────────────────────────────────┘   │
│                                                                         │
│  fastify.listen({ port: PORT, host: '0.0.0.0' })                       │
└─────────────────────────────────────────────────────────────────────────┘

                    ┌─────────────────────────────┐
                    │     Browser (Dashboard)     │
                    │                             │
                    │  fetch('/health')     ──────┤──▶ Status Banner + Cards
                    │  fetch('/version')    ──────┤──▶ Version & Env Cards
                    │  fetch('/simulate-*') ──────┤──▶ Action Buttons
                    │                             │
                    │  Auto-polling (3–30s)       │
                    │  Activity Log (50 entries)  │
                    └─────────────────────────────┘
```

---

## License

MIT
