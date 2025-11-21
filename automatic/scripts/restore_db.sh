#!/bin/bash
set -e

echo "....Iniciando restauración de base de datos..."

# Variables de entorno
DB_NAME=${POSTGRES_NEW_DB} #Nueva DB
DB_USER=${POSTGRES_USER} #Usuario utilizado en la creación del contenedor postgreSQL

# Crear nueva base de datos utilizando la base de datos "postgres"
echo ".....Creando base de datos $DB_NAME..."
psql -U "$DB_USER" -d postgres -c "CREATE DATABASE $DB_NAME;"

# Crear usuarios
echo "....Creando usuarios..."
psql -U "$DB_USER" -d "$DB_NAME" -f ./dumps/dependencias.sql

# Restaurar dump del esquema
echo "...Restaurando estructura desde dump..."
psql -U "$DB_USER" -d "$DB_NAME" -f ./dumps/dump-estructura.sql

echo "...Restauración completa."