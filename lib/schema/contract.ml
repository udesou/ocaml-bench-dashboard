(** Benchmarking data contract — canonical OCaml types.

    OCaml is the source of truth (see docs/DATA_CONTRACT.md, decision §10.1); a
    JSON Schema is generated from these types for non-OCaml consumers such as the
    Python running-ng validator.

    Every artifact type here has [to_yojson] / [of_yojson] (via
    ppx_deriving_yojson). [of_yojson] doubles as the validator: a record that
    does not parse is not conformant.

    Open/flexible parts of the contract — [dimensions], [selector], string maps —
    are represented as JSON objects with hand-written converters so the wire
    shape is exactly `{ "space_overhead": 80, … }` rather than a derived
    encoding. This is deliberate: the wire format *is* the contract. *)

let schema_version = "1.0"

(* ------------------------------------------------------------------ *)
(* Flexible JSON building blocks (exact object encodings)              *)
(* ------------------------------------------------------------------ *)

type json = Yojson.Safe.t

let json_to_yojson (j : json) : Yojson.Safe.t = j
let json_of_yojson (j : Yojson.Safe.t) : (json, string) result = Ok j

(** An open map of axis name -> scalar value, e.g. {"space_overhead": 80}. The
    single place GC/sweep dimensions live — replaces the reader's hardwired
    KNOWN_GC_PARAMS. *)
type dimensions = (string * json) list

let dimensions_to_yojson (d : dimensions) : Yojson.Safe.t = `Assoc d
let dimensions_of_yojson : Yojson.Safe.t -> (dimensions, string) result =
  function `Assoc l -> Ok l | _ -> Error "dimensions: expected object"

(** A string->string map serialized as a JSON object (tool_versions, raw_ref). *)
type str_map = (string * string) list

let str_map_to_yojson (m : str_map) : Yojson.Safe.t =
  `Assoc (List.map (fun (k, v) -> (k, `String v)) m)
let str_map_of_yojson : Yojson.Safe.t -> (str_map, string) result = function
  | `Assoc l -> (
      try Ok (List.map (function k, `String v -> (k, v) | _ -> raise Exit) l)
      with Exit -> Error "str_map: expected string values")
  | _ -> Error "str_map: expected object"

(** A comparison selector: field path -> required value, e.g.
    {"runtime.version": "5.4.1", "space_overhead": 80}. *)
type selector = (string * json) list

let selector_to_yojson (s : selector) : Yojson.Safe.t = `Assoc s
let selector_of_yojson : Yojson.Safe.t -> (selector, string) result =
  function `Assoc l -> Ok l | _ -> Error "selector: expected object"

(* JSON Schema fragments for the hand-written flex types. ppx_deriving_jsonschema
   resolves a field of type [t] by referencing [t_jsonschema], so these make the
   generated schema complete without the deriver understanding our encodings. *)
let json_jsonschema : Yojson.Safe.t = `Assoc []  (* {} = any *)
let dimensions_jsonschema : Yojson.Safe.t =
  `Assoc [ ("type", `String "object") ]
let str_map_jsonschema : Yojson.Safe.t =
  `Assoc
    [ ("type", `String "object");
      ("additionalProperties", `Assoc [ ("type", `String "string") ]) ]
let selector_jsonschema : Yojson.Safe.t = `Assoc [ ("type", `String "object") ]

(* ------------------------------------------------------------------ *)
(* Config descriptor (§4.2) — identity of HOW a benchmark was run      *)
(* ------------------------------------------------------------------ *)

type runtime = {
  kind : string;                         (* "OCaml" | "OxCaml" | "OCamlMMTk" *)
  version : string;                      (* explicit — never peeled off a name *)
  commit : string option; [@default None]
  options : string list; [@default []]   (* ["frame-pointers"; "flambda"] *)
}
[@@deriving yojson, jsonschema]

type config_descriptor = {
  config_id : string;                    (* canonical hash of the normative fields *)
  runtime : runtime;
  dimensions : dimensions; [@default []]
  tools : string list; [@default []]
  (* advisory provenance — running-ng spellings; consumers must not depend on these *)
  runtime_name : string option; [@key "_runtime_name"] [@jsonschema.key "_runtime_name"] [@default None]
  modifiers : string list; [@key "_modifiers"] [@jsonschema.key "_modifiers"] [@default []]
}
[@@deriving yojson, jsonschema]

(* ------------------------------------------------------------------ *)
(* Measurement record (§4.3) — one per invocation, the linchpin        *)
(* ------------------------------------------------------------------ *)

type metric = {
  name : string;
  value : float;
  unit_ : string; [@key "unit"] [@jsonschema.key "unit"]
  source : string;                       (* tool provenance: "olly" | "perf" | … *)
  layer : int;                           (* 1 user-visible | 2 GC | 3 hardware *)
}
[@@deriving yojson, jsonschema]

type benchmark_ref = {
  name : string;
  suite : string;
  tags : string list; [@default []]
}
[@@deriving yojson, jsonschema]

type config_ref = { config_id : string } [@@deriving yojson, jsonschema]

type measurement = {
  schema_version : string;  (* mandatory: always emitted, required on parse *)
  run_id : string;
  benchmark : benchmark_ref;
  config : config_ref;
  invocation : int;
  metrics : metric list;
  raw_ref : str_map; [@default []]
}
[@@deriving yojson, jsonschema]

(* ------------------------------------------------------------------ *)
(* Comparison declaration (§4.5) — inter / intra / both                *)
(* ------------------------------------------------------------------ *)

type comparison = {
  kind : string;                         (* "inter" | "intra" | "both" *)
  label : string option; [@default None]
  over : json option; [@default None]    (* "runtime" | ["space_overhead"; …] *)
  mode : string option; [@default None]  (* "pairwise" | "cartesian" *)
  baseline : selector option; [@default None]
  variants : selector list option; [@default None]
  fix : selector option; [@default None]
  baseline_at : selector option; [@default None]
}
[@@deriving yojson, jsonschema]

(* ------------------------------------------------------------------ *)
(* Run manifest (§4.4) — one per run                                   *)
(* ------------------------------------------------------------------ *)

type machine = {
  hostname : string;
  cpu_model : string option; [@default None]
  cores : int option; [@default None]
  kernel : string option; [@default None]
  governor : string option; [@default None]
  isolcpus : string option; [@default None]
  turbo : bool option; [@default None]
}
[@@deriving yojson, jsonschema]

type manifest = {
  schema_version : string;  (* mandatory: always emitted, required on parse *)
  run_id : string;
  created_at : string;                   (* ISO-8601 *)
  machine : machine;
  tool_versions : str_map; [@default []]
  configs : config_descriptor list; [@default []]
  comparisons : comparison list; [@default []]
  benchmarks : benchmark_ref list; [@default []]
  (* advisory provenance — how these artifacts were produced, e.g.
     "running-ng 1.3 (native)" or "adapter 0.1 (from legacy)". Lets a consumer
     tell natively-emitted data from adapted data. *)
  produced_by : string option; [@key "_produced_by"] [@jsonschema.key "_produced_by"] [@default None]
}
[@@deriving yojson, jsonschema]

(* ------------------------------------------------------------------ *)
(* Benchmark registry entry (§4.1) — identity of a workload            *)
(* ------------------------------------------------------------------ *)

type benchmark_entry = {
  name : string;
  suite : string;
  path : string;
  args : string list; [@default []]
  tags : string list; [@default []]
  build_model : string;                  (* "switch" | "monorepo" *)
}
[@@deriving yojson, jsonschema]
