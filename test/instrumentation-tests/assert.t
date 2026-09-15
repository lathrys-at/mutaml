Create dune and dune-project files:
  $ bash ../write_dune_files.sh

Make an .ml-file:
  $ cat > test.ml <<'EOF'
  > let foo = match Sys.word_size with
  >   | 32 -> 32
  >   | _  -> assert false
  > EOF

---------------------------------------------------------------
Quick interlude:  This can be useful to observe the parse tree:
---------------------------------------------------------------

;  $ ocamlc -dparsetree test.ml
;  [
;    structure_item (test.ml[1,0+0]..[3,48+22])
;      Pstr_value Nonrec
;      [
;        <def>
;          pattern (test.ml[1,0+4]..[1,0+7])
;            Ppat_var "foo" (test.ml[1,0+4]..[1,0+7])
;          expression (test.ml[1,0+10]..[3,48+22])
;            Pexp_match
;            expression (test.ml[1,0+16]..[1,0+29])
;              Pexp_ident "Sys.word_size" (test.ml[1,0+16]..[1,0+29])
;            [
;              <case>
;                pattern (test.ml[2,35+4]..[2,35+6])
;                  Ppat_constant PConst_int (32,None)
;                expression (test.ml[2,35+10]..[2,35+12])
;                  Pexp_constant PConst_int (32,None)
;              <case>
;                pattern (test.ml[3,48+4]..[3,48+5])
;                  Ppat_any
;                expression (test.ml[3,48+10]..[3,48+22])
;                  Pexp_assert
;                  expression (test.ml[3,48+17]..[3,48+22])
;                    Pexp_construct "false" (test.ml[3,48+17]..[3,48+22])
;                    None
;            ]
;      ]
;  ]

----------------------------------------------------------------------------------
Test mutation of the 'assert false':
----------------------------------------------------------------------------------

Set seed and (full) mutation rate as environment variables, for repeatability
  $ export MUTAML_SEED=896745231
  $ export MUTAML_MUT_RATE=100

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
  let foo =
    match Sys.word_size with
    | 32 ->
        if __is_mutaml_mutant__ "test.ml:foo:int-constant:7a183cb4:0"
        then 33
        else 32
    | _ -> assert false


----------------------------------------------------------------------------------
Test mutation of another 'assert' form:
----------------------------------------------------------------------------------

Make an .ml-file:
  $ cat > test.ml <<'EOF'
  > let foo = match Sys.word_size with
  >   | 32 -> 32
  >   | _  -> assert (1>0); 0
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
  let foo =
    match Sys.word_size with
    | 32 ->
        if __is_mutaml_mutant__ "test.ml:foo:int-constant:7a183cb4:0"
        then 33
        else 32
    | _ ->
        (if __is_mutaml_mutant__ "test.ml:foo:sequence:cc170de4:0"
         then ()
         else assert (1 > 0);
         if __is_mutaml_mutant__ "test.ml:foo:int-constant:92be9951:0"
         then 1
         else 0)


  $ MUTAML_MUTANT="test.ml:foo:int-constant:7a183cb4:0" dune exec --no-build -- ./test.bc

  $ MUTAML_MUTANT="test.ml:foo:int-constant:92be9951:0" dune exec --no-build -- ./test.bc


----------------------------------------------------------------------------------
Test mutation of two asserts:
----------------------------------------------------------------------------------

