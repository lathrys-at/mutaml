type error =
  | Cannot_run of string
  | Refused of string list

(* The lines of one file that the change touched, as runs of lines. A
   run holds its first and its last line, both counted from 1. *)
type t =
  {
    (* Where the working directory sits in the repository, as git
       writes it: the empty text at the root, and otherwise a path that
       ends with "/". *)
    prefix : string;
    files  : (string * (int * int) list) list;
    (* The files that git does not track. A diff against a revision
       says nothing about such a file, so every line of it counts as
       changed. *)
    others : string list;
  }

(* The settings that git is given, whatever the person's own
   configuration holds. Each one stops a setting that would change the
   text below into text that this reader cannot read, which would leave
   it finding no changed line and the runner testing nothing.

   - core.quotePath writes a file name that holds a byte above 127
     inside quotation marks, with escapes.
   - diff.external hands the work to another program, whose output has
     no hunk header at all. --no-ext-diff stops that, and --no-textconv
     stops the same thing for one path.
   - diff.mnemonicPrefix and diff.noprefix change or drop the "b/" in
     front of the name of the file as it is now. --dst-prefix puts it
     back. *)
let fixed_config = ["-c"; "core.quotePath=false"]
let fixed_diff = ["--no-ext-diff"; "--no-textconv"; "--dst-prefix=b/"]

let error_message = function
  | Cannot_run reason ->
    Printf.sprintf
      "Could not run git, which --changed-since needs to find the lines that changed - %s"
      reason
  | Refused args ->
    Printf.sprintf
      "git could not do \"%s\". Check that the revision is one that git knows, and that this directory is in a git repository."
      (String.concat " " ("git" :: args))

(* [read_all ch] is every byte left in [ch]. *)
let read_all ch =
  let buf = Buffer.create 4096 in
  let chunk = Bytes.create 4096 in
  let rec loop () =
    let read = input ch chunk 0 (Bytes.length chunk) in
    if read > 0
    then (Buffer.add_subbytes buf chunk 0 read; loop ()) in
  loop ();
  Buffer.contents buf

(* [close_fd fd] closes [fd] and passes over a failure to close, which
   leaves nothing for the caller to do. *)
let close_fd fd = try Unix.close fd with Unix.Unix_error _ -> ()

(* [errors_fd ()] is where the messages of git go: away, so that the
   runner writes the one message of its own and the output of the tool
   is the same on every machine. It is the error output of the runner
   itself when the empty file cannot be opened. *)
let errors_fd () =
  match Unix.openfile "/dev/null" [Unix.O_WRONLY] 0 with
  | fd -> fd
  | exception Unix.Unix_error _ -> Unix.stderr

(* [git args] is what git writes to its output when it is given [args],
   and an error when it cannot be run or does not do the work. It runs
   git without a shell, so an argument holding a character that a shell
   reads is still one argument. *)
let git args =
  let args = fixed_config @ args in
  match Unix.pipe () with
  | exception Unix.Unix_error (e,_,_) -> Error (Cannot_run (Unix.error_message e))
  | (from_git, to_us) ->
    let errors = errors_fd () in
    let close_errors () = if errors <> Unix.stderr then close_fd errors in
    (match
       Unix.create_process "git" (Array.of_list ("git" :: args))
         Unix.stdin to_us errors
     with
     | exception Unix.Unix_error (e,_,_) ->
       close_fd from_git;
       close_fd to_us;
       close_errors ();
       Error (Cannot_run (Unix.error_message e))
     | pid ->
       (* This process holds the only other end of the pipe, so it must
          let go of it or the read below never reaches the end. *)
       close_fd to_us;
       close_errors ();
       let ch = Unix.in_channel_of_descr from_git in
       let output =
         Fun.protect ~finally:(fun () -> close_in_noerr ch) (fun () -> read_all ch) in
       (match Unix.waitpid [] pid with
        | exception Unix.Unix_error (e,_,_) -> Error (Cannot_run (Unix.error_message e))
        | (_, Unix.WEXITED 0)   -> Ok output
        | (_, Unix.WEXITED 127) -> Error (Cannot_run "the command git is not on PATH")
        | (_, _)                -> Error (Refused args)))

(* [starts_with ~prefix text] says whether [text] begins with [prefix].
   String.starts_with is a 4.13 addition and this tool builds on 4.12. *)
let starts_with ~prefix text =
  String.length text >= String.length prefix
  && String.equal (String.sub text 0 (String.length prefix)) prefix

(* [after ~prefix text] is what is left of [text] once [prefix] is taken
   from its front. [text] begins with [prefix]. *)
