(** Making the directories that the runner writes into.

    The runner writes the output of every test run under [_mutations],
    and a run with more than one job gives each worker a directory of
    its own under it. Both make a directory before they write to it,
    and this is the one function that makes one. *)

val ensure : string -> unit
(** [ensure path] makes the directory [path], and every directory above
    it that is not there yet. It does nothing when [path] is a
    directory already.

    Two processes may call it for one path at the same time. A
    directory that another process made in between counts as made.

    @raise Sys_error when a name on the path is there and is not a
    directory, and when the system refuses to make a directory. The
    message names the path. The caller decides what to tell the person
    who runs the tool. *)
