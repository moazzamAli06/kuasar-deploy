#!/bin/sh
# Runs once, the first time the PostgreSQL volume is created (docker-entrypoint-initdb.d).
#
# For every service it creates ONE database and TWO roles:
#   <svc>_owner  owns the database. Used only by the one-shot migration job, to create/alter tables.
#   <svc>_app    what the running service connects as. It can read and write rows, but cannot create, alter or drop anything.
#
# Nobody else can even connect: CONNECT is revoked from PUBLIC, so identity_app cannot open kuasar_audit, and so on.
# The PostgreSQL superuser (POSTGRES_USER) is for operators only; no service is ever given it.
#
# Passwords arrive as environment variables (DB_<SERVICE>_OWNER_PASSWORD / DB_<SERVICE>_APP_PASSWORD) and are passed to psql as
# variables, never pasted into the SQL text.
set -eu

create_database() {
  svc="$1"; owner_pw="$2"; app_pw="$3"
  db="kuasar_${svc}"; owner="${svc}_owner"; app="${svc}_app"

  echo "init: creating database ${db} with roles ${owner} and ${app}"

  psql -v ON_ERROR_STOP=1 -v owner_pw="$owner_pw" -v app_pw="$app_pw" --username "$POSTGRES_USER" --dbname postgres <<SQL
    CREATE ROLE ${owner} LOGIN PASSWORD :'owner_pw';
    CREATE ROLE ${app}   LOGIN PASSWORD :'app_pw';
    CREATE DATABASE ${db} OWNER ${owner};
    REVOKE ALL ON DATABASE ${db} FROM PUBLIC;
    GRANT CONNECT ON DATABASE ${db} TO ${app};
SQL

  psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$db" <<SQL
    REVOKE ALL ON SCHEMA public FROM PUBLIC;
    ALTER SCHEMA public OWNER TO ${owner};
    GRANT USAGE ON SCHEMA public TO ${app};

    -- Every table the owner creates later (through migrations) is automatically usable by the app role for normal row access.
    -- Individual migrations then take away more where needed (for example audit_events becomes insert-only).
    ALTER DEFAULT PRIVILEGES FOR ROLE ${owner} IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO ${app};
    ALTER DEFAULT PRIVILEGES FOR ROLE ${owner} IN SCHEMA public GRANT USAGE, SELECT ON SEQUENCES TO ${app};
SQL
}

require() { eval "value=\${$1:-}"; [ -n "$value" ] || { echo "init: $1 is required" >&2; exit 1; }; }

for svc in identity organization project audit platform ai sandbox billing; do
  upper=$(echo "$svc" | tr '[:lower:]' '[:upper:]')
  require "DB_${upper}_OWNER_PASSWORD"; require "DB_${upper}_APP_PASSWORD"
  eval "owner_pw=\$DB_${upper}_OWNER_PASSWORD; app_pw=\$DB_${upper}_APP_PASSWORD"
  create_database "$svc" "$owner_pw" "$app_pw"
done
echo "init: all databases and roles created"
