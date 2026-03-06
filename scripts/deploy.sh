#!/bin/bash

# -------------------------------

# Detect project paths

# -------------------------------

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

STATE_FILE="$PROJECT_ROOT/state/active_version.txt"
APP_DIR="$PROJECT_ROOT/app"
NGINX_CONF="$PROJECT_ROOT/nginx/nginx.conf"
LOG_FILE="$PROJECT_ROOT/logs/deployment.log"

VERSION=$1

if [ -z "$VERSION" ]; then
echo "Usage: ./deploy.sh <version>"
exit 1
fi

# -------------------------------

# Determine active environment

# -------------------------------

ACTIVE_ENV=$(cat "$STATE_FILE")

echo "Current active environment: $ACTIVE_ENV"

if [ "$ACTIVE_ENV" = "blue" ]; then
TARGET_ENV="green"
TARGET_PORT=5002
OLD_ENV="blue"
OLD_PORT=5001
else
TARGET_ENV="blue"
TARGET_PORT=5001
OLD_ENV="green"
OLD_PORT=5002
fi

echo "Deploying to: $TARGET_ENV on port $TARGET_PORT"

echo "$(date) Starting deployment: version=$VERSION target=$TARGET_ENV" >> "$LOG_FILE"

# -------------------------------

# Build Docker Image

# -------------------------------

echo "Building Docker image version: $VERSION"

docker build -t deployment-app:$VERSION "$APP_DIR"

if [ $? -ne 0 ]; then
echo "Docker build failed."
echo "$(date) Deployment FAILED during build: version=$VERSION" >> "$LOG_FILE"
exit 1
fi

echo "$(date) Docker image built: deployment-app:$VERSION" >> "$LOG_FILE"

# -------------------------------

# Stop old target container

# -------------------------------

docker rm -f $TARGET_ENV 2>/dev/null

# -------------------------------

# Start new container

# -------------------------------

echo "Starting new container..."

docker run -d --name $TARGET_ENV -p $TARGET_PORT:5000 \
-e APP_VERSION=$VERSION \
-e APP_ENV=$TARGET_ENV \
deployment-app:$VERSION

# -------------------------------

# Health Check Retry

# -------------------------------

echo "Waiting for application to become healthy..."

MAX_RETRIES=10
RETRY_INTERVAL=2
RETRY_COUNT=0

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do

    HEALTH_CHECK=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:$TARGET_PORT/health)

    if [ "$HEALTH_CHECK" = "200" ]; then
        echo "Health check passed."
        break
    fi

    echo "Health check attempt $((RETRY_COUNT+1)) failed. Retrying..."

    RETRY_COUNT=$((RETRY_COUNT+1))
    sleep $RETRY_INTERVAL

done

# -------------------------------

# Deployment failure

# -------------------------------

if [ "$HEALTH_CHECK" != "200" ]; then

    echo "Deployment failed after retries. Rolling back..."

    docker rm -f $TARGET_ENV

    echo "$(date) Deployment FAILED: version=$VERSION" >> "$LOG_FILE"

    exit 1

fi

# -------------------------------

# Switch Traffic

# -------------------------------

echo "Switching traffic to $TARGET_ENV..."

sed -i "s/server host.docker.internal:[0-9]*/server host.docker.internal:$TARGET_PORT/" "$NGINX_CONF"

docker exec $(docker ps -q --filter ancestor=nginx) nginx -s reload

echo $TARGET_ENV > "$STATE_FILE"

echo "Deployment successful. Active environment is now $TARGET_ENV"

echo "$(date) Deployment SUCCESS: version=$VERSION active=$TARGET_ENV" >> "$LOG_FILE"

# -------------------------------

# AUTO ROLLBACK WATCHDOG

# -------------------------------

WATCHDOG_PID_FILE="$PROJECT_ROOT/state/watchdog.pid"
WATCHDOG_LOG="$PROJECT_ROOT/logs/watchdog.log"

# Kill any previous watchdog process
if [ -f "$WATCHDOG_PID_FILE" ]; then
    OLD_PID=$(cat "$WATCHDOG_PID_FILE")
    if kill -0 "$OLD_PID" 2>/dev/null; then
        echo "Killing previous watchdog (PID: $OLD_PID)..."
        kill "$OLD_PID" 2>/dev/null
        sleep 1
    fi
    rm -f "$WATCHDOG_PID_FILE"
fi

echo "Starting auto-rollback watchdog..."

nohup bash -c '
FAIL_COUNT=0
MAX_FAILS=3
CHECK_INTERVAL=5

echo "$(date) Watchdog started – monitoring '"$TARGET_ENV"' (port '"$TARGET_PORT"')" >> "'"$WATCHDOG_LOG"'"
echo "$(date) Watchdog started – monitoring '"$TARGET_ENV"' (port '"$TARGET_PORT"')" >> "'"$LOG_FILE"'"

while true
do
    STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/health)

    if [ "$STATUS" != "200" ]; then
        FAIL_COUNT=$((FAIL_COUNT + 1))
        echo "$(date) Health check FAILED ($FAIL_COUNT/$MAX_FAILS) – HTTP $STATUS" >> "'"$WATCHDOG_LOG"'"

        if [ $FAIL_COUNT -ge $MAX_FAILS ]; then

            echo "$(date) === AUTO ROLLBACK TRIGGERED ===" >> "'"$WATCHDOG_LOG"'"
            echo "$(date) Runtime failure detected after $MAX_FAILS consecutive failures. Rolling back to '"$OLD_ENV"'" >> "'"$LOG_FILE"'"

            # Switch nginx back to old environment
            sed -i "s/server host.docker.internal:[0-9]*/server host.docker.internal:'"$OLD_PORT"'/" "'"$NGINX_CONF"'"

            docker exec $(docker ps -q --filter ancestor=nginx) nginx -s reload

            # Remove broken container
            docker rm -f '"$TARGET_ENV"'

            echo '"$OLD_ENV"' > "'"$STATE_FILE"'"

            echo "$(date) Rollback complete. Traffic restored to '"$OLD_ENV"' (port '"$OLD_PORT"')" >> "'"$WATCHDOG_LOG"'"
            echo "$(date) ROLLBACK SUCCESS: restored to '"$OLD_ENV"'" >> "'"$LOG_FILE"'"

            # Clean up PID file
            rm -f "'"$WATCHDOG_PID_FILE"'"

            exit 1
        fi
    else
        # Reset fail counter on successful check
        if [ $FAIL_COUNT -gt 0 ]; then
            echo "$(date) Health check recovered – resetting fail counter" >> "'"$WATCHDOG_LOG"'"
        fi
        FAIL_COUNT=0
    fi

    sleep $CHECK_INTERVAL

done
' > /dev/null 2>&1 &

# Save watchdog PID
WATCHDOG_PID=$!
echo $WATCHDOG_PID > "$WATCHDOG_PID_FILE"

echo "Watchdog started (PID: $WATCHDOG_PID) – will rollback after 3 consecutive failures"
echo "$(date) Watchdog PID=$WATCHDOG_PID monitoring $TARGET_ENV" >> "$LOG_FILE"
