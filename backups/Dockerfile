FROM alpine:3.23

# Install PostgreSQL 18 client tools and other dependencies
RUN apk add --no-cache \
    postgresql18 \
    postgresql18-contrib \
    aws-cli \
    bash \
    curl \
    jq \
    && rm -rf /var/cache/apk/*

# Install supercronic for cron scheduling
RUN wget -O /usr/local/bin/supercronic https://github.com/aptible/supercronic/releases/download/v0.2.29/supercronic-linux-amd64 \
    && chmod +x /usr/local/bin/supercronic

# Create backup script
COPY backup.sh /backup.sh
RUN chmod +x /backup.sh

# Create run script
COPY run.sh /run.sh
RUN chmod +x /run.sh

# Set default environment variables
ENV SCHEDULE="**None**" \
    S3_ACCESS_KEY_ID="**None**" \
    S3_SECRET_ACCESS_KEY="**None**" \
    S3_BUCKET="**None**" \
    S3_ENDPOINT="**None**" \
    S3_REGION="us-east-1" \
    S3_S3V4="no" \
    POSTGRES_DATABASE="**None**" \
    POSTGRES_BACKUP_ALL="false" \
    POSTGRES_HOST="**None**" \
    POSTGRES_PORT="5432" \
    POSTGRES_USER="**None**" \
    POSTGRES_PASSWORD="**None**" \
    POSTGRES_EXTRA_OPTS=""

CMD ["/run.sh"] 