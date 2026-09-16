The help text names every option of the runner, what its value is, and
what the runner does without it.

  $ mutaml-runner --help
  Usage: mutaml-runner [options] <test-command>
    --muts                      Run mutations in the given muts-file
    --build-context             Specify the build context to read from
    --timeout <seconds>         Stop a test run that takes longer than <seconds>. Without this option the limit is 5 times the run without a mutant, and never less than 10 seconds
    --test-env <NAME=VALUE>     Set NAME to VALUE in every test process. In the value, {} becomes the number of the run: 1 and 2 for the two runs without a mutation, and the number of the run for a mutation. Repeatable
    --baseline-env <NAME=VALUE> Run the test suite a second time without a mutation, with NAME set to VALUE on top of what --test-env sets. Needed only for a value that is not the number of the run. Repeatable
    -j <count>                  Test <count> mutations at one time. The default is 1
    --repeat <count>            Run the test command for one mutation until a run kills it, up to <count> runs, each with a different {} in the values of --test-env
    -help                       Display this list of options
    --help                      Display this list of options
