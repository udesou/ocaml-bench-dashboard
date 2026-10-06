(** Canonical types of the benchmarking data contract (docs/DATA_CONTRACT.md);
    schema/json is generated from them and [of_yojson] is the validator. The
    open parts (dimensions, selector, string maps) use hand-written converters
    so the wire shape is a plain JSON object, not a derived encoding. *)

let schema_version = "1.0"

type json = Yojson.Safe.t

let json_to_yojson (j : json) : Yojson.Safe.t = j
let json_of_yojson (j : Yojson.Safe.t) : (json, string) result = Ok j

(** Open map of axis name -> scalar, e.g. {"space_overhead": 80}; the only
    place sweep dimensions live. *)
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

(** A string->int map serialized as a JSON object (machine.cpu_kinds). *)
type int_map = (string * int) list

let int_map_to_yojson (m : int_map) : Yojson.Safe.t =
  `Assoc (List.map (fun (k, v) -> (k, `Int v)) m)
let int_map_of_yojson : Yojson.Safe.t -> (int_map, string) result = function
  | `Assoc l -> (
      try Ok (List.map (function k, `Int v -> (k, v) | _ -> raise Exit) l)
      with Exit -> Error "int_map: expected integer values")
  | _ -> Error "int_map: expected object"

(** Comparison selector: field path -> required value, e.g.
    {"runtime.version": "5.4.1", "space_overhead": 80}. *)
type selector = (string * json) list

let selector_to_yojson (s : selector) : Yojson.Safe.t = `Assoc s
let selector_of_yojson : Yojson.Safe.t -> (selector, string) result =
  function `Assoc l -> Ok l | _ -> Error "selector: expected object"

(* ppx_deriving_jsonschema references [t_jsonschema] for a field of type [t];
   these complete the generated schema for the hand-written encodings. *)
let json_jsonschema : Yojson.Safe.t = `Assoc []  (* {} = any *)
let dimensions_jsonschema : Yojson.Safe.t =
  `Assoc [ ("type", `String "object") ]
let str_map_jsonschema : Yojson.Safe.t =
  `Assoc
    [ ("type", `String "object");
      ("additionalProperties", `Assoc [ ("type", `String "string") ]) ]
let int_map_jsonschema : Yojson.Safe.t =
  `Assoc
    [ ("type", `String "object");
      ("additionalProperties", `Assoc [ ("type", `String "integer") ]) ]
let selector_jsonschema : Yojson.Safe.t = `Assoc [ ("type", `String "object") ]

(* Config descriptor, DATA_CONTRACT.md §4.2 *)

type runtime = {
  kind : string;                         (* "OCaml" | "OxCaml" | "OCamlMMTk" *)
  version : string;                      (* never derived from a runtime name *)
  commit : string option; [@default None]
  options : string list; [@default []]   (* ["frame-pointers"; "flambda"] *)
}
[@@deriving yojson, jsonschema]

type config_descriptor = {
  config_id : string;                    (* see Registry.canonical_config_id *)
  runtime : runtime;
  dimensions : dimensions; [@default []]
  tools : string list; [@default []]
  (* advisory running-ng spellings; consumers must not depend on these *)
  runtime_name : string option; [@key "_runtime_name"] [@jsonschema.key "_runtime_name"] [@default None]
  modifiers : string list; [@key "_modifiers"] [@jsonschema.key "_modifiers"] [@default []]
}
[@@deriving yojson, jsonschema]

(* Measurement record (one per invocation), DATA_CONTRACT.md §4.3 *)

type metric = {
  name : string;
  value : float;
  unit_ : string; [@key "unit"] [@jsonschema.key "unit"]
  source : string;                       (* "olly" | "perf" | … *)
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
  schema_version : string;
  run_id : string;
  benchmark : benchmark_ref;
  config : config_ref;
  invocation : int;
  metrics : metric list;
  raw_ref : str_map; [@default []]
}
[@@deriving yojson, jsonschema]

(* Comparison declaration, DATA_CONTRACT.md §4.5 *)

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

(* Run manifest (one per run), DATA_CONTRACT.md §4.4 *)

type machine = {
  hostname : string;
  cpu_model : string option; [@default None]
  cores : int option; [@default None]
  kernel : string option; [@default None]
  governor : string option; [@default None]
  isolcpus : string option; [@default None]
  turbo : bool option; [@default None]
  (* Topology: results from the same cpu_model are not comparable if one ran on
     E-cores or spanned sockets, and nothing else in the manifest shows it. *)
  cpu_isolation : string option; [@default None]  (* isolcpus|irqaffinity|topology|none *)
  physical_cores : int option; [@default None]
  threads_per_core : int option; [@default None]
  numa_nodes : int option; [@default None]
  sockets : int option; [@default None]
  cpu_kinds : int_map; [@default []]              (* e.g. {"P": 8, "E": 16} *)
}
[@@deriving yojson, jsonschema]

type manifest = {
  schema_version : string;
  run_id : string;
  created_at : string;                   (* ISO-8601 *)
  machine : machine;
  tool_versions : str_map; [@default []]
  configs : config_descriptor list; [@default []]
  comparisons : comparison list; [@default []]
  benchmarks : benchmark_ref list; [@default []]
  (* advisory, e.g. "running-ng 1.3 (native)" or "adapter 0.1 (from legacy)" *)
  produced_by : string option; [@key "_produced_by"] [@jsonschema.key "_produced_by"] [@default None]
}
[@@deriving yojson, jsonschema]

(* Benchmark registry entry, DATA_CONTRACT.md §4.1 *)

type benchmark_entry = {
  name : string;
  suite : string;
  path : string;
  args : string list; [@default []]
  tags : string list; [@default []]
  build_model : string;                  (* "switch" | "monorepo" *)
}
[@@deriving yojson, jsonschema]
