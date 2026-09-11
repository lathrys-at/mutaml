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
   `mutaml-report` prints the mutation score and exits with 2 when the
   score is too low, so it can decide a build.
   It can also write the report to a file, as a Markdown summary for
   the page of a CI job or in the mutation-testing-elements format that
   a viewer of that format reads. See "Report Options and Environment
   Variables" below.


Steps 3 and 4 output a number of additional files.
These are all written to a dedicated directory named `_mutations`.



Mutation Operators
------------------

A mutation operator is a rule that makes one kind of small change to
the program. Each operator has a name that does not change, such as
`compare-boundary`. Mutaml keeps a mutant only when it is sure the
mutant still typechecks, which it must decide without types, so each
operator below is safe for a reason of shape alone.

Every operator has a switch that turns it on or off, and the name of
the operator gives the name of the switch. The command-line option is
the name with a hyphen in front of it; the environment variable is the
name in capitals after `MUTAML_`, with each hyphen changed to an
underscore. So `compare-boundary` reads `-compare-boundary false` in a
`dune` file, or `MUTAML_COMPARE_BOUNDARY=false` in the environment.
The table gives both for each operator.

| operator | change | default | option | variable |
|---|---|---|---|---|
| `bool-constant` | `true` to `false`, and the reverse | on | `-bool-constant` | `MUTAML_BOOL_CONSTANT` |
| `int-constant` | `1` to `0`; any other integer `i` to `i+1` | on | `-int-constant` | `MUTAML_INT_CONSTANT` |
| `space-string` | `" "` to `""` | on | `-space-string` | `MUTAML_SPACE_STRING` |
| `arith-operator` | `+` to `-`, `-` to `+`, `*` to `+`, `/` to `mod`, `mod` to `/` | on | `-arith-operator` | `MUTAML_ARITH_OPERATOR` |
| `arith-identity` | `1 + e`, `e + 1` and `e - 1` to `e` | on | `-arith-identity` | `MUTAML_ARITH_IDENTITY` |
| `if-condition` | the condition of an `if` is negated | on | `-if-condition` | `MUTAML_IF_CONDITION` |
| `sequence` | in `e0; e1`, the expression `e0` becomes `()` | on | `-sequence` | `MUTAML_SEQUENCE` |
| `omit-case` | a case of a pattern match fires never | on | `-omit-case` | `MUTAML_OMIT_CASE` |
| `merge-cases` | two neighbouring cases become one or-pattern | on | `-merge-cases` | `MUTAML_MERGE_CASES` |
| `compare-boundary` | `<` to `<=`, `<=` to `<`, `>` to `>=`, `>=` to `>` | on | `-compare-boundary` | `MUTAML_COMPARE_BOUNDARY` |
| `compare-negation` | `=` to `<>`, `<>` to `=` | on | `-compare-negation` | `MUTAML_COMPARE_NEGATION` |
| `equal-function` | `String.equal a b` to `not (String.equal a b)` | on | `-equal-function` | `MUTAML_EQUAL_FUNCTION` |
| `connective` | `&&` to `\|\|`, `\|\|` to `&&` | on | `-connective` | `MUTAML_CONNECTIVE` |
| `not-expression` | `not e` to `e` | on | `-not-expression` | `MUTAML_NOT_EXPRESSION` |
| `some-to-none` | `Some e` to `None` | on | `-some-to-none` | `MUTAML_SOME_TO_NONE` |
| `argument-off-by-one` | an integer argument, or an integer result, gains one or loses one | on | `-argument-off-by-one` | `MUTAML_ARGUMENT_OFF_BY_ONE` |
| `guard-always-true` | the `when` guard of a match case always holds | off | `-guard-always-true` | `MUTAML_GUARD_ALWAYS_TRUE` |
| `string-literal` | any string literal to `""`, and `""` to `" "` | off | `-string-literal` | `MUTAML_STRING_LITERAL` |

Two of them are off by default because they make many mutants that no
test suite can kill. A guard that always holds often lets a case do
what a later case already does. Most string literals of a program are
messages that no test reads. Turn each on when your tests do read what
it changes.

Turning an operator off does not stop the preprocessor looking inside
the expression: `n + 1` with both `arith-identity` and `arith-operator`
off still gives the literal `1` the mutant of `int-constant`.

Two of the operators work on the same expressions, so it is worth
saying how they meet. `arith-identity` takes `1 + e`, `e + 1` and
`e - 1` and gives back `e`. While it is on, those three shapes are its
own and `arith-operator` does not touch them. Turn `arith-identity`
off and `arith-operator` takes them instead, turning the `+` into a
`-`.

### What each operator cannot see

The preprocessor works on the text of the program, and it has no
types. Four operators therefore rest on a rule of shape that a program
can break. Each names its switch, so that a program that breaks the
rule can turn the operator off.

