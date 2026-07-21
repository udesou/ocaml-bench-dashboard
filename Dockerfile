# Serve the pre-built static dashboard.
#
# The site is fully static: `npm run build` bakes the ingested run into
# `dist/` (see README "Share the dashboard"), so this image just serves those
# files with nginx — no OCaml, Node, or ingestor at run time. Build `dist/`
# FIRST, then build this image.
#
#   export BENCH_RUN_DIR=~/running-ng/<a-run>
#   npm run build
#   docker build --build-arg RUN_LABEL=<run> -t ocaml-bench-dashboard:<run> .
#   docker run --rm -p 8080:80 ocaml-bench-dashboard:<run>   # http://localhost:8080
FROM nginx:alpine

# Provenance: which benchmark run is baked into this image (shown by
# `docker inspect`). Defaults to unknown when not passed.
ARG RUN_LABEL=unknown
LABEL org.opencontainers.image.title="OCaml Benchmark Dashboard" \
      org.opencontainers.image.description="Static OCaml benchmark dashboard; baked run: ${RUN_LABEL}" \
      org.opencontainers.image.source="https://github.com/ocaml/ocaml-bench-dashboard"

# Clean-URL routing (/curves -> curves.html); see nginx.conf.
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY dist/ /usr/share/nginx/html/
