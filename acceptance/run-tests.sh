#!/usr/bin/env bash

set -e
set -u
set -o pipefail

./db-reset.sh $1

prove -v .
