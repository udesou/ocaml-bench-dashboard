(* Generate JSON Schema files from the canonical OCaml contract types
   (DATA_CONTRACT §10.1). Run: `dune exec tools/gen_schema.exe -- schema/json`.

   Structure/properties/types come straight from ppx_deriving_jsonschema, so they
   can never drift from the OCaml types. One correction is applied: the deriver
   marks every non-`option` field `required`, but our collection fields carry
   `[@default []]` and are optional on the wire (ppx_deriving_yojson drops them
   when empty). So we recursively remove those field names from every `required`
   array — at every nesting level, since objects are inlined not referenced. *)

(* Fields that are optional on the wire everywhere they appear. *)
let always_optional =
  [ "tags"; "options"; "tools"; "_modifiers"; "dimensions"; "raw_ref";
    "configs"; "comparisons"; "benchmarks"; "tool_versions"; "args" ]

let rec fix_required (j : Yojson.Safe.t) : Yojson.Safe.t =
  match j with
  | `Assoc l ->
      `Assoc
        (List.map
           (fun (k, v) ->
             match (k, v) with
             | "required", `List names ->
                 ( k,
                   `List
                     (List.filter
                        (function `String s -> not (List.mem s always_optional) | _ -> true)
                        names) )
             | _ -> (k, fix_required v))
           l)
  | `List xs -> `List (List.map fix_required xs)
  | other -> other

let draft = "https://json-schema.org/draft/2020-12/schema"

let set k v = function
  | `Assoc l -> `Assoc ((k, v) :: List.remove_assoc k l)
  | other -> other

let finalize ~title schema =
  fix_required schema |> set "$schema" (`String draft) |> set "title" (`String title)

let types : (string * Yojson.Safe.t) list =
  [
    ("runtime", Schema.Contract.runtime_jsonschema);
    ("config_descriptor", Schema.Contract.config_descriptor_jsonschema);
    ("metric", Schema.Contract.metric_jsonschema);
    ("benchmark_ref", Schema.Contract.benchmark_ref_jsonschema);
    ("config_ref", Schema.Contract.config_ref_jsonschema);
    ("measurement", Schema.Contract.measurement_jsonschema);
    ("machine", Schema.Contract.machine_jsonschema);
    ("comparison", Schema.Contract.comparison_jsonschema);
    ("manifest", Schema.Contract.manifest_jsonschema);
    ("benchmark_entry", Schema.Contract.benchmark_entry_jsonschema);
  ]

let rec mkdir_p dir =
  if dir <> "" && dir <> "." && dir <> "/" && not (Sys.file_exists dir) then begin
    mkdir_p (Filename.dirname dir);
    (try Unix.mkdir dir 0o755 with Unix.Unix_error (Unix.EEXIST, _, _) -> ())
  end

let () =
  let outdir = if Array.length Sys.argv > 1 then Sys.argv.(1) else "schema/json" in
  mkdir_p outdir;
  List.iter
    (fun (name, schema) ->
      let path = Filename.concat outdir (name ^ ".schema.json") in
      let oc = open_out path in
      output_string oc (Yojson.Safe.pretty_to_string (finalize ~title:name schema));
      output_char oc '\n';
      close_out oc;
      Printf.printf "wrote %s\n" path)
    types
