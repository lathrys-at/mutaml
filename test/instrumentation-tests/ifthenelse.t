Example with a simple if-then-else:

  $ bash ../write_dune_files.sh

  $ cat > test.ml <<'EOF'
  > let test x = if x then "true" else "false"
  > let () = test true  |> print_endline
  > let () = test false |> print_endline
  > EOF

  $ export MUTAML_SEED=896745231
  $ export MUTAML_MUT_RATE=100
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
  let test x =
    if
      (if __is_mutaml_mutant__ "test.ml:test:if-condition:e8e7a668:0"
       then not x
       else x)
    then "true"
    else "false"
  let () =
    (test
       (if __is_mutaml_mutant__ "test.ml:toplevel:bool-constant:5bf88c8b:0"
        then false
        else true))
      |> print_endline
  let () =
    (test
       (if __is_mutaml_mutant__ "test.ml:toplevel:bool-constant:c7a6885d:0"
        then true
        else false))
      |> print_endline


  $ _build/default/test.bc
  true
  false

  $ MUTAML_MUTANT="test.ml:test:if-condition:e8e7a668:0" _build/default/test.bc
  false
  true


  $ mutaml-runner _build/default/test.bc
  read mut file test.muts
  Testing without a mutant ... passed
  The limit of a test run is 5 times the run without a mutant, and never less than 10 seconds.
  Testing mutant test.ml:test:if-condition:e8e7a668:0 ... passed
  Testing mutant test.ml:toplevel:bool-constant:5bf88c8b:0 ... passed
  Testing mutant test.ml:toplevel:bool-constant:c7a6885d:0 ... passed
  Writing report data to mutaml-report.json


  $ mutaml-report
  Attempting to read from mutaml-report.json...
  
  Mutaml report summary:
  ----------------------
  
   target                          #mutations      #failed      #timeouts      #passed 
   -------------------------------------------------------------------------------------
   test.ml                                3       0.0%    0     0.0%    0   100.0%    3
   =====================================================================================
  
  Mutation programs passing the test suite:
  -----------------------------------------
  
  Mutation "test.ml-mutant0" passed (see "_mutations/test.ml-mutant0.output"):
  
  --- test.ml
  +++ test.ml-mutant0
  @@ -1,3 +1,3 @@
  -let test x = if x then "true" else "false"
  +let test x = if not x then "true" else "false"
   let () = test true  |> print_endline
   let () = test false |> print_endline
  
  ---------------------------------------------------------------------------
  
  Mutation "test.ml-mutant1" passed (see "_mutations/test.ml-mutant1.output"):
  
  --- test.ml
  +++ test.ml-mutant1
  @@ -1,3 +1,3 @@
   let test x = if x then "true" else "false"
  -let () = test true  |> print_endline
  +let () = test false  |> print_endline
   let () = test false |> print_endline
  
  ---------------------------------------------------------------------------
  
  Mutation "test.ml-mutant2" passed (see "_mutations/test.ml-mutant2.output"):
  
  --- test.ml
  +++ test.ml-mutant2
  @@ -1,3 +1,3 @@
   let test x = if x then "true" else "false"
   let () = test true  |> print_endline
  -let () = test false |> print_endline
  +let () = test true |> print_endline
  
  ---------------------------------------------------------------------------
  
  Mutation score: 0.0% (3 mutations: 0 failed, 0 timed out, 3 passed)
  The score is below 100%. Use --fail-under to accept a lower score.
  [2]





