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
      | `List ys -> Ok (List.map test_result_of_yojson ys)
      | _        -> Error "Did not find the expected JSON list"
    with Yojson.Json_error _ -> Error "Invalid JSON"
  in match mutants_opt with
  | Error msg ->
    close_in ch;
    fail_and_exit (Printf.sprintf "Could not parse JSON in %s: %s" report_file msg)
  | Ok mutants ->
    mutants


(** A type and function to process test result data *)

type results =
  {
    count   : int;
    passed  : test_result list;
    timeout : test_result list;
    failed  : test_result list;
  }

let part_results results =
  let count = List.length results in
  let passed,rest =
    List.partition (fun res -> outcome_of_status res.status = Passed) results in
  let timeout,failed =
    List.partition (fun res -> outcome_of_status res.status = Timed_out) rest in
  {count;passed;timeout;failed}

(** The mutation score of [results], as a percentage from 0 to 100.
    A mutation that timed out counts with the mutations that failed.
    [results] must hold at least one test result. *)
let mutation_score results =
  let parted = part_results results in
  if parted.count = 0
  then invalid_arg "mutation_score: no test results"
  else
    let caught = List.length parted.failed + List.length parted.timeout in
    100. *. (float_of_int caught) /. (float_of_int parted.count)


(** Output functions *)

module CLI =
struct
  let usage_msg =
    Printf.sprintf "Usage: %s [-no-diff] [--fail-under <percent>] [file.json]\n%s\n%s\n%s\n" (Sys.argv.(0))
      "Generates a report summarizing the findings of a mutaml-driver run."
      "The mutation score is the share of mutations that failed or timed out."
      "Exits with 0 when the score is high enough, with 2 when it is not, and with 1 on an error."

  let print_diff = ref true

  (* The lowest score that the run may have. [None] means 100 percent. *)
  let fail_under = ref None

  let set_fail_under str = match float_of_string_opt str with
    | Some percent when percent >= 0. && percent <= 100. -> fail_under := Some percent
    | _ ->
      fail_and_exit "The value of --fail-under must be a number from 0 to 100."

  let arg_spec =
    Arg.align
      ["--no-diff", Arg.Clear print_diff, " Don't output diffs to the console";
       "--fail-under", Arg.String set_fail_under,
       "<percent> Exit with an error when the score is below <percent>"]

  let diff_cmd = match Sys.getenv_opt "MUTAML_DIFF_COMMAND", Sys.getenv_opt "CI" with
    | Some cmd, _       -> cmd
    | None, Some "true" -> "diff -u"
    | None, _           -> "diff --color -u"
end

let file_contents file_name =
  let ch = open_in file_name in
  let buf = Buffer.create 1024 in
  let rec loop () =
    try
      let src_line = Stdlib.input_line ch in
      Buffer.add_string buf (src_line ^ "\n");
      loop ()
    with
      End_of_file ->
      close_in ch;
      (*Buffer.add_string buf "\n";*)
      Buffer.contents buf in
  loop ()

let write_mutated_version output_file ~start ~stop contents repl =
    let ch =
      try open_out output_file
      with Sys_error msg -> fail_and_exit (Printf.sprintf "Could not open file %s" msg)
    in
    output_string ch (String.sub contents 0 start.pos_cnum);
    output_string ch repl;
    output_string ch (String.sub contents stop.pos_cnum (String.length contents - stop.pos_cnum));
    close_out ch

(** prints details for a mutation that passed, i.e., flew under the radar *)
let print_passed print_diff (res:test_result) =
  let loc,mut_number = res.mutant.loc,res.mutant.number in
  let test_output_file = output_file_name loc.loc_start.pos_fname mut_number in
  let file_name = loc.loc_start.pos_fname in
  let mut_name = Printf.sprintf "%s-mutant%i" file_name mut_number in
  let full_mut_name = full_path mut_name in
  let repl = match res.mutant.repl with None -> "" | Some repl -> repl in
  let contents = file_contents file_name in
  write_mutated_version full_mut_name ~start:loc.loc_start ~stop:loc.loc_end contents repl;
  if print_diff
  then
    begin
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
      Format.printf "%s\n\n" (String.make 75 '-');
    end
  else
    Printf.printf "Mutation \"%s\" passed (see \"%s\")\n%!" mut_name test_output_file

let part_files results =
  let files = List.map (fun r -> r.mutant.loc.loc_start.pos_fname) results
              |> List.sort_uniq String.compare in
  let per_file_results =
    List.fold_left
      (fun acc f ->
         let from_f = List.filter (fun r -> f = r.mutant.loc.loc_start.pos_fname) results in
         (f,from_f)::acc) [] files
  in List.rev per_file_results

let print_report results =
  let print_summary_line (label,results) =
    let {count;passed;timeout;failed} = part_results results in
    let percent c = 100. *. (float_of_int c) /. (float_of_int count) in
    let lab c = Printf.sprintf "%3.1f%% %4i" (percent c) c in
    let num_passed  = List.length passed in
    let num_timeout = List.length timeout in
    let num_failed  = List.length failed in
    Printf.printf " %-30s %9i     %11s   %11s   %11s\n" label count (lab num_failed) (lab num_timeout) (lab num_passed);
    passed
  in

  let part_results = part_files results in
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
  let crashed =
    List.filter (fun res -> outcome_of_status res.status = Crashed) results in
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
  let parted = part_results results in
  let score = mutation_score results in
  Printf.printf "Mutation score: %.1f%% (%i mutations: %i failed, %i timed out, %i passed)\n"
    score parted.count (List.length parted.failed) (List.length parted.timeout)
    (List.length parted.passed);
  match !CLI.fail_under with
  | Some limit ->
    if score < limit
    then fail_gate_and_exit (Printf.sprintf "The score is below %.1f%%." limit)
  | None ->
    if parted.passed <> []
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
  let passed = print_report results in
  print_crashed results;
  if passed <> []
  then
    (Printf.printf "Mutation programs passing the test suite:\n";
     Printf.printf "-----------------------------------------\n\n";
     List.iter (print_passed !CLI.print_diff) passed);
  print_score_and_gate results
