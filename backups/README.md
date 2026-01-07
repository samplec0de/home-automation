# PostgreSQL Backup Tool

This directory contains a Docker-based PostgreSQL backup tool that automatically backs up databases to S3-compatible storage.

## Overview

The backup tool uses Docker containers to create scheduled PostgreSQL database backups and upload them to S3. It supports:
- Scheduled backups using cron syntax
- SSH tunnel support for remote databases
- Multiple database backups
- S3-compatible storage (AWS S3, MinIO, Yandex Object Storage, etc.)
- Automatic cleanup of temporary files

## Resource Requirements

### Minimal Requirements
- **CPU**: 0.5 CPU cores
- **Memory**: 256 MB RAM
- **Disk Space**: 500 MB (for temporary backup files during dump/upload)
- **Network**: Stable connection to PostgreSQL and S3 endpoints

### Recommended Requirements
- **CPU**: 1 CPU core
- **Memory**: 512 MB RAM
- **Disk Space**: 2 GB (for temporary backup files; scales with database size)
- **Network**: Stable, high-bandwidth connection to PostgreSQL and S3 endpoints

**Note**: Resource usage scales with database size. For large databases (>10 GB), consider:
- Increasing memory to 1-2 GB
- Allocating more disk space (at least 2x the largest database size)
- Ensuring sufficient network bandwidth for S3 uploads

## Components

- **`Dockerfile`**: Builds the backup container image with PostgreSQL client tools, AWS CLI, and supercronic
- **`docker-compose.example.yml`**: Example configuration for backing up multiple databases
- **`backup.sh`**: Main backup script that handles SSH tunnel setup, database dumps, and S3 uploads
- **`run.sh`**: Entrypoint script that handles scheduling and runs the backup script

## Quick Start

1. **Create environment file**: Copy `.env_pgbackups3` and configure your settings:
   ```bash
   # Edit .env_pgbackups3 with your configuration
   ```

2. **Create backup user** (if needed): Create a dedicated backup user with read-only permissions:
   ```sql
   CREATE USER backup WITH PASSWORD 'your_secure_password_here';
   
   -- Grant connect permission to databases
   GRANT CONNECT ON DATABASE your_database TO backup;
   
   -- Grant usage on schema
   GRANT USAGE ON SCHEMA public TO backup;
   
   -- Grant select permissions on all tables and sequences
   GRANT SELECT ON ALL TABLES IN SCHEMA public TO backup;
   GRANT SELECT ON ALL SEQUENCES IN SCHEMA public TO backup;
   
   -- Grant permissions on future tables
   ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO backup;
   ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON SEQUENCES TO backup;
   
   -- Grant temporary table permission (required by some backup tools)
   GRANT TEMPORARY ON DATABASE your_database TO backup;
   ```
   Replace `your_database` with your actual database name(s) and set a secure password.

3. **Create your docker-compose.yml**: Copy `docker-compose.example.yml` to `docker-compose.yml` and configure it for your databases:
   ```bash
   cp docker-compose.example.yml docker-compose.yml
   # Edit docker-compose.yml with your database configuration
   ```

4. **Start backup services**:
   ```bash
   docker-compose up -d
   ```

## Configuration

### Environment Variables

The backup tool uses environment variables for configuration. Common variables include:

#### S3 Configuration
- `S3_ACCESS_KEY_ID`: S3 access key ID (required)
- `S3_SECRET_ACCESS_KEY`: S3 secret access key (required)
- `S3_BUCKET`: S3 bucket name (required)
- `S3_ENDPOINT`: S3 endpoint URL (optional, for S3-compatible services)
- `S3_REGION`: AWS region (default: `us-east-1`)
- `S3_PREFIX`: Prefix for backup files in S3 (optional)

#### PostgreSQL Configuration
- `POSTGRES_HOST`: PostgreSQL hostname or IP (required)
- `POSTGRES_PORT`: PostgreSQL port (default: `5432`)
- `POSTGRES_USER`: PostgreSQL username (required)
- `POSTGRES_PASSWORD`: PostgreSQL password (required)
- `POSTGRES_DATABASE`: Database name(s), comma-separated for multiple (required unless `POSTGRES_BACKUP_ALL=true`)
- `POSTGRES_BACKUP_ALL`: Set to `true` to backup all databases (default: `false`)
- `POSTGRES_EXTRA_OPTS`: Additional options for `pg_dump` (e.g., `--schema=public --blobs`)

