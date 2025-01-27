#!/bin/bash

set -x
set -eo pipefail
if ! [ -x "$(command -v sqlx)" ]; then
    echo >&2 "Error: sqlx is not installed."
    echo >&2 "Use:"
    echo >&2 " cargo install --version='~0.8' sqlx-cli \
    --no-default-features --features rustls,postgres"
    echo >&2 "to install it."
    exit 1
fi

CONTAINER_NAME="postgres16-zerotoprod"

DB_PORT="${POSTGRES_PORT:=5432}"
SUPERUSER="${SUPERUSER:=postgres}"
SUPERUSER_PWD="${SUPERUSER_PWD:=password}"

APP_USER="${APP_USER:=app}"
APP_USER_PWD="${APP_USER_PWD:=secret}"
APP_DB_NAME="${APP_DB_NAME:=newsletter}"

# docker run \
# --env POSTGRES_USER=${SUPERUSER} \
# --env POSTGRES_PASSWORD=${SUPERUSER_PWD} \
# --publish "${DB_PORT}":5432 \
# --detach \
# --name "${CONTAINER_NAME}" \
# postgres -N 1000
# ^ Increased maximum number of connections for testing purposes

POSTGRES_USER=${SUPERUSER} POSTGRES_PASSWORD=${SUPERUSER_PWD} docker compose up --detach

until [ \
    "$(docker inspect -f "{{.State.Health.Status}}" "${CONTAINER_NAME}")" == \
    "healthy" \
]; do
    >&2 echo "Postgres is still unavailable - sleeping"
    sleep 1
done

>&2 echo "Postgres is up and running on port ${DB_PORT}!"

CREATE_QUERY="CREATE USER ${APP_USER} WITH PASSWORD '${APP_USER_PWD}';"
docker exec -it "${CONTAINER_NAME}" psql -U "${SUPERUSER}" -c "${CREATE_QUERY}"
# Grant create db privileges to the app user
GRANT_QUERY="ALTER USER ${APP_USER} CREATEDB;"
docker exec -it "${CONTAINER_NAME}" psql -U "${SUPERUSER}" -c "${GRANT_QUERY}"


DATABASE_URL=postgres://${APP_USER}:${APP_USER_PWD}@localhost:${DB_PORT}/${APP_DB_NAME}
export DATABASE_URL

sqlx database create