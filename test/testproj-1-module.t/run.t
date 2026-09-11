Let us try something:

  $ ls *.ml
  lib.ml
  main.ml
  ounittest.ml

  $ cat > dune-project << EOF
  > (lang dune 2.9)
  > EOF

  $ cat > dune <<'EOF'
  > (library
  >  (name lib)
  >  (modules lib)
  >  (libraries stdlib-random.v4)
  >  (instrumentation (backend mutaml))
  > )
  > 
  > (executable
  >  (name main)
  >  (modules main)
  >  (libraries lib)
  > )
  > 
  > (test
  >   (name ounittest)
  >   (modules ounittest)
  >   (libraries lib ounit2)
  > )
  > EOF

Check that files were created as expected:
  $ ls dune* *.ml
  dune
  dune-project
  lib.ml
  main.ml
  ounittest.ml

Set diff command to make sure this test also works under macOS
  $ export MUTAML_DIFF_COMMAND="diff -u"

Set seed and (full) mutation rate as environment variables, for repeatability
  $ export MUTAML_SEED=896745231
  $ export MUTAML_MUT_RATE=100

  $ bash ../filter_dune_build.sh ./ounittest.exe --instrument-with mutaml
  Running mutaml instrumentation on "lib.ml"
  Randomness seed: 896745231   Mutation rate: 100   GADTs enabled: true
  Created 15 mutations of lib.ml
  Writing mutation info to lib.muts

  $ ls _build/default/*.exe _build/default/*.ml _build/.mutaml/default/*.muts _build/.mutaml/default/*.txt
  _build/.mutaml/default/lib.muts
  _build/.mutaml/default/mutaml-build-id.txt
  _build/.mutaml/default/mutaml-mut-files.txt
  _build/default/lib.ml
  _build/default/lib.pp.ml
  _build/default/ounittest.exe
  _build/default/ounittest.ml

  $ mutaml-runner _build/default/ounittest.exe
  read mut file lib.muts
  Testing without a mutant ... passed
  Testing mutant lib:0 ... failed
  Testing mutant lib:1 ... failed
  Testing mutant lib:2 ... failed
  Testing mutant lib:3 ... failed
  Testing mutant lib:4 ... failed
  Testing mutant lib:5 ... failed
  Testing mutant lib:6 ... passed
  Testing mutant lib:7 ... failed
  Testing mutant lib:8 ... passed
  Testing mutant lib:9 ... failed
  Testing mutant lib:10 ... failed
  Testing mutant lib:11 ... failed
  Testing mutant lib:12 ... failed
  Testing mutant lib:13 ... failed
  Testing mutant lib:14 ... passed
  Writing report data to mutaml-report.json

  $ mutaml-report mutaml-report.json
  Attempting to read from mutaml-report.json...
  
  Mutaml report summary:
  ----------------------
  
   target                          #mutations      #failed      #timeouts      #passed 
   -------------------------------------------------------------------------------------
   lib.ml                                15      80.0%   12     0.0%    0    20.0%    3
   =====================================================================================
  
  Mutation programs passing the test suite:
  -----------------------------------------
  
  Mutation "lib.ml-mutant6" passed (see "_mutations/lib.ml-mutant6.output"):
  
  --- lib.ml
  +++ lib.ml-mutant6
  @@ -21,7 +21,7 @@
   
   let pi total =
     let rec loop n inside =
  -    if n = 0 then
  +    if n = 1 then
         4. *. (float_of_int inside /. float_of_int total)
       else
         let x = 1.0 -. Random.float 2.0 in
  
  ---------------------------------------------------------------------------
  
  Mutation "lib.ml-mutant8" passed (see "_mutations/lib.ml-mutant8.output"):
  
  --- lib.ml
  +++ lib.ml-mutant8
  @@ -26,7 +26,7 @@
       else
         let x = 1.0 -. Random.float 2.0 in
         let y = 1.0 -. Random.float 2.0 in
  -      if x *. x +. y *. y <= 1.
  +      if ((x *. x) +. (y *. y)) < 1.
         then loop (n-1) (inside+1)
         else loop (n-1) (inside)
     in
  
  ---------------------------------------------------------------------------
  
  Mutation "lib.ml-mutant14" passed (see "_mutations/lib.ml-mutant14.output"):
  
  --- lib.ml
  +++ lib.ml-mutant14
  @@ -30,4 +30,4 @@
         then loop (n-1) (inside+1)
         else loop (n-1) (inside)
     in
  -  loop total 0
  +  loop total 1
  
  ---------------------------------------------------------------------------
  
  Mutation score: 80.0% (15 mutations: 12 failed, 0 timed out, 3 passed)
  The score is below 100%. Use --fail-under to accept a lower score.
  [2]


Restarting runner should give the same output:

  $ mutaml-runner _build/default/ounittest.exe
  read mut file lib.muts
  Testing without a mutant ... passed
  Testing mutant lib:0 ... failed
  Testing mutant lib:1 ... failed
  Testing mutant lib:2 ... failed
  Testing mutant lib:3 ... failed
  Testing mutant lib:4 ... failed
  Testing mutant lib:5 ... failed
  Testing mutant lib:6 ... passed
  Testing mutant lib:7 ... failed
  Testing mutant lib:8 ... passed
  Testing mutant lib:9 ... failed
  Testing mutant lib:10 ... failed
  Testing mutant lib:11 ... failed
  Testing mutant lib:12 ... failed
  Testing mutant lib:13 ... failed
  Testing mutant lib:14 ... passed
  Writing report data to mutaml-report.json


  $ mutaml-runner _build/default/ounittest.exe
  read mut file lib.muts
  Testing without a mutant ... passed
  Testing mutant lib:0 ... failed
  Testing mutant lib:1 ... failed
  Testing mutant lib:2 ... failed
  Testing mutant lib:3 ... failed
  Testing mutant lib:4 ... failed
  Testing mutant lib:5 ... failed
  Testing mutant lib:6 ... passed
  Testing mutant lib:7 ... failed
  Testing mutant lib:8 ... passed
  Testing mutant lib:9 ... failed
  Testing mutant lib:10 ... failed
  Testing mutant lib:11 ... failed
  Testing mutant lib:12 ... failed
  Testing mutant lib:13 ... failed
  Testing mutant lib:14 ... passed
  Writing report data to mutaml-report.json


Similarly for the reporter:

  $ mutaml-report mutaml-report.json
  Attempting to read from mutaml-report.json...
  
  Mutaml report summary:
  ----------------------
  
   target                          #mutations      #failed      #timeouts      #passed 
   -------------------------------------------------------------------------------------
   lib.ml                                15      80.0%   12     0.0%    0    20.0%    3
   =====================================================================================
  
  Mutation programs passing the test suite:
  -----------------------------------------
  
  Mutation "lib.ml-mutant6" passed (see "_mutations/lib.ml-mutant6.output"):
  
  --- lib.ml
  +++ lib.ml-mutant6
  @@ -21,7 +21,7 @@
   
   let pi total =
     let rec loop n inside =
  -    if n = 0 then
  +    if n = 1 then
         4. *. (float_of_int inside /. float_of_int total)
       else
         let x = 1.0 -. Random.float 2.0 in
  
  ---------------------------------------------------------------------------
  
  Mutation "lib.ml-mutant8" passed (see "_mutations/lib.ml-mutant8.output"):
  
  --- lib.ml
  +++ lib.ml-mutant8
  @@ -26,7 +26,7 @@
       else
         let x = 1.0 -. Random.float 2.0 in
         let y = 1.0 -. Random.float 2.0 in
  -      if x *. x +. y *. y <= 1.
  +      if ((x *. x) +. (y *. y)) < 1.
         then loop (n-1) (inside+1)
         else loop (n-1) (inside)
     in
  
  ---------------------------------------------------------------------------
  
  Mutation "lib.ml-mutant14" passed (see "_mutations/lib.ml-mutant14.output"):
  
  --- lib.ml
  +++ lib.ml-mutant14
  @@ -30,4 +30,4 @@
         then loop (n-1) (inside+1)
         else loop (n-1) (inside)
     in
  -  loop total 0
  +  loop total 1
  
  ---------------------------------------------------------------------------
  
  Mutation score: 80.0% (15 mutations: 12 failed, 0 timed out, 3 passed)
  The score is below 100%. Use --fail-under to accept a lower score.
  [2]

Try a second run to check that we get the same:

  $ mutaml-report mutaml-report.json
  Attempting to read from mutaml-report.json...
  
  Mutaml report summary:
  ----------------------
  
   target                          #mutations      #failed      #timeouts      #passed 
   -------------------------------------------------------------------------------------
   lib.ml                                15      80.0%   12     0.0%    0    20.0%    3
   =====================================================================================
  
  Mutation programs passing the test suite:
  -----------------------------------------
  
  Mutation "lib.ml-mutant6" passed (see "_mutations/lib.ml-mutant6.output"):
  
  --- lib.ml
  +++ lib.ml-mutant6
  @@ -21,7 +21,7 @@
   
   let pi total =
     let rec loop n inside =
  -    if n = 0 then
  +    if n = 1 then
         4. *. (float_of_int inside /. float_of_int total)
       else
         let x = 1.0 -. Random.float 2.0 in
  
  ---------------------------------------------------------------------------
  
  Mutation "lib.ml-mutant8" passed (see "_mutations/lib.ml-mutant8.output"):
  
  --- lib.ml
  +++ lib.ml-mutant8
  @@ -26,7 +26,7 @@
       else
         let x = 1.0 -. Random.float 2.0 in
         let y = 1.0 -. Random.float 2.0 in
  -      if x *. x +. y *. y <= 1.
  +      if ((x *. x) +. (y *. y)) < 1.
         then loop (n-1) (inside+1)
         else loop (n-1) (inside)
     in
  
  ---------------------------------------------------------------------------
  
  Mutation "lib.ml-mutant14" passed (see "_mutations/lib.ml-mutant14.output"):
  
  --- lib.ml
  +++ lib.ml-mutant14
  @@ -30,4 +30,4 @@
         then loop (n-1) (inside+1)
         else loop (n-1) (inside)
     in
  -  loop total 0
  +  loop total 1
  
  ---------------------------------------------------------------------------
  
  Mutation score: 80.0% (15 mutations: 12 failed, 0 timed out, 3 passed)
  The score is below 100%. Use --fail-under to accept a lower score.
  [2]


Try without providing an explicit file name:

  $ mutaml-report
  Attempting to read from mutaml-report.json...
  
  Mutaml report summary:
  ----------------------
  
   target                          #mutations      #failed      #timeouts      #passed 
   -------------------------------------------------------------------------------------
   lib.ml                                15      80.0%   12     0.0%    0    20.0%    3
   =====================================================================================
  
  Mutation programs passing the test suite:
  -----------------------------------------
  
  Mutation "lib.ml-mutant6" passed (see "_mutations/lib.ml-mutant6.output"):
  
  --- lib.ml
  +++ lib.ml-mutant6
  @@ -21,7 +21,7 @@
   
   let pi total =
     let rec loop n inside =
  -    if n = 0 then
  +    if n = 1 then
         4. *. (float_of_int inside /. float_of_int total)
       else
         let x = 1.0 -. Random.float 2.0 in
  
  ---------------------------------------------------------------------------
  
  Mutation "lib.ml-mutant8" passed (see "_mutations/lib.ml-mutant8.output"):
  
  --- lib.ml
  +++ lib.ml-mutant8
  @@ -26,7 +26,7 @@
       else
         let x = 1.0 -. Random.float 2.0 in
         let y = 1.0 -. Random.float 2.0 in
  -      if x *. x +. y *. y <= 1.
  +      if ((x *. x) +. (y *. y)) < 1.
         then loop (n-1) (inside+1)
         else loop (n-1) (inside)
     in
  
  ---------------------------------------------------------------------------
  
  Mutation "lib.ml-mutant14" passed (see "_mutations/lib.ml-mutant14.output"):
  
  --- lib.ml
  +++ lib.ml-mutant14
  @@ -30,4 +30,4 @@
         then loop (n-1) (inside+1)
         else loop (n-1) (inside)
     in
  -  loop total 0
  +  loop total 1
  
  ---------------------------------------------------------------------------
  
  Mutation score: 80.0% (15 mutations: 12 failed, 0 timed out, 3 passed)
  The score is below 100%. Use --fail-under to accept a lower score.
  [2]


Now try the --no-diff option while providing an explicit file name:

  $ mutaml-report --no-diff mutaml-report.json
  Attempting to read from mutaml-report.json...
  
  Mutaml report summary:
  ----------------------
  
   target                          #mutations      #failed      #timeouts      #passed 
   -------------------------------------------------------------------------------------
   lib.ml                                15      80.0%   12     0.0%    0    20.0%    3
   =====================================================================================
  
  Mutation programs passing the test suite:
  -----------------------------------------
  
  Mutation "lib.ml-mutant6" passed (see "_mutations/lib.ml-mutant6.output")
  Mutation "lib.ml-mutant8" passed (see "_mutations/lib.ml-mutant8.output")
  Mutation "lib.ml-mutant14" passed (see "_mutations/lib.ml-mutant14.output")
  Mutation score: 80.0% (15 mutations: 12 failed, 0 timed out, 3 passed)
  The score is below 100%. Use --fail-under to accept a lower score.
  [2]


--------------------------------------------------------------------------------


And try the --no-diff option without providing an explicit file name:

  $ mutaml-report --no-diff
  Attempting to read from mutaml-report.json...
  
  Mutaml report summary:
  ----------------------
  
   target                          #mutations      #failed      #timeouts      #passed 
   -------------------------------------------------------------------------------------
   lib.ml                                15      80.0%   12     0.0%    0    20.0%    3
   =====================================================================================
  
  Mutation programs passing the test suite:
  -----------------------------------------
  
  Mutation "lib.ml-mutant6" passed (see "_mutations/lib.ml-mutant6.output")
  Mutation "lib.ml-mutant8" passed (see "_mutations/lib.ml-mutant8.output")
  Mutation "lib.ml-mutant14" passed (see "_mutations/lib.ml-mutant14.output")
  Mutation score: 80.0% (15 mutations: 12 failed, 0 timed out, 3 passed)
  The score is below 100%. Use --fail-under to accept a lower score.
  [2]


--------------------------------------------------------------------------------


And try with a different MUTAML_DIFF_COMMAND environment variable:

  $ export MUTAML_DIFF_COMMAND="diff -U 2"
  $ mutaml-report
  Attempting to read from mutaml-report.json...
  
  Mutaml report summary:
  ----------------------
  
   target                          #mutations      #failed      #timeouts      #passed 
   -------------------------------------------------------------------------------------
   lib.ml                                15      80.0%   12     0.0%    0    20.0%    3
   =====================================================================================
  
  Mutation programs passing the test suite:
  -----------------------------------------
  
  Mutation "lib.ml-mutant6" passed (see "_mutations/lib.ml-mutant6.output"):
  
  --- lib.ml
  +++ lib.ml-mutant6
  @@ -22,5 +22,5 @@
   let pi total =
     let rec loop n inside =
  -    if n = 0 then
  +    if n = 1 then
         4. *. (float_of_int inside /. float_of_int total)
       else
  
  ---------------------------------------------------------------------------
  
  Mutation "lib.ml-mutant8" passed (see "_mutations/lib.ml-mutant8.output"):
  
  --- lib.ml
  +++ lib.ml-mutant8
  @@ -27,5 +27,5 @@
         let x = 1.0 -. Random.float 2.0 in
         let y = 1.0 -. Random.float 2.0 in
  -      if x *. x +. y *. y <= 1.
  +      if ((x *. x) +. (y *. y)) < 1.
         then loop (n-1) (inside+1)
         else loop (n-1) (inside)
  
  ---------------------------------------------------------------------------
  
  Mutation "lib.ml-mutant14" passed (see "_mutations/lib.ml-mutant14.output"):
  
  --- lib.ml
  +++ lib.ml-mutant14
  @@ -31,3 +31,3 @@
         else loop (n-1) (inside)
     in
  -  loop total 0
  +  loop total 1
  
  ---------------------------------------------------------------------------
  
  Mutation score: 80.0% (15 mutations: 12 failed, 0 timed out, 3 passed)
  The score is below 100%. Use --fail-under to accept a lower score.
  [2]


Also check that MUTAML_DIFF_COMMAND doesn't affect --no-diff:

  $ mutaml-report --no-diff
  Attempting to read from mutaml-report.json...
  
  Mutaml report summary:
  ----------------------
  
   target                          #mutations      #failed      #timeouts      #passed 
   -------------------------------------------------------------------------------------
   lib.ml                                15      80.0%   12     0.0%    0    20.0%    3
   =====================================================================================
  
  Mutation programs passing the test suite:
  -----------------------------------------
  
  Mutation "lib.ml-mutant6" passed (see "_mutations/lib.ml-mutant6.output")
  Mutation "lib.ml-mutant8" passed (see "_mutations/lib.ml-mutant8.output")
  Mutation "lib.ml-mutant14" passed (see "_mutations/lib.ml-mutant14.output")
  Mutation score: 80.0% (15 mutations: 12 failed, 0 timed out, 3 passed)
  The score is below 100%. Use --fail-under to accept a lower score.
  [2]


Now clean-up MUTAML_DIFF_COMMAND again to default again

  $ export MUTAML_DIFF_COMMAND="diff -u"

--------------------------------------------------------------------------------


Now move file to a different name and retry the --no-diff option with the new name:

  $ mv mutaml-report.json some-report-name.json
  $ mutaml-report --no-diff some-report-name.json
  Attempting to read from some-report-name.json...
  
  Mutaml report summary:
  ----------------------
  
   target                          #mutations      #failed      #timeouts      #passed 
   -------------------------------------------------------------------------------------
   lib.ml                                15      80.0%   12     0.0%    0    20.0%    3
   =====================================================================================
  
  Mutation programs passing the test suite:
  -----------------------------------------
  
  Mutation "lib.ml-mutant6" passed (see "_mutations/lib.ml-mutant6.output")
  Mutation "lib.ml-mutant8" passed (see "_mutations/lib.ml-mutant8.output")
  Mutation "lib.ml-mutant14" passed (see "_mutations/lib.ml-mutant14.output")
  Mutation score: 80.0% (15 mutations: 12 failed, 0 timed out, 3 passed)
  The score is below 100%. Use --fail-under to accept a lower score.
  [2]


--------------------------------------------------------------------------------

Now test with another build context than _build/default:
--------------------------------------------------------

Create a dune-workspace file with another build context:
  $ cat > dune-workspace <<'EOF'
  > (lang dune 2.9)
  > (context default)
  > (context (default (name mutation) (instrument_with mutaml)))
  > EOF


  $ dune clean
  $ unset MUTAML_MUT_RATE
  $ export MUTAML_SEED=896745231
  $ bash ../filter_dune_build.sh ./ounittest.exe
  Running mutaml instrumentation on "lib.ml"
  Randomness seed: 896745231   Mutation rate: 50   GADTs enabled: true
  Created 10 mutations of lib.ml
  Writing mutation info to lib.muts

  $ ls _* dune* *.ml some-report-name.json
  dune
  dune-project
  dune-workspace
  lib.ml
  main.ml
  ounittest.ml
  some-report-name.json
  
  _build:
  default
  mutation
  trace.csexp
  
  _mutations:
  baseline-1.output
  lib.ml-mutant0.output
  lib.ml-mutant1.output
  lib.ml-mutant10.output
  lib.ml-mutant11.output
  lib.ml-mutant12.output
  lib.ml-mutant13.output
  lib.ml-mutant14
  lib.ml-mutant14.output
  lib.ml-mutant2.output
  lib.ml-mutant3.output
  lib.ml-mutant4.output
  lib.ml-mutant5.output
  lib.ml-mutant6
  lib.ml-mutant6.output
  lib.ml-mutant7.output
  lib.ml-mutant8
  lib.ml-mutant8.output
  lib.ml-mutant9.output

  $ ls _build/default/*.exe _build/default/*.ml
  _build/default/lib.ml
  _build/default/ounittest.exe
  _build/default/ounittest.ml

  $ ls _build/mutation/*.exe _build/mutation/*.ml _build/.mutaml/mutation/*.muts _build/.mutaml/mutation/*.txt
  _build/.mutaml/mutation/lib.muts
  _build/.mutaml/mutation/mutaml-build-id.txt
  _build/.mutaml/mutation/mutaml-mut-files.txt
  _build/mutation/lib.ml
  _build/mutation/lib.pp.ml
  _build/mutation/ounittest.exe
  _build/mutation/ounittest.ml

  $ export MUTAML_BUILD_CONTEXT="_build/mutation"
  $ mutaml-runner _build/mutation/ounittest.exe
  read mut file lib.muts
  Testing without a mutant ... passed
  Testing mutant lib:0 ... failed
  Testing mutant lib:1 ... failed
  Testing mutant lib:2 ... failed
  Testing mutant lib:3 ... failed
  Testing mutant lib:4 ... failed
  Testing mutant lib:5 ... passed
  Testing mutant lib:6 ... failed
  Testing mutant lib:7 ... failed
  Testing mutant lib:8 ... failed
  Testing mutant lib:9 ... passed
  Writing report data to mutaml-report.json

  $ mutaml-report
  Attempting to read from mutaml-report.json...
  
  Mutaml report summary:
  ----------------------
  
   target                          #mutations      #failed      #timeouts      #passed 
   -------------------------------------------------------------------------------------
   lib.ml                                10      80.0%    8     0.0%    0    20.0%    2
   =====================================================================================
  
  Mutation programs passing the test suite:
  -----------------------------------------
  
  Mutation "lib.ml-mutant5" passed (see "_mutations/lib.ml-mutant5.output"):
  
  --- lib.ml
  +++ lib.ml-mutant5
  @@ -26,7 +26,7 @@
       else
         let x = 1.0 -. Random.float 2.0 in
         let y = 1.0 -. Random.float 2.0 in
  -      if x *. x +. y *. y <= 1.
  +      if ((x *. x) +. (y *. y)) < 1.
         then loop (n-1) (inside+1)
         else loop (n-1) (inside)
     in
  
  ---------------------------------------------------------------------------
  
  Mutation "lib.ml-mutant9" passed (see "_mutations/lib.ml-mutant9.output"):
  
  --- lib.ml
  +++ lib.ml-mutant9
  @@ -30,4 +30,4 @@
         then loop (n-1) (inside+1)
         else loop (n-1) (inside)
     in
  -  loop total 0
  +  loop total 1
  
  ---------------------------------------------------------------------------
  
  Mutation score: 80.0% (10 mutations: 8 failed, 0 timed out, 2 passed)
  The score is below 100%. Use --fail-under to accept a lower score.
  [2]
Similar, but by passing a command line option:

  $ dune clean
  $ bash ../filter_dune_build.sh ./ounittest.exe
  Running mutaml instrumentation on "lib.ml"
  Randomness seed: 896745231   Mutation rate: 50   GADTs enabled: true
  Created 10 mutations of lib.ml
  Writing mutation info to lib.muts

  $ ls _build/mutation/*.exe _build/mutation/*.ml _build/.mutaml/mutation/*.muts _build/.mutaml/mutation/*.txt
  _build/.mutaml/mutation/lib.muts
  _build/.mutaml/mutation/mutaml-build-id.txt
  _build/.mutaml/mutation/mutaml-mut-files.txt
  _build/mutation/lib.ml
  _build/mutation/lib.pp.ml
  _build/mutation/ounittest.exe
  _build/mutation/ounittest.ml

  $ unset MUTAML_BUILD_CONTEXT
  $ mutaml-runner --build-context "_build/mutation" _build/mutation/ounittest.exe
  read mut file lib.muts
  Testing without a mutant ... passed
  Testing mutant lib:0 ... failed
  Testing mutant lib:1 ... failed
  Testing mutant lib:2 ... failed
  Testing mutant lib:3 ... failed
  Testing mutant lib:4 ... failed
  Testing mutant lib:5 ... passed
  Testing mutant lib:6 ... failed
  Testing mutant lib:7 ... failed
  Testing mutant lib:8 ... failed
  Testing mutant lib:9 ... passed
  Writing report data to mutaml-report.json

  $ mutaml-report
  Attempting to read from mutaml-report.json...
  
  Mutaml report summary:
  ----------------------
  
   target                          #mutations      #failed      #timeouts      #passed 
   -------------------------------------------------------------------------------------
   lib.ml                                10      80.0%    8     0.0%    0    20.0%    2
   =====================================================================================
  
  Mutation programs passing the test suite:
  -----------------------------------------
  
  Mutation "lib.ml-mutant5" passed (see "_mutations/lib.ml-mutant5.output"):
  
  --- lib.ml
  +++ lib.ml-mutant5
  @@ -26,7 +26,7 @@
       else
         let x = 1.0 -. Random.float 2.0 in
         let y = 1.0 -. Random.float 2.0 in
  -      if x *. x +. y *. y <= 1.
  +      if ((x *. x) +. (y *. y)) < 1.
         then loop (n-1) (inside+1)
         else loop (n-1) (inside)
     in
  
  ---------------------------------------------------------------------------
  
  Mutation "lib.ml-mutant9" passed (see "_mutations/lib.ml-mutant9.output"):
  
  --- lib.ml
  +++ lib.ml-mutant9
  @@ -30,4 +30,4 @@
         then loop (n-1) (inside+1)
         else loop (n-1) (inside)
     in
  -  loop total 0
  +  loop total 1
  
  ---------------------------------------------------------------------------
  
  Mutation score: 80.0% (10 mutations: 8 failed, 0 timed out, 2 passed)
  The score is below 100%. Use --fail-under to accept a lower score.
  [2]
Finally, test overriding:

Similar, but by passing a command line option:

  $ dune clean
  $ bash ../filter_dune_build.sh ./ounittest.exe
  Running mutaml instrumentation on "lib.ml"
  Randomness seed: 896745231   Mutation rate: 50   GADTs enabled: true
  Created 10 mutations of lib.ml
  Writing mutation info to lib.muts

  $ ls _build/mutation/*.exe _build/mutation/*.ml _build/.mutaml/mutation/*.muts _build/.mutaml/mutation/*.txt
  _build/.mutaml/mutation/lib.muts
  _build/.mutaml/mutation/mutaml-build-id.txt
  _build/.mutaml/mutation/mutaml-mut-files.txt
  _build/mutation/lib.ml
  _build/mutation/lib.pp.ml
  _build/mutation/ounittest.exe
  _build/mutation/ounittest.ml

  $ export MUTAML_BUILD_CONTEXT="_build/in-a-galaxy-far-far-away"
  $ mutaml-runner --build-context "_build/mutation" _build/mutation/ounittest.exe
  read mut file lib.muts
  Testing without a mutant ... passed
  Testing mutant lib:0 ... failed
  Testing mutant lib:1 ... failed
  Testing mutant lib:2 ... failed
  Testing mutant lib:3 ... failed
  Testing mutant lib:4 ... failed
  Testing mutant lib:5 ... passed
  Testing mutant lib:6 ... failed
  Testing mutant lib:7 ... failed
  Testing mutant lib:8 ... failed
  Testing mutant lib:9 ... passed
  Writing report data to mutaml-report.json

  $ mutaml-report
  Attempting to read from mutaml-report.json...
  
  Mutaml report summary:
  ----------------------
  
   target                          #mutations      #failed      #timeouts      #passed 
   -------------------------------------------------------------------------------------
   lib.ml                                10      80.0%    8     0.0%    0    20.0%    2
   =====================================================================================
  
  Mutation programs passing the test suite:
  -----------------------------------------
  
  Mutation "lib.ml-mutant5" passed (see "_mutations/lib.ml-mutant5.output"):
  
  --- lib.ml
  +++ lib.ml-mutant5
  @@ -26,7 +26,7 @@
       else
         let x = 1.0 -. Random.float 2.0 in
         let y = 1.0 -. Random.float 2.0 in
  -      if x *. x +. y *. y <= 1.
  +      if ((x *. x) +. (y *. y)) < 1.
         then loop (n-1) (inside+1)
         else loop (n-1) (inside)
     in
  
  ---------------------------------------------------------------------------
  
  Mutation "lib.ml-mutant9" passed (see "_mutations/lib.ml-mutant9.output"):
  
  --- lib.ml
  +++ lib.ml-mutant9
  @@ -30,4 +30,4 @@
         then loop (n-1) (inside+1)
         else loop (n-1) (inside)
     in
  -  loop total 0
  +  loop total 1
  
  ---------------------------------------------------------------------------
  
  Mutation score: 80.0% (10 mutations: 8 failed, 0 timed out, 2 passed)
  The score is below 100%. Use --fail-under to accept a lower score.
  [2]



Here's an example of a manual diff from the console:

  $ diff -u --label "lib.ml" -u lib.ml --label "lib.ml-mutant6" _mutations/lib.ml-mutant6
  --- lib.ml
  +++ lib.ml-mutant6
  @@ -21,7 +21,7 @@
   
   let pi total =
     let rec loop n inside =
  -    if n = 0 then
  +    if n = 1 then
         4. *. (float_of_int inside /. float_of_int total)
       else
         let x = 1.0 -. Random.float 2.0 in
  [1]


Old git diff attempts
% $ git diff --no-index -U lib.ml lib.ml-mutant8
% $ git diff -D --no-index -- lib.ml lib.ml-mutant8
% $ git --no-pager diff --no-index --color=always -u --ignore-cr-at-eol lib.ml lib.ml-mutant8
% $ git diff --find-copies-harder -B -C -u --no-index lib.ml lib.ml-mutant8
