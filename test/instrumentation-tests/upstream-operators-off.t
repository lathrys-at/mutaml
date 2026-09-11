Tests the switch of each mutation operator that upstream mutaml has.
Every one of them is on by default, so a project that sets nothing sees
what it always saw. Each section below shows the operator working, and
then the same program with the operator turned off.

  $ bash ../write_dune_files.sh

Set seed and (full) mutation rate as environment variables, for repeatability
  $ export MUTAML_SEED=896745231
  $ export MUTAML_MUT_RATE=100


bool-constant: true becomes false, and the reverse

  $ cat > test.ml <<'EOF'
  > let f () = true;;
  > assert (f ())
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
  let f () = if __is_mutaml_mutant__ "test:0" then false else true
  ;;assert (f ())

  $ dune clean
  $ MUTAML_BOOL_CONSTANT=false bash ../filter_dune_build.sh ./test.bc --instrument-with mutaml
  Running mutaml instrumentation on "test.ml"
  Randomness seed: 896745231   Mutation rate: 100   GADTs enabled: true
  Created 0 mutations of test.ml
  Writing mutation info to test.muts
  
  let __MUTAML_MUTANT__ = Stdlib.Sys.getenv_opt "MUTAML_MUTANT"
  let __is_mutaml_mutant__ m =
    match __MUTAML_MUTANT__ with
    | None -> false
    | Some mutant -> String.equal m mutant
  let f () = true
  ;;assert (f ())


int-constant: an integer literal gains one

  $ dune clean
  $ cat > test.ml <<'EOF'
  > let f () = 42;;
  > assert (f () = 42)
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
  let f () = if __is_mutaml_mutant__ "test:0" then 43 else 42
  ;;assert ((f ()) = 42)

  $ dune clean
  $ MUTAML_INT_CONSTANT=false bash ../filter_dune_build.sh ./test.bc --instrument-with mutaml
  Running mutaml instrumentation on "test.ml"
  Randomness seed: 896745231   Mutation rate: 100   GADTs enabled: true
  Created 0 mutations of test.ml
  Writing mutation info to test.muts
  
  let __MUTAML_MUTANT__ = Stdlib.Sys.getenv_opt "MUTAML_MUTANT"
  let __is_mutaml_mutant__ m =
    match __MUTAML_MUTANT__ with
    | None -> false
    | Some mutant -> String.equal m mutant
  let f () = 42
  ;;assert ((f ()) = 42)


space-string: the literal " " becomes ""

  $ dune clean
  $ cat > test.ml <<'EOF'
  > let f () = " ";;
  > assert (f () = " ")
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
  let f () = if __is_mutaml_mutant__ "test:0" then "" else " "
  ;;assert ((f ()) = " ")

  $ dune clean
  $ MUTAML_SPACE_STRING=false bash ../filter_dune_build.sh ./test.bc --instrument-with mutaml
  Running mutaml instrumentation on "test.ml"
  Randomness seed: 896745231   Mutation rate: 100   GADTs enabled: true
  Created 0 mutations of test.ml
  Writing mutation info to test.muts
  
  let __MUTAML_MUTANT__ = Stdlib.Sys.getenv_opt "MUTAML_MUTANT"
  let __is_mutaml_mutant__ m =
    match __MUTAML_MUTANT__ with
    | None -> false
    | Some mutant -> String.equal m mutant
  let f () = " "
  ;;assert ((f ()) = " ")


arith-operator: * becomes +

  $ dune clean
  $ cat > test.ml <<'EOF'
  > let f a b = a * b;;
  > assert (f 2 3 = 6)
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
  let f a b = if __is_mutaml_mutant__ "test:0" then a + b else a * b
  ;;assert ((f 2 3) = 6)

  $ dune clean
  $ MUTAML_ARITH_OPERATOR=false bash ../filter_dune_build.sh ./test.bc --instrument-with mutaml
  Running mutaml instrumentation on "test.ml"
  Randomness seed: 896745231   Mutation rate: 100   GADTs enabled: true
  Created 0 mutations of test.ml
  Writing mutation info to test.muts
  
  let __MUTAML_MUTANT__ = Stdlib.Sys.getenv_opt "MUTAML_MUTANT"
  let __is_mutaml_mutant__ m =
    match __MUTAML_MUTANT__ with
    | None -> false
    | Some mutant -> String.equal m mutant
  let f a b = a * b
  ;;assert ((f 2 3) = 6)


