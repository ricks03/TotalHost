#!/usr/bin/env bash

for t in *.t
do
    echo "# Running ${t}"
    ./${t}
done
