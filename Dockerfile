# Serve the pre-built static dashboard with nginx. Run `npm run build` first so
# dist/ exists (see README "Share the dashboard").
FROM nginx:alpine

# Which benchmark run is baked into this image (visible via `docker inspect`).
ARG RUN_LABEL=unknown
LABEL org.opencontainers.image.title="OCaml Benchmark Dashboard" \
      org.opencontainers.image.description="Static OCaml benchmark dashboard; baked run: ${RUN_LABEL}" \
      org.opencontainers.image.source="https://github.com/ocaml/ocaml-bench-dashboard"

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY dist/ /usr/share/nginx/html/
