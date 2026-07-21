#!/bin/sh
# Build the static site for a chosen benchmark run and package it as a
# self-contained Docker image that serves it with nginx.
#
#   BENCH_RUN_DIR=~/running-ng/<a-run> sh scripts/package-image.sh [tag]
#
# `tag` defaults to the run directory's basename, so the image name records
# which experiment it shows (e.g. ocaml-bench-dashboard:monolith-2026-05-25-...).
# After it prints the image name, share it via a registry (docker push) or as a
# file (docker save) — see README "Share the dashboard".
set -e

RUN_DIR="${BENCH_RUN_DIR:-$HOME/running-ng/gc-sweep-logs-pr14796/monolith-2026-05-25-Mon-102618}"
IMAGE="${IMAGE:-ocaml-bench-dashboard}"
RUN_LABEL="$(basename "$RUN_DIR")"
TAG="${1:-$RUN_LABEL}"

if [ ! -d "$RUN_DIR" ]; then
  echo "BENCH_RUN_DIR does not exist: $RUN_DIR" >&2
  exit 1
fi

echo ">> Building static site from run: $RUN_DIR"
BENCH_RUN_DIR="$RUN_DIR" npm run build

echo ">> Building image $IMAGE:$TAG"
docker build --build-arg "RUN_LABEL=$RUN_LABEL" -t "$IMAGE:$TAG" .

echo
echo "Done. Preview it:"
echo "  docker run --rm -p 8080:80 $IMAGE:$TAG   # then open http://localhost:8080"
echo
echo "Share it (pick one):"
echo "  # via registry (GHCR):"
echo "  docker tag  $IMAGE:$TAG ghcr.io/<owner>/$IMAGE:$TAG"
echo "  docker push ghcr.io/<owner>/$IMAGE:$TAG"
echo "  # via file (no registry):"
echo "  docker save $IMAGE:$TAG | gzip > $IMAGE-$TAG.tar.gz"
