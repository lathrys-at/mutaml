Next release
------------

- Support ppxlib.0.36 and above, where one parse tree constructor holds
  both `fun` and `function`
- Write the preprocessor's `lib.muts` files and `mutaml-mut-files.txt`
  beside the build context, in `_build/.mutaml/<context>`, so that
  `dune`'s preprocessor sandbox and its cleaning of the build directory
  no longer delete them #16 #18 #31 #34 #42
- Name in `mutaml-mut-files.txt` the files of the current build alone,
  so that a second build no longer makes the runner test every mutation
  twice
- Run the test command twice with no mutation before testing any
  mutation, and stop when a run fails or the two runs do not agree
- Add `--test-env NAME=VALUE` to `mutaml-runner`, repeatable, and write
  the variables it set beside every result in `mutaml-report.json`
- Add `--timeout <seconds>` and `MUTAML_TIMEOUT` to `mutaml-runner`,
  and report a test run that a signal ended as a crash and not as a
  timeout #32
- Name a mutation and its output file after the source file that the
  mutation belongs to, so that a `--muts` path that starts at the root
  of the file system no longer reports every mutation as passing
- Exit with 1 from `mutaml-report` when a mutation passed the test
  suite, and add `--fail-under <percent>` to accept a lower score
- Print the mutation score in `mutaml-report`, counting a mutation that
  timed out with the mutations that failed
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
