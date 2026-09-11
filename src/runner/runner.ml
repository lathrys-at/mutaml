(* driver for mutation testing *)

let timeout_cmd     = "timeout"
let default_timeout = 20

open Mutaml_common

(** Input / output functions *)

(*let meta_outfile = Filename.concat (Sys.getcwd ()) mutaml_mutants_file*)

(*
Read filenames from _build/default/ ^ mutaml_mut_file
Read mutants from each filename mentioned
Adjust env-variable value to include path+filename+mut:

 src/lib1.ml$0
 src/lib2.ml$1
 src/somelib/foo.ml:0  <--  path should distinguish these
 src/other/foo.ml:0    <--  path should distinguish these
*)

module CLI =
struct
  let usage_string = "Usage: mutaml-runner [options] <test-command>"

  let print_usage_and_exit () =
    Printf.printf "%s\n" usage_string;
    exit 1

  let muts_file = ref ""
  let build_ctx = ref ""

  (* Seconds that one test run may take. [None] means the default. *)
  let timeout = ref None

  (* Variables to set in every test process, in the order given. *)
  let test_env = ref []

  (* Variables to set in the second run without a mutation, on top of
     [test_env]. Empty means that there is no second run. *)
  let baseline_env = ref []

  let set_timeout_from source str = match int_of_string_opt str with
    | Some secs when secs > 0 -> timeout := Some secs
    | _ ->
      fail_and_exit
        (Printf.sprintf
           "The value of %s must be a whole number of seconds above 0." source)

  let set_timeout str = set_timeout_from "--timeout" str

  let rec all_chars_from ok str i =
    i >= String.length str || (ok str.[i] && all_chars_from ok str (i+1))

  let is_variable_name name =
    name <> ""
    && (match name.[0] with 'A'..'Z' | 'a'..'z' | '_' -> true | _ -> false)
    && all_chars_from
         (function 'A'..'Z' | 'a'..'z' | '0'..'9' | '_' -> true | _ -> false) name 0

  let add_env option_name where str = match String.index_opt str '=' with
    | None ->
      fail_and_exit
        (Printf.sprintf "The value of %s must have the form NAME=VALUE." option_name)
    | Some i ->
      let name = String.sub str 0 i in
      let value = String.sub str (i+1) (String.length str - i - 1) in
      if is_variable_name name
      then where := !where @ [(name,value)]
      else
        fail_and_exit
          (Printf.sprintf
             "%s is not a name that a variable may have. A variable name holds letters, digits and the character _, and it does not start with a digit."
             name)

  let add_test_env str = add_env "--test-env" test_env str
  let add_baseline_env str = add_env "--baseline-env" baseline_env str

  let arg_spec =
    Arg.align
      [("--muts",          Arg.Set_string muts_file, " Run mutations in the given muts-file");
       ("--build-context", Arg.Set_string build_ctx, " Specify the build context to read from");
       ("--timeout",       Arg.String set_timeout,
        "<seconds> Stop a test run that takes longer than <seconds>");
       ("--test-env",      Arg.String add_test_env,
        "<NAME=VALUE> Set NAME to VALUE in every test process. Repeatable");
       ("--baseline-env",  Arg.String add_baseline_env,
        "<NAME=VALUE> Run the test suite a second time without a mutation, with NAME set to VALUE. Repeatable")]
end

let ensure_output_dir dir_name =
  if 0 <> Sys.command ("mkdir -p " ^ dir_name)
  then fail_and_exit (Printf.sprintf "Failed to create directory %s" dir_name)
(* Sys.mkdir is a 4.12 addition. Use a crude Sys.command for backwards compat. for now *)
(*
let rec ensure_output_dir dir_name =
  try (* base case: directory exists *)
    if not (Sys.is_directory dir_name)
    then fail_and_exit (Printf.sprintf "Expected directory %s is not a directory" dir_name)
  with Sys_error _ ->
    (* rec.case: ensure parent directory exists *)
    let par_name = Filename.dirname dir_name in
    ensure_output_dir par_name;
    Sys.mkdir dir_name 0o755
*)

let test_results = ref []

let read_instrumentation_overview ppx_output_prefix file_name =
  let rec read_loop ch acc =
    try
      let file_name = input_line ch in
      read_loop ch (file_name::acc)
    with End_of_file -> List.rev acc
  in
  try
    let ch = open_in (full_ppx_path ppx_output_prefix file_name) in
    let file_names = read_loop ch [] in
    let () = close_in ch in
    file_names
  with Sys_error msg ->
    fail_and_exit (Printf.sprintf "Could not read file %s - %s" file_name msg)

