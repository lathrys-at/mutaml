(** The variables that the runner sets in a test process.

    The value of a variable may hold the two characters ["{}"]. The
    runner replaces them by the number of the run, so that one command
    line gives a different seed to each run of one mutation. *)

val expand : run:int -> (string * string) list -> (string * string) list
(** [expand ~run env] is [env] with every ["{}"] in a value replaced by
    [run], written as a decimal number. A name does not change, and the
    order of [env] does not change.

    [run] counts the runs of one mutation from 1. *)
