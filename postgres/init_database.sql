-- PostgreSQL Initialization Script
-- Mail Box Indexer Database Setup
--
-- This script creates the database, user, and grants necessary permissions
-- Run this after installing PostgreSQL

-- Connect as postgres superuser first:
-- psql -U postgres -f init_database.sql

-- ============================================================================
-- Database Creation
-- ============================================================================

-- Create the database for Mail Box Indexer
CREATE DATABASE mail_box_indexer
    WITH
    OWNER = postgres
    ENCODING = 'UTF8'
    LC_COLLATE = 'C'
    LC_CTYPE = 'C'
    TABLESPACE = pg_default
    CONNECTION LIMIT = -1
    IS_TEMPLATE = False;

COMMENT ON DATABASE mail_box_indexer
    IS 'Blockchain indexer database for WildDuck mail server';

-- ============================================================================
-- User Creation
-- ============================================================================

-- Check if user exists, create if not
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'ponder') THEN
        CREATE USER ponder WITH PASSWORD 'password';
        RAISE NOTICE 'User "ponder" created with default password';
        RAISE NOTICE 'IMPORTANT: Change the password immediately for production!';
        RAISE NOTICE 'Run: ALTER USER ponder WITH PASSWORD ''your-strong-password'';';
    ELSE
        RAISE NOTICE 'User "ponder" already exists';
    END IF;
END
$$;

-- Configure user settings
ALTER USER ponder WITH
    NOSUPERUSER
    NOCREATEDB
    NOCREATEROLE
    NOINHERIT
    LOGIN
    NOREPLICATION
    NOBYPASSRLS
    CONNECTION LIMIT -1;

COMMENT ON ROLE ponder
    IS 'Mail Box Indexer application user (Ponder framework)';

-- ============================================================================
-- Database Permissions
-- ============================================================================

-- Grant connection to database
GRANT CONNECT ON DATABASE mail_box_indexer TO ponder;

-- Grant temporary table creation
GRANT TEMPORARY ON DATABASE mail_box_indexer TO ponder;

-- Connect to the database to set schema permissions
\c mail_box_indexer

-- Grant usage and create on public schema
GRANT USAGE ON SCHEMA public TO ponder;
GRANT CREATE ON SCHEMA public TO ponder;

-- Grant all privileges on all existing tables in public schema
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO ponder;

-- Grant all privileges on all existing sequences
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO ponder;

-- Grant all privileges on all existing functions
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO ponder;

-- Set default privileges for future objects created by postgres
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT ALL PRIVILEGES ON TABLES TO ponder;

ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT ALL PRIVILEGES ON SEQUENCES TO ponder;

ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT ALL PRIVILEGES ON FUNCTIONS TO ponder;

ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT ALL PRIVILEGES ON TYPES TO ponder;

-- Set default privileges for objects created by ponder itself
ALTER DEFAULT PRIVILEGES FOR USER ponder IN SCHEMA public
    GRANT ALL PRIVILEGES ON TABLES TO ponder;

ALTER DEFAULT PRIVILEGES FOR USER ponder IN SCHEMA public
    GRANT ALL PRIVILEGES ON SEQUENCES TO ponder;

ALTER DEFAULT PRIVILEGES FOR USER ponder IN SCHEMA public
    GRANT ALL PRIVILEGES ON FUNCTIONS TO ponder;

-- Make ponder the owner of the database and schema (recommended)
ALTER DATABASE mail_box_indexer OWNER TO ponder;
ALTER SCHEMA public OWNER TO ponder;

-- ============================================================================
-- Extensions
-- ============================================================================

-- Install useful extensions
-- These are optional but commonly useful for indexer applications

-- pgcrypto: Cryptographic functions
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- uuid-ossp: UUID generation functions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- pg_trgm: Trigram matching for fast text search
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- btree_gin: GIN index support for btree data types
CREATE EXTENSION IF NOT EXISTS btree_gin;

-- btree_gist: GiST index support for btree data types
CREATE EXTENSION IF NOT EXISTS btree_gist;

-- ============================================================================
-- Monitoring Extensions
-- ============================================================================

-- pg_stat_statements: Query performance monitoring
-- Requires: shared_preload_libraries = 'pg_stat_statements' in postgresql.conf
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- Grant access to monitoring views
GRANT SELECT ON pg_stat_statements TO ponder;
GRANT SELECT ON pg_stat_activity TO ponder;

-- ============================================================================
-- Initial Configuration
-- ============================================================================

-- Set default search path for ponder user
ALTER USER ponder SET search_path TO public;

-- Set default statement timeout (30 seconds)
ALTER USER ponder SET statement_timeout TO '30s';

-- Set default idle in transaction timeout (60 seconds)
ALTER USER ponder SET idle_in_transaction_session_timeout TO '60s';

-- ============================================================================
-- Verification Queries
-- ============================================================================

-- List databases
\l

-- List users and their privileges
\du

-- Show database size
SELECT pg_database.datname,
       pg_size_pretty(pg_database_size(pg_database.datname)) AS size
FROM pg_database
WHERE datname = 'mail_box_indexer';

-- Show installed extensions
\dx

-- ============================================================================
-- Success Messages
-- ============================================================================

\echo '============================================================================'
\echo 'Database setup completed successfully!'
\echo '============================================================================'
\echo ''
\echo 'Database: mail_box_indexer'
\echo 'User: ponder'
\echo 'Password: password (CHANGE THIS FOR PRODUCTION!)'
\echo ''
\echo 'Connection string for .env file:'
\echo 'DATABASE_URL=postgresql://ponder:password@localhost:5432/mail_box_indexer'
\echo ''
\echo 'For Docker on Windows:'
\echo 'DATABASE_URL=postgresql://ponder:password@host.docker.internal:5432/mail_box_indexer'
\echo ''
\echo 'Next steps:'
\echo '1. Change the password: ALTER USER ponder WITH PASSWORD ''your-strong-password'';'
\echo '2. Copy postgresql.conf to C:\PostgreSQL\data\postgresql.conf'
\echo '3. Copy pg_hba.conf to C:\PostgreSQL\data\pg_hba.conf'
\echo '4. Restart PostgreSQL: Restart-Service postgresql-x64-17'
\echo '5. Test connection: psql -U ponder -d mail_box_indexer'
\echo ''
\echo '============================================================================'
