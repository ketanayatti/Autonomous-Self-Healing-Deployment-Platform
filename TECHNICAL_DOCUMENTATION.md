# Autonomous Self-Healing Deployment Platform — Technical Documentation

> Production-grade blue-green deployment orchestration with intelligent health monitoring and automated rollback—eliminating deployment downtime and manual intervention toil.

## Table of Contents

- [Project Overview](#project-overview)
- [Architecture Summary](#architecture-summary)
- [Technology Stack](#technology-stack)
- [System Design & Rationale](#system-design--rationale)
- [Setup & Configuration](#setup--configuration)
- [Deployment Workflow](#deployment-workflow)
- [Infrastructure Overview](#infrastructure-overview)
- [Health Monitoring & Rollback Strategy](#health-monitoring--rollback-strategy)
- [Failure Handling & Recovery](#failure-handling--recovery)
- [API Reference](#api-reference)
- [Operational Considerations](#operational-considerations)

---

## Project Overview

The **Autonomous Self-Healing Deployment Platform** is a containerized deployment orchestration system designed to eliminate the operational friction of traditional release workflows. Built on Linux and Docker, it implements blue-green deployments with automated health monitoring and intelligent rollback, enabling zero-downtime releases without manual intervention.

The system serves dual purposes: **(1)** production-grade deployment automation for real applications, and **(2)** a fully instrumented test harness for validating CI/CD pipelines, load balancers, and orchestrators against deployment failure scenarios. The platform prioritizes operational clarity—every deployment decision is logged, every failure is predictable, and every rollback is deterministic.

### Core Problem Statement

Traditional rolling deployments and manual rollback procedures introduce operational risk and downtime windows. This platform solves that by:
- **Eliminating deployment windows** through parallel environment provisioning
- **Automating failure detection** via continuous health checks
- **Removing manual rollback decisions** through deterministic, scripted recovery

---

## Architecture Summary

The system operates on a **two-tier deployment model** using simultaneous blue and green environments, with Nginx serving as the intelligent routing layer.

```
┌─────────────────────────────────────────────────────────────┐
│                    EXTERNAL TRAFFIC                         │
└──────────────┬──────────────────────────────────────────────┘
               │
               ▼
        ┌─────────────┐
        │   NGINX     │
        │ Reverse     │
        │ Proxy       │  Dynamic routing based on
        │             │  state/active_version.txt
        └────┬────┬───┘
             │    │
        ┌────▼─┐ ┌┴────────┐
        │ BLUE │ │ GREEN   │
        │ :5001│ │ :5002   │
        │      │ │         │
        │ App  │ │ App     │
        │ v1.x │ │ v2.x    │
        │      │ │ (staging)
        └──────┘ └─────────┘
```

**Key Design Principle:** The blue environment serves live traffic. The green environment is the deployment target—either staging for validation or live after traffic is switched. The NGINX configuration is updated dynamically; no reload of the entire service is required (leveraging `nginx -s reload`).

### Deployment Flow (Simplified)

1. **Build Phase** – Docker image built for new version
2. **Provision Phase** – Container started on idle environment (green)
3. **Health Check Phase** – Retry loop polls `/health` until passing or max retries exceeded
4. **Traffic Switch Phase** – On success, NGINX re-pointed to new environment; state file updated
5. **Automatic Rollback Phase** – On failure, container stopped; traffic remains on previous environment

This design ensures that:
- Failed deployments never reach production traffic
- Deployments are atomic at the routing layer (traffic switch happens in NGINX config + state file update)
- Previous environment remains running and immediately switchable if post-deployment issues arise

---

## Technology Stack

| Layer | Technology | Version | Purpose | Notes |
|-------|-----------|---------|---------|-------|
| **Compute** | Node.js | 18-Alpine | Application runtime | Alpine for minimal image size (~150MB) |
| **Application** | Fastify | 5.3.2 | HTTP framework | Low-latency, high-throughput request handling |
| **Reverse Proxy** | NGINX | Latest | Traffic routing | Handles layer 7 health state, dynamic config injection |
| **Containerization** | Docker | 20.10+ | Isolation & portability | Single-layer caching strategy via Dockerfile layer order |
| **Orchestration** | Bash | 4.0+ | Deployment automation | Deterministic, no external dependencies (no Kubernetes, Terraform, or cloud SDKs) |
| **State Management** | File System | N/A | Version tracking | Single-source-of-truth: `/state/active_version.txt` |
| **Logging** | File-based | N/A | Audit trail | `/logs/deployment.log` (append-only, sequential ordering preserved) |

### Dependency Rationale

- **Bash instead of Python/Go** – Eliminates runtime dependencies; works on any POSIX-compliant Linux distribution without installation overhead
- **File-based state** – Avoids database/external coordinator complexity; enables replicas or manual intervention without consensus issues
- **Alpine Linux** – Reduces attack surface, image pull latency, and storage overhead for at-scale deployments
- **Fastify** – Chosen for low memory footprint and middleware-first design; suitable for embedded health checks and failure simulation

---

## System Design & Rationale

### Blue-Green Topology Rationale

This system uses **simultaneous blue and green environments** rather than rolling deployments for these reasons:

| Aspect | Blue-Green | Rolling Deployment |
|--------|-----------|-------------------|
| **Deployment Window** | Zero—traffic switches atomically | Non-zero—staged instance-by-instance |
| **Rollback Cost** | Single NGINX config switch | Redeploy previous version to N instances |
| **Resource Overhead** | 2x compute (constant) | 1x compute (during rollout, temporary) |
| **Testing Window** | Full green environment available for smoke tests pre-switch | Limited to canary instance |
| **Operational Clarity** | One active, one staging—state is binary | Multiple versions in transit |

**Tradeoff Accepted:** 2x permanent compute overhead in exchange for zero-downtime, predictable rollback, and operational simplicity. For teams managing multi-instance systems, the eliminated operational complexity outweighs the storage cost.

### Health Check Design

```
┌─ Deployment Script ──────────────────────────────────────┐
│                                                          │
│  while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do             │
│    HEALTH=$(curl http://target:port/health)             │
│    if [[ 200 ]] → PASS → switch traffic                 │
│    else        → RETRY after 2s delay                   │
│  done                                                    │
│                                                          │
│  if [ FAILED ]: stop container, keep old traffic intact  │
└──────────────────────────────────────────────────────────┘
```

**Retry Configuration:**
- **Max Retries:** 10 attempts
- **Interval:** 2 seconds
- **Total timeout:** ~20 seconds

This provides a **20-second readiness window**—sufficient for Node.js startup, dependency initialization, and first database connection. Failures after this window result in automatic rollback without manual intervention.

---

## Setup & Configuration

### Prerequisites

- **OS:** Linux (Ubuntu 20.04 LTS or equivalent)
- **Runtime:** Docker Engine 20.10+ (with Docker daemon running)
- **Tools:** Bash 4.0+, `curl`, `sed`, standard GNU utilities
- **Disk:** ≥2 GB for two container images
- **Network:** Localhost ports 80 (NGINX), 5001 (blue), 5002 (green) must be available

### Initial Setup

```bash
# 1. Clone or extract project
cd /opt/deployment-platform

# 2. Ensure directory structure
mkdir -p logs state
touch logs/deployment.log
echo "blue" > state/active_version.txt

# 3. Make deployment script executable
chmod +x scripts/deploy.sh

# 4. Pre-build the Docker image (optional, to avoid build latency during first deployment)
docker build -t deployment-app:v0.0.0 app/

# 5. Verify NGINX container is running (handles traffic routing)
docker run -d --name nginx-lb -p 80:80 \
  -v $(pwd)/nginx/nginx.conf:/etc/nginx/nginx.conf \
  nginx:latest

# 6. Test baseline connectivity
curl http://localhost/api
# Expected: { message: "Deployment platform test app", version: "v0.0.0", environment: "blue" }
```

### Environment Variables

The application reads the following at startup (immutable per container lifecycle):

| Variable | Default | Purpose | Set By |
|----------|---------|---------|--------|
| `APP_VERSION` | `v1` | Semantic version identifier | Deployment script |
| `APP_ENV` | `blue` | Deployment slot identifier (blue\|green) | Deployment script |
| `PORT` | `5000` | Internal container port | Dockerfile ENV |
| `FAILURE_MODE` | `false` | Simulate application failure (true\|false) | Test harness |

**Example deployment invocation:**
```bash
./scripts/deploy.sh v1.2.3
```

This triggers a Docker build tagged `deployment-app:v1.2.3`, and passes `APP_VERSION=v1.2.3` to the container at runtime.

### State File Format

**File:** `/state/active_version.txt`  
**Content:** Single line containing `blue` or `green`  
**Semantics:** Indicates which environment is currently receiving production traffic

This is the single source of truth. Both the deployment script and NGINX configuration reference this file to determine routing behavior.

---

## Deployment Workflow

### Phase 1: Pre-Deployment Validation

```
Input: VERSION (semantic version string, e.g., v2.1.0)
├─ Check ACTIVE_ENV from state file
├─ Determine TARGET_ENV (opposite of ACTIVE_ENV)
└─ Log deployment initiation with timestamp
```

### Phase 2: Container Build

```
Action: docker build -t deployment-app:$VERSION $APP_DIR
├─ Multi-stage build (implicit via Dockerfile structure)
├─ Caching strategy: package manifests copied first
├─ Non-root user created (appuser:appgroup)
├─ Base image: node:18-alpine (~150 MB)
└─ On failure: log error, exit(1) - no traffic switched
```

**Build Duration:** ~15–30 seconds (on cold cache), ~2–5 seconds (warm cache with layer reuse)

### Phase 3: Container Provisioning

```
Action: docker rm -f $TARGET_ENV  # Remove any stale instance
        docker run -d --name $TARGET_ENV -p $TARGET_PORT:5000 \
          -e APP_VERSION=$VERSION \
          -e APP_ENV=$TARGET_ENV \
          deployment-app:$VERSION

├─ Target port: 5001 (if blue) or 5002 (if green)
├─ Run in background (-d flag)
├─ Health checks managed by script (not Docker --health-cmd)
└─ Container immediately begins accepting connections
```

### Phase 4: Health Check & Retry Loop

```
Retry Loop:
├─ Interval: 2 seconds
├─ Max attempts: 10
├─ Condition: HTTP GET /health → HTTP 200
│
└─ Outcomes:
   ├─ Success (200 received): Proceed to Phase 5
   ├─ Non-200 or connection error: Retry or fail
   └─ Max retries exceeded: Rollback (Phase 6)
```

**Critical Design Note:** Health checks run *outside* the container. This ensures:
- Dead container process doesn't report false "healthy"
- Network issues between host and container are detected
- Load balancer sees same health status as deployment script

### Phase 5: Traffic Switch

On successful health check, **three operations execute in rapid sequence:**

1. **Update NGINX Configuration**
   ```bash
   sed -i "s/server host.docker.internal:[0-9]*/server host.docker.internal:$TARGET_PORT/" \
     $NGINX_CONF
   ```
   Inline replacement of upstream port; sed used for determinism and portability.

2. **Reload NGINX (Hot Reload)**
   ```bash
   docker exec $(docker ps -q --filter ancestor=nginx) nginx -s reload
   ```
   - `-s reload` — graceful reload; existing connections drain, new connections route to new upstream
   - No traffic loss; existing client connections remain open
   - Duration: <100ms

3. **Persist State**
   ```bash
   echo $TARGET_ENV > $STATE_FILE
   ```
   Single atomic write (in practice, the kernel guarantee on single-block writes makes this safe).

### Phase 6: Automatic Rollback (On Failure)

If health check fails after max retries:

```bash
docker rm -f $TARGET_ENV
# Previous environment continues serving traffic unchanged
# Deployment marked FAILED in log
exit 1
```

**No traffic is switched.** The old environment remains active. The failed container is removed to free resources. Manual investigation required; no automatic retry.

---

## Infrastructure Overview

### Container Architecture

```
host.docker.internal (Docker internal DNS)
│
├─ nginx:latest (port 80)
│  ├─ Listens on :80 (HTTP)
│  ├─ Routes to upstream (blue:5001 or green:5002)
│  ├─ Adds X-Forwarded-For, X-Real-IP headers
│  └─ Reloaded via `docker exec nginx -s reload`
│
├─ deployment-app:vX.Y.Z (port 5001 or 5002)
│  ├─ Runs as appuser (non-root)
│  ├─ Fastify framework listening on :5000 (mapped to host port)
│  ├─ Serves /public static assets
│  ├─ Provides /health, /api, /version endpoints
│  └─ Listens for /simulate-failure and /simulate-recovery (test harness)
│
└─ previous deployment-app:vA.B.C (opposite port)
   └─ Remains running and ready for instant fallback
```

### File System Layout

```
/opt/deployment-platform/
├── app/                          # Application source
│   ├── Dockerfile                 # Alpine-based, non-root execution
│   ├── package.json               # Fastify 5.3.2 + @fastify/static
│   ├── server.js                  # 250 lines; HTTP routes + health checks
│   └── public/                    # Static assets (served by Fastify)
│       └── index.html             # Deployment dashboard UI
│
├── nginx/                         # Reverse proxy configuration
│   └── nginx.conf                 # Upstream routing (dynamically updated)
│
├── scripts/                       # Orchestration
│   └── deploy.sh                  # Main deployment automation (180 lines)
│
├── state/                         # Persistent state
│   └── active_version.txt         # "blue" or "green" (single line)
│
├── logs/                          # Audit trail
│   └── deployment.log             # Append-only log of all deployments
│
└── README.md                      # User-facing overview
```

### Network Topology

```
External Client
      │
      ▼ (HTTP :80)
   NGINX (port 80)
      │
      ├─ X-Forwarded-For: client IP
      ├─ X-Real-IP: client IP
      └─ Host: preserved
           │
           ▼
     upstream (blue:5001 or green:5002)
           │
           ├─ Blue (5001)  ─ deployment-app container on port 5000
           └─ Green (5002) ─ deployment-app container on port 5000
```

---

## Health Monitoring & Rollback Strategy

### Health Check Endpoint Design

**Endpoint:** `GET /health`  
**Response (Healthy):**
```json
{
  "status": "ok",
  "version": "v1.2.3"
}
```
HTTP 200

**Response (Failure Mode):**
```json
{
  "status": "failure"
}
```
HTTP 500

**Logic:**
```javascript
if (failureMode) {
  reply.code(500);
  return { status: "failure" };
}
return { status: "ok", version: APP_VERSION };
```

**Why this design:**
- **Minimal payload** – No extraneous fields; load balancers parse only `status` and HTTP code
- **Version inclusion** – Deployment script can verify correct version is running post-switch
- **Stateful failure mode** – Toggled at runtime via `/simulate-failure` (useful for chaos engineering)

### Automatic Rollback Conditions

| Condition | Action | Result |
|-----------|--------|--------|
| Health check passes (HTTP 200) within 10 retries | Switch traffic | ✅ Deployment succeeds |
| Health check fails after 10 × 2s retries (~20s) | `docker rm $TARGET_ENV`, log failure, exit(1) | ❌ Rollback automatic; traffic stays on old env |
| Docker build fails | Log error, exit(1) before container starts | ❌ No traffic change |
| NGINX reload fails | Health check already passed; rollback impossible (operational intervention required) | ⚠️ Rare; requires manual fix |

### Observability

**Deployment Log Format:**
```
Fri May 12 10:23:45 UTC 2026 Starting deployment: version=v2.0.0 target=green
Fri May 12 10:23:52 UTC 2026 Docker image built: deployment-app:v2.0.0
Fri May 12 10:24:02 UTC 2026 Health check passed; traffic switched to green
```

**Log Location:** `/logs/deployment.log`

Logs are append-only and human-readable. No structured logging (JSON) is used; timestamps are UTC and machine-parseable via `grep` and `awk`.

---

## Failure Handling & Recovery

### Predictable Failure Modes

#### 1. **Docker Build Failure**
- **Symptom:** Dockerfile syntax error, missing base image, or build-time dependency unavailable
- **Detection:** Build command exit code ≠ 0
- **Handling:** Log error, exit deployment script, no traffic switched
- **Recovery:** Fix Dockerfile, re-run `./deploy.sh $VERSION`

#### 2. **Container Startup Failure**
- **Symptom:** Node.js process crashes (e.g., memory exhaustion, uncaught exception)
- **Detection:** Container exits before health check reaches it; curl returns connection refused
- **Handling:** Health check fails after 10 retries; container is removed; traffic remains on old env
- **Recovery:** Investigate container logs (`docker logs green`), fix code, rebuild

#### 3. **Health Check Timeout (Network Issue)**
- **Symptom:** Container runs but doesn't respond to HTTP requests (network configuration, port binding mismatch)
- **Detection:** curl unable to connect after 20 seconds
- **Handling:** Automatic rollback (same as startup failure)
- **Recovery:** Verify port mappings, NGINX upstream configuration, container network namespace

#### 4. **NGINX Reload Failure**
- **Symptom:** Syntax error in nginx.conf after sed injection
- **Detection:** `docker exec ... nginx -s reload` returns non-zero exit code
- **Handling:** Health check already passed; no automatic recovery
- **Recovery:** Manual intervention: `docker exec nginx nginx -t` to validate config, restore previous version, re-run deployment

### Chaos Testing & Failure Simulation

The platform includes two test endpoints for validating rollback behavior:

**Endpoint:** `GET /simulate-failure`  
**Effect:** Toggles `failureMode` on; subsequent calls to `/health` return HTTP 500

**Endpoint:** `GET /simulate-recovery`  
**Effect:** Toggles `failureMode` off; `/health` returns HTTP 200

**Typical chaos scenario:**
```bash
# 1. Deploy v2.0.0 successfully
./scripts/deploy.sh v2.0.0

# 2. Simulate failure on green environment
curl http://localhost:5002/simulate-failure

# 3. Manually trigger a new deployment to test rollback
# Monitor that old environment (blue) remains active
./scripts/deploy.sh v2.0.1

# 4. Verify rollback occurred
cat state/active_version.txt  # Should show "blue"
```

---

## API Reference

### Application Endpoints

All endpoints served by Fastify on internal port 5000 (mapped to 5001 or 5002 on host).

#### `GET /api`
**Purpose:** Application identity  
**Response:**
```json
{
  "message": "Deployment platform test app",
  "version": "v1.2.3",
  "environment": "blue"
}
```

#### `GET /health`
**Purpose:** Health check (consumed by deployment script and load balancers)  
**Response (healthy):**
```json
{
  "status": "ok",
  "version": "v1.2.3"
}
```
HTTP 200

**Response (failure mode):**
```json
{
  "status": "failure"
}
```
HTTP 500

#### `GET /version`
**Purpose:** Metadata endpoint (quick version query)  
**Response:**
```json
{
  "version": "v1.2.3",
  "environment": "blue"
}
```

#### `GET /simulate-failure`
**Purpose:** Trigger failure mode for chaos testing  
**Response:**
```json
{
  "message": "Failure mode enabled – /health will now return HTTP 500",
  "failureMode": true
}
```
**Effect:** Subsequent calls to `/health` return HTTP 500 until `/simulate-recovery` is called

#### `GET /simulate-recovery`
**Purpose:** Disable failure mode  
**Response:**
```json
{
  "message": "Recovery complete – /health will now return HTTP 200",
  "failureMode": false
}
```

#### `GET /` (Static Assets)
**Purpose:** Serve frontend dashboard  
**Served From:** `/app/public/index.html`  
**Content-Type:** `text/html`

---

## Operational Considerations

### Scaling Strategy

**Current Model:** 2× fixed compute (blue + green environments)

**Horizontal Scaling Approaches:**

| Approach | Complexity | Downtime | Cost |
|----------|-----------|----------|------|
| **Add more replicas behind NGINX (round-robin)** | Medium | Zero | +2× per additional environment |
| **Use container orchestrator (Kubernetes)** | High | Zero (native support) | Variable; infrastructure cost |
| **Sticky sessions (NGINX)** | Low | Zero | None |

**Recommendation for current scale:** Stick with binary blue-green. If you need horizontal scaling, migrate to Kubernetes; the investment in orchestration pays off at 3+ parallel instances.

### Monitoring & Alerting

#### Key Metrics to Track
1. **Deployment frequency** – Count of deployments per day/week
2. **Deployment success rate** – % of deployments that succeeded (didn't rollback)
3. **Time to deploy** – Duration from `deploy.sh` invocation to traffic switch (should be <30s)
4. **Rollback frequency** – Count of automatic rollbacks (indicates build or code quality issues)
5. **NGINX reload latency** – Time to reload (should be <100ms)

#### Log Monitoring
```bash
# Failed deployments
grep "FAILED" logs/deployment.log

# Deployments older than 7 days (for cleanup)
find logs/ -mtime +7

# Deployment history (audit trail)
tail -100 logs/deployment.log
```

### Disaster Recovery

#### Scenario: NGINX Container Crashes

**Detection:** External health check fails; traffic unavailable

**Recovery:**
```bash
# 1. Restart NGINX
docker restart nginx-lb

# 2. Verify routing restored
curl http://localhost/api
```

**Prevention:** Monitor `docker ps` for container state; alert if NGINX container is not running.

#### Scenario: Both Blue and Green Containers Fail

**Detection:** All traffic fails; `/health` unreachable

**Recovery:**
```bash
# 1. Determine last known good version
tail -5 logs/deployment.log

# 2. Redeploy known-good version
./scripts/deploy.sh v1.5.0  # Assuming v1.5.0 was stable

# 3. If deployment script fails, manually start container
docker run -d --name blue -p 5001:5000 \
  -e APP_VERSION=v1.5.0 \
  -e APP_ENV=blue \
  deployment-app:v1.5.0
```

### Security Posture

#### Non-Root Execution
- **Rationale:** Reduces blast radius if container is compromised
- **Implementation:** Dockerfile creates `appuser:appgroup`; all application code runs as this user
- **Limitation:** Cannot bind to ports <1024 (not required for this design)

#### Network Isolation
- **Current:** Containers communicate via Docker's internal network (host.docker.internal)
- **Limitation:** No network policies between containers; assumes trusted host environment
- **Recommendation for production:** Use iptables or Docker user-defined networks with explicit firewall rules

#### Secrets Management
- **Current:** All configuration via environment variables; no secrets stored
- **Limitation:** Not applicable to this system (no credentials in code)
- **For future:** If external services (databases, APIs) are added, use Docker secrets or external key management (e.g., HashiCorp Vault)

---

## Performance Characteristics

### Deployment Duration Breakdown

| Phase | Duration | Notes |
|-------|----------|-------|
| Build | 15–30s (cold) / 2–5s (warm) | Layer caching; depends on base image pull |
| Provision | 1–2s | Container start + resource allocation |
| Health check | 2–20s | 10 retries × 2s interval |
| Traffic switch | <1s | sed + nginx reload |
| **Total** | ~20–40s | End-to-end; deterministic |

### Resource Consumption

Per environment (blue or green):
- **CPU:** ~50mCPU (idle), ~200mCPU (peak traffic simulation)
- **Memory:** ~60MB (Node.js process) + 30MB (buffer overhead)
- **Disk (image):** ~150MB (Alpine + Node.js + dependencies)

**Total system overhead:** ~400MB RAM, ~300MB disk (both images)

---

*Documentation generated for engineering review purposes.*  
*Last updated: May 2026*
