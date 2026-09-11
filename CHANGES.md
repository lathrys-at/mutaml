Next release
------------

- Name a mutation by its file, the top-level binding that holds it, the
  mutation operator, a digest of the text it changes, and an ordinal,
  instead of by its file and a counter. The name holds no line number,
  so a function added above a mutation no longer renames it, and a list
  of names that a project keeps goes on naming the same code. The name
  is what `MUTAML_MUTANT` takes and what the JSON report gives as `id`
- Record in each `lib.muts` file the mutation operator that made each
  mutation, the top-level binding it sits in, and the text it replaces
- Add `--json-report <path>` to `mutaml-report`, which writes the run in
  the mutation-testing-elements format that Stryker, Infection and Mull
  share, so that the HTML viewer of that format can show it
- Add `--markdown <path>` to `mutaml-report`, which writes a summary for
  the page of a CI job: the mutation score, a table with a row for each
  source file, and every mutation that the test suite did not catch,
  with its name and its diff
- Say in `mutaml-report`, when a report file holds a test result of the
  shape that an older mutaml wrote, that the result has not the fields
  this release reads, instead of saying that the file is not JSON
- Give one line that names the source file, in `mutaml-report`, when the
  source of a mutation that the test suite did not catch is no longer in
  the project, and when that file changed so that the place the mutation
  sits in is outside it. Each of the two ended the tool with an uncaught
  exception and no score before
- Support ppxlib.0.36 and above, where one parse tree constructor holds
  both `fun` and `function`
- Write the preprocessor's `lib.muts` files and `mutaml-mut-files.txt`
  beside the build context, in `_build/.mutaml/<context>`, so that
  `dune`'s preprocessor sandbox and its cleaning of the build directory
  no longer delete them #16 #18 #31 #34 #42
- Name in `mutaml-mut-files.txt` every `lib.muts` file that is present,
  each of them once, so that a second build no longer makes the runner
  test every mutation twice and an incremental build no longer drops the
  mutations of the files it did not rebuild
- Run the test command with no mutation before testing any mutation, and
  stop when it fails
- Add `--baseline-env NAME=VALUE` to `mutaml-runner`, repeatable, which
  runs the test command a second time with no mutation and those
  variables set, and stops when the two runs do not agree
- Skip in `mutaml-runner` a `lib.muts` file whose source file `lib.ml`
  is not in the project, and say so
- Add `--test-env NAME=VALUE` to `mutaml-runner`, repeatable, and write
  the variables it set beside every result in `mutaml-report.json`
- Add `--timeout <seconds>` and `MUTAML_TIMEOUT` to `mutaml-runner`,
  and report a test run that a signal ended as a crash and not as a
  timeout #32
- Name a mutation and its output file after the source file that the
  mutation belongs to, so that a `--muts` path that starts at the root
  of the file system no longer reports every mutation as passing
- Exit with 2 from `mutaml-report` when the mutation score is too low,
  keeping 1 for a fault of the tool itself, and add
  `--fail-under <percent>` to accept a lower score
- Print the mutation score in `mutaml-report`, counting a mutation that
  timed out with the mutations that failed
- Add mutation operators for the comparisons `<`, `<=`, `>` and `>=`,
  for the equality tests `=` and `<>`, for the `equal` function of the
  modules of the standard library, for the Boolean connectives `&&`
  and `||`, for `not e`, for `Some e`, and for the integer arguments of
  a known list of functions
- Add two mutation operators that are off by default: a `when` guard
  made always true, and any string literal made empty
- Name every mutation operator, and give every operator, the ones
  upstream already had as well as the new ones, a command-line option
  and an environment variable that turn it off. Every operator that
  was on before is still on by default, so a project that sets nothing
  sees no change
- List every mutation operator in the README, with its default and
  what it cannot see
- Use dune.3.18 support to generate `x-maintenance-intent` entry
- Patch `ppx_yojson_conv` dependency which was missing a `v`-prefix
- Introduce a `mutaml.opam.template` to avoid opam linting failure #41
- Adjust RE to support `runtest` on OpenBSD too #40
- Remove `which` and `conf-which` dependency #39
- Support ppxlib.0.34 and runtest on OCaml 5.3 #36

0.3
---

- Avoid mutations in attribute parameters #29
- Avoid polymorphic equality which is incompatible with Core #30

0.2
---

- Add support for ppxlib.0.28 and above #27
- Avoid triggering 2 mutations of a pattern incl. a when-clause
  causing a redundant sub-pattern warning #22, #23

0.1
---

- Initial opam release of `mutaml`
