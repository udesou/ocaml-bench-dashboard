(lang dune 3.0)
(name bench-contract)
(version 1.0.0)
(generate_opam_files true)

(package
 (name bench-contract)
 (synopsis "OCaml benchmarking data contract: canonical types, registries, validators")
 (description
  "Canonical OCaml types for the benchmarking data contract (measurement\n\
   records, run manifest, config descriptors, comparisons), the metric and\n\
   dimension registries, and JSON (de)serializers that double as validators.\n\
   Shared by the ingestor and by runner-side adapters/emitters so there is a\n\
   single source of truth for the contract. The package version tracks the\n\
   contract's schema_version.")
 (depends
  (ocaml (>= 4.14))
  dune
  yojson
  (ppx_deriving_yojson (>= 3.9.0))
  ; Upper bounds are deliberate, not laziness — see CLAUDE.md "Gotchas".
  ; ppx_deriving_jsonschema 0.0.8 renamed the runtime functions the deriver
  ; emits (`list_jsonschema` and friends), so lib/schema stops compiling with
  ; `Unbound value list_jsonschema`. It also generates different `default` /
  ; nullability output, which would silently rewrite every schema/json/*.json.
  ; Raise this bound only together with a regeneration commit.
  (ppx_deriving_jsonschema (and (>= 0.0.7) (< 0.0.8)))
  ; ppxlib 0.38 is what 0.0.7 is built against here; both ppx above must agree
  ; on it, so an unconstrained solve can pick a combination that won't build.
  (ppxlib (>= 0.36.0))))
