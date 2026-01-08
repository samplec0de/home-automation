#!/bin/sh

set -eo pipefail
set -o pipefail

if [ "${S3_ACCESS_KEY_ID}" = "**None**" ]; then
  echo "You need to set the S3_ACCESS_KEY_ID environment variable."
  exit 1
fi

if [ "${S3_SECRET_ACCESS_KEY}" = "**None**" ]; then
  echo "You need to set the S3_SECRET_ACCESS_KEY environment variable."
  exit 1
fi

if [ "${S3_BUCKET}" = "**None**" ]; then
  echo "You need to set the S3_BUCKET environment variable."
  exit 1
fi

if [ "${POSTGRES_DATABASE}" = "**None**" -a "${POSTGRES_BACKUP_ALL}" != "true" ]; then
  echo "You need to set the POSTGRES_DATABASE environment variable."
  exit 1
fi

if [ "${POSTGRES_HOST}" = "**None**" ]; then
  if [ -n "${POSTGRES_PORT_5432_TCP_ADDR}" ]; then
    POSTGRES_HOST=$POSTGRES_PORT_5432_TCP_ADDR
    POSTGRES_PORT=$POSTGRES_PORT_5432_TCP_PORT
  else
    echo "You need to set the POSTGRES_HOST environment variable."
    exit 1
  fi
fi

if [ "${POSTGRES_USER}" = "**None**" ]; then
  echo "You need to set the POSTGRES_USER environment variable."
  exit 1
fi

if [ "${POSTGRES_PASSWORD}" = "**None**" ]; then
  echo "You need to set the POSTGRES_PASSWORD environment variable or link to a container named POSTGRES."
  exit 1
fi

# SSH tunnel setup
SSH_TUNNEL_PID=""
SSH_KEY_FILE="/tmp/ssh_key"
SSH_LOCAL_PORT="5433"
SSH_PID_FILE=""
ORIGINAL_POSTGRES_HOST="$POSTGRES_HOST"
ORIGINAL_POSTGRES_PORT="$POSTGRES_PORT"