#### SSH Tunnel Configuration (Optional)
- `SSH_TUNNEL_ENABLED`: Set to `true` to enable SSH tunnel (default: `false`)
- `SSH_HOST`: SSH server hostname or IP (required if tunnel enabled)
- `SSH_USER`: SSH username (default: `root`)
- `SSH_PORT`: SSH port (default: `22`)
- `SSH_PRIVATE_KEY`: SSH private key content (required if tunnel enabled)
- `SSH_RETRY_COUNT`: Number of SSH connection retries (default: `3`)
- `SSH_RETRY_DELAY`: Delay between retries in seconds (default: `5`)

#### Scheduling
- `SCHEDULE`: Cron schedule expression (e.g., `@daily`, `0 2 * * *`). Set to `**None**` to run once and exit.

### Example Environment File

```env
S3_ACCESS_KEY_ID=your_access_key
S3_SECRET_ACCESS_KEY=your_secret_key
S3_BUCKET=my-backup-bucket
S3_ENDPOINT=https://s3.example.com
S3_REGION=us-east-1

POSTGRES_HOST=postgres.example.com
POSTGRES_PORT=5432
POSTGRES_USER=backup
POSTGRES_PASSWORD=secure_password
```

## Usage

### Running a One-Time Backup

Set `SCHEDULE=**None**` in your environment and run:
```bash
docker-compose run --rm pgbackups3-database
```
Replace `pgbackups3-database` with your service name from `docker-compose.yml`.

### Scheduled Backups

Configure `SCHEDULE` in your environment (e.g., `@daily`, `0 2 * * *`) and start the service:
```bash
docker-compose up -d
```

### SSH Tunnel Setup

To backup a database that's not directly accessible, enable SSH tunneling:

1. Add SSH tunnel variables to your service in your `docker-compose.yml`:
   ```yaml
   environment:
     SSH_TUNNEL_ENABLED: "true"
     SSH_HOST: "ssh-server.example.com"
     SSH_USER: "root"
     SSH_PORT: "22"
     SSH_PRIVATE_KEY: "-----BEGIN OPENSSH PRIVATE KEY-----\n...\n-----END OPENSSH PRIVATE KEY-----"
   ```

2. Set `POSTGRES_HOST` to the hostname/IP as seen from the SSH server, not the backup container.

### Backup File Naming

Backup files are named with the following pattern:
- Single database: `{database_name}_{timestamp}.sql.gz`
- All databases: `all_{timestamp}.sql.gz`

Timestamps use ISO 8601 format: `YYYY-MM-DDTHH:MM:SSZ`

## Database User Setup

For security, it's recommended to create a dedicated backup user with read-only permissions. Example SQL to create a backup user:

```sql
CREATE USER backup WITH PASSWORD 'your_secure_password_here';

-- Grant connect permission to databases
GRANT CONNECT ON DATABASE your_database TO backup;

-- Grant usage on schema
GRANT USAGE ON SCHEMA public TO backup;

-- Grant select permissions on all tables and sequences
GRANT SELECT ON ALL TABLES IN SCHEMA public TO backup;
GRANT SELECT ON ALL SEQUENCES IN SCHEMA public TO backup;

-- Grant permissions on future tables
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO backup;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON SEQUENCES TO backup;

-- Grant temporary table permission (required by some backup tools)
GRANT TEMPORARY ON DATABASE your_database TO backup;
```

Replace `your_database` with your actual database name(s) and set a secure password. Repeat the `GRANT CONNECT` and `GRANT TEMPORARY` statements for each database you want to backup.

## Building the Docker Image

To build the custom backup image:

```bash
docker build -t your-registry/pgbackups3:latest .
```

## Troubleshooting

### SSH Tunnel Issues

- Verify SSH key format (should include newlines as `\n` in environment variable)
- Check SSH server connectivity and credentials
- Review SSH tunnel retry settings if connections are unstable
- Check logs: `docker-compose logs <service-name>`

### S3 Upload Issues

- Verify S3 credentials and bucket permissions
- Check endpoint URL format (include `https://` if using custom endpoint)
- Ensure network connectivity to S3 endpoint

### Database Connection Issues

- Verify PostgreSQL host, port, and credentials
- Check firewall rules if connecting remotely
- Ensure database user has necessary permissions
- For SSH tunnel: verify `POSTGRES_HOST` is correct from SSH server perspective

## Backup Retention

This tool does not automatically delete old backups. Implement a retention policy using:
- S3 lifecycle policies
- External cleanup scripts
- Your S3 provider's retention features

## Security Considerations

- Store sensitive credentials in `.env_pgbackups3` (not in version control)
- Use a dedicated backup user with minimal permissions
- Rotate SSH keys and database passwords regularly
- Enable S3 bucket encryption
- Restrict S3 bucket access policies
- Use SSH keys instead of passwords for SSH tunnel

