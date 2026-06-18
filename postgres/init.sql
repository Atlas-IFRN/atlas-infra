-- Atlas — inicialização do PostgreSQL
-- Cria os schemas isolados para cada serviço Django

CREATE SCHEMA IF NOT EXISTS auth;
CREATE SCHEMA IF NOT EXISTS tracks;
CREATE SCHEMA IF NOT EXISTS scholarship;

-- Extensões úteis
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";

-- Garante que o usuário da aplicação tem acesso a todos os schemas
GRANT ALL PRIVILEGES ON SCHEMA auth TO atlas_user;
GRANT ALL PRIVILEGES ON SCHEMA tracks TO atlas_user;
GRANT ALL PRIVILEGES ON SCHEMA scholarship TO atlas_user;

