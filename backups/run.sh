#!/bin/sh

set -eo pipefail

if [ "${S3_S3V4}" = "yes" ]; then
    aws configure set default.s3.signature_version s3v4
fi

if [ "${SCHEDULE}" = "**None**" ]; then
  sh backup.sh
else
  echo "Starting backup scheduler with schedule: $SCHEDULE"
  
  # Create a temporary crontab file
  echo "$SCHEDULE /bin/sh backup.sh" > /tmp/crontab
  
  # Run supercronic with passthrough logs - show all output
  exec supercronic -passthrough-logs /tmp/crontab
fi