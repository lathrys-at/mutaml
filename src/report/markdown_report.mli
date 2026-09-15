(** The Markdown summary of a run.

    [mutaml-report --markdown <path>] writes this text. It holds the
    mutation score, a table with one row for each source file, and the
    mutants that the test suite did not catch, each with its name and
    its diff.

    GitHub Actions shows the Markdown of the file that its variable
    [GITHUB_STEP_SUMMARY] names on the page of the job. *)

val render :
  sources:(string * string) list ->
  results:Mutaml_common.test_result list ->
  string
(** [render ~sources ~results] is the Markdown summary of [results].

    [sources] pairs the name of a source file with the whole text of
    that file, as the bytes on disk. The summary needs those bytes to
    write the diff of a mutant that lived, because the location of a
    mutant counts bytes from the start of the file. A mutant whose file
    is not in [sources], or whose location does not fit the text there,
    gets a line that says why it has no diff.

    The summary assumes that the source files did not change after the
    runner ran, which is the same assumption that the console report
    makes.

    The result ends with a newline. When [results] is empty the result
    is a heading and one line that says there is no result. *)
