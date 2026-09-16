(** The report in the mutation-testing-elements format.

    [mutaml-report --json-report <path>] writes this JSON. The format is
    the [MutationTestResult] schema of the mutation-testing-elements
    project, at
    https://github.com/stryker-mutator/mutation-testing-elements, in
    [packages/report-schema]. Stryker, Infection and Mull write the same
    format, and the HTML viewer [mutation-test-report-app] reads it.

    The four outcomes of a run of [mutaml-runner] take these statuses of
    the schema.

    - A mutant that made a test fail is [Killed].
    - A mutant whose test run a signal ended is [Killed] as well, with a
      [statusReason] that names the signal.
    - A mutant whose test run timed out is [Timeout]. The viewer counts
      a mutant of that status as caught.
    - A mutant that let the test suite pass is [Survived].

    A place that [[@mutaml.skip "reason"]] took out of the run is a
    mutant of the status [Ignored], with the reason in [statusReason]
    and the operator name [skip]. The viewer leaves a mutant of that
    status out of every count, so a skipped place is outside the score.
    The preprocessor made no mutation in such a place, so the operator
    name says only that the place was skipped; the operators that the
    place would have had are in [description]. *)

val render :
  fail_under:float option ->
  sources:(string * string) list ->
  results:Mutaml_common.test_result list ->
  skipped:Mutaml_common.skipped list ->
  string
(** [render ~fail_under ~sources ~results] is the JSON report of
    [results].

    [fail_under] is the lowest score that the run may have, as the
    option [--fail-under] gives it, and [None] when the option is not
    given. It becomes the low threshold of the report, which decides
    the colour that the viewer paints the score. The schema asks for a
    whole number there, so a value with a fraction loses it: 99.9
    becomes 99. A report without the option has a low threshold of 0.
    The high threshold is always 100.

    [sources] pairs the name of a source file with the whole text of
    that file, as the bytes on disk. The schema asks for the text of
    every file that holds a mutant, so that the viewer can show the
    mutant in its place. A file that [sources] does not name gets an
    empty text, and so does a file whose text no longer holds every
    mutant of it where the run recorded it. The viewer then shows the
    mutants of that file without their surroundings, which is the
    truth, rather than over text that the mutants never touched.

    [skipped] holds the places that the preprocessor took out of the
    run. A file that holds a skipped place is in the report even when
    no mutant of it ran.

    The result ends with a newline. When [results] and [skipped] are
    both empty the report holds no file. *)
