The attribute `[@mutaml.skip "reason"]` on the first expression of a
sequence `e0; e1` stopped the build. The preprocessor made the mutated
sequence as a copy of `e0`, so the new sequence took the attributes of
`e0`, and the mark with them. The check for marks that are left in the
tree then found the mark on the sequence, where no pass takes it out.

  $ ls ../filter_dune_build.sh
  ../filter_dune_build.sh

Create a file whose function counts in a sequence, with the attribute
on the first step:

  $ cat > test.ml <<'EOF'
  > let count () =
  >   let c = ref 0 in
  >   (c := !c + 1)[@mutaml.skip "the first step is checked elsewhere"];
  >   c := !c + 2;
  >   !c
  > ;;
  > assert (count () = 3)
  > EOF

Create the dune files:

  $ cat > dune-project <<'EOF'
  > (lang dune 2.9)
  > EOF

  $ cat > dune <<'EOF'
  > (executable
  >  (name test)
  >  (ocamlc_flags -dsource)
  >  (instrumentation (backend mutaml))
  > )
  > EOF

Set seed and (full) mutation rate as environment variables, for repeatability

  $ export MUTAML_SEED=896745231
  $ export MUTAML_MUT_RATE=100

The build passes. The marked step `c := !c + 1` holds no mutation. The
second step keeps its own mutations. Each of the two sequences keeps its
mutation of the `sequence` operator, which takes the first step of that
sequence out. That mutation belongs to the sequence and not to the
marked step, so the attribute does not take it out:

  $ ../filter_dune_build.sh ./test.exe --instrument-with mutaml > with-skip.txt
  $ grep -v '^ *$' with-skip.txt
  Running mutaml instrumentation on "test.ml"
  Randomness seed: 896745231   Mutation rate: 100   GADTs enabled: true
  Created 5 mutations of test.ml
  Skipped 1 place in test.ml
  Writing mutation info to test.muts
  let __MUTAML_MUTANT__ = Stdlib.Sys.getenv_opt "MUTAML_MUTANT"
  let __is_mutaml_mutant__ m =
    match __MUTAML_MUTANT__ with
    | None -> false
    | Some mutant -> String.equal m mutant
  let count () =
    let c =
      ref
        (if __is_mutaml_mutant__ "test.ml:count:int-constant:92be9951:0"
         then 1
         else 0) in
    if __is_mutaml_mutant__ "test.ml:count:sequence:e28aecad:0"
    then ()
    else c := ((!c) + 1);
    if __is_mutaml_mutant__ "test.ml:count:sequence:b894a030:0"
    then ()
    else
      c :=
        ((let __MUTAML_TMP0__ =
            if __is_mutaml_mutant__ "test.ml:count:int-constant:626aba84:0"
            then 3
            else 2 in
          let __MUTAML_TMP1__ = !c in
          if __is_mutaml_mutant__ "test.ml:count:arith-operator:4fddaa5a:0"
          then __MUTAML_TMP1__ - __MUTAML_TMP0__
          else __MUTAML_TMP1__ + __MUTAML_TMP0__));
    !c
  ;;assert ((count ()) = 3)

The `.muts` file holds the place, its reason, and the operator that the
preprocessor would have used inside it:

  $ grep -o '"reason":"[^"]*"' _build/.mutaml/default/test.muts
  "reason":"the first step is checked elsewhere"
  $ grep -o '"kinds":\[[^]]*\]' _build/.mutaml/default/test.muts
  "kinds":["arith-identity"]

The program runs, and the runner tests every mutation:

  $ _build/default/test.exe

  $ mutaml-runner _build/default/test.exe
  read mut file test.muts
  Testing without a mutant ... passed
  The limit of a test run is 5 times the run without a mutant, and never less than 10 seconds.
  Testing mutant test.ml:count:int-constant:92be9951:0 ... failed
  Testing mutant test.ml:count:int-constant:626aba84:0 ... failed
  Testing mutant test.ml:count:arith-operator:4fddaa5a:0 ... failed
  Testing mutant test.ml:count:sequence:b894a030:0 ... failed
  Testing mutant test.ml:count:sequence:e28aecad:0 ... failed
  Writing report data to mutaml-report.json

Take the attribute away and compare the names. Without the attribute,
the marked step has a mutation of its own. The mutation of the outer
sequence covers the text of the attribute too, and its name holds a
digest of that text, so its name changes with the attribute. No other
name changes:

  $ grep -o '"test.ml:[a-z_]*:[a-z-]*:[0-9a-f]*:[0-9]*"' with-skip.txt | sort -u > with-skip-names.txt
  $ cat > test.ml <<'EOF'
  > let count () =
  >   let c = ref 0 in
  >   (c := !c + 1);
  >   c := !c + 2;
  >   !c
  > ;;
  > assert (count () = 3)
  > EOF
  $ ../filter_dune_build.sh ./test.exe --instrument-with mutaml > no-skip.txt
  $ grep -o '"test.ml:[a-z_]*:[a-z-]*:[0-9a-f]*:[0-9]*"' no-skip.txt | sort -u > no-skip-names.txt
  $ comm -23 with-skip-names.txt no-skip-names.txt
  "test.ml:count:sequence:e28aecad:0"
  $ comm -13 with-skip-names.txt no-skip-names.txt
  "test.ml:count:arith-identity:6ea70f2c:0"
  "test.ml:count:sequence:417552e6:0"

The mutated sequence also keeps the attributes of the sequence. Here a
warning attribute on the sequence allows a variable that the first step
does not use. The copy of `e0` dropped the attribute, and the build
then stopped on the warning:

  $ cat > test.ml <<'EOF'
  > let twice c =
  >   ((let unused = 5 in incr c); incr c)[@ocaml.warning "-26"]
  > ;;
  > assert (let c = ref 0 in twice c; !c = 2)
  > EOF
  $ ../filter_dune_build.sh ./test.exe --instrument-with mutaml 2>&1 | grep -v '^ *$'
  Running mutaml instrumentation on "test.ml"
  Randomness seed: 896745231   Mutation rate: 100   GADTs enabled: true
  Created 2 mutations of test.ml
  Writing mutation info to test.muts
  let __MUTAML_MUTANT__ = Stdlib.Sys.getenv_opt "MUTAML_MUTANT"
  let __is_mutaml_mutant__ m =
    match __MUTAML_MUTANT__ with
    | None -> false
    | Some mutant -> String.equal m mutant
  let twice c =
    ((if __is_mutaml_mutant__ "test.ml:twice:sequence:123fe235:0"
      then ()
      else
        (let unused =
           if __is_mutaml_mutant__ "test.ml:twice:int-constant:6311d79c:0"
           then 6
           else 5 in
         incr c);
      incr c)
    [@ocaml.warning "-26"])
  ;;assert (let c = ref 0 in twice c; (!c) = 2)
  $ _build/default/test.exe
