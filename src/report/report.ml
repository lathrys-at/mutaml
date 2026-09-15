(* reporter for mutation testing *)

open Mutaml_common
open Mutaml_common.Loc

(** Input function *)

let read_reports report_file =
  let open Result in
  Printf.printf "Attempting to read from %s...\n" report_file;
  let ch =
    try open_in report_file
    with Sys_error msg -> fail_and_exit (Printf.sprintf "Could not open file %s" msg)
  in
  let mutants_opt =
    try
      match Yojson.Safe.from_channel ch with
      | `List ys -> Ok (List.map test_result_of_yojson_exn ys)
      | _        -> Error "Did not find the expected JSON list"
    with Yojson.Json_error _ -> Error "Invalid JSON"
       | Failure _ ->
         Error "a test result does not hold the fields that this release of mutaml reads. A report file that an older mutaml wrote needs a new run of mutaml-runner"
  in match mutants_opt with
  | Error msg ->
    close_in ch;
    fail_and_exit (Printf.sprintf "Could not parse JSON in %s: %s" report_file msg)
  | Ok mutants ->
    mutants


(** The counts of a report come from [Summary]. The console table
    prints the mutations that a signal ended in its column of failed
    mutations, because a signal is a fault that the test suite found. *)

let num_failed summary = Summary.count summary Failed + Summary.count summary Crashed


(** Output functions *)

module CLI =
struct
  let usage_msg =
    Printf.sprintf "Usage: %s [--no-diff] [--fail-under <percent>] [--json-report <path>] [--markdown <path>] [file.json]\n%s\n%s\n%s\n" (Sys.argv.(0))
      "Generates a report summarizing the findings of a mutaml-driver run."
      "The mutation score is the share of mutations that failed or timed out."
      "Exits with 0 when the score is high enough, with 2 when it is not, and with 1 on an error."

  let print_diff = ref true

  (* The lowest score that the run may have. [None] means 100 percent. *)
  let fail_under = ref None

  (* Where to write the report in the mutation-testing-elements format,
     and where to write the Markdown summary. [None] means not to write
     that file. *)
  let json_report = ref None
  let markdown = ref None

  let set_fail_under str = match float_of_string_opt str with
    | Some percent when percent >= 0. && percent <= 100. -> fail_under := Some percent
    | _ ->
      fail_and_exit "The value of --fail-under must be a number from 0 to 100."

  let arg_spec =
    Arg.align
      ["--no-diff", Arg.Clear print_diff, " Don't output diffs to the console";
       "--fail-under", Arg.String set_fail_under,
       "<percent> Exit with an error when the score is below <percent>";
       "--json-report", Arg.String (fun path -> json_report := Some path),
       "<path> Write the report in the mutation-testing-elements format to <path>";
       "--markdown", Arg.String (fun path -> markdown := Some path),
       "<path> Write a Markdown summary to <path>, for the summary page of a CI job"]

  let diff_cmd = match Sys.getenv_opt "MUTAML_DIFF_COMMAND", Sys.getenv_opt "CI" with
    | Some cmd, _       -> cmd
    | None, Some "true" -> "diff -u"
    | None, _           -> "diff --color -u"
end

(* The bytes of [file_name], or [None] when the file cannot be read.
   The Markdown summary and the JSON report count bytes from the start
   of the file, as the locations of the mutants do, so this reads the
   file as it is and does not rebuild its lines. *)
let file_contents_opt file_name =
  try
    let ch = open_in_bin file_name in
    Fun.protect ~finally:(fun () -> close_in_noerr ch)
      (fun () -> Some (really_input_string ch (in_channel_length ch)))
  with Sys_error _ | End_of_file -> None

(* The bytes of every source file that [results] names. A file that
   cannot be read is left out, and named, because the report of its
   mutants then holds no source. *)
let read_sources results =
  List.filter_map
    (fun (file_name,_) -> match file_contents_opt file_name with
       | Some contents -> Some (file_name,contents)
       | None ->
         Printf.printf "Could not read the source file %s\n%!" file_name;
         None)
    (Summary.by_file results)

(* Writes [text] to [file_name], and stops the program when it cannot. *)
let write_text_file file_name text =
  try
    let ch = open_out file_name in
    Fun.protect ~finally:(fun () -> close_out_noerr ch)
      (fun () -> output_string ch text; flush ch)
  with Sys_error msg ->
    fail_and_exit (Printf.sprintf "Could not write file %s" msg)

(* Writes the report files that the command line asked for. *)
let write_report_files results =
  match !CLI.json_report, !CLI.markdown with
  | None, None -> ()
  | json_path, markdown_path ->
    let sources = read_sources results in
    Option.iter
      (fun path ->
         Printf.printf "Writing the Markdown summary to %s\n%!" path;
         write_text_file path (Markdown_report.render ~sources ~results))
      markdown_path;
    Option.iter
      (fun path ->
         Printf.printf "Writing the JSON report to %s\n%!" path;
         write_text_file path
           (Mte_report.render ~fail_under:!CLI.fail_under ~sources ~results))
      json_path

let write_mutated_version output_file ~start ~stop contents repl =
    let ch =
      try open_out output_file
      with Sys_error msg -> fail_and_exit (Printf.sprintf "Could not open file %s" msg)
    in
    output_string ch (String.sub contents 0 start.pos_cnum);
    output_string ch repl;
    output_string ch (String.sub contents stop.pos_cnum (String.length contents - stop.pos_cnum));
    close_out ch

(* Prints the diff between the source file and its mutated copy, as the
   diff command of the system makes it. *)
let print_diff_of_passed ~file_name ~mut_name ~full_mut_name ~test_output_file =
  Printf.printf "Mutation \"%s\" passed (see \"%s\"):\n\n%!" mut_name test_output_file;
  let cmd =
    Printf.sprintf "%s --label \"%s\" %s --label \"%s\" %s 1>&2"
      CLI.diff_cmd file_name file_name mut_name full_mut_name in
  let () = match Sys.command cmd with
    | 1 -> ()
    | 0   -> fail_and_exit "The two source code files did not differ, despite mutation"
    | 127 -> fail_and_exit "Could not find the 'diff' command"
    | i   -> fail_and_exit (Printf.sprintf "'diff' command failed with status code %i" i)
  in
  Format.printf "\n";
  Format.printf "%s\n\n" (String.make 75 '-')

(** prints details for a mutation that passed, i.e., flew under the radar *)
let print_passed print_diff (res:test_result) =
  let loc,mut_number = res.mutant.loc,res.mutant.number in
  let file_name = loc.loc_start.pos_fname in
  let test_output_file = output_file_name file_name mut_number in
  let mut_name = Printf.sprintf "%s-mutant%i" file_name mut_number in
  let full_mut_name = full_path mut_name in
  let repl = match res.mutant.repl with None -> "" | Some repl -> repl in
  match file_contents_opt file_name with
  | None ->
    Printf.printf "Mutation \"%s\" passed (see \"%s\"), and the source file %s could not be read\n%!"
      mut_name test_output_file file_name
  | Some contents when not (span_fits contents loc) ->
    Printf.printf "Mutation \"%s\" passed (see \"%s\"), and the source file %s is not as it was when the tests ran\n%!"
      mut_name test_output_file file_name
  | Some contents ->
    write_mutated_version full_mut_name
      ~start:loc.loc_start ~stop:loc.loc_end contents repl;
    if print_diff
    then
      print_diff_of_passed ~file_name ~mut_name ~full_mut_name ~test_output_file
    else
      Printf.printf "Mutation \"%s\" passed (see \"%s\")\n%!" mut_name test_output_file

let print_report results =
  let print_summary_line (label,results) =
    let summary = Summary.of_results results in
    let count = Summary.total summary in
    let percent c = 100. *. (float_of_int c) /. (float_of_int count) in
    let lab c = Printf.sprintf "%3.1f%% %4i" (percent c) c in
    let num_passed  = Summary.count summary Passed in
    let num_timeout = Summary.count summary Timed_out in
    let num_failed  = num_failed summary in
    Printf.printf " %-30s %9i     %11s   %11s   %11s\n" label count (lab num_failed) (lab num_timeout) (lab num_passed);
    Summary.with_outcome summary Passed
  in

  let part_results = Summary.by_file results in
  Printf.printf "\nMutaml report summary:\n";
  Printf.printf   "----------------------\n\n";
  Printf.printf " %-30s %11s   %11s   %11s   %11s\n" "target" "#mutations" "#failed " "#timeouts" "#passed ";
  Format.printf " %s\n" (String.make 85 '-');
  let passed = List.map print_summary_line part_results in
  if List.length part_results > 1
  then
    begin
      Format.printf " %s\n" (String.make 85 '-');
      ignore (print_summary_line ("total",results));
    end;
  (* *)
  Format.printf " %s\n\n" (String.make 85 '=');
  List.concat passed


(** Prints the mutations that a signal ended. A signal ends a test process
    for a reason that is not a failing test, so the report names those
    mutations even though it counts them with the mutations that failed. *)
let print_crashed results =
  let crashed = Summary.with_outcome (Summary.of_results results) Crashed in
  if crashed <> []
  then
    begin
      Printf.printf "Mutation programs that a signal ended:\n";
      Printf.printf "-------------------------------------\n\n";
      List.iter
        (fun res ->
           let file_name = res.mutant.loc.loc_start.pos_fname in
           Printf.printf "Mutation \"%s-mutant%i\" ended with status %i (see \"%s\")\n"
             file_name res.mutant.number res.status
             (output_file_name file_name res.mutant.number))
        crashed;
      Printf.printf "\n"
    end

(* Prints [message] and ends the program with status 2, which says that
   the score is too low. Status 1 says that the tool itself could not do
   its work. *)
let fail_gate_and_exit message =
  print_endline message;
  exit 2

(** Prints the mutation score and stops the program when the score is too
    low. Exits with status 2 when the score is below the limit that
    [CLI.fail_under] gives, or below 100 percent when it gives none. *)
let print_score_and_gate results =
  let summary = Summary.of_results results in
  let score = Summary.score summary in
  Printf.printf "Mutation score: %.1f%% (%i mutations: %i failed, %i timed out, %i passed)\n"
    score (Summary.total summary) (num_failed summary) (Summary.count summary Timed_out)
    (Summary.count summary Passed);
  match !CLI.fail_under with
  | Some limit ->
    if score < limit
    then fail_gate_and_exit (Printf.sprintf "The score is below %.1f%%." limit)
  | None ->
    if Summary.with_outcome summary Passed <> []
    then
      fail_gate_and_exit
        "The score is below 100%. Use --fail-under to accept a lower score."


(** Executable entry point *)

let () =
  let args = ref [] in
  let save_arg arg = (args := arg::!args) in
  let () = Arg.parse CLI.arg_spec save_arg CLI.usage_msg in
  let report_file = match !args with
    | [] -> Mutaml_common.defaults.mutaml_report_file
    | [filename] -> filename
    | _ ->
      fail_and_exit (Arg.usage_string CLI.arg_spec CLI.usage_msg) in
  let results = read_reports report_file in
  if results = []
  then fail_and_exit (Printf.sprintf "Found no test results in %s" report_file);
  write_report_files results;
  let passed = print_report results in
  print_crashed results;
  if passed <> []
  then
    (Printf.printf "Mutation programs passing the test suite:\n";
     Printf.printf "-----------------------------------------\n\n";
     List.iter (print_passed !CLI.print_diff) passed);
  print_score_and_gate results
