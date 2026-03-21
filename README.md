<div align="center">

```
 █████╗ ██╗   ██╗████████╗ ██████╗ ███╗   ██╗ ██████╗ ███╗   ███╗ ██████╗ ██╗   ██╗███████╗
██╔══██╗██║   ██║╚══██╔══╝██╔═══██╗████╗  ██║██╔═══██╗████╗ ████║██╔═══██╗██║   ██║██╔════╝
███████║██║   ██║   ██║   ██║   ██║██╔██╗ ██║██║   ██║██╔████╔██║██║   ██║██║   ██║███████╗
██╔══██║██║   ██║   ██║   ██║   ██║██║╚██╗██║██║   ██║██║╚██╔╝██║██║   ██║██║   ██║╚════██║
██║  ██║╚██████╔╝   ██║   ╚██████╔╝██║ ╚████║╚██████╔╝██║ ╚═╝ ██║╚██████╔╝╚██████╔╝███████║
╚═╝  ╚═╝ ╚═════╝    ╚═╝    ╚═════╝ ╚═╝  ╚═══╝ ╚═════╝ ╚═╝     ╚═╝ ╚═════╝  ╚═════╝ ╚══════╝
```

# 🚀 Autonomous Self-Healing Deployment Platform

### _Zero-Downtime Blue-Green Deployments with Intelligent Auto-Rollback_

<br/>

