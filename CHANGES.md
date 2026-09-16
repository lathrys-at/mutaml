Next release
------------

- Add the attribute `[@mutaml.skip "reason"]`, which marks a place that
  the preprocessor must not mutate. It goes on an expression, on a
  `let` binding, on a module, on an `open` and on an `include`. The
  reason is a string and it is not optional: an attribute without one
  stops the build with a message that names the file and the line, and
  so does an attribute in any other place, which would otherwise pass
  unread and leave the place mutated. A
  marked place is outside the mutation score, and it moves the name of
  no other mutation of the file. The terminal report and the Markdown
  summary name each place, its reason, and the mutation operators that
  the attribute takes out of it; the JSON report gives it the status
  `Ignored` with the reason in `statusReason`. A project in which the
  attribute marks every place that mutaml can mutate has no mutation
  and no score: the runner runs no test and says why, and the report
  gives the places and lets the run through
- Write each `lib.muts` file as a JSON object with the fields `mutants`
  and `skipped`, in place of a JSON list of mutations, and
  `mutaml-report.json` as a JSON object with the fields `results` and
  `skipped`, in place of a JSON list of test results. A file of the
  older shape is refused with a message that says to build, or to run
  `mutaml-runner`, again
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
- Say in `mutaml-runner`, when a `lib.muts` file holds a mutation of the
  shape that an older mutaml wrote, that the mutation has not the fields
  this release reads and that a new build with `--instrument-with
  mutaml` writes them
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
- Add `-j <count>` and `MUTAML_JOBS` to `mutaml-runner`, which test
  `<count>` mutations at one time. Each worker writes to the output file
  of the mutation it holds and has `TMPDIR` set to a directory of its
  own, and the results keep the order of the mutations, so the printed
  lines and the report do not depend on which run ends first. The runner
  refuses more than one at a time for a test command that starts with
  `dune`, which locks the build directory
- Add `--repeat <count>` to `mutaml-runner`, which runs the test command
  for one mutation until a run kills it, up to `<count>` runs. The value
  that `--test-env` gives may hold the two characters `{}`, which the
  runner replaces by the number of the run, so `--repeat 3 --test-env
  QCHECK_SEED={}` gives one mutation the seeds 1, 2 and 3. A test suite
  that draws random values then reports a mutation as a survivor only
  when every seed passes, and the report names the seed that killed a
  mutation
- Run each test in a process that `mutaml-runner` starts itself, and
  stop a run that takes too long in `mutaml-runner` itself, in place of
  the `timeout` command. The tool needs no `timeout` command on `PATH`,
  and macOS needs no GNU coreutils for it. Each run leads a process
  group, so a run that is stopped takes with it the programs that it
  started
- Take the limit of a test run from the run without a mutation, when
  `--timeout` gives no limit: five times that run, and never less than
  10 seconds, in place of the fixed 20 seconds. The run without a
  mutation may itself take 300 seconds
- Print the limit of a test run, as the rule that gives it, after the
  runs without a mutation
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
- Write the `diff` of a mutation in `mutaml-report` itself, in the
  unified format, instead of running the `diff` command of the system.
  The text is now the same on every machine, the package no longer
  depends on `conf-diffutils`, and the environment variable
  `MUTAML_DIFF_COMMAND` is gone
- Give the two runs without a mutation the numbers 1 and 2, so that a
  value of `--test-env` that holds `{}` gives them two seeds. The
  runner tests without a mutation a second time when the second run
  would not be the first run over again, which is when `--baseline-env`
  changes a value or when a value holds `{}`. `--baseline-env` is now
  needed only for a value that is not the number of the run
- Make every directory that `mutaml-runner` needs in one function, with
  `Sys.mkdir`, in place of a call to the shell command `mkdir -p` and a
  second copy of the same work. The runner no longer needs a shell to
  make a directory, and it names the directory and the reason when it
  cannot make one
- Add `--changed-since <rev>` to `mutaml-runner`, which tests only the
  mutations that sit on a line that the project changed since the
  revision `<rev>`. It asks `git diff --unified=0 <rev> --` for the
  lines, and it counts every line of a file that git does not track as
  changed. Every other mutation is recorded as not run, which is a new
  outcome that the three reports name and that the mutation score leaves
  out. When no mutation is left, the runner says so, runs no test at
  all, and `mutaml-report` says that the run has no score instead of
  printing a clean score over nothing
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
