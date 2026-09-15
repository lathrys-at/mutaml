Let us try something:

  $ ls ../filter_dune_build.sh
  ../filter_dune_build.sh

Create a file with a 'when' clause reduced from https://github.com/jmid/mutaml/issues/22
  $ cat > test.ml << EOF
  > let accepted_codes n = (n=42)
  > let make status =
  >   let open Unix in
  >   let exit_status = match status with
  >     | WEXITED n when accepted_codes n -> Ok n
  >     | WEXITED n -> Error (Printf.sprintf "Exited %n" n)
  >     | WSIGNALED n -> Error (Printf.sprintf "Signaled %n" n)
  >     | WSTOPPED _ -> assert false
  >   in
  >   exit_status
  > ;;
  > assert (make (Unix.WEXITED 0) = Error "Exited 0")
  > EOF

Create the dune files:
  $ cat > dune-project << EOF
  > (lang dune 2.9)
  > EOF

  $ cat > dune <<'EOF'
  > (executable
  >  (name test)
  >  (ocamlc_flags -dsource)
  >  (libraries unix)
  >  (instrumentation (backend mutaml))
  > )
  > EOF

Check that files were created as expected:
  $ ls dune* test.ml
  dune
  dune-project
  test.ml

Set seed and (full) mutation rate as environment variables, for repeatability
  $ export MUTAML_SEED=896745231
  $ export MUTAML_MUT_RATE=100

  $ ../filter_dune_build.sh ./test.exe --instrument-with mutaml
  Running mutaml instrumentation on "test.ml"
  Randomness seed: 896745231   Mutation rate: 100   GADTs enabled: true
  Created 3 mutations of test.ml
  Writing mutation info to test.muts
  
  let __MUTAML_MUTANT__ = Stdlib.Sys.getenv_opt "MUTAML_MUTANT"
  let __is_mutaml_mutant__ m =
    match __MUTAML_MUTANT__ with
    | None -> false
    | Some mutant -> String.equal m mutant
  let accepted_codes n =
    let __MUTAML_TMP0__ =
      if __is_mutaml_mutant__ "test.ml:accepted_codes:int-constant:5ca5a1be:0"
      then 43
      else 42 in
    if
      __is_mutaml_mutant__ "test.ml:accepted_codes:compare-negation:5478078a:0"
    then n <> __MUTAML_TMP0__
    else n = __MUTAML_TMP0__
  let make status =
    let open Unix in
      let exit_status =
        ((match status with
          | WEXITED n when
              (accepted_codes n) &&
                (not (__is_mutaml_mutant__ "test.ml:make:omit-case:893b3af7:0"))
              -> Ok n
          | WEXITED n -> Error (Printf.sprintf "Exited %n" n)
          | WSIGNALED n -> Error (Printf.sprintf "Signaled %n" n)
          | WSTOPPED _ -> assert false)
        [@ocaml.warning "-8"]) in
      exit_status
  ;;assert ((make (Unix.WEXITED 0)) = (Error "Exited 0"))

  $ ls _build
  default
  trace.csexp

  $ ls _build/default
  test.exe
  test.ml
  test.pp.ml

  $ mutaml-runner _build/default/test.exe
  read mut file test.muts
  Testing without a mutant ... passed
  Testing mutant test.ml:accepted_codes:int-constant:5ca5a1be:0 ... passed
  Testing mutant test.ml:accepted_codes:compare-negation:5478078a:0 ... failed
  Testing mutant test.ml:make:omit-case:893b3af7:0 ... passed
  Writing report data to mutaml-report.json

  $ mutaml-report
  Attempting to read from mutaml-report.json...
  
  Mutaml report summary:
  ----------------------
  
   target                          #mutations      #failed      #timeouts      #passed 
   -------------------------------------------------------------------------------------
   test.ml                                3      33.3%    1     0.0%    0    66.7%    2
   =====================================================================================
  
  Mutation programs passing the test suite:
  -----------------------------------------
  
  Mutation "test.ml-mutant0" passed (see "_mutations/test.ml-mutant0.output"):
  
  --- test.ml
  +++ test.ml-mutant0
  @@ -1,4 +1,4 @@
  -let accepted_codes n = (n=42)
  +let accepted_codes n = (n=43)
   let make status =
     let open Unix in
     let exit_status = match status with
  
  ---------------------------------------------------------------------------
  
  Mutation "test.ml-mutant2" passed (see "_mutations/test.ml-mutant2.output"):
  
  --- test.ml
  +++ test.ml-mutant2
  @@ -2,7 +2,6 @@
   let make status =
     let open Unix in
     let exit_status = match status with
  -    | WEXITED n when accepted_codes n -> Ok n
       | WEXITED n -> Error (Printf.sprintf "Exited %n" n)
       | WSIGNALED n -> Error (Printf.sprintf "Signaled %n" n)
       | WSTOPPED _ -> assert false
  
  ---------------------------------------------------------------------------
  
  Mutation score: 33.3% (3 mutations: 1 failed, 0 timed out, 2 passed)
  The score is below 100%. Use --fail-under to accept a lower score.
  [2]




  $ ls _mutations
  baseline-1.output
  test.ml-mutant0
  test.ml-mutant0.output
  test.ml-mutant1.output
  test.ml-mutant2
  test.ml-mutant2.output
