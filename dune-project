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
  ppx_deriving_yojson
  ppx_deriving_jsonschema))