cleanup_ssh_tunnel() {
  if [ -n "$SSH_TUNNEL_PID" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 🔌 Closing SSH tunnel (PID: $SSH_TUNNEL_PID)..."
    kill $SSH_TUNNEL_PID 2>/dev/null || true
    wait $SSH_TUNNEL_PID 2>/dev/null || true
    SSH_TUNNEL_PID=""
  fi
  # Also cleanup using PID file if it exists
  if [ -n "$SSH_LOCAL_PORT" ] && [ -f "/tmp/ssh_tunnel_${SSH_LOCAL_PORT}.pid" ]; then
    OLD_PID=$(cat "/tmp/ssh_tunnel_${SSH_LOCAL_PORT}.pid" 2>/dev/null)
    if [ -n "$OLD_PID" ] && kill -0 $OLD_PID 2>/dev/null; then
      kill $OLD_PID 2>/dev/null || true
    fi
    rm -f "/tmp/ssh_tunnel_${SSH_LOCAL_PORT}.pid"
  fi
  if [ -f "$SSH_KEY_FILE" ]; then
    rm -f "$SSH_KEY_FILE"
  fi
  # Cleanup error log file if it exists
  if [ -f "/tmp/ssh_error.log" ]; then
    rm -f "/tmp/ssh_error.log"
  fi
}

# Set trap to cleanup SSH tunnel on exit
trap cleanup_ssh_tunnel EXIT INT TERM

if [ "${SSH_TUNNEL_ENABLED}" = "true" ]; then
  if [ "${SSH_HOST}" = "**None**" ]; then
    echo "You need to set the SSH_HOST environment variable when SSH_TUNNEL_ENABLED is true."
    exit 1
  fi

  if [ "${SSH_PRIVATE_KEY}" = "**None**" ]; then
    echo "You need to set the SSH_PRIVATE_KEY environment variable when SSH_TUNNEL_ENABLED is true."
    exit 1
  fi

  echo "[$(date '+%Y-%m-%d %H:%M:%S')] 🔌 Setting up SSH tunnel to ${SSH_USER}@${SSH_HOST}:${SSH_PORT}..."

  # Clean up any stale SSH tunnels from previous runs (e.g., if killed with SIGKILL)
  # This prevents "port already in use" errors
  if [ -f "/tmp/ssh_tunnel_${SSH_LOCAL_PORT}.pid" ]; then
    OLD_PID=$(cat "/tmp/ssh_tunnel_${SSH_LOCAL_PORT}.pid" 2>/dev/null)
    if [ -n "$OLD_PID" ] && kill -0 $OLD_PID 2>/dev/null; then
      echo "[$(date '+%Y-%m-%d %H:%M:%S')] 🧹 Cleaning up stale SSH tunnel (PID: $OLD_PID)..."
      kill $OLD_PID 2>/dev/null || true
      sleep 1
    fi
    rm -f "/tmp/ssh_tunnel_${SSH_LOCAL_PORT}.pid"
  fi

  # Write SSH private key to file with secure permissions
  # Use printf instead of echo to correctly interpret escape sequences like \n
  printf '%b\n' "$SSH_PRIVATE_KEY" > "$SSH_KEY_FILE"
  chmod 600 "$SSH_KEY_FILE"

  # Disable strict host key checking for automation
  SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -i $SSH_KEY_FILE"

  # Create SSH tunnel: forward local port to remote PostgreSQL
  # Use a PID file to track the tunnel process
  SSH_PID_FILE="/tmp/ssh_tunnel_${SSH_LOCAL_PORT}.pid"
  SSH_ERROR_FILE="/tmp/ssh_error.log"
  
  # Set default retry values if not provided
  SSH_RETRY_COUNT=${SSH_RETRY_COUNT:-3}
  SSH_RETRY_DELAY=${SSH_RETRY_DELAY:-5}
  
  # Retry loop for SSH tunnel creation
  ATTEMPT=1
  TUNNEL_ESTABLISHED=false
  
  while [ $ATTEMPT -le $SSH_RETRY_COUNT ]; do
    # Clean up any previous error log
    rm -f "$SSH_ERROR_FILE"
    
    if [ $ATTEMPT -gt 1 ]; then
      echo "[$(date '+%Y-%m-%d %H:%M:%S')] 🔄 Retrying SSH tunnel connection (attempt $ATTEMPT/$SSH_RETRY_COUNT)..."
      sleep $SSH_RETRY_DELAY
    fi
    
    # Start SSH tunnel in background and capture PID
    # Capture stderr to error file for diagnostics
    ssh $SSH_OPTS -N -L ${SSH_LOCAL_PORT}:${ORIGINAL_POSTGRES_HOST}:${ORIGINAL_POSTGRES_PORT} -p ${SSH_PORT} ${SSH_USER}@${SSH_HOST} > /dev/null 2>"$SSH_ERROR_FILE" &
    SSH_TUNNEL_PID=$!
    echo $SSH_TUNNEL_PID > "$SSH_PID_FILE"

    # Wait a moment for tunnel to establish
    sleep 2

    # Check if tunnel process is still running
    if kill -0 $SSH_TUNNEL_PID 2>/dev/null; then
      TUNNEL_ESTABLISHED=true
      echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✅ SSH tunnel established (PID: $SSH_TUNNEL_PID)"
      rm -f "$SSH_ERROR_FILE"
      break
    else
      # Tunnel failed, check for error message
      if [ -f "$SSH_ERROR_FILE" ] && [ -s "$SSH_ERROR_FILE" ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ⚠️  SSH tunnel attempt $ATTEMPT failed:"
        cat "$SSH_ERROR_FILE" | sed 's/^/  /'
      else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ⚠️  SSH tunnel attempt $ATTEMPT failed (process exited immediately)"
      fi
      
      rm -f "$SSH_PID_FILE"
      ATTEMPT=$((ATTEMPT + 1))
    fi
  done

  # If all retries failed, exit with error
  if [ "$TUNNEL_ESTABLISHED" = "false" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ❌ Failed to establish SSH tunnel after $SSH_RETRY_COUNT attempts"
    if [ -f "$SSH_ERROR_FILE" ] && [ -s "$SSH_ERROR_FILE" ]; then
      echo "Last SSH error:"
      cat "$SSH_ERROR_FILE" | sed 's/^/  /'
    fi
    rm -f "$SSH_ERROR_FILE"
    exit 1
  fi

  # Update connection to use localhost through tunnel
  POSTGRES_HOST="localhost"
  POSTGRES_PORT="$SSH_LOCAL_PORT"
fi

if [ "${S3_ENDPOINT}" == "**None**" ]; then
  AWS_ARGS=""
else
  AWS_ARGS="--endpoint-url ${S3_ENDPOINT}"
fi

# env vars needed for aws tools
export AWS_ACCESS_KEY_ID=$S3_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY=$S3_SECRET_ACCESS_KEY
export AWS_DEFAULT_REGION=$S3_REGION

export PGPASSWORD=$POSTGRES_PASSWORD
POSTGRES_HOST_OPTS="-h $POSTGRES_HOST -p $POSTGRES_PORT -U $POSTGRES_USER $POSTGRES_EXTRA_OPTS"

if [ -z ${S3_PREFIX+x} ]; then
  S3_PREFIX="/"
else
  S3_PREFIX="/${S3_PREFIX}/"  
fi

if [ "${POSTGRES_BACKUP_ALL}" == "true" ]; then
  if [ "${SSH_TUNNEL_ENABLED}" = "true" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 🔄 Creating backup of all databases from ${ORIGINAL_POSTGRES_HOST} (via SSH tunnel)..."
  else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 🔄 Creating backup of all databases from ${POSTGRES_HOST}..."
  fi

  pg_dumpall -h $POSTGRES_HOST -p $POSTGRES_PORT -U $POSTGRES_USER | gzip > dump.sql.gz

  echo "[$(date '+%Y-%m-%d %H:%M:%S')] 📤 Uploading backup to s3://${S3_BUCKET}${S3_PREFIX}all_$(date +"%Y-%m-%dT%H:%M:%SZ").sql.gz"

  cat dump.sql.gz | aws $AWS_ARGS s3 cp - "s3://${S3_BUCKET}${S3_PREFIX}all_$(date +"%Y-%m-%dT%H:%M:%SZ").sql.gz" || exit 2

  echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✅ Backup completed successfully"

  rm -rf dump.sql.gz
else
  OIFS="$IFS"
  IFS=','
  for DB in $POSTGRES_DATABASE
  do
    IFS="$OIFS"

    if [ "${SSH_TUNNEL_ENABLED}" = "true" ]; then
      echo "[$(date '+%Y-%m-%d %H:%M:%S')] 🔄 Creating backup of ${DB} database from ${ORIGINAL_POSTGRES_HOST} (via SSH tunnel)..."
    else
      echo "[$(date '+%Y-%m-%d %H:%M:%S')] 🔄 Creating backup of ${DB} database from ${POSTGRES_HOST}..."
    fi

    pg_dump $POSTGRES_HOST_OPTS $DB | gzip > dump.sql.gz

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 📤 Uploading backup to s3://${S3_BUCKET}${S3_PREFIX}${DB}_$(date +"%Y-%m-%dT%H:%M:%SZ").sql.gz"

    cat dump.sql.gz | aws $AWS_ARGS s3 cp - "s3://${S3_BUCKET}${S3_PREFIX}${DB}_$(date +"%Y-%m-%dT%H:%M:%SZ").sql.gz" || exit 2

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✅ Backup of ${DB} completed successfully"

    rm -rf dump.sql.gz
  done
fi 