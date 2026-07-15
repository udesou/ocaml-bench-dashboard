(** The two "one place to touch when extending" tables (DATA_CONTRACT §6), plus
    the canonical [config_id] derivation.

    - [dimension_of_modifier] replaces the reader's hardwired KNOWN_GC_PARAMS:
      add a row here to teach the pipeline a new sweep axis.
    - [olly_field_map] / [perf_event_map] / [metric_catalog] are the raw->canonical
      metric mapping: add a row to surface a new metric (e.g. future olly
      fragmentation stats) with NO schema change — see DATA_CONTRACT §7. *)

(* ------------------------------------------------------------------ *)
(* Modifier name -> (dimension key, unit)                              *)
(* ------------------------------------------------------------------ *)

let dimension_of_modifier : (string * (string * string)) list =
  [
    ("s", ("minor_heap", "words"));
    ("o", ("space_overhead", "pct"));
    ("M", ("custom_major_ratio", "pct"));
    ("m", ("custom_minor_ratio", "pct"));
    ("re", ("runtime_events_ring_log2", "log2_words"));
    ("md", ("max_domains", "count"));
    (* lavyek-scoped variants map to the SAME axes *)
    ("re_par", ("runtime_events_ring_log2", "log2_words"));
    ("md_par", ("max_domains", "count"));
  ]

(* ------------------------------------------------------------------ *)
(* Canonical metric catalog: name -> (unit, layer, source)             *)
(* layer: 1 user-visible | 2 GC/runtime | 3 hardware  (roadmap Metrics) *)
(* ------------------------------------------------------------------ *)

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

(* ------------------------------------------------------------------ *)
(* Source-tool compatibility (the bridge to external tools)            *)
(*                                                                     *)
(* Three DISTINCT version concepts — keep them apart:                  *)
(*   - Contract.schema_version : our canonical artifact contract       *)
(*   - manifest.tool_versions  : the ACTUAL tool binary versions,      *)
(*       recorded uniformly by the runner via `<tool> --version`       *)
(*       (provenance, one entry per tool, every run)                   *)
(*   - tool_supported_versions : the tool versions the maps above are  *)
(*       written against (below)                                       *)
(*                                                                     *)
(* Ingestion compares each recorded binary version against the         *)
(* supported set here, uniformly for every tool, and FAILS LOUD on an  *)
(* unsupported one rather than silently misparsing. Field-presence     *)
(* checks back this up (a metric named in a map but absent from the     *)
(* raw output is reported, never a silent null).                       *)
(*                                                                     *)
(* Breaking tool change: update the map(s), bump the entry here, and — *)
(* ONLY if it changes canonical metric names/units/semantics — bump    *)
(* Contract.schema_version. Otherwise it is absorbed here and consumers *)
(* never see it.                                                        *)
(* ------------------------------------------------------------------ *)

(** Supported *release* version prefixes per tool, matched (prefix) against the
    versions the runner records via `<tool> --version` in manifest.tool_versions.

    These are the tools' RELEASE versions — olly 0.5.x (runtime_events_tools),
    perf 6.x — NOT olly's self-stamped JSON output "version" field, which is a
    separate, coarser format version (see [olly_output_version_supported]). *)
let tool_supported_versions : (string * string list) list =
  [ ("olly", [ "0.5" ]); ("perf", [ "6" ]) ]

let tool_supported (tool : string) (version : string) : bool =
  let has_prefix p =
    String.length version >= String.length p && String.sub version 0 (String.length p) = p
  in
  match List.assoc_opt tool tool_supported_versions with
  | Some prefixes -> List.exists has_prefix prefixes
  | None -> false

(** Distinct from the release version above: olly self-stamps its JSON *output*
    with a top-level integer "version" (currently 1) — the format version of the
    gc-stats JSON, independent of the 0.5.x release number. The adapter checks
    this against the set below; the uniform guard is the release version. *)
let olly_output_version_supported : int list = [ 1 ]

(* ------------------------------------------------------------------ *)
(* Canonical config_id (DATA_CONTRACT §4.2 / §8)                       *)
(* A content hash of the NORMATIVE fields only, so two conforming       *)
(* runners produce the same id for the same config -> data is joinable. *)
(* ------------------------------------------------------------------ *)

(* config_id canonicalization — deliberately a delimiter-joined string, NOT a
   JSON serialization, so any language reproduces it bit-identically without
   matching a JSON library's spacing/key-order/escaping quirks. The exact recipe
   is exported in vocab.json (config_id block) for non-OCaml producers.

   canonical = kind ⟨FS⟩ version ⟨FS⟩ (commit|"") ⟨FS⟩
               join(sorted(options), ",") ⟨FS⟩
               join(sorted("k=v" for each dimension), ",")
   where FS = US (0x1f); config_id = "cfg_" ^ md5_hex(canonical). *)
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
