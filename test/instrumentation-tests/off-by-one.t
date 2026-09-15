Tests the argument-off-by-one operator, which adds one to an integer
argument of a known function, or takes one from it

  $ bash ../write_dune_files.sh

Set seed and (full) mutation rate as environment variables, for repeatability
  $ export MUTAML_SEED=896745231
  $ export MUTAML_MUT_RATE=100


String.sub has two integer arguments, the start and the length, so it
gains four mutants. The fifth mutant is the one on the literal 0, which
mutaml already had.

  $ cat > test.ml <<'EOF'
  > let head s n = String.sub s 0 n;;
  > assert (head "abc" 2 = "ab")
  > EOF

  $ bash ../filter_dune_build.sh ./test.bc --instrument-with mutaml
  Running mutaml instrumentation on "test.ml"
  Randomness seed: 896745231   Mutation rate: 100   GADTs enabled: true
  Created 5 mutations of test.ml
  Writing mutation info to test.muts
  
  let __MUTAML_MUTANT__ = Stdlib.Sys.getenv_opt "MUTAML_MUTANT"
  let __is_mutaml_mutant__ m =
    match __MUTAML_MUTANT__ with
    | None -> false
    | Some mutant -> String.equal m mutant
  let head s n =
    String.sub s
      (let __MUTAML_TMP0__ =
         if __is_mutaml_mutant__ "test.ml:head:int-constant:92be9951:0"
         then 1
         else 0 in
       if __is_mutaml_mutant__ "test.ml:head:argument-off-by-one:1dc645bb:0"
       then __MUTAML_TMP0__ + 1
       else
         if __is_mutaml_mutant__ "test.ml:head:argument-off-by-one:c8fc2b9e:0"
         then __MUTAML_TMP0__ - 1
         else __MUTAML_TMP0__)
      (if __is_mutaml_mutant__ "test.ml:head:argument-off-by-one:459b10bf:0"
       then n + 1
       else
         if __is_mutaml_mutant__ "test.ml:head:argument-off-by-one:af7a2276:0"
         then n - 1
         else n)
  ;;assert ((head "abc" 2) = "ab")

Check that instrumentation hasn't changed the program's behaviour
  $ dune exec --no-build ./test.bc

A start one too large takes the wrong part of the string
  $ MUTAML_MUTANT="test.ml:head:argument-off-by-one:1dc645bb:0" dune exec --no-build ./test.bc
  Fatal error: exception Assert_failure("test.ml", 2, 0)
  [2]

A length one too small takes too little of it
  $ MUTAML_MUTANT="test.ml:head:argument-off-by-one:af7a2276:0" dune exec --no-build ./test.bc
  Fatal error: exception Assert_failure("test.ml", 2, 0)
  [2]


Only the argument positions that the table names gain a mutant. For
List.nth that is the index, and not the list:

  $ dune clean
  $ cat > test.ml <<'EOF'
  > let item xs = List.nth xs 1;;
  > assert (item [0; 1; 2] = 1)
  > EOF

  $ bash ../filter_dune_build.sh ./test.bc --instrument-with mutaml
  Running mutaml instrumentation on "test.ml"
  Randomness seed: 896745231   Mutation rate: 100   GADTs enabled: true
  Created 3 mutations of test.ml
  Writing mutation info to test.muts
  
  let __MUTAML_MUTANT__ = Stdlib.Sys.getenv_opt "MUTAML_MUTANT"
  let __is_mutaml_mutant__ m =
    match __MUTAML_MUTANT__ with
    | None -> false
    | Some mutant -> String.equal m mutant
  let item xs =
    List.nth xs
      (let __MUTAML_TMP0__ =
         if __is_mutaml_mutant__ "test.ml:item:int-constant:50c5a5ff:0"
         then 0
         else 1 in
       if __is_mutaml_mutant__ "test.ml:item:argument-off-by-one:01485684:0"
       then __MUTAML_TMP0__ + 1
       else
         if __is_mutaml_mutant__ "test.ml:item:argument-off-by-one:e91e18c4:0"
         then __MUTAML_TMP0__ - 1
         else __MUTAML_TMP0__)
  ;;assert ((item [0; 1; 2]) = 1)

  $ dune exec --no-build ./test.bc

An index one too small reads the item before the wanted one
  $ MUTAML_MUTANT="test.ml:item:argument-off-by-one:e91e18c4:0" dune exec --no-build ./test.bc
  Fatal error: exception Assert_failure("test.ml", 2, 0)
  [2]


String.length takes no integer argument. Its result is an integer, so the
result gains the two mutants:

  $ dune clean
  $ cat > test.ml <<'EOF'
  > let size s = String.length s;;
  > assert (size "abc" = 3)
  > EOF

  $ bash ../filter_dune_build.sh ./test.bc --instrument-with mutaml
  Running mutaml instrumentation on "test.ml"
  Randomness seed: 896745231   Mutation rate: 100   GADTs enabled: true
  Created 2 mutations of test.ml
  Writing mutation info to test.muts
  
  let __MUTAML_MUTANT__ = Stdlib.Sys.getenv_opt "MUTAML_MUTANT"
  let __is_mutaml_mutant__ m =
    match __MUTAML_MUTANT__ with
    | None -> false
    | Some mutant -> String.equal m mutant
  let size s =
    let __MUTAML_TMP0__ = String.length s in
    if __is_mutaml_mutant__ "test.ml:size:argument-off-by-one:e25e40b6:0"
    then __MUTAML_TMP0__ + 1
    else
      if __is_mutaml_mutant__ "test.ml:size:argument-off-by-one:b5307632:0"
      then __MUTAML_TMP0__ - 1
      else __MUTAML_TMP0__
  ;;assert ((size "abc") = 3)

  $ dune exec --no-build ./test.bc

A size one too small
  $ MUTAML_MUTANT="test.ml:size:argument-off-by-one:b5307632:0" dune exec --no-build ./test.bc
  Fatal error: exception Assert_failure("test.ml", 2, 0)
  [2]


A function that the table does not name gains no mutant of this
operator. List.length is not in the table:

  $ dune clean
  $ cat > test.ml <<'EOF'
  > let f xs = List.length xs;;
  > assert (f [0] = 1)
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
  let f xs = List.length xs
  ;;assert ((f [0]) = 1)

  $ dune exec --no-build ./test.bc


The environment variable MUTAML_ARGUMENT_OFF_BY_ONE=false turns the
operator off:

  $ dune clean
  $ export MUTAML_ARGUMENT_OFF_BY_ONE=false
  $ cat > test.ml <<'EOF'
  > let head s n = String.sub s 0 n;;
  > assert (head "abc" 2 = "ab")
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
  let head s n =
    String.sub s
      (if __is_mutaml_mutant__ "test.ml:head:int-constant:92be9951:0"
       then 1
       else 0) n
  ;;assert ((head "abc" 2) = "ab")

  $ dune exec --no-build ./test.bc


The instrumentation option -argument-off-by-one false does the same:

  $ dune clean
  $ unset MUTAML_ARGUMENT_OFF_BY_ONE
  $ cat > dune <<'EOF'
  > (executable
  >  (name test)
  >  (modes byte)
  >  (ocamlc_flags -dsource)
  >  (instrumentation (backend mutaml -argument-off-by-one false)))
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
  let head s n =
    String.sub s
      (if __is_mutaml_mutant__ "test.ml:head:int-constant:92be9951:0"
       then 1
       else 0) n
  ;;assert ((head "abc" 2) = "ab")
