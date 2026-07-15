#!/bin/sh
# Ingestor (contract-only): validate + emit measurement records from ./contract.
set -e
./bin/ingest measurements contract