let read_module_mutations_json ppx_output_prefix file_name =
  try
    let ch = open_in (full_ppx_path ppx_output_prefix file_name) in
    let mutants = match Yojson.Safe.from_channel ch with
      | `List ys -> List.map mutant_of_yojson ys
      | _        -> fail_and_exit ("Could not parse " ^ file_name)
    in
    mutants
  with Sys_error msg ->
    fail_and_exit (Printf.sprintf "Could not read file %s - %s" file_name msg)

let read_all_mutations ppx_output_prefix file_name =
  (* Sorted, so that the order of the report does not depend on the order
     in which the build system ran the preprocessor. *)
  let mut_files =
    List.sort_uniq String.compare
      (read_instrumentation_overview ppx_output_prefix file_name) in
  List.iter (fun fname -> Printf.printf "read mut file %s\n%!" fname) mut_files;
  List.map (fun f -> (f, read_module_mutations_json ppx_output_prefix f)) mut_files

let count_mutations (f,ms) =
  if ms=[]
  then Printf.printf "Warning: No mutations were listed in %s\n" f
  else ();
  List.length ms

let validate_muts_file mpair =
  if 0 = count_mutations mpair
  then fail_and_exit "Exiting as there is no report data to write"

let validate_mutants file_name muts =
  if muts=[]
  then fail_and_exit ("No files were listed in " ^ file_name)
  else
    let counts = List.map count_mutations muts in
    if 0 = List.fold_left (+) 0 counts
    then
      fail_and_exit
        (Printf.sprintf "Did not find any mutations across the files listed in %s" file_name)
    else ()

(* Drops a .muts file whose source file is not in the project. Dune runs
   the preprocessor again only for a source file that changed, so the list
   of .muts files can name a file whose source is gone. The mutations of
   such a file cannot be reported, because the report tool reads the
   source to make its diff. *)
let drop_absent_sources muts =
  List.filter
    (fun (file_name,mutants) -> match mutants with
       | [] -> true
       | mut::_ ->
         let source = mut.loc.loc_start.pos_fname in
         Sys.file_exists source
         || (Printf.printf "Skipping %s: the source file %s does not exist\n%!"
               file_name source;
             false))
    muts

let save_test_outcome ret test_env mut =
  test_results := { status = ret; mutant = mut; test_env }::(!test_results)

let write_report_file file_name =
  Printf.printf "Writing report data to %s\n" file_name;
  let ch = open_out file_name in
  let ys = !test_results |> List.rev |> List.map yojson_of_test_result in
  let () = Yojson.Safe.to_channel ch (`List ys) in
  let () = close_out ch in
  ()


(** The actual test runner *)

(* The shell assignments that set the fixed variables of a test process. *)
let env_prefix test_env =
  String.concat ""
    (List.map
       (fun (name,value) -> Printf.sprintf "%s=%s " name (Filename.quote value))
       test_env)

(* Runs [test_cmd] once, with [mut_id] in MUTAML_MUTANT and with [test_env]
   set, and with its output in [output_file]. The empty [mut_id] runs the
   program without a mutant. Returns the exit status of the test process. *)
let run_test_command test_cmd ~test_env ~timeout ~mut_id ~output_file =
  ensure_output_dir (Filename.dirname output_file);
  let env_test_cmd =
    Printf.sprintf "%sMUTAML_MUTANT=%s %s %i %s > %s 2>&1"
      (env_prefix test_env) (Filename.quote mut_id) timeout_cmd timeout
      test_cmd output_file in
  let ret = Sys.command env_test_cmd in (*tests can both succeed and err*)
  match ret with
  | 127 -> fail_and_exit (Printf.sprintf "Command not found: failed to run the test command \"%s\"" test_cmd)
  | _   -> ret

let status_word status = outcome_word (outcome_of_status status)

let run_single_test test_cmd ~test_env ~timeout mut =
  let file_name = mut.loc.loc_start.pos_fname in
  let mut_id = make_mut_id file_name mut.number in
  let output_file = output_file_name file_name mut.number in
  let () = Printf.printf "Testing mutant %s ... %!" mut_id in
  let ret = run_test_command test_cmd ~test_env ~timeout ~mut_id ~output_file in
  let () = Printf.printf "%s\n%!" (status_word ret) in
  ret

