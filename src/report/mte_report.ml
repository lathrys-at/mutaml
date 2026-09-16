open Mutaml_common

(* The version of the schema that this report follows. *)
let schema_version = "2"

(* The name that the schema gives a language, for the colouring of the
   source in the viewer. *)
let language = "ocaml"

(* A position of the schema counts lines and columns from 1. A position
   of the parse tree holds the line, the byte offset of the start of
   the line, and the byte offset of the position itself. *)
let json_position (p:Loc.position) =
  `Assoc [
    "line",   `Int p.pos_lnum;
    "column", `Int (max 1 (p.pos_cnum - p.pos_bol + 1));
  ]

let json_location (loc:Loc.location) =
  `Assoc [
    "start", json_position loc.loc_start;
    "end",   json_position loc.loc_end;
  ]

(* The status of the schema for one outcome, and the reason to give
   beside it. Only a run that a signal ended has a reason: the status
   alone does not say that the test suite found a fault of that kind. *)
let json_status status = match outcome_of_status status with
  | Failed    -> ("Killed", None)
  | Crashed   ->
    ("Killed",
     Some (Printf.sprintf "signal %i ended the test process" (status - 128)))
  | Timed_out -> ("Timeout", None)
  | Passed    -> ("Survived", None)

let json_mutant (res:test_result) =
  let mutant = res.mutant in
  let status,reason = json_status res.status in
  let fields = [
    "id",          `String (mutant_name mutant);
    "mutatorName", `String (kind_name mutant.kind);
    "location",    json_location mutant.loc;
    "status",      `String status;
    "replacement", `String (Option.value mutant.repl ~default:"");
  ] in
  let fields = match reason with
    | None        -> fields
    | Some reason -> fields @ ["statusReason", `String reason] in
  `Assoc fields

(* The operator name that the schema gives a place which
   [[@mutaml.skip "reason"]] took out of the run. The preprocessor made
   no mutation there, so no operator of the tool names it. *)
let skip_mutator_name = "skip"

let json_skipped (s : skipped) =
  `Assoc [
    "id",           `String (skip_name s);
    "mutatorName",  `String skip_mutator_name;
    "location",     json_location s.loc;
    "status",       `String "Ignored";
    "statusReason", `String s.reason;
    "description",  `String (skip_operators s);
  ]

(* A file whose text no longer holds every mutation and every skipped
   place where the run recorded it goes into the report without its
   text. A viewer draws each mutation over the text of its file, and a
   file that changed after the run would put every mutation of it over
   other code. *)
let json_file sources file ~results ~skipped =
  let fits text =
    List.for_all (fun res -> span_fits text res.mutant.loc) results
    && List.for_all (fun (s : skipped) -> span_fits text s.loc) skipped in
  let source = match List.assoc_opt file sources with
    | Some text when fits text -> text
    | Some _ | None            -> "" in
  (file,
   `Assoc [
     "language", `String language;
     "source",   `String source;
     "mutants",  `List (List.map json_mutant results
                        @ List.map json_skipped skipped);
   ])

(* One entry for each source file that the run names, whether the file
   holds a mutant, a skipped place, or both. *)
let json_files sources ~results ~skipped =
  let by_result = Summary.by_file results in
  let by_skipped = Summary.skipped_by_file skipped in
  let files =
    List.sort_uniq String.compare
      (List.map fst by_result @ List.map fst by_skipped) in
  List.map
    (fun file ->
       json_file sources file
         ~results:(Option.value (List.assoc_opt file by_result) ~default:[])
         ~skipped:(Option.value (List.assoc_opt file by_skipped) ~default:[]))
    files

(* The thresholds decide the colour that the viewer paints a score. The
   low one is the score that the run demands, so that a score the gate
   accepts is never painted as a failure. *)
let json_thresholds fail_under =
  let low = match fail_under with
    | None         -> 0
    | Some percent -> int_of_float percent in
  `Assoc [ "high", `Int 100; "low", `Int low ]

let render ~fail_under ~sources ~results ~skipped =
  let report =
    `Assoc [
      "schemaVersion", `String schema_version;
      "thresholds",    json_thresholds fail_under;
      "framework",     `Assoc [ "name",    `String "mutaml";
                                "version", `String Version.mutaml ];
      "files",         `Assoc (json_files sources ~results ~skipped);
    ] in
  Yojson.Safe.pretty_to_string report ^ "\n"
