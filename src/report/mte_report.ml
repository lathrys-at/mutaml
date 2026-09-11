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

(* [fits source loc] says whether the run of bytes that [loc] covers
   lies inside [source]. *)
let fits source (loc:Loc.location) =
  let start = loc.loc_start.pos_cnum and stop = loc.loc_end.pos_cnum in
  0 <= start && start <= stop && stop <= String.length source

(* A file whose text no longer holds every mutation where the run
   recorded it goes into the report without its text. A viewer draws
   each mutation over the text of its file, and a file that changed
   after the run would put every mutation of it over other code. *)
let json_file sources (file,results) =
  let source = match List.assoc_opt file sources with
    | Some text when List.for_all (fun res -> fits text res.mutant.loc) results -> text
    | Some _ | None -> "" in
  (file,
   `Assoc [
     "language", `String language;
     "source",   `String source;
     "mutants",  `List (List.map json_mutant results);
   ])

(* The thresholds decide the colour that the viewer paints a score. The
   low one is the score that the run demands, so that a score the gate
   accepts is never painted as a failure. *)
let json_thresholds fail_under =
  let low = match fail_under with
    | None         -> 0
    | Some percent -> int_of_float percent in
  `Assoc [ "high", `Int 100; "low", `Int low ]

let render ~fail_under ~sources ~results =
  let report =
    `Assoc [
      "schemaVersion", `String schema_version;
      "thresholds",    json_thresholds fail_under;
      "framework",     `Assoc [ "name",    `String "mutaml";
                                "version", `String Version.mutaml ];
      "files",         `Assoc (List.map (json_file sources) (Summary.by_file results));
    ] in
  Yojson.Safe.pretty_to_string report ^ "\n"
