(* ingest.ml — the CONTRACT-ONLY ingestor (boundary ③).

   Consumes ONLY data-contract artifacts (a directory with manifest.json and
   measurements.json, as produced by the adapter or, later, by running-ng
   natively). It has NO knowledge of the legacy on-disk layout — that lives
   entirely in the adapter.

   Its job is the read-side validation gate: parse, check the schema version,
   validate every record against the contract, and re-emit canonical contract
   JSON for downstream (the Observable data loaders). A non-conforming artifact
   fails loud (non-zero exit) rather than flowing through.

     ingest measurements <contract-dir>   -> validated Contract.measurement array
     ingest manifest     <contract-dir>   -> validated Contract.manifest
*)

open Schema

let major v = match String.split_on_char '.' v with m :: _ -> m | [] -> v

let our_major = major Contract.schema_version

let check_version got =
  if major got <> our_major then (
    Printf.eprintf
      "FATAL: schema_version %s is incompatible with this ingestor (%s.x); refusing.\n%!" got
      our_major;
    exit 1)

let read_json path =
  if not (Sys.file_exists path) then (
    Printf.eprintf "FATAL: expected contract file not found: %s\n%!" path;
    exit 1);
  try Yojson.Safe.from_file path
  with e ->
    Printf.eprintf "FATAL: %s is not valid JSON: %s\n%!" path (Printexc.to_string e);
    exit 1

let fail_invalid what e =
  Printf.eprintf "FATAL: %s failed contract validation: %s\n%!" what e;
  exit 1

(* recursively collect *.ndjson under a directory (any nesting is allowed; the
   path is never parsed for meaning) *)
let rec ndjson_files dir =
  if not (Sys.file_exists dir) then []
  else
    Sys.readdir dir |> Array.to_list
    |> List.concat_map (fun e ->
           let p = Filename.concat dir e in
           if Sys.is_directory p then ndjson_files p
           else if Filename.check_suffix p ".ndjson" then [ p ]
           else [])

let read_lines path =
  let ic = open_in path in
  let rec loop acc =
    match input_line ic with
    | line -> loop (if String.trim line = "" then acc else line :: acc)
    | exception End_of_file -> close_in ic; List.rev acc
  in
  loop []

let identity (m : Contract.measurement) =
  String.concat "\x1f"
    [ m.run_id; m.config.config_id; m.benchmark.name; m.benchmark.suite; string_of_int m.invocation ]

(* merge a per-tool partial into an existing record of the same identity:
   union metrics (report a same-name clash across tools, keep first) + raw_ref *)
let merge (prev : Contract.measurement) (m : Contract.measurement) : Contract.measurement =
  let prev_names = List.map (fun (x : Contract.metric) -> x.name) prev.metrics in
  let new_metrics =
    List.filter
      (fun (x : Contract.metric) ->
        if List.mem x.name prev_names then (
          Printf.eprintf "WARN: duplicate metric %S for %s/%s inv %d; keeping first\n%!"
            x.name prev.run_id prev.benchmark.name prev.invocation;
          false)
        else true)
      m.metrics
  in
  let new_raw = List.filter (fun (k, _) -> not (List.mem_assoc k prev.raw_ref)) m.raw_ref in
  { prev with metrics = prev.metrics @ new_metrics; raw_ref = prev.raw_ref @ new_raw }

let ingest_measurements dir =
  (* referential integrity needs the manifest's config set *)
  let man =
    match Contract.manifest_of_yojson (read_json (Filename.concat dir "manifest.json")) with
    | Ok m -> check_version m.Contract.schema_version; m
    | Error e -> fail_invalid "manifest.json" e
  in
  let known_configs = List.map (fun (c : Contract.config_descriptor) -> c.config_id) man.configs in
  let files = ndjson_files (Filename.concat dir "measurements") in
  if files = [] then fail_invalid "measurements/" "no *.ndjson files found";
  (* parse + validate + version-gate every record *)
  let records =
    List.concat_map
      (fun path ->
        List.mapi
          (fun i line ->
            match Contract.measurement_of_yojson (Yojson.Safe.from_string line) with
            | Ok m ->
                check_version m.Contract.schema_version;
                if not (List.mem m.config.config_id known_configs) then
                  fail_invalid
                    (Printf.sprintf "%s:%d" (Filename.basename path) (i + 1))
                    (Printf.sprintf "config_id %s not in manifest" m.config.config_id);
                m
            | Error e -> fail_invalid (Printf.sprintf "%s:%d" (Filename.basename path) (i + 1)) e
            | exception e -> fail_invalid (Printf.sprintf "%s:%d" (Filename.basename path) (i + 1)) (Printexc.to_string e))
          (read_lines path))
      files
  in
  (* merge partials by identity, preserving first-seen order *)
  let tbl = Hashtbl.create 4096 and order = ref [] in
  List.iter
    (fun m ->
      let k = identity m in
      match Hashtbl.find_opt tbl k with
      | None -> Hashtbl.add tbl k m; order := k :: !order
      | Some prev -> Hashtbl.replace tbl k (merge prev m))
    records;
  let merged = List.rev_map (Hashtbl.find tbl) !order in
  Printf.eprintf "ingest: %d partial record(s) across %d file(s) -> %d merged measurement(s)\n%!"
    (List.length records) (List.length files) (List.length merged);
  print_string (Yojson.Safe.pretty_to_string (`List (List.map Contract.measurement_to_yojson merged)))

let ingest_manifest dir =
  let json = read_json (Filename.concat dir "manifest.json") in
  match Contract.manifest_of_yojson json with
  | Ok m ->
      check_version m.Contract.schema_version;
      print_string (Yojson.Safe.pretty_to_string (Contract.manifest_to_yojson m))
  | Error e -> fail_invalid "manifest.json" e

let () =
  match Sys.argv with
  | [| _; "measurements"; dir |] -> ingest_measurements dir
  | [| _; "manifest"; dir |] -> ingest_manifest dir
  | _ ->
      prerr_endline "usage: ingest {measurements|manifest} <contract-dir>";
      exit 2
