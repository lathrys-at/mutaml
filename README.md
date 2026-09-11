Mutaml: A Mutation Tester for OCaml [![Main CI workflow](https://github.com/jmid/mutaml/actions/workflows/ci.yml/badge.svg)](https://github.com/jmid/mutaml/actions/workflows/ci.yml)
===============================================

Mutaml is a mutation testing tool for OCaml.  
Briefly, that means Mutaml tries to change your code randomly to see
if the changes are caught by your tests.

![](demo.gif)

In more detail: [Mutation testing](https://en.wikipedia.org/wiki/Mutation_testing) is
a form of fault injection used to assess the quality of a program's
test suite. Mutation testing works by repeatedly making small, breaking
changes to a program's text, such as turning a `+` into `-`, negating
the condition of an `if-then-else`, ..., and subsequently rerunning
the test suite to see if each such 'mutant program' is 'killed'
(caught) by one or more tests in the test suite. By finding examples of
uncaught wrong behaviour, mutation testing can thereby reveal
limitations of an existing test suite and indirectly suggest
improvements.

Since OCaml already prevents many potential programming errors at compile
time due to its strong type system, pattern-match compiler warnings, etc. Mutaml
favors mutations that
- preserve typing and
- would not be caught statically, e.g., changes in the values computed.

Mutaml consists of:

 - a [`ppxlib`](https://github.com/ocaml-ppx/ppxlib)-preprocessor that
   first transforms the program under test.
 - `mutaml-runner` that loops through a range of possible program mutations,
   and saves the output from running the test suite on each of the mutants
 - `mutaml-report` that prints a test report to the console.


Installation:
-------------

You can install `mutaml` with a single `opam` command:

```
$ opam install mutaml

```

Alternatively, you can also install it from a clone of the repository:

```
$ git clone https://github.com/jmid/mutaml.git
$ cd mutaml
$ opam install .
```


Instructions:
-------------

How you can use `mutaml` depends on your project's build setup.
For now it has only been tested with `dune`, but it should work
with other build systems supporting an explicit two-staged build
process.


### Using Mutaml with `dune`

1. Mark the target code for instrumentation in your `dune` file(s):
   ```
   (library
     (public_name your_library)
     (instrumentation (backend mutaml)))
   ```
   Using `dune`'s [`instrumentation` stanza](https://dune.readthedocs.io/en/stable/instrumentation.html), your project's code is
   only instrumented when you pass the `--instrument-with mutaml`
   option.


2. Compile your test code with `mutaml` instrumentation enabled:
   ```
   $ dune build test --instrument-with mutaml
   ```
   assuming you have a `test/mytests.ml` test driver.
   This creates/overwrites an individual `lib.muts` file for each
   instrumented `lib.ml` file and an overview file
   `mutaml-mut-files.txt` listing them.
   These files are written *beside* `dune`'s current build context, in
   `_build/.mutaml/default` for an ordinary project, or in
   `_build/.mutaml/mutation` for a build context named `mutation`.
   They go beside the build context and not in it because `dune`
   removes from a build context directory every file it does not know
   about, and it knows about neither of these.
   `dune` names its build context in the environment variable
   `INSIDE_DUNE`, which is how the preprocessor finds the place without
   being told. That variable is not part of `dune`'s documented
   interface. A `dune` that stopped setting it would make the
   preprocessor write to its working directory, and `mutaml-runner`
   would then say that it cannot read `mutaml-mut-files.txt`.
   `dune clean` removes the whole `_build` directory, and with it every
   `lib.muts` file and the overview file.
   The overview file names every `lib.muts` file that is present. `dune`
   runs the preprocessor again only for a source file that changed, and
   the `lib.muts` file of a file that did not change still describes the
   program that was built, so a build that changes one file of several
   leaves all of them listed. A name leaves the overview file when its
   `lib.muts` file is no longer there. After `dune clean` the overview
   file is gone too, so the next build starts the list from nothing.


3. Start `mutaml-runner`, passing the name of the test executable to run:
   ```
   $ mutaml-runner _build/default/test/mytests.exe
   ```
   This reads from the files written in step 2. Running the command also
   creates/overwrites the file `mutaml-report.json`.
   Before it tests any mutation, `mutaml-runner` runs the test command
   twice with no mutation. A test suite that fails with no mutation
   makes every mutation look killed, and a test suite that answers
   differently in the two runs makes the score meaningless, so the
   runner stops with an error in both cases.
   You can also pass a command that runs the executable through `dune`
   if you prefer:
   ```
   $ mutaml-runner "dune exec --no-build test/mytests.exe"
   ```

4. Generate a report, optionally passing the json-file
   (`mutaml-report.json`) created above:
   ```
   $ mutaml-report
   ```
   By default this prints `diff`s for each mutation that flew under
   the radar of your test suite. The `diff` output can be suppressed by
   passing `--no-diff`.
   `mutaml-report` prints the mutation score and exits with 1 when the
   score is too low, so it can decide a build.


Steps 3 and 4 output a number of additional files.
These are all written to a dedicated directory named `_mutations`.



Instrumentation Options and Environment Variables
-------------------------------------------------

The preprocessor's behaviour can be configured through either
environment variables or instrumentation options in the `dune` file:

- `MUTAML_SEED` - an integer value to seed `mutaml-ppx`'s randomized
  mutations (overridden by instrumentation option `-seed`)
- `MUTAML_MUT_RATE` - a integer between 0 and 100 to specify the
  mutation frequency (0 means never and 100 means always - overridden
  by instrumentation option `-mut-rate`)
- `MUTAML_GADT` - allow only pattern mutations compatible with GADTs
  (`true` or `false`, overridden by instrumentation option `-gadt`)
- `MUTAML_PPX_OUT_DIR` - the directory to write `lib.muts` and
  `mutaml-mut-files.txt` into, instead of the one named in step 2
  above. It has no instrumentation option. You do not need it under
  `dune`, which tells the preprocessor where its build context is.
  Set it when another build system runs the preprocessor, or when you
  want the files somewhere of your own choosing. Pass the same
  directory to `mutaml-runner` as its `--build-context`. A relative
  directory is taken from the root of your project, not from the
  directory the preprocessor runs in, which under `dune` is a sandbox
  directory that `dune` deletes.


For example, the following `dune` file sets all three instrumentation
options:
```
 (executable
  (name test)
  (instrumentation (backend mutaml -seed 42 -mut-rate 75 -gadt false))
 )
```
We could achieve the same behaviour by setting three environment
variables:
```bash
  $ export MUTAML_SEED=42
  $ export MUTAML_MUT_RATE=75
  $ export MUTAML_GADT=false
```
If you do both, the values passed as instrumentation options in the
`dune` file take precedence.


Runner Options and Environment Variables
----------------------------------------

By default, `mutaml-runner` expects to find the preprocessor's output
files beside the default build context `_build/default`, that is, in
`_build/.mutaml/default`. You name the build context itself, and the
runner looks beside it. This can be configured via an environment
variable or a command-line option, e.g.,
if [instrumentation is enabled via another `dune-workspace` build context](https://dune.readthedocs.io/en/stable/instrumentation.html#enabling-disabling-instrumentation):

- `MUTAML_BUILD_CONTEXT` - a path prefix string (overridden by
  command-line option `--build-context`)

`mutaml-runner` also repeats test suite runs for all instrumented
`lib.ml` files by default. An option `--muts muts-file` is available
to enable more targeted mutation testing. Running, e.g.,
```
mutaml-runner --muts lib/lib2.muts _build/default/test/mytests.exe
```
will only consider mutations of the corresponding library
`lib/lib2.ml`, which the runner searches for in the build context.

The other options of `mutaml-runner` are:

- `--timeout seconds` - the time that one test run may take. The
  default is 20 seconds. A run that takes longer is stopped and counted
  as a timeout. The environment variable `MUTAML_TIMEOUT` sets the same
  value, and the command-line option takes precedence over it.

- `--test-env NAME=VALUE` - set `NAME` to `VALUE` in every test
  process. Repeat the option for each variable you want to set. Use it
  to fix the seed of a test suite that draws random values, for example
  `--test-env QCHECK_SEED=1234`, so that the whole run repeats exactly.
  `mutaml-runner` writes the variables it set beside every result in
  `mutaml-report.json`, so the result of a killed mutation names the
  environment that killed it.

- `--baseline-env NAME=VALUE` - run the test suite a second time with no
  mutation, with `NAME` set to `VALUE` on top of what `--test-env` sets.
  Repeat the option for each variable you want to change. Use it to run
  the second time with another seed, for example `--test-env
  QCHECK_SEED=1 --baseline-env QCHECK_SEED=2`. A test suite that passes
  under one seed and fails under another does not give a mutation score
  any meaning, and this is how to find that out before the run.

`mutaml-runner` runs the test command with no mutation before it tests
any mutation, and again a second time when `--baseline-env` is given. It
stops with an error when a run fails, because every mutation would then
look killed, and when the two runs do not agree. It writes the output of
the runs to `_mutations/baseline-1.output` and, when there is a second
run, `_mutations/baseline-2.output`.

`mutaml-runner` skips a `lib.muts` file whose source file `lib.ml` is
not in the project, and says on one line that it did. `dune` runs the
preprocessor again only for a source file that changed, so the list of
`.muts` files can name a file you have since deleted or renamed.

`mutaml-runner` runs every test through the `timeout` command, which
must be on `PATH`. It reads the exit status of that command to tell
what happened: 124 means that the run took too long, and a status above
128 means that a signal ended the run, which the runner reports as a
crash and not as a timeout. GNU coreutils `timeout` follows those
rules. macOS has no `timeout` command of its own, so install GNU
coreutils there.


Report Options and Environment Variables
----------------------------------------

Currently `mutaml-report` uses `diff --color -u` as its default
command to print `diff`s. It falls back to `diff -u` when the
environment variable `CI` is `true`. The used command can also be
configured with an environment variable:

- `MUTAML_DIFF_COMMAND` - the command and options to use instead,
  e.g. `MUTAML_DIFF_COMMAND="diff -U 5"` will disable colored outputs
  and add 5 lines of unified context. Mutaml expects the specified
  command to support `--label` options.

Passing the option `--no-diff` to `mutaml-report` prevents any
mutation `diff`s from being printed.

`mutaml-report` prints the mutation score, and exits with 2 when the
score is below 100 percent. The mutation score is the share of the
mutations that failed or timed out, of all the mutations that ran. A
mutation that timed out counts with the mutations that failed, because
a test run that never ends is a fault that the test suite found.

- `--fail-under percent` - accept a score of `percent` or above.
  `mutaml-report` then exits with 2 only when the score is below the
  number, and a score equal to the number passes. `--fail-under 0`
  accepts every score.

The three exit codes of `mutaml-report` are:

| code | meaning |
|---|---|
| 0 | the score is at or above the limit |
| 2 | the score is below the limit |
| 1 | the tool could not do its work, for example because it could not read its input |

A job that must tell a low score from a broken run reads the code.



Status
------

This is an *alpha* release. There are therefore rough edges:

- Mutaml is designed to avoid repeated recompilation for each
  mutation. It does so by writing files during preprocessing which are
  later read during the `mutaml-runner` testing loop. As a consequence,
  if you attempt to merge steps 2 and 3 above into one step this will not work:
  ```
  $ mutaml-runner "dune test --force --instrument-with mutaml"
  ```
  The preprocessor in this case only writes the relevant files when
  `mutaml-runner` first calls the command, and thus *after* it needs the
  information contained in the files...

- There are [issues to force `dune` to
rebuild](https://github.com/ocaml/dune/issues/4390). This can affect
  Mutaml, e.g., in case just an environment variable changed. `dune
  clean` is a crude but effective work-around to this issue.

- The output files are not registered with `dune`. They are written
  beside the build context to keep `dune` from deleting them, so steps
  2, 3 and 4 above can be run again. A source file that you delete
  without running `dune clean` leaves its `lib.muts` file behind.
  `mutaml-runner` passes over a `lib.muts` file whose source file it
  cannot find, and says which one, so the mutations of a deleted file do
  not enter the score. Run `dune clean` to remove the file itself.

- ...


Mutations should not introduce compiler errors, be it type errors or
from the pattern-match compiler. If you encounter a situation where
this happens please report it in an issue.


Acknowledgements
----------------

Mutaml was developed with support from the [OCaml Software Foundation](https://ocaml-sf.org/).
While developing it, I also benefitted from studying the source code
of [bisect_ppx](https://github.com/aantron/bisect_ppx).
