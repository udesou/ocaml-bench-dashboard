(** Extension tables (DATA_CONTRACT.md §6, §7) and the canonical [config_id]
    derivation. A new sweep axis is a row in [dimension_of_modifier]; a new
    metric is a row in the metric maps. Neither needs a schema change. *)

let dimension_of_modifier : (string * (string * string)) list =
  [
    ("s", ("minor_heap", "words"));
    ("o", ("space_overhead", "pct"));
    ("M", ("custom_major_ratio", "pct"));
    ("m", ("custom_minor_ratio", "pct"));
    ("re", ("runtime_events_ring_log2", "log2_words"));
    ("md", ("max_domains", "count"));
    (* lavyek-scoped variants share the axes *)
    ("re_par", ("runtime_events_ring_log2", "log2_words"));
    ("md_par", ("max_domains", "count"));
    (* MMTk name-value modifiers (plan-Bactrian, threads-1), so configs differing
       only by MMTK_PLAN / MMTK_THREADS get distinct config_ids *)
    ("plan", ("gc_plan", "name"));
    ("threads", ("gc_threads", "count"));
  ]

(* name -> (unit, layer, source); layer 1 user-visible, 2 GC/runtime, 3 hardware *)

let metric_catalog : (string * (string * int * string)) list =
  [
    ("wall_time", ("s", 1, "olly"));
    ("cpu_time", ("s", 1, "olly"));
    ("max_rss", ("KiB", 1, "olly"));
    ("mean_latency", ("ms", 1, "olly"));
    ("gc_overhead", ("pct", 2, "olly"));
    ("gc_time", ("s", 2, "olly"));
    ("minor_collections", ("count", 2, "olly"));
    ("major_collections", ("count", 2, "olly"));
    ("promoted_pct", ("pct", 2, "olly"));
    ("minor_words", ("words", 2, "olly"));
    ("major_words", ("words", 2, "olly"));
    ("instructions", ("count", 3, "perf"));
    ("cycles", ("count", 3, "perf"));
    ("page_faults", ("count", 3, "perf"));
    ("task_clock", ("ns", 3, "perf"));
  ]

(** olly raw field (dotted path into the olly object) -> canonical metric name. *)
let olly_field_map : (string * string) list =
  [
    ("wall_time", "wall_time");
    ("cpu_time", "cpu_time");
    ("gc_time", "gc_time");
    ("gc_overhead", "gc_overhead");
    ("max_rss_kb", "max_rss");
    ("mean_latency", "mean_latency");
    ("allocations.promoted_pct", "promoted_pct");
    ("allocations.minor_heap", "minor_words");
    ("allocations.major_heap", "major_words");
    ("collections.minor", "minor_collections");
    ("collections.major", "major_collections");
  ]

(** perf event name (as emitted by `perf stat -j`) -> canonical metric name. *)
let perf_event_map : (string * string) list =
  [
    ("instructions", "instructions");
    ("cycles", "cycles");
    ("page-faults", "page_faults");
    ("task-clock", "task_clock");
  ]

(* A breaking tool change updates the maps above and this table; bump
   Contract.schema_version only if canonical metric names/units/semantics change. *)

(** Release-version prefixes (olly 0.5.x, perf 6.x) matched against the
    `<tool> --version` strings in manifest.tool_versions; ingest fails loudly on
    an unsupported one. Not olly's JSON "version" ([olly_output_version_supported]). *)
let tool_supported_versions : (string * string list) list =
  [ ("olly", [ "0.5" ]); ("perf", [ "6" ]) ]

let tool_supported (tool : string) (version : string) : bool =
  let has_prefix p =
    String.length version >= String.length p && String.sub version 0 (String.length p) = p
  in
  match List.assoc_opt tool tool_supported_versions with
  | Some prefixes -> List.exists has_prefix prefixes
  | None -> false

(** olly's self-stamped JSON output "version" (format version, independent of
    the release). 2 (olly 9e5b2d6) only added an [outliers] block, so both
    parse with [olly_field_map]. *)
let olly_output_version_supported : int list = [ 1; 2 ]

(* config_id (DATA_CONTRACT.md §8): hash of the normative fields only, as a
   US-joined string rather than JSON so any language reproduces it bit-identically;
   the recipe is exported in vocab.json (config_id block). *)
let config_id_field_sep = "\x1f"
let config_id_list_sep = ","
let config_id_prefix = "cfg_"

let dim_value_to_string : Contract.json -> string = function
  | `Int i -> string_of_int i
  | `Float f -> Printf.sprintf "%g" f
  | `Bool b -> if b then "true" else "false"
  | `String s -> s
  | other -> Yojson.Safe.to_string other

let canonical_config_id (rt : Contract.runtime) (dims : Contract.dimensions) :
    string =
  let options = String.concat config_id_list_sep (List.sort String.compare rt.options) in
  let dim_str =
    dims
    |> List.map (fun (k, v) -> k ^ "=" ^ dim_value_to_string v)
    |> List.sort String.compare
    |> String.concat config_id_list_sep
  in
  let canonical =
    String.concat config_id_field_sep
      [ rt.kind; rt.version; (match rt.commit with Some c -> c | None -> ""); options; dim_str ]
  in
  config_id_prefix ^ Digest.to_hex (Digest.string canonical)
