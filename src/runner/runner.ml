(* driver for mutation testing *)

(* The limit of one mutant run, when --timeout gives none: this many
   times the run without a mutant, and never less than the floor. The
   floor is a number of seconds. *)
let timeout_multiple = 5
let timeout_floor    = 10

(* The limit of a run without a mutant, in seconds, when --timeout
   gives none. The limit of a mutant run comes from that run, so that
   run cannot take its limit from itself. *)
let baseline_timeout = 300

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

  (* Mutations to test at one time. [None] means the default. *)
  let jobs = ref None

  (* The greatest number of test runs that one mutation gets. *)
  let repeat = ref 1

  let set_timeout_from source str = match int_of_string_opt str with
    | Some secs when secs > 0 -> timeout := Some secs
    | _ ->
      fail_and_exit
        (Printf.sprintf
           "The value of %s must be a whole number of seconds above 0." source)

  let set_timeout str = set_timeout_from "--timeout" str

  let set_jobs_from source str = match int_of_string_opt str with
    | Some count when count > 0 -> jobs := Some count
    | _ ->
      fail_and_exit
        (Printf.sprintf
           "The value of %s must be a whole number of jobs above 0." source)

  let set_jobs str = set_jobs_from "-j" str

  let set_repeat str = match int_of_string_opt str with
    | Some count when count > 0 -> repeat := count
    | _ ->
      fail_and_exit
        "The value of --repeat must be a whole number of runs above 0."

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
        Printf.sprintf
          "<seconds> Stop a test run that takes longer than <seconds>. Without this option the limit is %i times the run without a mutant, and never less than %i seconds"
          timeout_multiple timeout_floor);
       ("--test-env",      Arg.String add_test_env,
        "<NAME=VALUE> Set NAME to VALUE in every test process. In the value, {} becomes the number of the run: 1 and 2 for the two runs without a mutation, and the number of the run for a mutation. Repeatable");
       ("--baseline-env",  Arg.String add_baseline_env,
        "<NAME=VALUE> Run the test suite a second time without a mutation, with NAME set to VALUE on top of what --test-env sets. Needed only for a value that is not the number of the run. Repeatable");
       ("-j",              Arg.String set_jobs,
        "<count> Test <count> mutations at one time. The default is 1");
       ("--repeat",        Arg.String set_repeat,
        "<count> Run the test command for one mutation until a run kills it, up to <count> runs, each with a different {} in the values of --test-env")]
end