- **`some-to-none`.** `Some e` and `None` both have type `'a option`,
  so the mutant compiles. A program that defines its own constructor
  named `Some`, in a type that has no `None`, breaks this. The build
  then fails at the file that holds the type, in one of two ways.
  Either the compiler reports a type that does not match, naming your
  type and `option`; or, where the compiler can read `Some e` as the
  `Some` of `option`, it reports that a later pattern match is not
  exhaustive:

  ```
  Error (warning 8 [partial-match]): this pattern-matching is not exhaustive.
    Here is an example of a case that is not matched: None
  ```

  Neither message names this operator, because the failure lands in
  your code and not in what the preprocessor wrote. If you see either
  of them in a build that only mutaml changed, set
  `MUTAML_SOME_TO_NONE=false`, or `-some-to-none false` in your `dune`
  file, and build again.

- **`argument-off-by-one`.** The preprocessor cannot see that an
  argument has type `int`, so it holds a list of the functions of the
  standard library whose arguments it knows: `String.sub`,
  `String.get`, `Bytes.sub`, `Bytes.get` and `List.nth`, and
  `String.length`, whose result is an integer. A program with its own
  module named `String`, holding its own `sub` of another type, breaks
  this. Set `MUTAML_ARGUMENT_OFF_BY_ONE=false`.

- **`equal-function`.** The same, for the `equal` function of a fixed
  list of modules of the standard library: `Bool`, `Bytes`, `Char`,
  `Float`, `Int`, `Int32`, `Int64`, `Nativeint`, `String` and `Unit`,
  with or without a `Stdlib` in front. The `equal` of any other module
  is left alone, because the preprocessor cannot see that it returns a
  Boolean, and `not` of anything else does not typecheck. A program
  with its own module named `String` breaks the rule. Set
  `MUTAML_EQUAL_FUNCTION=false`.

- **`connective` and `not-expression`.** These read `&&`, `||` and
  `not` as the standard library defines them: two Boolean values in,
  one Boolean value out. A program that gives one of the three another
  meaning, and does not give its partner the same meaning, breaks the
  rule, and the mutant does not compile. Set
  `MUTAML_CONNECTIVE=false` or `MUTAML_NOT_EXPRESSION=false`.

- **`compare-boundary` and `compare-negation`.** These read the
  operator as it is written. `x < y` is mutated; `Int.( < ) x y`,
  written with a module in front of the operator, is not. Swapping a
  qualified operator is not safe, because a module that exports `=`
  need not export `<`. A module brought in with `open` usually shadows
  the whole family at once, as `Base` does, and there the swap stays
  safe, so the operators do mutate code written that way. A module
  that shadows only part of the family breaks the rule: one that
  defines `=` and no `<>`, or `<` and no `<=`, gives a mutant that
  does not compile. Set `MUTAML_COMPARE_NEGATION=false` or
  `MUTAML_COMPARE_BOUNDARY=false` for such a file.

- **`string-literal`.** A string literal that stands where a format is
  wanted does not have type `string`, and `""` does not typecheck
  there. The operator therefore leaves alone any literal that holds a
  `%`. A format literal with no conversion in it, such as
  `Printf.sprintf "plain"`, does typecheck as `""`, so the rule keeps
  the mutants that are worth having. Set `MUTAML_STRING_LITERAL=false`
  if a format of yours holds no `%` and still cannot be empty.


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

Each mutation operator adds one more variable and one more option,
both named after the operator, and the table under
[Mutation Operators](#mutation-operators) above lists all of them. For
example, `MUTAML_SOME_TO_NONE=false`, or the instrumentation option
`-some-to-none false`, turns off the operator that changes `Some e`
into `None`.


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

### Report files

`mutaml-report` prints its report to the terminal. Two options write
the report to a file as well. You may give both in one run.

- `--markdown path` - write a Markdown summary to `path`. The summary
  holds the mutation score, a table with one row for each source file
  and one row for the total, and every mutation that the test suite did
  not catch, with its name, its place in the file, and its diff.
  GitHub Actions shows the Markdown of the file that its variable
  `GITHUB_STEP_SUMMARY` names on the page of the job, so this step puts
  the summary there:
  ```
  - run: mutaml-report --markdown "$GITHUB_STEP_SUMMARY"
  ```
- `--json-report path` - write the report to `path` in the
  mutation-testing-elements format. [Stryker](https://stryker-mutator.io/),
  [Infection](https://infection.github.io/) and
  [Mull](https://mull.readthedocs.io/) write the same format, and the
  HTML viewer
  [mutation-test-report-app](https://github.com/stryker-mutator/mutation-testing-elements)
  reads it.

The table of the Markdown summary counts the four outcomes apart, so
its columns add up to the number of mutations of the file. The score
counts a mutation that timed out and a mutation that a signal ended
with the mutations that failed.

The JSON report gives every mutation one of the statuses of the format:

| outcome of the test run | status | note |
|---|---|---|
| a test failed | `Killed` | |
| the run took too long | `Timeout` | the viewer counts it as caught |
| a signal ended the run | `Killed` | `statusReason` names the signal |
| the test suite passed | `Survived` | |

In the JSON report, the `id` of a mutation is its name, the same string
that `MUTAML_MUTANT` takes, and `mutatorName` is the name of the
mutation operator that made it. `thresholds.low` is the value of
`--fail-under`, or 0 when you do not give that option, and
`thresholds.high` is 100.

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
