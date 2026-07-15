(* Export the contract's canonical *vocabulary* from lib/schema/Registry as a
   machine-readable vocab.json, so non-OCaml producers (running-ng) can generate
   an emitter that speaks the exact same names, mappings, and config_id algorithm.

   This is distinct from the JSON Schema (which describes structure): vocab.json
   carries the *semantics* the schema deliberately leaves open — canonical metric
   names/units/layers, the raw→canonical field maps, the modifier→dimension map,
   and the config_id recipe.

   Run: dune exec tools/gen_vocab.exe -- schema/json/vocab.json *)

module R = Schema.Registry
module C = Schema.Contract

let obj kvs = `Assoc kvs
let str s = `String s

let metric_catalog =
  obj (List.map (fun (name, (unit_, layer, source)) ->
    (name, obj [ ("unit", str unit_); ("layer", `Int layer); ("source", str source) ]))
    R.metric_catalog)

let str_map pairs = obj (List.map (fun (k, v) -> (k, str v)) pairs)

let dimension_of_modifier =
  obj (List.map (fun (m, (dim, unit_)) ->
    (m, obj [ ("dimension", str dim); ("unit", str unit_) ]))
    R.dimension_of_modifier)

let vocab : Yojson.Safe.t =
  obj
    [
      ("schema_version", str C.schema_version);
      ( "config_id",
        obj
          [
            ("algorithm", str "md5");
            ("prefix", str R.config_id_prefix);
            ("field_separator", str R.config_id_field_sep);
            ("list_separator", str R.config_id_list_sep);
            ("fields", `List [ str "kind"; str "version"; str "commit"; str "options"; str "dimensions" ]);
            ( "recipe",
              str
                "canonical = kind FS version FS (commit|\"\") FS join(sorted(options),LS) FS \
                 join(sorted(\"k=v\" for dims),LS); id = prefix + md5_hex(canonical). \
                 FS=field_separator, LS=list_separator. Dimension values: int/bool/string \
                 stringified plainly, floats via %g." );
          ] );
      ("metric_catalog", metric_catalog);
      ("olly_field_map", str_map R.olly_field_map);
      ("perf_event_map", str_map R.perf_event_map);
      ("dimension_of_modifier", dimension_of_modifier);
      ("olly_output_version_supported", `List (List.map (fun i -> `Int i) R.olly_output_version_supported));
      ( "tool_supported_versions",
        obj (List.map (fun (t, vs) -> (t, `List (List.map str vs))) R.tool_supported_versions) );
    ]

let () =
  let out = if Array.length Sys.argv > 1 then Sys.argv.(1) else "schema/json/vocab.json" in
  (try Unix.mkdir (Filename.dirname out) 0o755 with _ -> ());
  let oc = open_out out in
  output_string oc (Yojson.Safe.pretty_to_string vocab);
  output_char oc '\n';
  close_out oc;
  Printf.printf "wrote %s\n" out
