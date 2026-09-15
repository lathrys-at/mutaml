(** The counts that a report of a run needs.

    A run of [mutaml-runner] gives one test result for each mutant.
    This module groups those results in two ways: by the outcome of the
    test process, and by the source file that the mutant belongs to. *)

open Mutaml_common

type t
(** The results of one run, grouped by the outcome of the test process.
    Build a value with {!of_results}. *)

val of_results : test_result list -> t
(** [of_results results] groups [results] by the outcome that
    [Mutaml_common.outcome_of_status] gives for the exit status of each
    result. Inside a group the results keep the order they have in
    [results]. *)

val total : t -> int
(** [total t] is the number of results in [t]. *)

val with_outcome : t -> outcome -> test_result list
(** [with_outcome t outcome] holds the results in [t] whose outcome is
    [outcome], in the order that {!of_results} received them. *)

val count : t -> outcome -> int
(** [count t outcome] is the number of results in [t] whose outcome is
    [outcome]. It is the length of [with_outcome t outcome]. *)

val score : t -> float
(** [score t] is the share of the mutants of [t] that the test suite
    caught, as a percentage from 0 to 100. It is the number of results
    whose outcome is not [Passed], over the number of results.

    @raise Invalid_argument when [t] holds no result. A share of
    nothing has no value, and the caller must say so in its own words. *)

val by_file : test_result list -> (string * test_result list) list
(** [by_file results] pairs the name of each source file that
    [results] names with the results of the mutants of that file. The
    files come in the order of [String.compare], so that a report does
    not depend on the order in which the runner tested the mutants.
    Inside a pair the results keep the order they have in [results].

    The name of the source file of a result is the file of the start of
    the mutant's location, which is the name that the preprocessor
    recorded. *)
