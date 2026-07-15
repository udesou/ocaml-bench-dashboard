(* Smoke test: build contract values, serialize, validate by re-parsing, and
   show the wire shapes + a canonical config_id. Not a real test suite yet. *)
open Schema

let runtime : Contract.runtime =
  { kind = "OCaml"; version = "5.6.0+trunk"; commit = Some "cfb30145"; options = [] }

let dims : Contract.dimensions =
  [ ("runtime_events_ring_log2", `Int 25); ("max_domains", `Int 2) ]

let config_id = Registry.canonical_config_id runtime dims

let cfg : Contract.config_descriptor =
  { config_id; runtime; dimensions = dims; tools = [ "perf"; "olly" ];
    runtime_name = Some "ocaml-trunk-cfb30145";
    modifiers = [ "perf_grp1"; "re-25"; "md-2" ] }

let m : Contract.measurement =
  { schema_version = Contract.schema_version;
    run_id = "monolith-2026-05-25-Mon-102618";
    benchmark = { name = "cpdf_scale"; suite = "macro-cpdf-monorepo"; tags = [ "macro" ] };
    config = { config_id };
    invocation = 3;
    metrics =
      [ { name = "wall_time"; value = 13.02; unit_ = "s"; source = "olly"; layer = 1 };
        { name = "instructions"; value = 2.09e11; unit_ = "count"; source = "perf"; layer = 3 } ];
    raw_ref = [ ("olly", "olly_cpdf_scale.….json#L3") ] }

let () =
  Printf.printf "config_id = %s\n\n" config_id;
  Printf.printf "== config_descriptor ==\n%s\n\n"
    (Yojson.Safe.pretty_to_string (Contract.config_descriptor_to_yojson cfg));
  Printf.printf "== measurement ==\n%s\n\n"
    (Yojson.Safe.pretty_to_string (Contract.measurement_to_yojson m));
  (* validate by re-parsing *)
  let round = Contract.measurement_of_yojson (Contract.measurement_to_yojson m) in
  (match round with
   | Ok _ -> print_endline "measurement round-trip: OK (valid)"
   | Error e -> Printf.printf "measurement round-trip: INVALID: %s\n" e);
  (* a deliberately malformed record must be rejected loudly *)
  let bad = `Assoc [ ("run_id", `String "x") ] in
  (match Contract.measurement_of_yojson bad with
   | Ok _ -> print_endline "BUG: malformed record accepted"
   | Error e -> Printf.printf "malformed record rejected: %s\n" e)
