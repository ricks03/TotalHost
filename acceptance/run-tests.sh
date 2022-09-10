#!/usr/bin/env bash

set -e
set -u
set -o pipefail

wait-for tcp:db:5432

GOOSE_DRIVER=postgres
GOOSE_DBSTRING="user=postgres password=postgres dbname=totalhost host=db port=5432 sslmode=disable"

goose ${GOOSE_DRIVER} "${GOOSE_DBSTRING}" status
goose -dir $1 ${GOOSE_DRIVER} "${GOOSE_DBSTRING}" reset
goose -dir $1 ${GOOSE_DRIVER} "${GOOSE_DBSTRING}" up

for t in *.t
do
    echo "# Running ${t}"
    ./${t}
done
