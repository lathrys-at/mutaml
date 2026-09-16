The help text names every option of the runner, what its value is, and
what the runner does without it.

  $ mutaml-runner --help
  Usage: mutaml-runner [options] <test-command>
    --muts                      Run mutations in the given muts-file
    --build-context             Specify the build context to read from
    --timeout <seconds>         Stop a test run that takes longer than <seconds>. Without this option the limit is 5 times the run without a mutant, and never less than 10 seconds
    --test-env <NAME=VALUE>     Set NAME to VALUE in every test process. Repeatable
    --baseline-env <NAME=VALUE> Run the test suite a second time without a mutation, with NAME set to VALUE. Repeatable
    -j <count>                  Test <count> mutations at one time. The default is 1
    --repeat <count>            Run the test command for one mutation until a run kills it, up to <count> runs. In the value of a --test-env, {} becomes the number of the run
    -help                       Display this list of options
    --help                      Display this list of options