let rec run_module_mutation_tests test_cmd ~test_env ~timeout mutants = match mutants with
  | [] -> ()
  | mut::muts ->
    let ret = run_single_test test_cmd ~test_env ~timeout mut in
    save_test_outcome ret test_env mut;
    run_module_mutation_tests test_cmd ~test_env ~timeout muts

let rec run_all_mutation_tests test_cmd ~test_env ~timeout muts = match muts with
  | [] -> ()
  | (_file_name, mutations)::muts' ->
    run_module_mutation_tests test_cmd ~test_env ~timeout mutations;
    run_all_mutation_tests test_cmd ~test_env ~timeout muts'


(** The baseline run: the test suite without a mutant *)

(* [override base extra] is [base] with the value of [extra] for every
   name that [extra] holds, and with the names of [extra] that [base] does
   not hold added at the end. *)
let override base extra =
  let replaced =
    List.map
      (fun (name,value) -> match List.assoc_opt name extra with
         | Some other -> (name,other)
         | None -> (name,value))
      base in
  replaced @ List.filter (fun (name,_) -> not (List.mem_assoc name base)) extra

let baseline_output_file number =
  full_path (Printf.sprintf "baseline-%i.output" number)

(* Runs the test suite without a mutant. It runs a second time when
   [baseline_env] holds an assignment, with those assignments on top of
   [test_env]. Stops the program when a run fails, and when the two runs
   disagree: a score has no meaning in either case. *)
let run_baseline test_cmd ~test_env ~baseline_env ~timeout =
  let run number env =
    let output_file = baseline_output_file number in
    let () =
      if number = 1
      then Printf.printf "Testing without a mutant ... %!"
      else Printf.printf "Testing without a mutant a second time ... %!" in
    let ret = run_test_command test_cmd ~test_env:env ~timeout ~mut_id:"" ~output_file in
    let () = Printf.printf "%s\n%!" (status_word ret) in
    ret in
  let first = run 1 test_env in
  if first <> 0
  then
    fail_and_exit
      (Printf.sprintf
         "The test suite did not pass without a mutant. Its exit status was %i.\nThe output of the run is in %s.\nEvery mutant would look killed, so mutaml-runner stops here."
         first (baseline_output_file 1));
  if baseline_env <> []
  then
    let second = run 2 (override test_env baseline_env) in
    if second <> 0
    then
      fail_and_exit
        (Printf.sprintf
           "The test suite ran twice without a mutant. It passed in one run and not in the other.\nThe output of the two runs is in %s and %s.\nThe test suite does not give the same result every time, so a mutation score would have no meaning."
           (baseline_output_file 1) (baseline_output_file 2))


(** Executable entry point *)

let () =
  if 0 <> Sys.command ("command -v " ^ timeout_cmd ^ " > /dev/null")
  then fail_and_exit ("Could not find time-out command: " ^ timeout_cmd)
  else
    let test_cmd = ref "" in
    let set_test_cmd str = if "" = !test_cmd then test_cmd := str else CLI.print_usage_and_exit () in
    let () = Arg.parse CLI.arg_spec set_test_cmd CLI.usage_string in
    if "" = !test_cmd then CLI.print_usage_and_exit () else
    let () = match !CLI.timeout, Sys.getenv_opt "MUTAML_TIMEOUT" with
      | None, Some secs -> CLI.set_timeout_from "MUTAML_TIMEOUT" secs
      | _, _            -> () in
    let ppx_output_prefix = match !CLI.build_ctx, Sys.getenv_opt "MUTAML_BUILD_CONTEXT" with
      | "", opt -> Option.fold ~some:Fun.id opt ~none:defaults.ppx_output_prefix
      | s, _opt -> s in
    let mut_file = defaults.mutaml_mut_file in
    let mutants = match !CLI.muts_file with
      | ""        ->
        let ms = read_all_mutations ppx_output_prefix mut_file in
        validate_mutants mut_file ms;
        ms
      | muts_file ->
        let mpair = (muts_file,read_module_mutations_json ppx_output_prefix muts_file) in
        validate_muts_file mpair;
        [mpair]
    in
    let mutants = drop_absent_sources mutants in
    if mutants = []
    then fail_and_exit "No mutation file is left to test: every source file is gone";
    ensure_output_dir defaults.output_file_prefix;
    let test_env = !CLI.test_env in
    let baseline_env = !CLI.baseline_env in
    let timeout = Option.value !CLI.timeout ~default:default_timeout in
    run_baseline !test_cmd ~test_env ~baseline_env ~timeout;
    run_all_mutation_tests !test_cmd ~test_env ~timeout mutants;
    write_report_file defaults.mutaml_report_file;
    ()
