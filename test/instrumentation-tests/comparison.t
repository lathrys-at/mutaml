Tests mutation of comparison and equality

  $ bash ../write_dune_files.sh

Set seed and (full) mutation rate as environment variables, for repeatability
  $ export MUTAML_SEED=896745231
  $ export MUTAML_MUT_RATE=100


Test <:

  $ cat > test.ml <<'EOF'
  > let f x y = x < y;;
  > assert (not (f 10 10))
  > EOF

  $ bash ../filter_dune_build.sh ./test.bc --instrument-with mutaml
  Running mutaml instrumentation on "test.ml"
  Randomness seed: 896745231   Mutation rate: 100   GADTs enabled: true
  Created 1 mutation of test.ml
  Writing mutation info to test.muts
  
  let __MUTAML_MUTANT__ = Stdlib.Sys.getenv_opt "MUTAML_MUTANT"
  let __is_mutaml_mutant__ m =
    match __MUTAML_MUTANT__ with
    | None -> false
    | Some mutant -> String.equal m mutant
  let f x y =
    if __is_mutaml_mutant__ "test.ml:f:compare-boundary:ef265273:0"
    then x <= y
    else x < y
  ;;assert (not (f 10 10))

Check that instrumentation hasn't changed the program's behaviour
  $ dune exec --no-build ./test.bc

And that mutation has changed it as expected
  $ MUTAML_MUTANT="test.ml:f:compare-boundary:ef265273:0" dune exec --no-build ./test.bc
  Fatal error: exception Assert_failure("test.ml", 2, 0)
  [2]



Test <=:

  $ cat > test.ml <<'EOF'
  > let f x y = x <= y;;
  > assert (f 10 10)
  > EOF

  $ bash ../filter_dune_build.sh ./test.bc --instrument-with mutaml
  Running mutaml instrumentation on "test.ml"
  Randomness seed: 896745231   Mutation rate: 100   GADTs enabled: true
  Created 1 mutation of test.ml
  Writing mutation info to test.muts
  
  let __MUTAML_MUTANT__ = Stdlib.Sys.getenv_opt "MUTAML_MUTANT"
  let __is_mutaml_mutant__ m =
    match __MUTAML_MUTANT__ with
    | None -> false
    | Some mutant -> String.equal m mutant
  let f x y =
    if __is_mutaml_mutant__ "test.ml:f:compare-boundary:b62bfd0f:0"
    then x < y
    else x <= y
  ;;assert (f 10 10)

  $ dune exec --no-build ./test.bc

  $ MUTAML_MUTANT="test.ml:f:compare-boundary:b62bfd0f:0" dune exec --no-build ./test.bc
  Fatal error: exception Assert_failure("test.ml", 2, 0)
  [2]



Test >:

  $ cat > test.ml <<'EOF'
  > let f x y = x > y;;
  > assert (not (f 10 10))
  > EOF

  $ bash ../filter_dune_build.sh ./test.bc --instrument-with mutaml
  Running mutaml instrumentation on "test.ml"
  Randomness seed: 896745231   Mutation rate: 100   GADTs enabled: true
  Created 1 mutation of test.ml
  Writing mutation info to test.muts
  
  let __MUTAML_MUTANT__ = Stdlib.Sys.getenv_opt "MUTAML_MUTANT"
  let __is_mutaml_mutant__ m =
    match __MUTAML_MUTANT__ with
    | None -> false
    | Some mutant -> String.equal m mutant
  let f x y =
    if __is_mutaml_mutant__ "test.ml:f:compare-boundary:10e5793a:0"
    then x >= y
    else x > y
  ;;assert (not (f 10 10))

  $ dune exec --no-build ./test.bc

  $ MUTAML_MUTANT="test.ml:f:compare-boundary:10e5793a:0" dune exec --no-build ./test.bc
  Fatal error: exception Assert_failure("test.ml", 2, 0)
  [2]



