-- Create backup user
CREATE USER backup WITH PASSWORD 'your_secure_password_here';

-- Grant connect permission to the user
GRANT CONNECT ON DATABASE outline TO backup;
GRANT CONNECT ON DATABASE bitwarden TO backup;
GRANT CONNECT ON DATABASE umami TO backup;
GRANT CONNECT ON DATABASE shlink TO backup;

-- Grant usage on schemas (needed to access tables)
GRANT USAGE ON SCHEMA public TO backup;

-- Grant select permissions on all tables in each database
-- For outline database
GRANT SELECT ON ALL TABLES IN SCHEMA public TO backup;
GRANT SELECT ON ALL SEQUENCES IN SCHEMA public TO backup;

-- For bitwarden database  
GRANT SELECT ON ALL TABLES IN SCHEMA public TO backup;
GRANT SELECT ON ALL SEQUENCES IN SCHEMA public TO backup;

-- For umami database
GRANT SELECT ON ALL TABLES IN SCHEMA public TO backup;
GRANT SELECT ON ALL SEQUENCES IN SCHEMA public TO backup;

-- For shlink database
GRANT SELECT ON ALL TABLES IN SCHEMA public TO backup;
GRANT SELECT ON ALL SEQUENCES IN SCHEMA public TO backup;

-- Grant permissions on future tables (optional - for new tables created after this)
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO backup;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON SEQUENCES TO backup;

-- If you need the user to be able to create temporary tables (useful for some backup tools)
GRANT TEMPORARY ON DATABASE outline TO backup;
GRANT TEMPORARY ON DATABASE bitwarden TO backup;
GRANT TEMPORARY ON DATABASE umami TO backup;
GRANT TEMPORARY ON DATABASE shlink TO backup; 