FROM alpine:3.23

# Install PostgreSQL 18 client tools and other dependencies
RUN apk add --no-cache \
    postgresql18 \
    postgresql18-contrib \
    aws-cli \
    bash \
    curl \
    jq \
    openssh-client \
    && rm -rf /var/cache/apk/*

# Install supercronic for cron scheduling
# Latest releases available at https://github.com/aptible/supercronic/releases
ENV SUPERCRONIC_URL=https://github.com/aptible/supercronic/releases/download/v0.2.41/supercronic-linux-amd64 \
    SUPERCRONIC_SHA1SUM=f70ad28d0d739a96dc9e2087ae370c257e79b8d7 \
    SUPERCRONIC=supercronic-linux-amd64

RUN curl -fsSLO "$SUPERCRONIC_URL" \
 && echo "${SUPERCRONIC_SHA1SUM}  ${SUPERCRONIC}" | sha1sum -c - \
 && chmod +x "$SUPERCRONIC" \
 && mv "$SUPERCRONIC" "/usr/local/bin/${SUPERCRONIC}" \
 && ln -s "/usr/local/bin/${SUPERCRONIC}" /usr/local/bin/supercronic

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
    POSTGRES_EXTRA_OPTS="" \
    SSH_TUNNEL_ENABLED="false" \
    SSH_HOST="**None**" \
    SSH_USER="root" \
    SSH_PORT="22" \
    SSH_PRIVATE_KEY="**None**" \
    SSH_RETRY_COUNT="3" \
    SSH_RETRY_DELAY="5"

CMD ["/run.sh"] 