Test >=:

  $ cat > test.ml <<'EOF'
  > let f x y = x >= y;;
  > assert (f 10 10)
  > EOF

  $ bash ../filter_dune_build.sh ./test.bc --instrument-with mutaml
  Running mutaml instrumentation on "test.ml"
  Randomness seed: 896745231   Mutation rate: 100   GADTs enabled: true
  Created 1 mutation of test.ml
  Writing mutation info to test.muts
  
  let __MUTAML_MUTANT__ = Stdlib.Sys.getenv_opt "MUTAML_MUTANT"
  let __is_mutaml_mutant__ m =
    match __MUTAML_MUTANT__ with
    | None -> false
    | Some mutant -> String.equal m mutant
  let f x y =
    if __is_mutaml_mutant__ "test.ml:f:compare-boundary:9e80950a:0"
    then x > y
    else x >= y
  ;;assert (f 10 10)

  $ dune exec --no-build ./test.bc

  $ MUTAML_MUTANT="test.ml:f:compare-boundary:9e80950a:0" dune exec --no-build ./test.bc
  Fatal error: exception Assert_failure("test.ml", 2, 0)
  [2]



Test =:

  $ cat > test.ml <<'EOF'
  > let f x y = x = y;;
  > assert (f 10 10)
  > EOF

  $ bash ../filter_dune_build.sh ./test.bc --instrument-with mutaml
  Running mutaml instrumentation on "test.ml"
  Randomness seed: 896745231   Mutation rate: 100   GADTs enabled: true
  Created 1 mutation of test.ml
  Writing mutation info to test.muts
  
  let __MUTAML_MUTANT__ = Stdlib.Sys.getenv_opt "MUTAML_MUTANT"
  let __is_mutaml_mutant__ m =
    match __MUTAML_MUTANT__ with
    | None -> false
    | Some mutant -> String.equal m mutant
  let f x y =
    if __is_mutaml_mutant__ "test.ml:f:compare-negation:9295ef5b:0"
    then x <> y
    else x = y
  ;;assert (f 10 10)

  $ dune exec --no-build ./test.bc

  $ MUTAML_MUTANT="test.ml:f:compare-negation:9295ef5b:0" dune exec --no-build ./test.bc
  Fatal error: exception Assert_failure("test.ml", 2, 0)
  [2]



Test <>:

  $ cat > test.ml <<'EOF'
  > let f x y = x <> y;;
  > assert (not (f 10 10))
  > EOF

  $ bash ../filter_dune_build.sh ./test.bc --instrument-with mutaml
  Running mutaml instrumentation on "test.ml"
  Randomness seed: 896745231   Mutation rate: 100   GADTs enabled: true
  Created 1 mutation of test.ml
  Writing mutation info to test.muts
  
  let __MUTAML_MUTANT__ = Stdlib.Sys.getenv_opt "MUTAML_MUTANT"
  let __is_mutaml_mutant__ m =
    match __MUTAML_MUTANT__ with
    | None -> false
    | Some mutant -> String.equal m mutant
  let f x y =
    if __is_mutaml_mutant__ "test.ml:f:compare-negation:9b8b387c:0"
    then x = y
    else x <> y
  ;;assert (not (f 10 10))

  $ dune exec --no-build ./test.bc

  $ MUTAML_MUTANT="test.ml:f:compare-negation:9b8b387c:0" dune exec --no-build ./test.bc
  Fatal error: exception Assert_failure("test.ml", 2, 0)
  [2]



The comparisons are polymorphic, so the same mutation applies to strings:

  $ cat > test.ml <<'EOF'
  > let f x y = x < y;;
  > assert (f "a" "b")
  > EOF

  $ bash ../filter_dune_build.sh ./test.bc --instrument-with mutaml
  Running mutaml instrumentation on "test.ml"
  Randomness seed: 896745231   Mutation rate: 100   GADTs enabled: true
  Created 1 mutation of test.ml
  Writing mutation info to test.muts
  
  let __MUTAML_MUTANT__ = Stdlib.Sys.getenv_opt "MUTAML_MUTANT"
  let __is_mutaml_mutant__ m =
    match __MUTAML_MUTANT__ with
    | None -> false
    | Some mutant -> String.equal m mutant
  let f x y =
    if __is_mutaml_mutant__ "test.ml:f:compare-boundary:ef265273:0"
    then x <= y
    else x < y
  ;;assert (f "a" "b")

  $ dune exec --no-build ./test.bc



