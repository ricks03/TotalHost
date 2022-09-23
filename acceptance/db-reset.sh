#!/usr/bin/env bash

set -e
set -u
set -o pipefail

wait-for tcp:db:5432

GOOSE_DRIVER=postgres
GOOSE_DBSTRING="user=${PGUSER} password=${PGPASSWORD} dbname=${PGDATABASE} host=${PGHOST} port=${PGPORT} sslmode=disable"

goose ${GOOSE_DRIVER} "${GOOSE_DBSTRING}" status
goose -dir $1 ${GOOSE_DRIVER} "${GOOSE_DBSTRING}" reset
goose -dir $1 ${GOOSE_DRIVER} "${GOOSE_DBSTRING}" up