(* Makes a directory that the runner needs, and stops the program with
   a message when it cannot. [Dir.ensure] does the work; the message is
   the runner's own. *)
let ensure_output_dir dir_name =
  match Dir.ensure dir_name with
  | () -> ()
  | exception Sys_error msg ->
    fail_and_exit (Printf.sprintf "Failed to make the directory %s - %s" dir_name msg)

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

(* The mutations and the skipped sites that one .muts file holds. The
   file holds a JSON object; a release before the skip attribute wrote a
   JSON list instead, and such a file needs a new build. *)
let read_module_mutations_json ppx_output_prefix file_name =
  let out_of_date () =
    fail_and_exit
      (Printf.sprintf
         "%s does not hold the fields that this release of mutaml reads. A mutation file that an older mutaml wrote needs a new build with --instrument-with mutaml."
         file_name) in
  try
    let ch = open_in (full_ppx_path ppx_output_prefix file_name) in
    Fun.protect ~finally:(fun () -> close_in_noerr ch)
      (fun () -> match Yojson.Safe.from_channel ch with
         | `Assoc _ as json -> muts_file_of_yojson_exn json
         | _                -> out_of_date ())
  with Sys_error msg ->
    fail_and_exit (Printf.sprintf "Could not read file %s - %s" file_name msg)
     | Yojson.Json_error msg ->
       fail_and_exit (Printf.sprintf "Could not parse %s - %s" file_name msg)
     | Failure _ -> out_of_date ()

let read_all_mutations ppx_output_prefix file_name =
  (* Sorted, so that the order of the report does not depend on the order
     in which the build system ran the preprocessor. *)
  let mut_files =
    List.sort_uniq String.compare
      (read_instrumentation_overview ppx_output_prefix file_name) in
  List.iter (fun fname -> Printf.printf "read mut file %s\n%!" fname) mut_files;
  List.map (fun f -> (f, read_module_mutations_json ppx_output_prefix f)) mut_files

let count_mutations (f,(ms : muts_file)) =
  if ms.mutants=[]
  then Printf.printf "Warning: No mutations were listed in %s\n" f
  else ();
  List.length ms.mutants

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
    (fun (file_name,(ms : muts_file)) -> match ms.mutants with
       | [] -> true
       | mut::_ ->
         let source = mut.loc.loc_start.pos_fname in
         Sys.file_exists source
         || (Printf.printf "Skipping %s: the source file %s does not exist\n%!"
               file_name source;
             false))
    muts

(* Writes the report file that mutaml-report reads: the result of every
   test run, and every site that the preprocessor skipped. *)
let write_report_file file_name ~results ~skipped =
  Printf.printf "Writing report data to %s\n" file_name;
  let ch = open_out file_name in
  Fun.protect ~finally:(fun () -> close_out_noerr ch)
    (fun () ->
       Yojson.Safe.to_channel ch (report_to_yojson { results; skipped }))


(** The actual test runner *)

(* Runs [test_cmd] once, with [mut_id] in MUTAML_MUTANT and with [test_env]
   set, and with its output in [output_file]. The empty [mut_id] runs the
   program without a mutant. Returns the run, which holds the exit status
   of the test process and the seconds the run took. [limit] is the
   seconds that the run may take. *)
let run_test_command test_cmd ~test_env ~limit ~mut_id ~output_file =
  ensure_output_dir (Filename.dirname output_file);
  let env = test_env @ [("MUTAML_MUTANT", mut_id)] in
  let run =
    Test_process.wait
      (Test_process.start ~cmd:test_cmd ~env ~output_file
         ~limit:(float_of_int limit)) in
  (*tests can both succeed and err*)
  match run.Test_process.status with
  | 127 -> fail_and_exit (Printf.sprintf "Command not found: failed to run the test command \"%s\"" test_cmd)
  | _   -> run

let status_word status = outcome_word (outcome_of_status status)


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

(* [baseline_run_env test_env baseline_env number] is the environment of
   the run without a mutant that has the number [number]. The first run
   has the variables of [test_env] and the second run has those of
   [baseline_env] on top of them. The number of the run replaces every
   "{}" in a value, so one --test-env option can give the two runs two
   seeds. *)
let baseline_run_env test_env baseline_env number =
  Run_env.expand ~run:number
    (if number = 1 then test_env else override test_env baseline_env)

(* Runs the test suite without a mutant. It runs a second time when the
   second run would not be the first run over again, which is when
   [baseline_env] changes a value or when a value holds "{}": two runs
   of one environment find nothing that one run does not find. Stops the
   program when a run fails, and when the two runs disagree: a score has
   no meaning in either case. Returns the seconds that the longer run
   took, which is the measurement that the limit of a mutant run comes
   from. *)
let run_baseline test_cmd ~test_env ~baseline_env ~limit =
  let env_of = baseline_run_env test_env baseline_env in
  let run number =
    let output_file = baseline_output_file number in
    let () =
      if number = 1
      then Printf.printf "Testing without a mutant ... %!"
      else Printf.printf "Testing without a mutant a second time ... %!" in
    let run =
      run_test_command test_cmd ~test_env:(env_of number) ~limit
        ~mut_id:"" ~output_file in
    let () = Printf.printf "%s\n%!" (status_word run.Test_process.status) in
    run in
  let first = run 1 in
  if first.Test_process.status <> 0
  then
    fail_and_exit
      (Printf.sprintf
         "The test suite did not pass without a mutant. Its exit status was %i.\nThe output of the run is in %s.\nEvery mutant would look killed, so mutaml-runner stops here."
         first.Test_process.status (baseline_output_file 1));
  if env_of 2 = env_of 1
  then first.Test_process.duration
  else
    let second = run 2 in
    if second.Test_process.status <> 0
    then
      fail_and_exit
        (Printf.sprintf
           "The test suite ran twice without a mutant. It passed in one run and not in the other.\nThe output of the two runs is in %s and %s.\nThe test suite does not give the same result every time, so a mutation score would have no meaning."
           (baseline_output_file 1) (baseline_output_file 2))
    else Float.max first.Test_process.duration second.Test_process.duration

(* [mutant_limit given measured] is the seconds that one mutant run may
   take. [given] is the value of --timeout, and [measured] is the
   seconds that the run without a mutant took. *)
let mutant_limit given measured = match given with
  | Some seconds -> seconds
  | None ->
    let derived = int_of_float (Float.ceil (float_of_int timeout_multiple *. measured)) in
    max timeout_floor derived

let seconds count =
  if count = 1 then "1 second" else Printf.sprintf "%i seconds" count

(* The line names the rule and not the limit it gives, because the
   measurement of the run without a mutant, and with it the limit,
   differs from one machine and one moment to the next. *)
let print_limit given limit = match given with
  | Some _ -> Printf.printf "The limit of a test run is %s.\n%!" (seconds limit)
  | None   ->
    Printf.printf
      "The limit of a test run is %i times the run without a mutant, and never less than %s.\n%!"
      timeout_multiple (seconds timeout_floor)


(** Executable entry point *)

let main () =
  let test_cmd = ref "" in
  let set_test_cmd str = if "" = !test_cmd then test_cmd := str else CLI.print_usage_and_exit () in
  let () = Arg.parse CLI.arg_spec set_test_cmd CLI.usage_string in
  if "" = !test_cmd then CLI.print_usage_and_exit () else
  let () = match !CLI.timeout, Sys.getenv_opt "MUTAML_TIMEOUT" with
    | None, Some secs -> CLI.set_timeout_from "MUTAML_TIMEOUT" secs
    | _, _            -> () in
  let () = match !CLI.jobs, Sys.getenv_opt "MUTAML_JOBS" with
    | None, Some count -> CLI.set_jobs_from "MUTAML_JOBS" count
    | _, _             -> () in
  let jobs = Option.value !CLI.jobs ~default:1 in
  let () = match Pool.jobs_conflict ~cmd:!test_cmd ~jobs with
    | None     -> ()
    | Some msg -> fail_and_exit msg in
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
  let given = !CLI.timeout in
  let measured =
    run_baseline !test_cmd ~test_env ~baseline_env
      ~limit:(Option.value given ~default:baseline_timeout) in
  let limit = mutant_limit given measured in
  print_limit given limit;
  let skipped =
    List.concat_map (fun (_file_name, (ms : muts_file)) -> ms.skipped) mutants in
  let results =
    Pool.run ~cmd:!test_cmd ~test_env ~jobs ~repeat:!CLI.repeat
      ~limit:(float_of_int limit)
      (List.concat_map (fun (_file_name, (ms : muts_file)) -> ms.mutants) mutants) in
  write_report_file defaults.mutaml_report_file ~results ~skipped

let () =
  try main () with
  | Test_process.Failed_to_run message -> fail_and_exit message