An example with nested ifs:
---------------------------

  $ cat > test.ml <<'EOF'
  > let test i =
  >   if i<0 then "negative" else
  >     if i>0 then "positive" else "zero"
  > let () = test ~-5  |> print_endline
  > let () = test 0    |> print_endline
  > let () = test 5    |> print_endline
  > EOF

  $ export MUTAML_SEED=896745231
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
  let test i =
    if
      let __MUTAML_TMP3__ =
        let __MUTAML_TMP0__ =
          if __is_mutaml_mutant__ "test.ml:test:int-constant:92be9951:0"
          then 1
          else 0 in
        if __is_mutaml_mutant__ "test.ml:test:compare-boundary:8dce48d9:0"
        then i <= __MUTAML_TMP0__
        else i < __MUTAML_TMP0__ in
      (if __is_mutaml_mutant__ "test.ml:test:if-condition:aa71fbe1:0"
       then not __MUTAML_TMP3__
       else __MUTAML_TMP3__)
    then "negative"
    else
      if
        (let __MUTAML_TMP2__ =
           let __MUTAML_TMP1__ =
             if __is_mutaml_mutant__ "test.ml:test:int-constant:92be9951:1"
             then 1
             else 0 in
           if __is_mutaml_mutant__ "test.ml:test:compare-boundary:fb82b93a:0"
           then i >= __MUTAML_TMP1__
           else i > __MUTAML_TMP1__ in
         if __is_mutaml_mutant__ "test.ml:test:if-condition:a49cdcf7:0"
         then not __MUTAML_TMP2__
         else __MUTAML_TMP2__)
      then "positive"
      else "zero"
  let () =
    (test
       (-
          (if __is_mutaml_mutant__ "test.ml:toplevel:int-constant:6311d79c:0"
           then 6
           else 5)))
      |> print_endline
  let () =
    (test
       (if __is_mutaml_mutant__ "test.ml:toplevel:int-constant:92be9951:0"
        then 1
        else 0))
      |> print_endline
  let () =
    (test
       (if __is_mutaml_mutant__ "test.ml:toplevel:int-constant:6311d79c:1"
        then 6
        else 5))
      |> print_endline


  $ _build/default/test.bc
  negative
  zero
  positive

  $ MUTAML_MUTANT="test.ml:test:compare-boundary:fb82b93a:0" _build/default/test.bc
  negative
  positive
  positive

  $ MUTAML_MUTANT="test.ml:test:int-constant:92be9951:1" _build/default/test.bc
  negative
  zero
  positive



  $ mutaml-runner _build/default/test.bc
  read mut file test.muts
  Testing without a mutant ... passed
  The limit of a test run is 5 times the run without a mutant, and never less than 10 seconds.
  Testing mutant test.ml:test:int-constant:92be9951:0 ... passed
  Testing mutant test.ml:test:compare-boundary:8dce48d9:0 ... passed
  Testing mutant test.ml:test:int-constant:92be9951:1 ... passed
  Testing mutant test.ml:test:compare-boundary:fb82b93a:0 ... passed
  Testing mutant test.ml:test:if-condition:a49cdcf7:0 ... passed
  Testing mutant test.ml:test:if-condition:aa71fbe1:0 ... passed
  Testing mutant test.ml:toplevel:int-constant:6311d79c:0 ... passed
  Testing mutant test.ml:toplevel:int-constant:92be9951:0 ... passed
  Testing mutant test.ml:toplevel:int-constant:6311d79c:1 ... passed
  Writing report data to mutaml-report.json


  $ mutaml-report
  Attempting to read from mutaml-report.json...
  
  Mutaml report summary:
  ----------------------
  
   target                          #mutations      #failed      #timeouts      #passed 
   -------------------------------------------------------------------------------------
   test.ml                                9       0.0%    0     0.0%    0   100.0%    9
   =====================================================================================
  
  Mutation programs passing the test suite:
  -----------------------------------------
  
  Mutation "test.ml-mutant0" passed (see "_mutations/test.ml-mutant0.output"):
  
  --- test.ml
  +++ test.ml-mutant0
  @@ -1,5 +1,5 @@
   let test i =
  -  if i<0 then "negative" else
  +  if i<1 then "negative" else
       if i>0 then "positive" else "zero"
   let () = test ~-5  |> print_endline
   let () = test 0    |> print_endline
  
  ---------------------------------------------------------------------------
  
  Mutation "test.ml-mutant1" passed (see "_mutations/test.ml-mutant1.output"):
  
  --- test.ml
  +++ test.ml-mutant1
  @@ -1,5 +1,5 @@
   let test i =
  -  if i<0 then "negative" else
  +  if i <= 0 then "negative" else
       if i>0 then "positive" else "zero"
   let () = test ~-5  |> print_endline
   let () = test 0    |> print_endline
  
  ---------------------------------------------------------------------------
  
  Mutation "test.ml-mutant2" passed (see "_mutations/test.ml-mutant2.output"):
  
  --- test.ml
  +++ test.ml-mutant2
  @@ -1,6 +1,6 @@
   let test i =
     if i<0 then "negative" else
  -    if i>0 then "positive" else "zero"
  +    if i>1 then "positive" else "zero"
   let () = test ~-5  |> print_endline
   let () = test 0    |> print_endline
   let () = test 5    |> print_endline
  
  ---------------------------------------------------------------------------
  
  Mutation "test.ml-mutant3" passed (see "_mutations/test.ml-mutant3.output"):
  
  --- test.ml
  +++ test.ml-mutant3
  @@ -1,6 +1,6 @@
   let test i =
     if i<0 then "negative" else
  -    if i>0 then "positive" else "zero"
  +    if i >= 0 then "positive" else "zero"
   let () = test ~-5  |> print_endline
   let () = test 0    |> print_endline
   let () = test 5    |> print_endline
  
  ---------------------------------------------------------------------------
  
  Mutation "test.ml-mutant4" passed (see "_mutations/test.ml-mutant4.output"):
  
  --- test.ml
  +++ test.ml-mutant4
  @@ -1,6 +1,6 @@
   let test i =
     if i<0 then "negative" else
  -    if i>0 then "positive" else "zero"
  +    if not (i > 0) then "positive" else "zero"
   let () = test ~-5  |> print_endline
   let () = test 0    |> print_endline
   let () = test 5    |> print_endline
  
  ---------------------------------------------------------------------------
  
  Mutation "test.ml-mutant5" passed (see "_mutations/test.ml-mutant5.output"):
  
  --- test.ml
  +++ test.ml-mutant5
  @@ -1,5 +1,5 @@
   let test i =
  -  if i<0 then "negative" else
  +  if not (i < 0) then "negative" else
       if i>0 then "positive" else "zero"
   let () = test ~-5  |> print_endline
   let () = test 0    |> print_endline
  
  ---------------------------------------------------------------------------
  
  Mutation "test.ml-mutant6" passed (see "_mutations/test.ml-mutant6.output"):
  
  --- test.ml
  +++ test.ml-mutant6
  @@ -1,6 +1,6 @@
   let test i =
     if i<0 then "negative" else
       if i>0 then "positive" else "zero"
  -let () = test ~-5  |> print_endline
  +let () = test ~-6  |> print_endline
   let () = test 0    |> print_endline
   let () = test 5    |> print_endline
  
  ---------------------------------------------------------------------------
  
  Mutation "test.ml-mutant7" passed (see "_mutations/test.ml-mutant7.output"):
  
  --- test.ml
  +++ test.ml-mutant7
  @@ -2,5 +2,5 @@
     if i<0 then "negative" else
       if i>0 then "positive" else "zero"
   let () = test ~-5  |> print_endline
  -let () = test 0    |> print_endline
  +let () = test 1    |> print_endline
   let () = test 5    |> print_endline
  
  ---------------------------------------------------------------------------
  
  Mutation "test.ml-mutant8" passed (see "_mutations/test.ml-mutant8.output"):
  
  --- test.ml
  +++ test.ml-mutant8
  @@ -3,4 +3,4 @@
       if i>0 then "positive" else "zero"
   let () = test ~-5  |> print_endline
   let () = test 0    |> print_endline
  -let () = test 5    |> print_endline
  +let () = test 6    |> print_endline
  
  ---------------------------------------------------------------------------
  
  Mutation score: 0.0% (9 mutations: 0 failed, 0 timed out, 9 passed)
  The score is below 100%. Use --fail-under to accept a lower score.
  [2]