Test String.equal, which becomes its own negation:

  $ cat > test.ml <<'EOF'
  > let f x y = String.equal x y;;
  > assert (f "a" "a")
  > EOF

  $ bash ../filter_dune_build.sh ./test.bc --instrument-with mutaml
  Running mutaml instrumentation on "test.ml"
  Randomness seed: 896745231   Mutation rate: 100   GADTs enabled: true
  Created 1 mutation of test.ml
  Writing mutation info to test.muts
  
  let __MUTAML_MUTANT__ = Stdlib.Sys.getenv_opt "MUTAML_MUTANT"
  let __is_mutaml_mutant__ m =
    match __MUTAML_MUTANT__ with
    | None -> false
    | Some mutant -> String.equal m mutant
  let f x y =
    let __MUTAML_TMP0__ = String.equal x y in
    if __is_mutaml_mutant__ "test.ml:f:equal-function:ba5c29c9:0"
    then not __MUTAML_TMP0__
    else __MUTAML_TMP0__
  ;;assert (f "a" "a")

  $ dune exec --no-build ./test.bc

  $ MUTAML_MUTANT="test.ml:f:equal-function:ba5c29c9:0" dune exec --no-build ./test.bc
  Fatal error: exception Assert_failure("test.ml", 2, 0)
  [2]



Test Int.equal:

  $ cat > test.ml <<'EOF'
  > let f x y = Int.equal x y;;
  > assert (f 1 1)
  > EOF

  $ bash ../filter_dune_build.sh ./test.bc --instrument-with mutaml
  Running mutaml instrumentation on "test.ml"
  Randomness seed: 896745231   Mutation rate: 100   GADTs enabled: true
  Created 1 mutation of test.ml
  Writing mutation info to test.muts
  
  let __MUTAML_MUTANT__ = Stdlib.Sys.getenv_opt "MUTAML_MUTANT"
  let __is_mutaml_mutant__ m =
    match __MUTAML_MUTANT__ with
    | None -> false
    | Some mutant -> String.equal m mutant
  let f x y =
    let __MUTAML_TMP0__ = Int.equal x y in
    if __is_mutaml_mutant__ "test.ml:f:equal-function:432db085:0"
    then not __MUTAML_TMP0__
    else __MUTAML_TMP0__
  ;;assert (f 1 1)

  $ dune exec --no-build ./test.bc

  $ MUTAML_MUTANT="test.ml:f:equal-function:432db085:0" dune exec --no-build ./test.bc
  Fatal error: exception Assert_failure("test.ml", 2, 0)
  [2]



An equal function of another module is left alone. The preprocessor has
no types, so it cannot see that such a function returns a Boolean, and
a negation of something else does not compile. Only the arithmetic in
the module below is mutated:

  $ cat > test.ml <<'EOF'
  > module M = struct let equal a b = a + b end
  > let f x y = M.equal x y;;
  > assert (f 1 1 = 2)
  > EOF

  $ bash ../filter_dune_build.sh ./test.bc --instrument-with mutaml
  Running mutaml instrumentation on "test.ml"
  Randomness seed: 896745231   Mutation rate: 100   GADTs enabled: true
  Created 1 mutation of test.ml
  Writing mutation info to test.muts
  
  let __MUTAML_MUTANT__ = Stdlib.Sys.getenv_opt "MUTAML_MUTANT"
  let __is_mutaml_mutant__ m =
    match __MUTAML_MUTANT__ with
    | None -> false
    | Some mutant -> String.equal m mutant
  module M =
    struct
      let equal a b =
        if __is_mutaml_mutant__ "test.ml:M.equal:arith-operator:86790c7e:0"
        then a - b
        else a + b
    end
  let f x y = M.equal x y
  ;;assert ((f 1 1) = 2)

  $ dune exec --no-build ./test.bc


