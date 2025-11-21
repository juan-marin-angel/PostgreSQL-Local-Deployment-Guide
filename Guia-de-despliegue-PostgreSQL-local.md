# Guía de Migración de Base de Datos PostgreSQL a Entorno Local en Contenedores
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16-blue.svg)](https://www.postgresql.org/)
[![pgAdmin](https://img.shields.io/badge/pgAdmin-pg-blue.svg)](https://www.pgadmin.org/)
[![Docker](https://img.shields.io/badge/Docker-Compose-blue.svg)](https://www.docker.com/)

---

> **Autor:** Juan Manuel Marin A  
> **Fecha:** 2025-11-11  
> **Versión:** 1.0  
> **Revisión:** Pública – Documento técnico demostrativo  

---

## 📋 Tabla de Contenido

- [Introducción](#-introduccion)
    - [Importancia del despliegue local para pruebas](#-importancia-despliegue-local)

- [Requisitos previos](#-requisitos-previos)
    - [Archivo de respaldo .sql](#-respaldo-sql)
    - [Dependencias globales (roles, extensiones)](#dependencias-globales)
    - [Identificación de extensiones](#-identificación-de-extensiones)
    - [Descarga de archivos desde el servidor remoto](#descarga-archivos-remotos)

- [Despliegue manual](#-despliegue-manual)
    - [Estructura del Proyecto](#-estructura-proyecto-manual)
    - [Creación de docker-compose](#-despliegue-contenedores-manual)
    - [Restauración del respaldo](#-restauración-respaldo)
    - [Consola interactiva de PostgreSQL](#-consola-interactiva-postgresql)
    - [Creación de la base de datos](#-creación-base-de-datos)
    - [Cargar roles y extensiones](#-cargar-roles-y-extensiones)
    - [Creación de usuarios y asignación de permisos](#-creación-de-usuarios)
    - [Carga de dump](#-carga-de-dump)
    - [Revisión](#-revisión)

- [Despliegue Automático](#-despliegue-automático)
    - [Estructura del Proyecto](#-estructura-proyecto-automático)
    - [Estrctura archivo .env](#-estructura-archivo-env)
    - [Estrctura archivo dependencias.sql](#-estructura-archivo-dependencias)
    - [Script de restauración](#-script-restauración)
    - [Descripción en docker-compose.yaml](#-despliegue-contenedores-automático)
    - [Verificación rápida](#-verificación-rápida)

---
---
---


## 📘 Introducción

Este documento describe el procedimiento para desplegar y restaurar una base de datos PostgreSQL desde un servidor remoto a un entorno local en contenedores Docker, utilizando configuraciones manuales y automáticas.

El objetivo es garantizar la disponibilidad de una réplica local del entorno de base de datos que permita realizar pruebas, validaciones y ajustes antes de ejecutar cambios en entornos productivos.

En este caso unicamente vamos a exportar la estructura de la base de datos sin información almacenada en ella.

### 🔍 Importancia del Despliegue Local para Pruebas

Contar con un entorno local ofrece múltiples beneficios:
- **Seguridad y control:** evita riesgos sobre la base de datos en producción.
- **Reproducibilidad:** permite replicar y probar los mismos escenarios que en entornos productivos.
- **Rapidez en el desarrollo:** reduce los tiempos de iteración y validación de cambios.
- **Independencia:** posibilita el trabajo sin conexión al entorno remoto.
- **Automatización:** facilita la integración con pipelines CI/CD y pruebas automatizadas.

---
---
---

## ⚙️ Requisitos Previos

- Docker y Docker Compose instalados.
- Acceso al servidor remoto PostgreSQL.
1. 🧾 Archivo de respaldo .sql obtenido desde el servidor remoto:
    - Cuando se hace una migración (por ejemplo, con pg_dump y pg_restore), los objetos (tablas, vistas, funciones, etc.) mantienen el nombre del propietario y los permisos asociados. 
    ```bash
       pg_dump -U <Usuario> -W -h <host> <base_de_datos>  \
       -n <schema> \
       --schema-only \
       --create --clean --if-exists \
       -f <nombrearchivo>.sql
    ```
    - Explicación:
        - **pg_dump**: Utilidad que permite extraer información de PostgreSQL en un archivo .dump o .sql.
        - **-U**: Indica el usuario para la conexión
        - **< Usuario >**: Usuario de base de datos a utilizar para generar el dump.
        - **-W**: Indica que se solicita contraseña para realizar el proceso.
        - **-h**: Indica el host donde se encuentra la base de datos
        - **<host>**: Dirección del servidor (IP - localhost)
        - **<base_de_datos>**: Nombre de la base de datos
        - **-n**: solo el schema específico
        - **<schema>**: schema al que se realiza el dump.
        - **--schema-only**: excluye todos los datos (solo estructura)
        - **--create**: incluye la creación del la base de datos y el schema
        - **--clean --if-exists**: limpia objetos previos al restaurar
        - **-f**: Indica que se debe generar en un archivo 
        - **<nombrearchivo>**:  Nombre del archivo con el que se genera el .sql

2. 🧩 Dependencias globales (roles, extensiones).
    - **Roles**:
        - En PostgreSQL, los roles representan usuarios y grupos con permisos específicos sobre bases de datos, esquemas, tablas, funciones, etc.
        - Un rol puede:
            - Conectarse a la base (LOGIN),
            - Crear objetos (CREATEDB, CREATEROLE),
            - Tener permisos de lectura/escritura sobre tablas,
            - Ser propietario de objetos dentro de la base.
        - **Si esos roles no existen en el entorno destino, ocurren problemas como:**
            - ❌ Errores de restauración
            - ⚠️ Propiedades huérfanas: los objetos quedan sin propietario.
            - 🔐 Pérdida de control de acceso: los permisos GRANT/REVOKE fallan.
            - 💣 Inconsistencias en entornos con múltiples aplicaciones o servicios.
    - **Extensiones**:
        - Las extensiones son paquetes que agregan funcionalidades adicionales a PostgreSQL.
        - Las extensiones definen tipos de datos, funciones y operadores usados por los objetos en la base.
        - Si la extensión no está instalada, la restauración puede fallar o los datos quedar corruptos.
        - Entre las mas comunes:
            - **uuid-ossp**: genera UUIDs.
            - **pgcrypto**: encriptación y hashing.
            - **postgis**: soporte geoespacial.
            - **citext**: tipo de texto case-insensitive.
            - **pg_stat_statements**: monitoreo de consultas.

     - **NOTA: No siempre es posible generarlo por los permisos que tenga el usuario con el que estemos realizando el proceso**
	    ```bash
        pg_dumpall -U <Usuario> -W -h <host> --globals-only -f <nombrearchivo>.sql
        ``` 
        - Explicación:
            - **pg_dumpall**: Utilidad que permite extraer información de PostgreSQL en un archivo .dump o .sql.
            - **-U**: Indica el usuario para la conexión
            - **< Usuario>**: Usuario de base de datos a utilizar para generar el archivo.
            - **-W**: Indica que se solicita contraseña para realizar el proceso.
            - **-h**: Indica el host donde se encuentra la base de datos
            - **< host>**: Dirección del servidor (IP - localhost)
            - **--globals-only**: Indica que solo exporte los objetos globales. Objetos que no pertenecen a una base de datos en particular.
            - **-f**: Indica que se debe generar en un archivo 
            - **<nombre_archivo>**:  Nombre del archivo con el que se genera el .sql

3. ⚙️ Identificación de extensiones
    - Si no fue posible generar el dump de las dependencias globales es necesario identificar las extensiones actuales en la base de datos para instalarlas en el nuevo destino. Para ello estando dentro de **psql** en la base de datos a migrar o exportar ejecutamos
        ```SQL
        \dx
        ```
    - Salida esperada:
        ```bash
                                    List of installed extensions
        Name     | Version |      Schema      |                 Description
        ----------+---------+------------------+---------------------------------------------
        plpgsql  | 1.0     | pg_catalog       | PL/pgSQL procedural language
        unaccent | 1.1     | <NombreSchema>   | text search dictionary that removes accents
        ```

4. 💾 Descarga de archivos desde el servidor remoto
    - Los archivos generados se deben descargar a local o donde se desplegaron los contenedores
        - Desde SO Windows para descargar un archivo desde un servidor remoto (mediante SSH) autenticando con una llave privada (.ppk) utiliando PSCP (PuTTY Secure Copy).
        ```bash
        pscp -i <ruta_public-key>.ppk <usuario>@<IP_servidor>:<path_archivo_a_descargar>.sql <path_para_descarga>
        ```
        - Explicación:
            - **pscp** : Herramienta de línea de comandos de PuTTY para copiar archivos de forma segura
            - **-i**: Indica que se usará llave privada (.ppk) para autenticar en el servidor (en lugar de contraseña). 
            - **<ruta_public-key>**: Ruta donde se encuentra la llave privada (.ppk)
            - **< usuario>@<IP_servidor>** : Credenciales de conexión SSH: el usuario remoto y la dirección IP o nombre de host del servidor.
            - **<path_para_descarga>**: Ruta completa del archivo remoto que deseas descargar desde el servidor.
            - **<path_para_descarga>**: Ruta local donde se guardará el archivo descargado.
---
---
---

## 🔧 Despliegue Manual

El despliegue manual permite controlar cada paso del proceso de migración, desde la creación del contenedor hasta la restauración del respaldo.

1. 📁 Estructura del Proyecto
    ```
    /postgres-local-deployment/
    └── manual/
        ├── docker-compose.yaml
        ├── dumps/
        └──── dump-base-de-datos.sql
    ```
    - Descripción:
        - **docker-compose.yaml**: define los servicios (PostgreSQL y pgAdmin) y lo que se ejecutara al crear los contenedores.
        - **dumps/**: contiene los archivos generados en la fase de exportación.

2. 🧱 Despliegue de los contenedores a partir de docker-compose.yaml
    - Contenido de archivo docker-compose.yaml con las instrucciones de los contenedores a utilizar.
        ```yaml
        services:
            postgres:
                image: postgres:16
                container_name: postgres_db
                restart: unless-stopped
                environment:
                POSTGRES_USER: postgres
                POSTGRES_PASSWORD: admin123
                volumes:
                - ./dumps:/etc/postgresql                     # Mapea los dumps locales hacia el contenedor.
                - postgres_data:/var/lib/postgresql/data
                ports:
                - "5432:5432"
                networks:
                - postgres_network

            pgadmin:
                image: dpage/pgadmin4:latest
                container_name: pgadmin
                restart: unless-stopped
                environment:
                PGADMIN_DEFAULT_EMAIL: admin@admin.com
                PGADMIN_DEFAULT_PASSWORD: admin123
                ports:
                - "8080:80"
                depends_on:
                - postgres
                networks:
                - postgres_network

        volumes:
          postgres_data:

        networks:
          postgres_network:
            driver: bridge
        ```
    - El archivo docker-compose.yaml contiene la descripción de:
        - Contenedor con imagen **postgres:16** para el despliegue del esquema de base de datos.
            - usuario y contraseña **preferiblemente agregar en variables de ambiente para mayor seguridad**
            - Se mapea la carpeta dumps para compartir el archivo con el dump realizado a la base de datos
            - Volumen para almacenar la información de PostgreSQL.
            - Red interna para conectar los dos contenedores
        - Contenedor con imagen **pgadmin** para la conexión al motor de base de datos.
            - usuario y contraseña **preferiblemente agregar en variables de ambiente para mayor seguridad**
            - Red interna para conectar los dos contenedores
    - Ejecutar el siguiente comando para levantar los contenedores a partir de la configuración de docker-compose.yaml
        ```bash
        docker-compose up -d
        ```
        * Salida esperada
            ```docker
            [+] Running 4/4
            ✔ Network desplieguemanual_postgres_network    Created             0.1s 
            ✔ Volume "desplieguemanual_postgres_data"      Created             0.0s 
            ✔ Container postgres_db                        Started             0.6s 
            ✔ Container pgadmin                            Started             0.7s
            ```
    - Validación de contenedores desplegados:
        - Acceder a **pgadmin** desde un navegador a [localhost:8080](http://localhost:8080) y utilizar los siguientes datos para el inicio de sesión:
            - **Email**: admin@admin.com
            - **Contraseña**: admin123
        - Dentro de la plataforma **pgadmin** es necesario agregar la conexión hacia el contenedor **PostgreSQL** haciendo la siguiente configuración:
            - Se debe crear un nuevo servidor en **Objeto > Register > Servidor**:
                -  En la pestaña **General**:
                    - **Nombre**: <nombre_identificación_servidor>
                - En la pestaña **Connection**:
                    - **Nombre/Dirección del servidor**: postgres
                    - **Puerto**: 5432
                    - **Nombre de usuario**: postgres
                    - **Contraseña**: admin123
            - Guardar la configuración para terminar
        - Ahora podemos ver la conexión hacia el servicio en el contenedor postgres

3. 💾 Restauración del respaldo
    - Consola interactiva de PostgreSQL
        - Ingresar a la linea de comandos del contendor postgres con el siguiente comando:
            ```bash
            docker exec -it <nombre_o_id_contenedor> /bin/bash
            ```
            - En el docker-compose el contenedor postgreSQL tiene como nombre postgres_db
        - Ingresar a la consola interactiva **psql** de PostgreSQL:
            ```bash
            psql -U <usuario> -d <nombre_base_datos>
            ```
            - En el docker-compose el usuario definido y la base de datos por defecto es "postgres"
            - Explicación:
                - **psql**: línea de comandos de PostgreSQL
                - **-U**: Indica el usuario para la conexión
                - **< usuario >**: Usuario de base de datos a utilizar para generar el archivo
                - **-d**: Especifica el nombre de la base de datos
                - **<nombre_base_datos>**: Base de datos a la que se va a conectar

    - Creación de la base de datos.
        - Estando en la consola interactiva **psql** crear la base de datos con el siguiente comando.
            - **NOTA**: Es posible crear la base de datos y usuario desde el docker-compose.yaml y evitar estos pasos.
            - **NOTA**: La base de datos a crear debe tener el mismo nombre que registra en el dump.
            ```SQL
            CREATE DATABASE <nombre_base_datos>;
            ``` 
            - Revisar en el dump el nombre de la base de datos

    - Cargar roles y extensiones
        - Si fue posible generar el archivo con configuraciones globales en los pasos de la sección Requisitos Previos, es momento de importarlos.
        - Es importante hacer esto antes de restaurar el esquema
            ```bash
            psql  -U <Usuario> -W -h <host> -f <nombrearchivo>.sql
            ```
            - Explicación:
                - **-U**: Indica el usuario para la conexión
                - **< Usuario>**: Usuario de base de datos a utilizar para generar el archivo.
                - **-W**: Indica que se solicita contraseña para realizar el proceso.
                - **-h**: Indica el host donde se encuentra la base de datos
                - **< host>**: Dirección del servidor (IP - localhost)
                - **-f**: Indica que se debe generar en un archivo 
                - **<nombre_archivo>**:  Nombre del archivo con el que se genera el .sql
        - **NOTA: Si no fue posible la generación del dump con las dependencias globales (extensiones, roles... ) se debe realizar la creación de forma manual como se indica a continuación.**
        - **NOTA: Si fue posible realizar el dump de dependencias globales y cargarlos en el paso anterior, no es necesario continuar con los pasos de creación de usuarios y asignación de permisos.**
        - Creación de usuarios y asignación de permisos
            - Es necesario revisar en el dump del schema el/los OWNER registrados dentro del archivo. Si existen OWNER diferentes al usuario 'postgres', estos deben ser creados antes de restaurar el dump del schema.
                - El usuario postgres ya se encuentra creado y es el usuario root dentro del contenedor postgreSQL.
                - Para crear usuarios adicionales. Estando en la linea de comandos **psql** Crear el usuario con el siguiente comando:
                    ```SQL
                    CREATE ROLE <usuario> WITH LOGIN PASSWORD 'password';
                    ```
                    - Explicación:
                        - **< usuario>**: Usuario identificado dentro del dump del esquema exportado
                        - **'password'**: Contraseña para el usuario.
                - Otorgar privilegios (permisos) a los usuarios hacia la base de datos
                    ```SQL
                    GRANT ALL PRIVILEGES ON DATABASE <nombre_base_datos> TO <usuario>;
                    ``` 
            - **NOTA: Esto se debe realizar por cada usuario encontrado dentro del schema y que sea diferente al usuario 'postgres'.**
        - Creación de extensiones identificadas en la fase de "Requisitos previos" en "Identificación de extensiones"
            - Estando en la linea de comandos **psql** conectado a la base de datos creada en pasos anteriores, ejecutar
                ```SQL
                CREATE EXTENSION IF NOT EXISTS <extensión>;
                ```
                - Explicación:
                    - **<extensión>**: Nombre de la extensión a agregar.
                - **NOTA: Esto se debe ejecutar por cada extensión identificada**

    - Carga de dump
        - Cargar el schema
            ```bash
            psql -U <Usuario> -d <nombre_base_datos> -f <nombre_archivo>.sql
            ```
            - Explicación:
                - **-U**: Indica el usuario para la conexión
                - **< Usuario>**: Usuario de base de datos a utilizar para generar el archivo.
                - **-d**: Especifica el nombre de la base de datos
                - **<base_de_datos>**: Nombre de la base de datos
                - **-f**: Indica que se debe generar en un archivo 
                - **<nombre_archivo>**:  Nombre del archivo con el que se genera el .sql
    - Revisión
        - Es necesario conectarse a la linea de comandos **psql** y a la base de datos donde fue cargado el dump.
            ```bash
            psql -U <Usuario> -d <nombre_base_datos>
            ```
        - Validar esquema
            ```bash
            \dn
            ```
            - Se deben listar los esquemas creados dentro de la base de datos observando el esquema importado
        - Validar relaciones
            ```bash
            \dt <schema>.*
            ```
            - **< schema>**: esquema a validar
            - Se debe listar las tablas que contiene el esquema con el esquema, el tipo y el propietario
        - Validar funciones
            ```bash
            \df <schema>.*
            ```
            - **< schema>**: esquema a validar
            - Debe listar las funciones dentro del esquema junto con el nombre, tipo de dato resultante, los argumentos y el tipo de función

---
---
---

## ⚙️ Despliegue Automático

El despliegue automático permite levantar el entorno de PostgreSQL, restaurar el respaldo y configurar los usuarios y extensiones de forma no interactiva, mediante el uso de Docker Compose y scripts de inicialización.
Este enfoque es ideal para integrarlo en procesos de CI/CD, reproducir entornos rápidamente y minimizar errores manuales.

En esta guía vamos a tratar el despliegue automático a partir del dump .sql de la base de datos ya generado y no automatizado.

1. 📁 Estructura del Proyecto
    ```
    /postgres-local-deployment/
    └── automatic/
        ├── docker-compose.yaml
        ├── .env
        └── scripts/
            ├── restore_db.sh
            └── dumps/
                ├── dump-estructura.sql
                └── dependencias.sql
    ```
    - Descripción:
        - **docker-compose.yaml**: define los servicios (PostgreSQL y pgAdmin) y los scripts que se ejecutarán automáticamente al crear los contenedores.
        - **scripts/restore_db.sh**: script que restaura el respaldo .sql automáticamente.
        - **scripts/init_extensions.sql**: archivo con las extensiones que deben crearse antes de importar el dump.
        - **dumps/**: contiene los archivos generados en la fase de exportación.
        - **.env**: define las variables de entorno sensibles (usuario, contraseña, base de datos).

2. ⚙️ Estrctura archivo .env
    - Es un archivo de texto simple que almacena variables de entorno, separando la configuración sensible (como claves de API, credenciales de bases de datos, etc.) del código. Este formato CLAVE=valor permite gestionar fácilmente la configuración en diferentes entornos (desarrollo, producción) mejorando la seguridad y la flexibilidad.

    - Ejemplo de configuración:
        ```bash
        # Configuración para la creación del contenedor de la base de datos
         # usuario root para la base de datos
        POSTGRES_USER=postgres
         # contraseña para el usuario root
        POSTGRES_PASSWORD=admin123
         # Nombre de la base de datos donde se va a restaurar el dump
        POSTGRES_NEW_DB=<Nombre_base_de_datos>


        # Configuración para la creación del contenedor pgadmin
         # Usuario por default de pgadmin 
        PGADMIN_DEFAULT_EMAIL=admin@admin.com
         # Contraseña para el usuario default de pgadmin
        PGADMIN_DEFAULT_PASSWORD=admin123
        ```

3. 💡 Estructura archivo /dumps/dependencias.sql
    - Este archivo contiene información importante de usuarios, permisos y extensiones que deben ser creados antes de restaurar el dump de la base de datos.
        ```bash
        -- Agregar usuarios
        -- CREATE ROLE <usuario> WITH LOGIN PASSWORD 'password';
        CREATE ROLE <usuario> WITH LOGIN PASSWORD 'password';

        -- Agregar permisos
        -- GRANT ALL PRIVILEGES ON DATABASE <nombre_base_datos> TO <usuario>;
        GRANT ALL PRIVILEGES ON DATABASE <nombre_base_datos> TO <usuario>;

        -- Agregar las extensiones necesarias
        -- CREATE EXTENSION IF NOT EXISTS <nombre_extension>;
        ```

4. 🧩 Script de restauración: restore_db.sh
    - El archivo restore_db.sh contiene los pasos e información para la restauración del esquema en la base de datos PostgreSQL a ser desplegada en los contenedores locales.
        ```bash
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
        ```

5. 🧱  Descripción de contenedores en docker-compose.yaml
    - Contenido de archivo docker-compose.yaml con las instrucciones de los contenedores a utilizar.
        ```yaml
        services:
            postgres:
                image: postgres:16
                container_name: postgres_db_auto
                restart: unless-stopped
                env_file:
                - .env
                volumes:
                - ./scripts:/docker-entrypoint-initdb.d/              # Mapea los scripts y dumps locales hacia el contenedor.
                - postgres_data:/var/lib/postgresql/data
                ports:
                - "5432:5432"
                networks:
                - postgres_network

            pgadmin:
                image: dpage/pgadmin4:latest
                container_name: pgadmin_auto
                restart: unless-stopped
                env_file:
                - .env
                ports:
                - "8080:80"
                depends_on:
                - postgres
                networks:
                - postgres_network

        volumes:
          postgres_data:

        networks:
          postgres_network:
            driver: bridge
        ```
    - El archivo docker-compose.yaml contiene la descripción de:
        - Contenedor con imagen **postgres:16** para el despliegue del esquema de base de datos.
            - .env archivo con variables de entorno 
            - Se mapea la carpeta dump para compartir el archivo con el dump realizado a la base de datos y los scripts para despliegue
            - Volumen para almacenar la información de PostgreSQL.
            - Red interna para conectar los dos contenedores
        - Contenedor con imagen **pgadmin** para la conexión al motor de base de datos.
            - .env archivo con variables de entorno 
            - Red interna para conectar los dos contenedores
        - PostgreSQL ejecuta automáticamente todos los scripts .sql y .sh presentes en **/docker-entrypoint-initdb.d/** solo la primera vez que se crea el volumen de datos.
            - Si se desea repetir la importación, primero se debe eliminar el volumen:
            ```bash
            docker compose down -v
            ```

    - Ejecutar el siguiente comando para levantar los contenedores a partir de la configuración de docker-compose.yaml
        ```bash
        docker-compose up -d
        ```
        * Salida esperada
            ```docker
            [+] Running 4/4
            ✔ Network despliegueautomático_postgres_network     Created             0.1s 
            ✔ Volume "despliegueautomático_postgres_data"       Created             0.0s 
            ✔ Container postgres_db_auto                        Started             0.6s 
            ✔ Container pgadmin_auto                            Started             0.7s
            ```

6. ✅ Verificación rápida
    - Una vez levantados los contenedores es posible realizar verificación del despliegue realizado
    - Si se lista el esquema y las tablas, la restauración fue exitosa.
        - Validar esquema
            ```bash
            docker exec -it postgres_db_auto psql -U postgres -d <base_de_datos> -c "\dn"    
            ```
            - **<base_de_datos>**: Nombre de la base de datos
            - Se debe listar el esquema desplegado

        ```bash
        docker exec -it postgres_db_auto psql -U postgres -d <base_de_datos> -c "\dt <esquema>.*"
        ```
        - **<base_de_datos>**: Nombre de la base de datos
        - **<base_de_datos>**: Nombre del esquema de la base de datos
    - El comando debe listar las tablas de la base de datos
    - Tambien es posible validar el despliegue desde **pgadmin** utilizando los datos de acceso agregados en el archivo .env
    