[![Platform](https://img.shields.io/badge/Platform-Linux-FCC624?style=for-the-badge&logo=linux&logoColor=black)](https://www.linux.org/)
[![Docker](https://img.shields.io/badge/Docker-Container_Runtime-2496ED?style=for-the-badge&logo=docker&logoColor=white)](https://www.docker.com/)
[![NGINX](https://img.shields.io/badge/NGINX-Reverse_Proxy-009639?style=for-the-badge&logo=nginx&logoColor=white)](https://nginx.org/)
[![Shell](https://img.shields.io/badge/Shell-Automation_Engine-4EAA25?style=for-the-badge&logo=gnu-bash&logoColor=white)](https://www.gnu.org/software/bash/)
[![Status](https://img.shields.io/badge/Deployment-Zero_Downtime-brightgreen?style=for-the-badge)](/)
[![Rollback](https://img.shields.io/badge/Rollback-Automated-blue?style=for-the-badge)](/)

<br/>

> **A production-grade DevOps system demonstrating modern deployment practices on Linux infrastructure.**  
> Implements zero-downtime releases, intelligent health monitoring, and automated self-healing rollback mechanisms.

<br/>

[📖 Overview](#-overview) · [🏗️ Architecture](#️-architecture) · [⚙️ Components](#️-core-components) · [🔄 Workflow](#-deployment-workflow) · [🚀 Getting Started](#-getting-started) · [🗺️ Roadmap](#️-roadmap)

</div>

---

## 📖 Overview

The **Autonomous Self-Healing Deployment Platform** is a production-style DevOps system built on Linux infrastructure. It eliminates deployment downtime and manual intervention by combining a **Blue-Green deployment strategy** with a **continuous watchdog monitoring** system that automatically rolls back failing environments.

### ✨ Key Highlights

| Capability                    | Implementation               | Outcome                                          |
| ----------------------------- | ---------------------------- | ------------------------------------------------ |
| 🟢 Zero-Downtime Deployment   | Blue-Green Strategy          | Instant traffic switch — no service interruption |
| 🔁 Auto Rollback              | Watchdog + Failure Threshold | Faults resolved autonomously in seconds          |
| 🐳 Containerized Environments | Docker Runtime               | Isolated, reproducible deployments               |
| 🔀 Traffic Control            | NGINX Reverse Proxy          | Dynamic routing without service restart          |
| ❤️ Health Validation          | API Health Endpoints         | Deployment aborted on bad health                 |
| 📋 Full Observability         | Structured Log Files         | Complete audit trail of every event              |

---

## 🏗️ Architecture

### System Architecture Overview

```
                          ┌──────────────────────────────────────────┐
                          │           DEPLOYMENT ENGINE               │
                          │  (Orchestrates entire release lifecycle)  │
                          └───────────────────┬──────────────────────┘
                                              │
              ┌───────────────────────────────┼───────────────────────────────┐
              │                               │                               │
     ┌────────▼────────┐           ┌──────────▼──────────┐        ┌──────────▼──────────┐
     │   DOCKER BUILD  │           │    NGINX PROXY      │        │   STATE MANAGEMENT  │
     │  (Container     │           │  (Traffic Routing)  │        │   (Active Env File) │
     │   Lifecycle)    │           │                     │        │                     │
     └────────┬────────┘           └──────────┬──────────┘        └─────────────────────┘
              │                               │
     ┌────────▼────────┐           ┌──────────▼──────────┐
     │ BLUE ENVIRONMENT│◄──────────►GREEN ENVIRONMENT    │
     │  (Port: Blue)   │  TRAFFIC  │  (Port: Green)      │
     │  ┌───────────┐  │  SWITCH   │  ┌───────────┐      │
     │  │ App + /   │  │           │  │ App + /   │      │
     │  │ health    │  │           │  │ health    │      │
     │  └───────────┘  │           │  └───────────┘      │
     └────────┬────────┘           └──────────┬──────────┘
              │                               │
              └───────────────┬───────────────┘
                              │
                   ┌──────────▼──────────┐
                   │  WATCHDOG MONITOR   │
                   │  (Continuous Health │
                   │   Checking Loop)    │
                   │                     │
                   │  Failure > Threshold│
                   │        ──▼──        │
                   │   ROLLBACK ENGINE   │
                   └─────────────────────┘
```

### Blue-Green Architecture

```
  User Request
      │
      ▼
 ┌─────────┐       ┌──────────────────┐       ┌─────────────┐
 │  Client │──────►│   NGINX Proxy    │──────►│  ACTIVE ENV │──────► Application
 └─────────┘       │ (Routes traffic) │       │ Blue/Green  │
                   └──────────────────┘       └─────────────┘
                          │  on switch
                          ▼
                   ┌──────────────────┐
                   │   STANDBY ENV    │ ◄── New deployments land here
                   │   Green/Blue     │     before traffic switch
                   └──────────────────┘
```

---

## 📁 Project Structure

```
autonomous-self-healing-deployment-platform/
│
├── 📂 app/                          # Application service source
│   ├── app.py                       # HTTP service with health endpoints
│   ├── requirements.txt             # Runtime dependencies
│   └── Dockerfile                   # Container image definition
│
├── 📂 nginx/                        # Reverse proxy configuration
│   └── nginx.conf                   # Upstream & routing config
│
├── 📂 scripts/                      # Deployment automation engine
│   ├── deploy.sh                    # Main deployment orchestrator
│   ├── rollback.sh                  # Manual rollback trigger
│   └── watchdog.sh                  # Continuous health monitor
│
├── 📂 logs/                         # Runtime logs (auto-generated)
│   ├── deployment.log               # Deployment lifecycle events
│   └── watchdog.log                 # Health checks & rollback events
│
├── 📂 state/                        # Active environment tracking
│   └── active_env                   # Stores: "blue" or "green"
│
└── README.md
```

---

## ⚙️ Core Components

### 1. 🚢 Deployment Engine (`scripts/deploy.sh`)

The central orchestration brain. Automates the complete release lifecycle from environment detection to post-deployment monitoring.

**Responsibilities:**

- Reads `state/active_env` to detect which environment is live
- Selects the inactive environment as the deployment target
- Builds a fresh Docker container image
- Deploys the container to the target environment
- Runs automated health checks before switching traffic
- Updates NGINX configuration to redirect traffic
- Starts the Watchdog service for post-deployment monitoring

---

### 2. 🌐 Application Service (`app/`)

A lightweight HTTP service simulating real production applications. Exposes all endpoints needed for automated deployment validation.

| Endpoint             | Method | Purpose                                                                        |
| -------------------- | ------ | ------------------------------------------------------------------------------ |
| `/health`            | GET    | Returns current health status — the foundation of all automated decisions      |
| `/version`           | GET    | Returns deployed version — enables version tracking and validation             |
| `/simulate-failure`  | POST   | Artificially degrades health — used for chaos engineering and rollback testing |
| `/simulate-recovery` | POST   | Restores health status — validates recovery scenarios                          |

---

### 3. 🔀 NGINX Reverse Proxy (`nginx/`)

Acts as the intelligent traffic controller between the user and the active environment.

**Responsibilities:**

- Receives all incoming client requests
- Routes 100% of traffic to the currently active environment (Blue or Green)
- Performs instant environment switching via config reload — **no service interruption**
- Supports load distribution across available instances

---

### 4. 🐕 Watchdog Monitoring System (`scripts/watchdog.sh`)

A background process that continuously validates the health of the active environment after every deployment.

```
  ┌─────────┐
  │  START  │
  └────┬────┘
       │ Poll every N seconds
       ▼
  ┌────────────┐    ✅ Healthy    ┌──────────────────┐
  │ CheckHealth├──────────────── ►│ ContinueMonitor  │◄──┐
  └────┬───────┘                  └──────────────────┘   │
       │ ❌ Failure                                        │
       ▼                                                   │
  ┌────────────────────┐                                   │
  │ IncreaseFailCounter│                                   │
  └────────┬───────────┘                                   │
           │                                               │
           ▼                                               │
  ┌─────────────────┐   Below Limit  ┌──────────┐         │
  │  CheckThreshold ├───────────────►│  Retry   ├─────────┘
  └────────┬────────┘                └──────────┘
           │ Exceeded
           ▼
  ┌──────────────────┐
  │  TRIGGER ROLLBACK│
  └──────────────────┘
```

---

### 5. 🔄 Self-Healing Rollback Engine

Triggered automatically when the Watchdog failure counter exceeds the configured threshold.

**Rollback Sequence:**

```
  FailureDetected
       │
       ▼
  StopBrokenEnvironment  ──── Terminates faulty container immediately
       │
       ▼
  RestorePreviousTraffic ──── NGINX config reverted to last stable env
       │
       ▼
  UpdateState            ──── active_env file updated
       │
       ▼
  ResumeMonitoring       ──── Watchdog restarted on restored environment
```

> No manual intervention required. The system restores production stability autonomously.

---

## 🔄 Deployment Workflow

### Complete Lifecycle

```
Developer triggers deploy.sh
         │
         ▼
  ① Detect Active Environment
    Read state/active_env → "blue"
         │
         ▼
  ② Select Deployment Target
    Active = blue  →  Target = green
         │
         ▼
  ③ Build Container
    docker build -t app:new ./app
         │
         ▼
  ④ Start New Environment
    docker run ... app-green
         │
         ▼
  ⑤ Health Validation
    curl http://localhost:PORT/health
    ┌────────────────────────────────┐
    │ ✅ HEALTHY → proceed           │
    │ ❌ UNHEALTHY → abort & preserve│
    │              active env        │
    └────────────────────────────────┘
         │ (if healthy)
         ▼
  ⑥ Switch Traffic
    Update nginx.conf → reload NGINX
    Active traffic now on green ✅
         │
         ▼
  ⑦ Update State
    echo "green" > state/active_env
         │
         ▼
  ⑧ Start Watchdog
    watchdog.sh monitors green env
         │
         ▼
  ✅ Deployment Complete
```

### Scenario: Auto-Rollback in Action

```
① Deployment to Green succeeds
② Health checks pass → traffic switches to Green
③ Over time: app starts degrading (crashes, timeouts)
④ Watchdog detects repeated /health failures
⑤ Failure counter exceeds threshold
⑥ Rollback engine fires automatically:
      → Green container stopped
      → NGINX reverted to Blue
      → State file updated
      → Watchdog restarted on Blue
⑦ Production restored — zero manual intervention ✅
```

---

## 📊 Deployment Metrics

| Metric                      | Value                                       |
| --------------------------- | ------------------------------------------- |
| Deployment Downtime         | **Zero** (Blue-Green instant switch)        |
| Rollback Time               | **Seconds** (traffic redirection)           |
| Health Check Interval       | **Configurable** (typically 5–10 seconds)   |
| Failure Detection Threshold | **Configurable** failure count              |
| Core Components             | **5** (Engine, App, Proxy, Watchdog, State) |
| Supported Strategies        | Blue-Green (canary & rolling on roadmap)    |
| Infrastructure              | Linux-based                                 |

---

## 🚀 Getting Started

### Prerequisites

```bash
# Required software
- Linux OS (Ubuntu 20.04+ recommended)
- Docker (daemon running)
- NGINX
- Bash shell
- Git
```

### Installation

```bash
# 1. Clone the repository
git clone https://github.com/ketanayatti/Autonomous-Self-Healing-Deployment-Platform.git
cd Autonomous-Self-Healing-Deployment-Platform

# 2. Build initial application container
docker build -t app:v1 ./app

# 3. Initialize state tracking
echo "blue" > state/active_env

# 4. Configure NGINX upstream servers
# Edit nginx/nginx.conf with your port configuration
sudo nginx -t && sudo systemctl reload nginx

# 5. Deploy the Blue environment
./scripts/deploy.sh v1
```

### Running a Deployment

```bash
# Trigger a new deployment
./scripts/deploy.sh v2

# Monitor deployment output
tail -f logs/deployment.log

# Monitor watchdog health checks
tail -f logs/watchdog.log

# Check active environment
cat state/active_env

# Verify deployed version
curl http://localhost/version

# Check application health
curl http://localhost/health
```

### Testing Rollback

```bash
# Simulate application failure (triggers auto-rollback)
curl -X POST http://localhost/simulate-failure

# Watch watchdog detect failure and roll back
tail -f logs/watchdog.log

# Confirm environment has reverted
cat state/active_env
```

---

## 🔍 Troubleshooting

| Issue                            | Likely Cause                           | Fix                                             |
| -------------------------------- | -------------------------------------- | ----------------------------------------------- |
| Health checks fail during deploy | App not listening on expected port     | Verify `Dockerfile` EXPOSE and app bind address |
| NGINX not routing after switch   | Config syntax error                    | Run `nginx -t` before reload                    |
| Watchdog not triggering rollback | Threshold not exceeded or process dead | Check `logs/watchdog.log` and watchdog PID      |
| Container startup failures       | Missing deps or env vars               | Inspect `docker logs <container_name>`          |

---

## 🗺️ Roadmap

```
Phase 1 — CI/CD Integration
  ├── GitHub Actions workflow automation
  ├── Automated test runs on every commit
  └── Artifact registry management

Phase 2 — Advanced Orchestration
  ├── Kubernetes deployment support
  ├── Helm chart development
  └── Horizontal pod autoscaling

Phase 3 — Deployment Strategies
  ├── Canary deployment (gradual rollout %)
  ├── Shadow traffic testing
  └── A/B testing framework

Phase 4 — Observability
  ├── Prometheus metrics integration
  ├── Grafana dashboard creation
  └── Distributed tracing

Phase 5 — Production Hardening
  ├── Secrets management
  ├── Network policy enforcement
  └── Security scanning automation
```

---

## 🛠️ DevOps Skills Demonstrated

| Domain                       | Implementation                                               |
| ---------------------------- | ------------------------------------------------------------ |
| **Linux Automation**         | Shell-based deployment engine with full lifecycle management |
| **Containerization**         | Docker image builds, container lifecycle, resource isolation |
| **Deployment Strategy**      | Blue-Green zero-downtime releases with validation gates      |
| **Infrastructure as Code**   | Scriptable, repeatable deployments — CI/CD ready             |
| **Reverse Proxy Management** | NGINX dynamic routing and configuration reload               |
| **Reliability Engineering**  | Self-healing watchdog, automated MTTR reduction              |
| **Observability**            | Structured logs for deployments, health, and rollback events |
| **Chaos Engineering**        | Failure simulation endpoints for validation testing          |

---

## 📄 License

This project is for **educational and portfolio demonstration purposes**.

---

<div align="center">

**Built by [Ketan Ayatti](https://github.com/ketanayatti)**

_Demonstrating production-grade DevOps engineering principles_

⭐ If this project helped you, please consider giving it a star!

</div>