arith-identity: n + 1 becomes n. With this operator off the expression
is no longer a special case, so the arith-operator rule takes it
instead and turns the + into a -.

  $ dune clean
  $ cat > test.ml <<'EOF'
  > let f n = n + 1;;
  > assert (f 1 = 2)
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
  let f n = if __is_mutaml_mutant__ "test:0" then n else n + 1
  ;;assert ((f 1) = 2)

  $ dune clean
  $ MUTAML_ARITH_IDENTITY=false bash ../filter_dune_build.sh ./test.bc --instrument-with mutaml
  Running mutaml instrumentation on "test.ml"
  Randomness seed: 896745231   Mutation rate: 100   GADTs enabled: true
  Created 2 mutations of test.ml
  Writing mutation info to test.muts
  
  let __MUTAML_MUTANT__ = Stdlib.Sys.getenv_opt "MUTAML_MUTANT"
  let __is_mutaml_mutant__ m =
    match __MUTAML_MUTANT__ with
    | None -> false
    | Some mutant -> String.equal m mutant
  let f n =
    let __MUTAML_TMP0__ = if __is_mutaml_mutant__ "test:0" then 0 else 1 in
    if __is_mutaml_mutant__ "test:1"
    then n - __MUTAML_TMP0__
    else n + __MUTAML_TMP0__
  ;;assert ((f 1) = 2)

With both of them off the "+" gains no mutant. The literal 1 still
gains its own, from the int-constant operator, which shows that an
operator that is off does not stop the preprocessor walking inside the
expression:

  $ dune clean
  $ MUTAML_ARITH_IDENTITY=false MUTAML_ARITH_OPERATOR=false bash ../filter_dune_build.sh ./test.bc --instrument-with mutaml
  Running mutaml instrumentation on "test.ml"
  Randomness seed: 896745231   Mutation rate: 100   GADTs enabled: true
  Created 1 mutation of test.ml
  Writing mutation info to test.muts
  
  let __MUTAML_MUTANT__ = Stdlib.Sys.getenv_opt "MUTAML_MUTANT"
  let __is_mutaml_mutant__ m =
    match __MUTAML_MUTANT__ with
    | None -> false
    | Some mutant -> String.equal m mutant
  let f n = n + (if __is_mutaml_mutant__ "test:0" then 0 else 1)
  ;;assert ((f 1) = 2)


if-condition: the condition of an if is negated

  $ dune clean
  $ cat > test.ml <<'EOF'
  > let f b = if b then "y" else "n";;
  > assert (f true = "y")
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
  let f b =
    if (if __is_mutaml_mutant__ "test:0" then not b else b) then "y" else "n"
  ;;assert ((f true) = "y")

  $ dune clean
  $ MUTAML_IF_CONDITION=false bash ../filter_dune_build.sh ./test.bc --instrument-with mutaml
  Running mutaml instrumentation on "test.ml"
  Randomness seed: 896745231   Mutation rate: 100   GADTs enabled: true
  Created 0 mutations of test.ml
  Writing mutation info to test.muts
  
  let __MUTAML_MUTANT__ = Stdlib.Sys.getenv_opt "MUTAML_MUTANT"
  let __is_mutaml_mutant__ m =
    match __MUTAML_MUTANT__ with
    | None -> false
    | Some mutant -> String.equal m mutant
  let f b = if b then "y" else "n"
  ;;assert ((f true) = "y")