Each of the three operators has an option that turns it off. The
instrumentation option in the dune file is one way to set it:

  $ dune clean
  $ cat > dune <<'EOF'
  > (executable
  >  (name test)
  >  (modes byte)
  >  (ocamlc_flags -dsource)
  >  (instrumentation (backend mutaml -compare-boundary false)))
  > EOF

  $ cat > test.ml <<'EOF'
  > let f x y = x < y;;
  > assert (not (f 10 10))
  > EOF

  $ bash ../filter_dune_build.sh ./test.bc --instrument-with mutaml
  Running mutaml instrumentation on "test.ml"
  Randomness seed: 896745231   Mutation rate: 100   GADTs enabled: true
  Created 0 mutations of test.ml
  Writing mutation info to test.muts
  
  let __MUTAML_MUTANT__ = Stdlib.Sys.getenv_opt "MUTAML_MUTANT"
  let __is_mutaml_mutant__ m =
    match __MUTAML_MUTANT__ with
    | None -> false
    | Some mutant -> String.equal m mutant
  let f x y = x < y
  ;;assert (not (f 10 10))


An environment variable is the other way. Put the dune file back
first:

  $ bash ../write_dune_files.sh
  $ dune clean
  $ export MUTAML_COMPARE_BOUNDARY=false

  $ bash ../filter_dune_build.sh ./test.bc --instrument-with mutaml
  Running mutaml instrumentation on "test.ml"
  Randomness seed: 896745231   Mutation rate: 100   GADTs enabled: true
  Created 0 mutations of test.ml
  Writing mutation info to test.muts
  
  let __MUTAML_MUTANT__ = Stdlib.Sys.getenv_opt "MUTAML_MUTANT"
  let __is_mutaml_mutant__ m =
    match __MUTAML_MUTANT__ with
    | None -> false
    | Some mutant -> String.equal m mutant
  let f x y = x < y
  ;;assert (not (f 10 10))


MUTAML_COMPARE_NEGATION=false leaves = and <> alone:

  $ dune clean
  $ export MUTAML_COMPARE_NEGATION=false
  $ cat > test.ml <<'EOF'
  > let f x y = x = y;;
  > assert (f 10 10)
  > EOF

  $ bash ../filter_dune_build.sh ./test.bc --instrument-with mutaml
  Running mutaml instrumentation on "test.ml"
  Randomness seed: 896745231   Mutation rate: 100   GADTs enabled: true
  Created 0 mutations of test.ml
  Writing mutation info to test.muts
  
  let __MUTAML_MUTANT__ = Stdlib.Sys.getenv_opt "MUTAML_MUTANT"
  let __is_mutaml_mutant__ m =
    match __MUTAML_MUTANT__ with
    | None -> false
    | Some mutant -> String.equal m mutant
  let f x y = x = y
  ;;assert (f 10 10)


MUTAML_EQUAL_FUNCTION=false leaves String.equal alone:

  $ dune clean
  $ export MUTAML_EQUAL_FUNCTION=false
  $ cat > test.ml <<'EOF'
  > let f x y = String.equal x y;;
  > assert (f "a" "a")
  > EOF

  $ bash ../filter_dune_build.sh ./test.bc --instrument-with mutaml
  Running mutaml instrumentation on "test.ml"
  Randomness seed: 896745231   Mutation rate: 100   GADTs enabled: true
  Created 0 mutations of test.ml
  Writing mutation info to test.muts
  
  let __MUTAML_MUTANT__ = Stdlib.Sys.getenv_opt "MUTAML_MUTANT"
  let __is_mutaml_mutant__ m =
    match __MUTAML_MUTANT__ with
    | None -> false
    | Some mutant -> String.equal m mutant
  let f x y = String.equal x y
  ;;assert (f "a" "a")