Make an .ml-file:
  $ cat > test.ml <<'EOF'
  > let () =
  >   let tmp = true = not false in
  >   assert tmp
  > let () =
  >   let tmp = String.length " " = 1 + String.length "" in
  >   assert tmp
  > EOF


  $ bash ../filter_dune_build.sh ./test.bc --instrument-with mutaml
  Running mutaml instrumentation on "test.ml"
  Randomness seed: 896745231   Mutation rate: 100   GADTs enabled: true
  Created 9 mutations of test.ml
  Writing mutation info to test.muts
  
  let __MUTAML_MUTANT__ = Stdlib.Sys.getenv_opt "MUTAML_MUTANT"
  let __is_mutaml_mutant__ m =
    match __MUTAML_MUTANT__ with
    | None -> false
    | Some mutant -> String.equal m mutant
  let () =
    let tmp =
      let __MUTAML_TMP1__ =
        let __MUTAML_TMP0__ =
          if __is_mutaml_mutant__ "test.ml:toplevel:bool-constant:c7a6885d:0"
          then true
          else false in
        if __is_mutaml_mutant__ "test.ml:toplevel:not-expression:15c8baf5:0"
        then __MUTAML_TMP0__
        else not __MUTAML_TMP0__ in
      let __MUTAML_TMP2__ =
        if __is_mutaml_mutant__ "test.ml:toplevel:bool-constant:5bf88c8b:0"
        then false
        else true in
      if __is_mutaml_mutant__ "test.ml:toplevel:compare-negation:ffcc8711:0"
      then __MUTAML_TMP2__ <> __MUTAML_TMP1__
      else __MUTAML_TMP2__ = __MUTAML_TMP1__ in
    assert tmp
  let () =
    let tmp =
      let __MUTAML_TMP4__ =
        let __MUTAML_TMP3__ = String.length "" in
        if __is_mutaml_mutant__ "test.ml:toplevel:arith-identity:e074f9cb:0"
        then __MUTAML_TMP3__
        else 1 + __MUTAML_TMP3__ in
      let __MUTAML_TMP6__ =
        let __MUTAML_TMP5__ =
          String.length
            (if __is_mutaml_mutant__ "test.ml:toplevel:space-string:cbda8879:0"
             then ""
             else " ") in
        if
          __is_mutaml_mutant__
            "test.ml:toplevel:argument-off-by-one:3f91aa3f:0"
        then __MUTAML_TMP5__ + 1
        else
          if
            __is_mutaml_mutant__
              "test.ml:toplevel:argument-off-by-one:92aff65e:0"
          then __MUTAML_TMP5__ - 1
          else __MUTAML_TMP5__ in
      if __is_mutaml_mutant__ "test.ml:toplevel:compare-negation:7a758936:0"
      then __MUTAML_TMP6__ <> __MUTAML_TMP4__
      else __MUTAML_TMP6__ = __MUTAML_TMP4__ in
    assert tmp


Check that running it doesn't fail when run like this

  $ _build/default/test.bc

or like this:

  $ dune exec --no-build ./test.bc


These should all fail however:

  $ MUTAML_MUTANT="test.ml:toplevel:bool-constant:c7a6885d:0" dune exec --no-build ./test.bc
  Fatal error: exception Assert_failure("test.ml", 3, 2)
  [2]

  $ MUTAML_MUTANT="test.ml:toplevel:not-expression:15c8baf5:0" dune exec --no-build ./test.bc
  Fatal error: exception Assert_failure("test.ml", 3, 2)
  [2]

  $ MUTAML_MUTANT="test.ml:toplevel:bool-constant:5bf88c8b:0" dune exec --no-build ./test.bc
  Fatal error: exception Assert_failure("test.ml", 3, 2)
  [2]

  $ MUTAML_MUTANT="test.ml:toplevel:compare-negation:ffcc8711:0" dune exec --no-build ./test.bc
  Fatal error: exception Assert_failure("test.ml", 3, 2)
  [2]

  $ MUTAML_MUTANT="test.ml:toplevel:arith-identity:e074f9cb:0" dune exec --no-build ./test.bc
  Fatal error: exception Assert_failure("test.ml", 6, 2)
  [2]

  $ MUTAML_MUTANT="test.ml:toplevel:space-string:cbda8879:0" dune exec --no-build ./test.bc
  Fatal error: exception Assert_failure("test.ml", 6, 2)
  [2]

  $ MUTAML_MUTANT="test.ml:toplevel:argument-off-by-one:92aff65e:0" dune exec --no-build ./test.bc
  Fatal error: exception Assert_failure("test.ml", 6, 2)
  [2]

  $ MUTAML_MUTANT="test.ml:toplevel:argument-off-by-one:3f91aa3f:0" dune exec --no-build ./test.bc
  Fatal error: exception Assert_failure("test.ml", 6, 2)
  [2]

  $ MUTAML_MUTANT="test.ml:toplevel:compare-negation:7a758936:0" dune exec --no-build ./test.bc
  Fatal error: exception Assert_failure("test.ml", 6, 2)
  [2]
