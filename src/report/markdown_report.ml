open Mutaml_common

(* A cell of a Markdown table ends at the character |, so a file name
   that holds one must escape it. *)
let escape_cell text =
  String.concat "\\|" (String.split_on_char '|' text)

(* A fenced block ends at the first line of as many backticks as the
   fence, so a fence longer than every run of backticks in the text
   holds the whole text. *)
let fence_for text =
  let longest = ref 0 and run = ref 0 in
  String.iter
    (fun c ->
       if Char.equal c '`'
       then (incr run; if !run > !longest then longest := !run)
       else run := 0)
    text;
  String.make (max 3 (!longest + 1)) '`'

let mutants_of n = if n = 1 then "1 mutant" else Printf.sprintf "%i mutants" n

(* The counts beside the score name the mutants that ran. A mutant that
   did not run is named apart from them, because it is in neither half
   of the score. *)
let counts_of summary =
  let left_out = Summary.count summary Not_run in
  Printf.sprintf "%s: %i killed, %i timed out, %i crashed, %i survived%s"
    (mutants_of (Summary.scored summary))
    (Summary.count summary Failed)
    (Summary.count summary Timed_out)
    (Summary.count summary Crashed)
    (Summary.count summary Passed)
    (if left_out = 0 then "" else Printf.sprintf "; %i did not run" left_out)

let add_row buf label summary =
  Printf.bprintf buf "| %s | %i | %i | %i | %i | %i | %i |\n"
    label
    (Summary.total summary)
    (Summary.count summary Failed)
    (Summary.count summary Timed_out)
    (Summary.count summary Crashed)
    (Summary.count summary Passed)
    (Summary.count summary Not_run)

let add_table buf results =
  let by_file = Summary.by_file results in
  Buffer.add_string buf "| file | mutants | killed | timed out | crashed | survived | not run |\n";
  Buffer.add_string buf "| --- | ---: | ---: | ---: | ---: | ---: | ---: |\n";
  List.iter
    (fun (file,file_results) ->
       add_row buf
         (Printf.sprintf "`%s`" (escape_cell file))
         (Summary.of_results file_results))
    by_file;
  if List.length by_file > 1
  then add_row buf "**total**" (Summary.of_results results);
  Buffer.add_string buf
    "\nThe score counts a killed mutant, a mutant that timed out and a\nmutant that a signal ended as caught. A mutant that did not run is\noutside the score.\n"

(* The diff of one mutant, or the reason why there is none. *)
let diff_of sources (res:test_result) =
  let mutant = res.mutant in
  let file = mutant.loc.loc_start.pos_fname in
  let name = mutant_name mutant in
  let start = mutant.loc.loc_start.pos_cnum
  and stop  = mutant.loc.loc_end.pos_cnum in
  match List.assoc_opt file sources with
  | None ->
    Error (Printf.sprintf "The source file `%s` could not be read, so there is no diff here." file)
  | Some contents ->
    if not (span_fits contents mutant.loc)
    then
      Error
        (Printf.sprintf
           "The source file `%s` is not as it was when the runner ran, so there is no diff here."
           file)
    else
      let repl = Option.value mutant.repl ~default:"" in
      match
        Unified_diff.unified
          ~old_label:file
          ~new_label:(Printf.sprintf "%s (mutant %s)" file name)
          ~contents ~start ~stop ~repl
      with
      | "" ->
        Error
          (Printf.sprintf
             "The mutation leaves the text of `%s` as it was, so there is no diff here."
             file)
      | diff -> Ok diff

let add_survivor buf sources res =
  let mutant = res.mutant in
  let file = mutant.loc.loc_start.pos_fname in
  Printf.bprintf buf "\n### `%s`\n\n" (mutant_name mutant);
  Printf.bprintf buf "`%s`, line %i.\n\n" file mutant.loc.loc_start.pos_lnum;
  match diff_of sources res with
  | Error reason -> Printf.bprintf buf "%s\n" reason
  | Ok diff ->
    let fence = fence_for diff in
    Printf.bprintf buf "%sdiff\n%s%s\n" fence diff fence

let places_of n = if n = 1 then "1 place" else Printf.sprintf "%i places" n

let add_skipped buf (s : skipped) =
  let file = s.loc.loc_start.pos_fname in
  Printf.bprintf buf "\n### `%s`\n\n" (skip_name s);
  Printf.bprintf buf "`%s`, line %i.\n\n" file s.loc.loc_start.pos_lnum;
  Printf.bprintf buf "The reason: %s\n\n" s.reason;
  Printf.bprintf buf "%s\n" (skip_operators s)

let add_skipped_section buf skipped =
  Buffer.add_string buf "\n## Skipped places\n";
  match skipped with
  | [] ->
    Buffer.add_string buf
      "\nNo attribute takes a place out of this run.\n"
  | skipped ->
    Printf.bprintf buf
      "\nThe attribute `[@mutaml.skip]` takes %s out of this run. A\nskipped place has no mutant, so it is outside the score and in no\nrow of the table above.\n"
      (places_of (List.length skipped));
    List.iter (add_skipped buf) skipped

let render ~sources ~results ~skipped =
  let buf = Buffer.create 4096 in
  Buffer.add_string buf "# Mutation report\n\n";
  if results = []
  then (Buffer.add_string buf "There is no test result.\n"; Buffer.contents buf)
  else
    let summary = Summary.of_results results in
    if Summary.scored summary = 0
    then
      Printf.bprintf buf
        "No mutant ran, so this run has no mutation score. Every one of the %s was left out.\n\n"
        (mutants_of (Summary.total summary))
    else
      Printf.bprintf buf "Mutation score: %.1f%% (%s).\n\n"
        (Summary.score summary) (counts_of summary);
    add_table buf results;
    Buffer.add_string buf "\n## Survivors\n";
    (match Summary.with_outcome summary Passed with
     | [] -> Buffer.add_string buf "\nThe test suite caught every mutant.\n"
     | survivors -> List.iter (add_survivor buf sources) survivors);
    add_skipped_section buf skipped;
    Buffer.contents buf
