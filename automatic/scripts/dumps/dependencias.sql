-- CREATE ROLE <usuario> WITH LOGIN PASSWORD 'password';
CREATE ROLE <usuario> WITH LOGIN PASSWORD 'password';

-- Agregar permisos
-- GRANT ALL PRIVILEGES ON DATABASE <nombre_base_datos> TO <usuario>;
GRANT ALL PRIVILEGES ON DATABASE <nombre_base_datos> TO <usuario>;

-- Agregar las extensiones necesarias
-- CREATE EXTENSION IF NOT EXISTS <nombre_extension>;