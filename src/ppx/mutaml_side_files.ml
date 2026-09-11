type t = { dir : string }

(* The file that holds the identifier of the build that filled the list
   of .muts files. *)
let build_marker_file = "mutaml-build-id.txt"

(* The file that the runs of the instrumentation take a lock on while
   they read and write the list of .muts files. *)
let lock_file = "mutaml-mut-files.lock"

let getenv_non_empty name = match Sys.getenv_opt name with
  | None | Some "" -> None
  | Some value -> Some value

let resolve () =
  match getenv_non_empty "MUTAML_PPX_OUT_DIR" with
  | Some dir -> { dir }
  | None ->
    (* Dune sets INSIDE_DUNE to the build context directory of the build
       that runs us, as an absolute path. It does so even when it runs us
       in a sandbox directory that it deletes afterwards, so this path
       leads out of the sandbox. Put the files beside that directory and
       not in it: dune deletes files it does not know about from a
       context directory, at the start of the next build. *)
    match getenv_non_empty "INSIDE_DUNE" with
    | Some ctx when not (Filename.is_relative ctx) ->
      let build_dir = Filename.dirname ctx in
      { dir = Filename.concat (Filename.concat build_dir ".mutaml")
                (Filename.basename ctx) }
    | Some _ | None -> { dir = Filename.current_dir_name }

(* The identifier of the build that runs us. Dune runs every
   instrumentation of one build from one process, so the process that
   started us names the build. A later build has a different one. *)
let build_id () = string_of_int (Unix.getppid ())

let rec make_dir name =
  if name = "" || name = Filename.current_dir_name || name = Filename.dirname name
  then ()
  else if Sys.file_exists name
  then
    (if not (Sys.is_directory name)
     then Mutaml_common.fail_and_exit
            (Printf.sprintf "Expected a directory but found a file: %s" name))
  else
    begin
      make_dir (Filename.dirname name);
      (* Another instrumentation of the same build may make it first. *)
      try Sys.mkdir name 0o755 with
      | Sys_error _ when Sys.file_exists name -> ()
      | Sys_error msg ->
        Mutaml_common.fail_and_exit
          (Printf.sprintf "Could not create directory %s - %s" name msg)
    end

let read_lines name =
  if not (Sys.file_exists name) then [] else
    match open_in name with
    | exception Sys_error msg ->
      Mutaml_common.fail_and_exit (Printf.sprintf "Could not read file %s - %s" name msg)
    | ch ->
      Fun.protect ~finally:(fun () -> close_in_noerr ch)
        (fun () ->
           let rec loop acc = match input_line ch with
             | line -> loop (line::acc)
             | exception End_of_file -> List.rev acc in
           loop [])

let write_lines name lines =
  match open_out name with
  | exception Sys_error msg ->
    Mutaml_common.fail_and_exit (Printf.sprintf "Could not write file %s - %s" name msg)
  | ch ->
    Fun.protect ~finally:(fun () -> close_out_noerr ch)
      (fun () -> List.iter (fun line -> output_string ch (line ^ "\n")) lines)

let write_muts t ~input_name json =
  let rel_name = Filename.(remove_extension input_name) ^ ".muts" in
  let full_name =
    if Filename.is_implicit rel_name
    then Filename.concat t.dir rel_name
    else rel_name in
  make_dir (Filename.dirname full_name);
  (match open_out full_name with
   | exception Sys_error msg ->
     Mutaml_common.fail_and_exit
       (Printf.sprintf "Could not write file %s - %s" full_name msg)
   | ch ->
     Fun.protect ~finally:(fun () -> close_out_noerr ch)
       (fun () -> Yojson.Safe.to_channel ch json));
  rel_name

(* Runs [f] while this process alone holds the lock on the directory.
   Closing the file releases the lock, on the error paths too. *)
let with_lock t f =
  make_dir t.dir;
  let name = Filename.concat t.dir lock_file in
  match Unix.openfile name [Unix.O_RDWR; Unix.O_CREAT] 0o660 with
  | exception Unix.Unix_error (err,_,_) ->
    Mutaml_common.fail_and_exit
      (Printf.sprintf "Could not open file %s - %s" name (Unix.error_message err))
  | fd ->
    Fun.protect ~finally:(fun () -> try Unix.close fd with Unix.Unix_error _ -> ())
      (fun () ->
         (match Unix.lockf fd Unix.F_LOCK 0 with
          | () -> ()
          | exception Unix.Unix_error (err,_,_) ->
            Mutaml_common.fail_and_exit
              (Printf.sprintf "Could not lock file %s - %s" name (Unix.error_message err)));
         f ())

let record_muts_file t name =
  with_lock t (fun () ->
      let list_name = Filename.concat t.dir Mutaml_common.defaults.mutaml_mut_file in
      let marker_name = Filename.concat t.dir build_marker_file in
      let id = build_id () in
      (* The list holds the files of this build alone. When the marker
         names another build, this is the first .muts file of a new
         build and the list starts again. *)
      let names =
        if read_lines marker_name = [id] then read_lines list_name else [] in
      (* Sorted, so that the list does not depend on the order in which
         dune happened to run the instrumentations. Everything the runner
         and the report print follows the order of this list. *)
      if not (List.mem name names)
      then write_lines list_name (List.sort_uniq String.compare (name::names));
      write_lines marker_name [id])
