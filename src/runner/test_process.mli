(** One run of the test command, in a process of the runner's own. *)

exception Failed_to_run of string
(** Raised when the runner cannot run the test command at all: it
    cannot open the file for the output of a run, it cannot make a new
    process, or the machine loses a process that it made. The string
    says which, in words for the person who runs the tool. *)

type run =
  {
    status   : int;
    duration : float;
  }
(** The end of one test run. [status] is 0 for a run that passed, 124
    for a run that the limit stopped, 128 plus the number of a signal
    for a run that a signal ended, and any other number for a run that
    failed. [Mutaml_common.outcome_of_status] reads a status of this
    shape.

    The number of a signal is the number that the operating system
    gives it. A few signals have a different number on each operating
    system. This module cannot name those, and a run that one of them
    ended has the status 192, which still reads as a run that a signal
    ended.

    [duration] is the time from the start of the process to its end,
    in seconds. *)

type t
(** One test process. [start] makes one, and [wait], [wait_any] or
    [stop_all] ends it.

    The caller owns the process between the two calls, and must end
    every process that it starts: a process that nobody ends runs until
    the runner itself ends. A value is spent once a wait has given back
    its run, and a spent value holds nothing that the caller must
    release. *)

val start :
  cmd:string ->
  env:(string * string) list ->
  output_file:string ->
  limit:float ->
  t
(** [start ~cmd ~env ~output_file ~limit] starts [cmd] and returns at
    once, before the run ends.

    [cmd] is a command for the shell [/bin/sh], which may hold
    arguments, a pipe, or the path of a script.

    The process gets the variables of the runner's own environment, and
    then each name of [env] with the value that [env] gives it. A name
    that [env] holds twice takes the value that comes last.

    Everything that the process and its children write to their
    standard output and to their standard error goes to [output_file].
    The file is made, and emptied when it is already there. The line
    that the shell prints when a child of it dies by a signal goes to
    the same file. The directory of [output_file] must exist.

    The process leads a group of its own, so that a signal that this
    module sends reaches the children of the shell as well. The process
    therefore has no terminal, and a test command that asks for one
    does not work here.

    [limit] is the number of seconds that the run may take. A wait
    stops a run that takes longer. With a limit of 0 or less, a wait
    stops the run at its first look at it.

    Raises [Failed_to_run] when it cannot open [output_file] or cannot
    make a process. *)

val pid : t -> int
(** [pid p] is the number that the operating system gives the process
    of [p]. It is the same number for the life of [p], and it names no
    process once [p] is spent. *)

val wait : t -> run
(** [wait p] waits until [p] ends, and gives back its run. [p] is spent
    afterwards.

    When the run reaches its limit, this module sends the group of the
    process the signal TERM, and the signal KILL two seconds later. It
    sends the signal KILL to the group as well once the process itself
    is gone, so that a program which the test command started and which
    answers the signal TERM is not left behind. The run then has the
    status 124, whatever the process answered.

    A run that ends before its limit keeps the status that it answered.

    Raises [Invalid_argument] when [p] is already spent. Raises
    [Failed_to_run] when the machine loses the process. *)

val wait_any : t list -> t * run
(** [wait_any ps] waits until one process of [ps] ends, and gives back
    that process and its run. The other processes of [ps] keep running,
    and the caller waits for each of them in turn.

    This holds the limit of every process of [ps], and not only of the
    one it gives back. A process of [ps] that reaches its limit while
    this waits is stopped as [wait] stops it, and a later wait gives
    back its run with the status 124.

    Raises [Invalid_argument] when [ps] is empty, and when a process of
    [ps] is already spent. Raises [Failed_to_run] when the machine
    loses a process. *)

val stop_all : t list -> unit
(** [stop_all ps] ends every process of [ps] that still runs, and waits
    for each of them, so that none is left on the machine. A process of
    [ps] that is already spent is passed over. Every process of [ps] is
    spent afterwards, and the runs are lost. *)
