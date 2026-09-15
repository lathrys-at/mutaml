(* one test run, in a process of the runner's own *)

exception Failed_to_run of string

type run =
  {
    status   : int;
    duration : float;
  }

(* The shell that reads the test command. *)
let shell = "/bin/sh"

(* Seconds between the signal TERM and the signal KILL. *)
let grace_period = 2.0

(* The status of a run that the limit stopped. *)
let timeout_status = 124

(* The number that stands for a signal whose own number this module
   cannot give. *)
let unknown_signal = 64

(* The shortest and the longest time that a wait sleeps between two
   looks at the processes, in seconds. *)
let first_pause   = 0.001
let longest_pause = 0.05

type state =
  | Running
  | Stopping of float (* the moment the signal KILL goes *)
  | Killed
  | Spent

type t =
  {
    pid              : int;
    started          : float;
    deadline         : float;
    mutable state    : state;
    mutable at_limit : bool;
  }

(* [system_signal n] is the number that the operating system gives the
   signal that OCaml numbers [n]. OCaml gives a signal it knows a
   number below 0, and leaves every other number as the operating
   system gives it. The table holds the signals whose number POSIX
   fixes, which is every signal that ends a program by fault. The
   number of each other signal differs from one operating system to the
   next, and [unknown_signal] stands for it. *)
let system_signal n =
  if n >= 0            then n
  else if n = Sys.sighup  then 1
  else if n = Sys.sigint  then 2
  else if n = Sys.sigquit then 3
  else if n = Sys.sigill  then 4
  else if n = Sys.sigtrap then 5
  else if n = Sys.sigabrt then 6
  else if n = Sys.sigfpe  then 8
  else if n = Sys.sigkill then 9
  else if n = Sys.sigsegv then 11
  else if n = Sys.sigpipe then 13
  else if n = Sys.sigalrm then 14
  else if n = Sys.sigterm then 15
  else unknown_signal

let status_of_end = function
  | Unix.WEXITED status              -> status
  | Unix.WSIGNALED n | Unix.WSTOPPED n -> 128 + system_signal n

let name_of_assignment text = match String.index_opt text '=' with
  | None   -> text
  | Some i -> String.sub text 0 i

(* [last_of_each env] is [env] without an earlier pair for a name that
   a later pair also names. *)
let rec last_of_each = function
  | [] -> []
  | (name,_ as pair)::rest ->
    if List.mem_assoc name rest
    then last_of_each rest
    else pair :: last_of_each rest

let environment_of env =
  let env = last_of_each env in
  let kept =
    List.filter
      (fun text -> not (List.mem_assoc (name_of_assignment text) env))
      (Array.to_list (Unix.environment ())) in
  Array.of_list
    (kept @ List.map (fun (name,value) -> name ^ "=" ^ value) env)

let start ~cmd ~env ~output_file ~limit =
  let fd =
    try Unix.openfile output_file [Unix.O_WRONLY; Unix.O_CREAT; Unix.O_TRUNC] 0o644
    with Unix.Unix_error (error,_,_) ->
      raise
        (Failed_to_run
           (Printf.sprintf
              "Could not write the file %s, which takes the output of a test run: %s"
              output_file (Unix.error_message error))) in
  let environment = environment_of env in
  (* The shell prints its line about a child that a signal ended only
     for a command in a group, so the test command goes in one. The
     line ends the group, because the test command can end in a
     comment. *)
  let script = Printf.sprintf "{ %s\n}" cmd in
  let () = flush stdout in
  let () = flush stderr in
  let started = Unix.gettimeofday () in
  match Unix.fork () with
  | 0 ->
    (* In the new process. It ends here, whatever happens. *)
    let () =
      try
        ignore (Unix.setsid () : int);
        Unix.dup2 fd Unix.stdout;
        Unix.dup2 fd Unix.stderr;
        if fd <> Unix.stdout && fd <> Unix.stderr then Unix.close fd;
        Unix.execve shell [| shell; "-c"; script |] environment
      with _ -> () in
    Unix._exit 127
  | pid ->
    Unix.close fd;
    { pid; started; deadline = started +. limit; state = Running;
      at_limit = false }
  | exception Unix.Unix_error (error,_,_) ->
    Unix.close fd;
    raise
      (Failed_to_run
         (Printf.sprintf "Could not make a process for a test run: %s"
            (Unix.error_message error)))

let pid p = p.pid

let signal_group p signal =
  (* The process leads its group, so the group holds its children as
     well. A process that ended in the meantime is gone, and the signal
     then reaches nothing. *)
  try Unix.kill (- p.pid) signal with Unix.Unix_error _ -> ()

let rec collect p = match Unix.waitpid [Unix.WNOHANG] p.pid with
  | 0, _      -> None
  | _, ending -> Some ending
  | exception Unix.Unix_error (Unix.EINTR,_,_) -> collect p
  | exception Unix.Unix_error (error,_,_) ->
    raise
      (Failed_to_run
         (Printf.sprintf "Lost the process of a test run: %s"
            (Unix.error_message error)))

(* Sends the signals that the limit of [p] asks for at the time [now].
   A run that reaches its limit takes the signal TERM, and the signal
   KILL a grace period later. *)
let advance p now = match p.state with
  | Running ->
    if now >= p.deadline
    then
      begin
        p.at_limit <- true;
        signal_group p Sys.sigterm;
        p.state <- Stopping (now +. grace_period)
      end
  | Stopping kill_at ->
    if now >= kill_at
    then (signal_group p Sys.sigkill; p.state <- Killed)
  | Killed | Spent -> ()

let finish p ending =
  p.state <- Spent;
  {
    status = (if p.at_limit then timeout_status else status_of_end ending);
    duration = Unix.gettimeofday () -. p.started;
  }

let check_unspent name p = match p.state with
  | Spent -> invalid_arg (name ^ ": this process is spent")
  | Running | Stopping _ | Killed -> ()

let rec wait_loop ps pause =
  let now = Unix.gettimeofday () in
  let () = List.iter (fun p -> advance p now) ps in
  match
    List.find_map (fun p -> Option.map (fun ending -> (p,ending)) (collect p)) ps
  with
  | Some (p,ending) -> (p, finish p ending)
  | None ->
    Unix.sleepf pause;
    wait_loop ps (Float.min longest_pause (pause *. 2.0))

let wait_any ps =
  if ps = []
  then invalid_arg "Test_process.wait_any: the list of processes is empty";
  List.iter (check_unspent "Test_process.wait_any") ps;
  wait_loop ps first_pause

let wait p =
  check_unspent "Test_process.wait" p;
  snd (wait_loop [p] first_pause)

let stop_all ps =
  let live =
    List.filter (fun p -> match p.state with Spent -> false | _ -> true) ps in
  let () = List.iter (fun p -> signal_group p Sys.sigterm) live in
  let kill_at = Unix.gettimeofday () +. grace_period in
  let rec drain ps pause = match ps with
    | [] -> ()
    | _  ->
      let () =
        if Unix.gettimeofday () >= kill_at
        then List.iter (fun p -> signal_group p Sys.sigkill) ps in
      let left =
        List.filter
          (fun p ->
             (* A process that the machine lost is not there to stop. *)
             match (try collect p with Failed_to_run _ -> Some (Unix.WEXITED 0)) with
             | Some _ -> p.state <- Spent; false
             | None   -> true)
          ps in
      if left <> []
      then
        begin
          Unix.sleepf pause;
          drain left (Float.min longest_pause (pause *. 2.0))
        end in
  drain live first_pause