sequence: in e0; e1 the expression e0 becomes ()

  $ dune clean
  $ cat > test.ml <<'EOF'
  > let f () = print_string "a"; print_string "b";;
  > f ()
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
  let f () =
    if __is_mutaml_mutant__ "test:0" then () else print_string "a";
    print_string "b"
  ;;f ()

  $ dune clean
  $ MUTAML_SEQUENCE=false bash ../filter_dune_build.sh ./test.bc --instrument-with mutaml
  Running mutaml instrumentation on "test.ml"
  Randomness seed: 896745231   Mutation rate: 100   GADTs enabled: true
  Created 0 mutations of test.ml
  Writing mutation info to test.muts
  
  let __MUTAML_MUTANT__ = Stdlib.Sys.getenv_opt "MUTAML_MUTANT"
  let __is_mutaml_mutant__ m =
    match __MUTAML_MUTANT__ with
    | None -> false
    | Some mutant -> String.equal m mutant
  let f () = print_string "a"; print_string "b"
  ;;f ()


omit-case: a case of a pattern match fires never

  $ dune clean
  $ cat > test.ml <<'EOF'
  > let f s = match s with
  >   | "a" -> "A"
  >   | "b" -> "B"
  >   | _ -> "other";;
  > assert (f "a" = "A")
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
  let f s =
    ((match s with
      | "a" when not (__is_mutaml_mutant__ "test:1") -> "A"
      | "b" when not (__is_mutaml_mutant__ "test:0") -> "B"
      | _ -> "other")
    [@ocaml.warning "-8"])
  ;;assert ((f "a") = "A")

  $ dune clean
  $ MUTAML_OMIT_CASE=false bash ../filter_dune_build.sh ./test.bc --instrument-with mutaml
  Running mutaml instrumentation on "test.ml"
  Randomness seed: 896745231   Mutation rate: 100   GADTs enabled: true
  Created 0 mutations of test.ml
  Writing mutation info to test.muts
  
  let __MUTAML_MUTANT__ = Stdlib.Sys.getenv_opt "MUTAML_MUTANT"
  let __is_mutaml_mutant__ m =
    match __MUTAML_MUTANT__ with
    | None -> false
    | Some mutant -> String.equal m mutant
  let f s = ((match s with | "a" -> "A" | "b" -> "B" | _ -> "other")
    [@ocaml.warning "-8"])
  ;;assert ((f "a") = "A")


merge-cases: two neighbouring cases become one or-pattern. This one
needs MUTAML_GADT=false, which is what lets the tool judge two
constructor patterns to agree.

  $ dune clean
  $ export MUTAML_GADT=false
  $ cat > test.ml <<'EOF'
  > let f b = match b with
  >   | true -> "y"
  >   | false -> "n";;
  > assert (f true = "y")
  > EOF
  $ bash ../filter_dune_build.sh ./test.bc --instrument-with mutaml
  Running mutaml instrumentation on "test.ml"
  Randomness seed: 896745231   Mutation rate: 100   GADTs enabled: false
  Created 1 mutation of test.ml
  Writing mutation info to test.muts
  
  let __MUTAML_MUTANT__ = Stdlib.Sys.getenv_opt "MUTAML_MUTANT"
  let __is_mutaml_mutant__ m =
    match __MUTAML_MUTANT__ with
    | None -> false
    | Some mutant -> String.equal m mutant
  let f b =
    ((match b with
      | true when not (__is_mutaml_mutant__ "test:0") -> "y"
      | true | false -> "n")
    [@ocaml.warning "-8"])
  ;;assert ((f true) = "y")

  $ dune clean
  $ MUTAML_MERGE_CASES=false bash ../filter_dune_build.sh ./test.bc --instrument-with mutaml
  Running mutaml instrumentation on "test.ml"
  Randomness seed: 896745231   Mutation rate: 100   GADTs enabled: false
  Created 0 mutations of test.ml
  Writing mutation info to test.muts
  
  let __MUTAML_MUTANT__ = Stdlib.Sys.getenv_opt "MUTAML_MUTANT"
  let __is_mutaml_mutant__ m =
    match __MUTAML_MUTANT__ with
    | None -> false
    | Some mutant -> String.equal m mutant
  let f b = ((match b with | true -> "y" | false -> "n")[@ocaml.warning "-8"])
  ;;assert ((f true) = "y")
  $ unset MUTAML_GADT
