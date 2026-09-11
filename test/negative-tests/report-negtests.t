Check that report tool fails without finding JSON file:
  $ mutaml-report
  Attempting to read from mutaml-report.json...
  Could not open file mutaml-report.json: No such file or directory
  [1]

Check that report tool fails without finding another inexisting JSON file:
  $ mutaml-report foobar.json
  Attempting to read from foobar.json...
  Could not open file foobar.json: No such file or directory
  [1]

Create a non-JSON file:
  $ cat > invalid-input.txt <<'EOF'
  > - finn : 42th birthday
  > - remember to buy toiletpaper
  > - æøå
  > EOF

Check that it was created:
  $ ls invalid-input.txt
  invalid-input.txt

Try to parse `invalid-input.txt` as JSON:
  $ mutaml-report invalid-input.txt
  Attempting to read from invalid-input.txt...
  Could not parse JSON in invalid-input.txt: Invalid JSON
  [1]

Create a JSON file in the wrong format:
  $ cat > mydoc.json <<'EOF'
  > { "finn" : 42;
  >   "john" : [1;2;3;true]
  > }
  > EOF

Check that it was created:
  $ ls mydoc.json
  mydoc.json

Now confirm that it is rejected by the report tool:
  $ mutaml-report mydoc.json
  Attempting to read from mydoc.json...
  Could not parse JSON in mydoc.json: Invalid JSON
  [1]

Check that a value of --fail-under above 100 is rejected:
  $ mutaml-report --fail-under 101 mydoc.json
  The value of --fail-under must be a number from 0 to 100.
  [1]

Check that a value of --fail-under below 0 is rejected:
  $ mutaml-report --fail-under -1 mydoc.json
  The value of --fail-under must be a number from 0 to 100.
  [1]

Check that a value of --fail-under that is not a number is rejected:
  $ mutaml-report --fail-under abc mydoc.json
  The value of --fail-under must be a number from 0 to 100.
  [1]

Create a report file that holds no test results:
  $ cat > empty-report.json <<'EOF'
  > []
  > EOF

Now confirm that the report tool gives no score for it:
  $ mutaml-report empty-report.json
  Attempting to read from empty-report.json...
  Found no test results in empty-report.json
  [1]

Create a report file that holds one test result:
  $ cat > one-result.json <<'EOF'
  > [ { "status" : 0,
  >     "mutant" : { "number" : 0, "binding" : "f", "kind" : "arith-operator",
  >                  "original" : "+", "ordinal" : 0, "repl" : "-",
  >                  "loc" : { "loc_start" : { "pos_fname" : "lib.ml", "pos_lnum" : 1, "pos_bol" : 0, "pos_cnum" : 12 },
  >                            "loc_end"   : { "pos_fname" : "lib.ml", "pos_lnum" : 1, "pos_bol" : 0, "pos_cnum" : 13 },
  >                            "loc_ghost" : false } } } ]
  > EOF

Check that the report tool says so when it cannot write the Markdown
summary:
  $ mutaml-report --markdown no-such-directory/summary.md one-result.json
  Attempting to read from one-result.json...
  Could not read the source file lib.ml
  Writing the Markdown summary to no-such-directory/summary.md
  Could not write file no-such-directory/summary.md: No such file or directory
  [1]