let after ~prefix text =
  String.sub text (String.length prefix) (String.length text - String.length prefix)

(* [hunk_lines header] is the run of lines of the file as it is now that
   the hunk [header] covers, and [None] when [header] is not a hunk
   header that this reader understands.

   A header reads "@@ -12,3 +14,2 @@", and the part after the "+" holds
   the first line and the number of lines, which is 1 when it is not
   there. A hunk of no line took lines away and added none; it marks the
   line that the removal follows, so that a change which only takes code
   away does not leave every mutation of the file untested. *)
let hunk_lines header =
  let range start count =
    if count > 0 then Some (start, start + count - 1)
    else Some (max 1 start, max 1 start) in
  match String.split_on_char ' ' header with
  | "@@" :: _taken :: added :: _ when starts_with ~prefix:"+" added ->
    (match String.split_on_char ',' (after ~prefix:"+" added) with
     | [start] ->
       (match int_of_string_opt start with
        | Some start -> range start 1
        | None       -> None)
     | [start; count] ->
       (match int_of_string_opt start, int_of_string_opt count with
        | Some start, Some count when count >= 0 -> range start count
        | _, _ -> None)
     | _ -> None)
  | _ -> None

(* [file_of_header header] is the file that the "+++" line of a diff
   names, and [None] when the line names no file, which is what git
   writes for a file that the change took away.

   git writes the name after "b/", because [fixed_diff] asks for that
   prefix whatever the configuration holds. The two characters come
   away only when they are there, so a git that writes the name alone
   is read as well. *)
let file_of_header header =
  let name = after ~prefix:"+++ " header in
  if String.equal name "/dev/null" then None
  else if starts_with ~prefix:"b/" name then Some (after ~prefix:"b/" name)
  else Some name

(* [parse diff] is the lines that the output [diff] of
   "git diff --unified=0" shows as lines of the files as they are now.

   The reader holds one of two states. It is in the head of a file
   section until it has seen the "+++" line of that section, and in the
   body of the section after it. No line of the body of a diff of no
   context begins with "diff --git ", because a line of the body begins
   with "+", with "-", or with the character that "\ No newline" begins
   with; and no line of the head begins with "+++ " but the one that
   names the file. Each state therefore reads the lines it needs
   without mistaking a line of the file for a line of the diff. *)
let parse diff =
  let add files file lines = match List.assoc_opt file files with
    | None      -> (file, [lines]) :: files
    | Some have -> (file, lines :: have) :: List.remove_assoc file files in
  let rec loop in_head file files = function
    | [] -> files
    | line :: rest ->
      if starts_with ~prefix:"diff --git " line
      then loop true None files rest
      else if in_head && starts_with ~prefix:"+++ " line
      then loop false (file_of_header line) files rest
      else if in_head
      then loop true file files rest
      else
        match file, hunk_lines line with
        | Some file, Some lines -> loop false (Some file) (add files file lines) rest
        | _, _                  -> loop false file files rest in
  let files = loop true None [] (String.split_on_char '\n' diff) in
  List.map (fun (file,runs) -> (file, List.rev runs)) files

(* [lines text] is the lines of [text], without the empty line that the
   newline at the end of the last one would otherwise make. *)
let lines text =
  List.filter (fun line -> not (String.equal line ""))
    (String.split_on_char '\n' text)

let since ~rev =
  match git ["rev-parse"; "--show-prefix"] with
  | Error _ as error -> error
  | Ok prefix ->
    (* git writes the prefix on one line, and the empty text at the root
       of the repository. *)
    let prefix = match String.split_on_char '\n' prefix with
      | first :: _ -> first
      | []         -> "" in
    (match git (["diff"] @ fixed_diff @ ["--unified=0"; rev; "--"]) with
     | Error _ as error -> error
     | Ok diff          ->
       (* A file that git does not track is in no diff against a
          revision, and a new source file is the code that most wants
          testing. Ask for those files by name. *)
       (match git ["ls-files"; "--others"; "--exclude-standard"; "--full-name"; "--"] with
        | Error _ as error -> error
        | Ok others        -> Ok { prefix; files = parse diff; others = lines others }))

let touches t ~file ~first ~last =
  if last < first then false
  else
    let path = if Filename.is_relative file then t.prefix ^ file else file in
    if List.exists (String.equal path) t.others then true
    else
      match List.assoc_opt path t.files with
      | None      -> false
      | Some runs -> List.exists (fun (from,upto) -> from <= last && first <= upto) runs
