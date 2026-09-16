(** The counts that a report of a run needs.

    A run of [mutaml-runner] gives one test result for each mutant, the
    mutants that did not run included, and one record for each place
    that [[@mutaml.skip "reason"]] took out of the run. This module
    groups the results in two ways, by the outcome of the test process
    and by the source file that the mutant belongs to, and it groups
    the skipped places by source file. *)

open Mutaml_common

type t
(** The results of one run, grouped by the outcome of the test process.
    Build a value with {!of_results}. *)

val of_results : test_result list -> t
(** [of_results results] groups [results] by outcome. The outcome of a
    result whose [not_run] field is true is [Not_run]; the outcome of
    every other result is what [Mutaml_common.outcome_of_status] gives
    for its exit status. Inside a group the results keep the order they
    have in [results]. *)

val total : t -> int
(** [total t] is the number of results in [t], the mutations that did
    not run included. *)

val scored : t -> int
(** [scored t] is the number of results in [t] that ran, which is
    {!total} less the number whose outcome is [Not_run]. It is the
    number of mutations that the mutation score is a share of. *)

val with_outcome : t -> outcome -> test_result list
(** [with_outcome t outcome] holds the results in [t] whose outcome is
    [outcome], in the order that {!of_results} received them. *)

val count : t -> outcome -> int
(** [count t outcome] is the number of results in [t] whose outcome is
    [outcome]. It is the length of [with_outcome t outcome]. *)

val score : t -> float
(** [score t] is the share of the mutants of [t] that the test suite
    caught, as a percentage from 0 to 100. It is the number of results
    that ran and whose outcome is not [Passed], over {!scored}.

    A mutation that did not run is in neither half of the share. A
    score is a share of what was tested, and such a mutation was not
    tested.

    @raise Invalid_argument when no result in [t] ran, which includes a
    [t] that holds no result at all. A share of nothing has no value,
    and the caller must say so in its own words. *)

val by_file : test_result list -> (string * test_result list) list
(** [by_file results] pairs the name of each source file that
    [results] names with the results of the mutants of that file. The
    files come in the order of [String.compare], so that a report does
    not depend on the order in which the runner tested the mutants.
    Inside a pair the results keep the order they have in [results].

    The name of the source file of a result is the file of the start of
    the mutant's location, which is the name that the preprocessor
    recorded. *)

val skipped_by_file : skipped list -> (string * skipped list) list
(** [skipped_by_file skipped] pairs the name of each source file that
    [skipped] names with the skipped places of that file. The files come
    in the order of [String.compare]. Inside a pair the places keep the
    order they have in [skipped].

    The name of the source file of a place is the file of the start of
    the place's location, which is the name that the preprocessor
    recorded. *)
