The preprocessor passes the mutations to the runner through files that
the compiler never reads: one `.muts` file for each instrumented source
file, and one list naming them. Dune knows about neither file. This test
pins where they go and how long they last.

Use a dune language version that runs the preprocessor in a sandbox
directory and then deletes it. Nothing below sets an environment
variable to say where the files should go.

  $ cat > dune-project << EOF
  > (lang dune 3.16)
  > EOF

  $ mkdir -p lib1 lib2

  $ cat > lib1/dune <<EOF
  > (library
  >  (name lib1)
  >  (instrumentation (backend mutaml)))
  > EOF

  $ cat > lib2/dune <<EOF
  > (library
  >  (name lib2)
  >  (instrumentation (backend mutaml)))
  > EOF

  $ cat > lib1/lib1.ml <<EOF
  > let add x = x + 1
  > EOF

  $ cat > lib2/lib2.ml <<EOF
  > let double x = x * 2
  > EOF

  $ export MUTAML_SEED=896745231
  $ export MUTAML_MUT_RATE=100

Dune instruments the two files in whatever order it likes, so sort
every listing below.

  $ dune build @all --instrument-with mutaml 2>&1 | grep Created | sort
  Created 1 mutation of lib1/lib1.ml
  Created 2 mutations of lib2/lib2.ml

The files are beside the build context directory:

  $ ls _build/.mutaml/default
  lib1
  lib2
  mutaml-build-id.txt
  mutaml-mut-files.lock
  mutaml-mut-files.txt
  $ ls _build/.mutaml/default/lib1
  lib1.muts
  $ ls _build/.mutaml/default/lib2
  lib2.muts
  $ sort _build/.mutaml/default/mutaml-mut-files.txt
  lib1/lib1.muts
  lib2/lib2.muts

They are not in the build context directory, because dune deletes from
it every file it does not know about:

  $ test -e _build/default/lib1/lib1.muts && echo found || echo none
  none
  $ test -e _build/default/mutaml-mut-files.txt && echo found || echo none
  none

A second dune command must not take the files away. A project whose
tests need data files needs two commands in a row: one to build, and one
to put the data files in place.

  $ dune build @all --instrument-with mutaml
  $ sort _build/.mutaml/default/mutaml-mut-files.txt
  lib1/lib1.muts
  lib2/lib2.muts

A source change makes the preprocessor run again for that file. The list
must not then name the file twice. Dune does not run the preprocessor
again for the file that did not change, so the list names the changed
file alone, and the runner would test the mutations of that file alone.

  $ cat > lib1/lib1.ml <<EOF
  > let add x = x + 2
  > EOF

  $ dune build @all --instrument-with mutaml 2>&1 | grep Created | sort
  Created 2 mutations of lib1/lib1.ml
  $ sort _build/.mutaml/default/mutaml-mut-files.txt
  lib1/lib1.muts

Building every instrumented file in one command lists them all again:

  $ dune clean
  $ dune build @all --instrument-with mutaml 2>&1 | grep Created | sort
  Created 2 mutations of lib1/lib1.ml
  Created 2 mutations of lib2/lib2.ml
  $ sort _build/.mutaml/default/mutaml-mut-files.txt
  lib1/lib1.muts
  lib2/lib2.muts

`dune clean` takes the files away with the rest of the build:

  $ dune clean
  $ test -d _build && echo found || echo none
  none

MUTAML_PPX_OUT_DIR puts the files somewhere else. Set it when another
build system runs the preprocessor, or to choose the place yourself.

  $ export MUTAML_PPX_OUT_DIR="$PWD/chosen-place"
  $ dune build @all --instrument-with mutaml 2>&1 | grep Created | sort
  Created 2 mutations of lib1/lib1.ml
  Created 2 mutations of lib2/lib2.ml
  $ sort chosen-place/mutaml-mut-files.txt
  lib1/lib1.muts
  lib2/lib2.muts
  $ ls chosen-place/lib1
  lib1.muts
  $ test -d _build/.mutaml && echo found || echo none
  none

A relative MUTAML_PPX_OUT_DIR is taken from the root of the project. It
cannot be taken from the directory the preprocessor runs in, because
under dune that is the sandbox directory that dune deletes.

  $ dune clean
  $ export MUTAML_PPX_OUT_DIR=chosen-relative
  $ dune build @all --instrument-with mutaml 2>&1 | grep Created | sort
  Created 2 mutations of lib1/lib1.ml
  Created 2 mutations of lib2/lib2.ml
  $ sort chosen-relative/mutaml-mut-files.txt
  lib1/lib1.muts
  lib2/lib2.muts
  $ ls chosen-relative/lib2
  lib2.muts
