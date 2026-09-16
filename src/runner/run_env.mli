(** The variables that the runner sets in a test process.

    The value of a variable may hold the two characters ["{}"]. The
    runner replaces them by the number of the run, so that one command
    line gives a different seed to each run of one mutation, and to
    each of the two runs without a mutation. *)

val expand : run:int -> (string * string) list -> (string * string) list
(** [expand ~run env] is [env] with every ["{}"] in a value replaced by
    [run], written as a decimal number. A name does not change, and the
    order of [env] does not change.

    [run] is the number of the run. The runs of one mutation are
    counted from 1, and so are the two runs without a mutation: the
    first is run 1 and the second is run 2. *)
