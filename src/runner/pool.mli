(** Runs the test command over a list of mutations, with more than one
    mutation at a time. *)

val jobs_conflict : cmd:string -> jobs:int -> string option
(** [jobs_conflict ~cmd ~jobs] is the message that says why the test
    command [cmd] cannot run [jobs] times at once, and [None] when it
    can. The first word of a command that cannot is [dune]: [dune]
    locks the build directory, so a second [dune] fails. A [jobs] of 1
    or less never conflicts.

    The caller owns the message. It is written for the person who runs
    the tool. *)

val run :
  cmd:string ->
  test_env:(string * string) list ->
  jobs:int ->
  repeat:int ->
  limit:float ->
  Mutaml_common.mutant list ->
  Mutaml_common.test_result list
(** [run ~cmd ~test_env ~jobs ~repeat ~limit mutants] runs the test
    command [cmd] for each mutation of [mutants], and answers one result
    for each, in the order of [mutants]. The order of the answer does
    not depend on the order in which the runs end.

    Each run has the variables of [test_env] set, with [Run_env.expand]
    applied to them, and [MUTAML_MUTANT] set to the name of the
    mutation. Its output goes to the output file of the mutation, and
    [run] makes the directory of that file when it is not there.
    [limit] is the number of seconds that one run may take.

    [jobs] is the greatest number of mutations that run at one time.
    Each of the [jobs] workers holds one mutation until every run of
    that mutation is over. When [jobs] is above 1, each worker has the
    variable [TMPDIR] set to a directory of its own under
    [_mutations/tmp], and [run] removes those directories before it
    answers. When [jobs] is 1, [run] sets no [TMPDIR], so a test process
    sees the variable that the runner was given.

    [repeat] is the greatest number of runs that one mutation gets. A
    mutation runs again while the run before it passed and while runs
    are left. The result is the first run that did not pass, or the last
    run when every run passed; [test_env] in the result holds the
    variables of that same run. The output file of a mutation holds the
    output of the last run that [run] made for it.

    [run] writes one line for each mutation to standard output, in the
    order of [mutants].

    Raises [Invalid_argument] when [jobs] is below 1, and when [repeat]
    is below 1. Raises [Test_process.Failed_to_run] when the runner
    cannot start a test process at all; every process that [run] started
    is ended before the exception leaves.

    [run] ends the program with a message when it cannot make a
    directory that it needs, and when a run answers the status 127,
    which is what a shell answers for a command that it cannot find. *)
