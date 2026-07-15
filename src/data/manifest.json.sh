#!/bin/sh
# Ingestor (contract-only): validate + emit the run manifest from ./contract.
set -e
./bin/ingest manifest contract
