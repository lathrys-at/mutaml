open Mutaml_common

(* [first_word cmd] is the text of [cmd] up to the first space or tab,
   with any space and tab in front of it dropped. *)
let first_word cmd =
  let len = String.length cmd in
  let is_blank c = c = ' ' || c = '\t' in
  let rec skip i = if i < len && is_blank cmd.[i] then skip (i + 1) else i in
  let rec take i = if i < len && not (is_blank cmd.[i]) then take (i + 1) else i in
  let start = skip 0 in
  String.sub cmd start (take start - start)

let jobs_conflict ~cmd ~jobs =
  if jobs <= 1 || Filename.basename (first_word cmd) <> "dune"
  then None
  else
    Some
      "mutaml-runner runs one test at a time when the test command starts with dune.\n\
       dune locks the build directory, so a second dune cannot run at the same time.\n\
       Give the path of the test executable to run more tests at a time, for example _build/default/test/mytests.exe."

(* [ensure_dir path] makes the directory [path] and every directory
   above it that is not there yet. It raises [Sys_error] when a name on
   the path is there and is not a directory. *)
let rec ensure_dir path =
  if not (Sys.file_exists path)
  then begin
    let parent = Filename.dirname path in
    if parent <> path then ensure_dir parent;
    try Sys.mkdir path 0o755 with
    | Sys_error _ when Sys.file_exists path && Sys.is_directory path -> ()
  end
  else if not (Sys.is_directory path)
  then raise (Sys_error (path ^ " is not a directory"))

(* [remove_tree path] removes [path] and everything under it. It removes
   a symbolic link itself and does not follow it. It passes over a name
   that it cannot remove. *)
let rec remove_tree path =
  match Unix.lstat path with
  | exception Unix.Unix_error _ -> ()
  | { Unix.st_kind = Unix.S_DIR; _ } ->
    (match Sys.readdir path with
     | names -> Array.iter (fun name -> remove_tree (Filename.concat path name)) names
     | exception Sys_error _ -> ());
    (try Sys.rmdir path with Sys_error _ -> ())
  | _ -> (try Sys.remove path with Sys_error _ -> ())

let tmp_root = full_path "tmp"

let worker_tmp_dir slot =
  Filename.concat (Sys.getcwd ()) (Filename.concat tmp_root (Printf.sprintf "job%i" slot))

(* One mutation that runs now, and the run of it that is in flight. *)
type job =
  {
    index      : int;                    (* the place of the mutation in the list *)
    mutant     : mutant;
    slot       : int;                    (* the worker that holds the mutation *)
    run_number : int;                    (* the run in flight, counted from 1 *)
    env        : (string * string) list; (* the variables of the run in flight *)
    proc       : Test_process.t;
  }

(* A mutation whose runs are over: the result to report, and the word
   to print for it. *)
type finished = { result : test_result; word : string }

(* A failure that stops the whole run. The pool raises it so that it
   stops every test process and removes every directory it made before
   the program ends. *)
exception Fatal of string

let run ~cmd ~test_env ~jobs ~repeat ~limit mutants =
  if jobs < 1 then invalid_arg "Pool.run: jobs is below 1";
  if repeat < 1 then invalid_arg "Pool.run: repeat is below 1";
  let items = Array.of_list mutants in
  let total = Array.length items in
  let finished = Array.make total None in
  let next = ref 0 in
  let free_slots = ref (List.init jobs (fun i -> i + 1)) in
  let running = ref [] in
  let printed = ref 0 in
  let fail_dir path msg =
    raise
      (Fatal
         (Printf.sprintf "Failed to make the directory %s for a test process - %s"
            path msg)) in
  let make_tmp_dirs slots =
    if jobs > 1
    then
      List.iter
        (fun slot ->
           let dir = worker_tmp_dir slot in
           match ensure_dir dir with
           | () -> ()
           | exception Sys_error msg -> fail_dir dir msg)
        slots in
  (* The runner prints the line of a mutation only when every mutation
     before it in the list has printed, so the printed order is the
     order of the list whatever the order in which the runs end. *)
  let rec flush_lines () =
    if !printed < total
    then match finished.(!printed) with
      | None -> ()
      | Some f ->
        if jobs = 1
        then Printf.printf "%s\n%!" f.word
        else
          Printf.printf "Testing mutant %s ... %s\n%!"
            (mutant_name f.result.mutant) f.word;
        incr printed;
        flush_lines () in
  let start_job ~index ~mutant ~slot ~run_number =
    let env = Run_env.expand ~run:run_number test_env in
    let child_env =
      env
      @ [("MUTAML_MUTANT", mutant_name mutant)]
      @ (if jobs > 1 then [("TMPDIR", worker_tmp_dir slot)] else []) in
    let output_file = output_file_name mutant.loc.loc_start.pos_fname mutant.number in
    let dir = Filename.dirname output_file in
    let () = match ensure_dir dir with
      | () -> ()
      | exception Sys_error msg -> fail_dir dir msg in
    let () =
      if jobs = 1 && run_number = 1
      then Printf.printf "Testing mutant %s ... %!" (mutant_name mutant) in
    let proc = Test_process.start ~cmd ~env:child_env ~output_file ~limit in
    { index; mutant; slot; run_number; env; proc } in
  let record job (r : Test_process.run) =
    if r.status = 127
    then
      raise
        (Fatal
           (Printf.sprintf "Command not found: failed to run the test command \"%s\"" cmd));
    let word = outcome_word (outcome_of_status r.status) in
    let word =
      if repeat > 1
      then Printf.sprintf "%s in run %i of %i" word job.run_number repeat
      else word in
    finished.(job.index) <-
      Some { result = { status = r.status; mutant = job.mutant; test_env = job.env }; word };
    free_slots := job.slot :: !free_slots;
    flush_lines () in
  let rec fill () = match !free_slots with
    | slot :: rest when !next < total ->
      free_slots := rest;
      let index = !next in
      incr next;
      running := start_job ~index ~mutant:items.(index) ~slot ~run_number:1 :: !running;
      fill ()
    | _ -> () in
  let rec loop () =
    fill ();
    match !running with
    | [] -> ()
    | jobs_now ->
      let (proc, r) = Test_process.wait_any (List.map (fun j -> j.proc) jobs_now) in
      let pid = Test_process.pid proc in
      let (job, rest) =
        List.partition (fun j -> Test_process.pid j.proc = pid) jobs_now in
      (match job with
       | [job] ->
         running := rest;
         if r.Test_process.status <> 0 || job.run_number >= repeat
         then record job r
         else
           running :=
             start_job ~index:job.index ~mutant:job.mutant ~slot:job.slot
               ~run_number:(job.run_number + 1) :: !running
       | _ ->
         raise
           (Fatal
              (Printf.sprintf
                 "A test process that mutaml-runner did not start ended, with the process id %i"
                 pid)));
      loop () in
  let stop_and_clean () =
    Test_process.stop_all (List.map (fun j -> j.proc) !running);
    running := [];
    if jobs > 1 then remove_tree (Filename.concat (Sys.getcwd ()) tmp_root) in
  let body () = make_tmp_dirs !free_slots; loop () in
  (match Fun.protect ~finally:stop_and_clean body with
   | () -> ()
   | exception Fatal msg -> fail_and_exit msg);
  Array.to_list
    (Array.mapi
       (fun index f -> match f with
          | Some f -> f.result
          | None ->
            fail_and_exit
              (Printf.sprintf "No test run answered for the mutant %s"
                 (mutant_name items.(index))))
       finished)
