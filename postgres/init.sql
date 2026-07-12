-- ============================================================
-- Atlas — inicialização do PostgreSQL
-- Banco único `atlas` com três schemas isolados.
-- O schema usado por cada serviço é definido por conexão via
-- PGOPTIONS=-c search_path=<schema>,public (ver docker-compose.yml).
-- ============================================================

-- Extensões (vivem no schema public, acessível por todos via search_path)
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- Schemas isolados por serviço
CREATE SCHEMA IF NOT EXISTS auth;
CREATE SCHEMA IF NOT EXISTS tracks;
CREATE SCHEMA IF NOT EXISTS scholarship;
CREATE SCHEMA IF NOT EXISTS notification;

-- O usuário da aplicação (POSTGRES_USER) é dono dos schemas.
-- Como todos os serviços conectam com o mesmo usuário, o isolamento
-- é garantido pelo search_path por conexão (PGOPTIONS), não por
-- permissões distintas. Os GRANTs abaixo são explícitos por clareza.
GRANT ALL PRIVILEGES ON SCHEMA auth         TO CURRENT_USER;
GRANT ALL PRIVILEGES ON SCHEMA tracks       TO CURRENT_USER;
GRANT ALL PRIVILEGES ON SCHEMA scholarship  TO CURRENT_USER;
GRANT ALL PRIVILEGES ON SCHEMA notification TO CURRENT_USER;

-- Garante que objetos criados futuramente em cada schema fiquem
-- acessíveis ao usuário da aplicação.
ALTER DEFAULT PRIVILEGES IN SCHEMA auth         GRANT ALL ON TABLES TO CURRENT_USER;
ALTER DEFAULT PRIVILEGES IN SCHEMA tracks       GRANT ALL ON TABLES TO CURRENT_USER;
ALTER DEFAULT PRIVILEGES IN SCHEMA scholarship  GRANT ALL ON TABLES TO CURRENT_USER;
ALTER DEFAULT PRIVILEGES IN SCHEMA notification GRANT ALL ON TABLES TO CURRENT_USER;
