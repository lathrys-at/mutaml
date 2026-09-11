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
   These files are written to `dune`'s current build context.


3. Start `mutaml-runner`, passing the name of the test executable to run:
   ```
   $ mutaml-runner _build/default/test/mytests.exe
   ```
   This reads from the files written in step 2. Running the command also
   creates/overwrites the file `mutaml-report.json`.
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


Steps 3 and 4 output a number of additional files.
These are all written to a dedicated directory named `_mutations`.



Mutation Operators
------------------

A mutation operator is a rule that makes one kind of small change to
the program. Each operator has a name that does not change, such as
`compare-boundary`. Mutaml keeps a mutant only when it is sure the
mutant still typechecks, which it must decide without types, so each
operator below is safe for a reason of shape alone.

The operators that this table marks "always on" have no switch. Each
of the others has one command-line option and one environment
variable: the option is the name of the operator with a hyphen in
front of it, and the variable is the name in capitals after `MUTAML_`,
with each hyphen changed to an underscore. So `compare-boundary` reads
`-compare-boundary false` in a `dune` file, or
`MUTAML_COMPARE_BOUNDARY=false` in the environment.

| operator | change | default |
|---|---|---|
| `bool-constant` | `true` to `false`, and the reverse | always on |
| `int-constant` | `1` to `0`; any other integer `i` to `i+1` | always on |
| `space-string` | `" "` to `""` | always on |
| `arith-operator` | `+` to `-`, `-` to `+`, `*` to `+`, `/` to `mod`, `mod` to `/` | always on |
| `arith-identity` | `1 + e`, `e + 1` and `e - 1` to `e` | always on |
| `if-condition` | the condition of an `if` is negated | always on |
| `sequence` | in `e0; e1`, the expression `e0` becomes `()` | always on |
| `omit-case` | a case of a pattern match fires never | always on |
| `merge-cases` | two neighbouring cases become one or-pattern | always on |
| `compare-boundary` | `<` to `<=`, `<=` to `<`, `>` to `>=`, `>=` to `>` | on |
| `compare-negation` | `=` to `<>`, `<>` to `=` | on |
| `equal-function` | `String.equal a b` to `not (String.equal a b)` | on |
| `connective` | `&&` to `\|\|`, `\|\|` to `&&` | on |
| `not-expression` | `not e` to `e` | on |
| `some-to-none` | `Some e` to `None` | on |
| `argument-off-by-one` | an integer argument, or an integer result, gains one or loses one | on |
| `guard-always-true` | the `when` guard of a match case always holds | off |
| `string-literal` | any string literal to `""`, and `""` to `" "` | off |

Two of them are off by default because they make many mutants that no
test suite can kill. A guard that always holds often lets a case do
what a later case already does. Most string literals of a program are
messages that no test reads. Turn each on when your tests do read what
it changes.

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

Each mutation operator that has a switch adds one more variable and
one more option, both named after the operator. The table under
[Mutation Operators](#mutation-operators) above lists them. For
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
files in the default build context `_build/default`. This can be
configured via an environment variable or a command-line option, e.g.,
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

- The output files to `_build/default` are not registered with `dune`.
  This means rerunning steps 2,3,4 above will fail, as the additional
  output files in `_build/default` are not cached by `dune` and hence
  deleted. Again `dune clean` is a crude but effective work-around.

- ...


Mutations should not introduce compiler errors, be it type errors or
from the pattern-match compiler. If you encounter a situation where
this happens please report it in an issue.


Acknowledgements
----------------

Mutaml was developed with support from the [OCaml Software Foundation](https://ocaml-sf.org/).
While developing it, I also benefitted from studying the source code
of [bisect_ppx](https://github.com/aantron/bisect_ppx).
