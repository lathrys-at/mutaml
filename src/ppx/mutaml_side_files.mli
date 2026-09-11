(** Where the instrumentation puts the files it passes to the runner.

    The instrumentation writes two kinds of file that the compiler never
    reads: one [.muts] file for each instrumented source file, holding
    that file's mutations, and one list naming those [.muts] files. The
    runner reads both.

    Dune knows about neither file, and that governs where they can go.
    From dune language 3.3 on, dune runs a preprocessor in a sandbox
    directory that it deletes afterwards, so a file written to the
    working directory is lost. Dune also deletes files it does not know
    about from a build context directory, at the start of the next
    build. So the files go beside the build context directory instead of
    inside it. {!resolve} gives the place. *)

type t
(** The directory that holds the side files of one build. Get one from
    {!resolve}. It holds no open file and needs no release. *)

val resolve : unit -> t
(** [resolve ()] is the directory to write the side files into. It reads
    the process environment, and takes the first of these that applies:

    - [MUTAML_PPX_OUT_DIR], when it is set and not empty. Set it when
      the instrumentation runs outside dune, or to put the files
      somewhere of your own choosing. Under dune you do not need it.
    - [<build dir>/.mutaml/<context name>], when dune has set
      [INSIDE_DUNE] to the build context directory, which dune does for
      every action it runs. For an ordinary project that is
      [_build/.mutaml/default]. [dune clean] removes it.
    - the working directory, when neither applies.

    This function reads the environment and nothing else. It creates no
    directory and never fails. *)

val dir : t -> string
(** [dir t] is the directory as a path, for a message to a person. *)

val write_muts : t -> input_name:string -> Yojson.Safe.t -> string
(** [write_muts t ~input_name json] writes [json] as the [.muts] file of
    the source file [input_name], and returns the name of that file
    relative to [dir t]: [write_muts t ~input_name:"src/lib.ml"] writes
    [dir t ^ "/src/lib.muts"] and returns ["src/lib.muts"]. It makes the
    directories it needs. An [input_name] that is not implicit, such as
    an absolute path, is used as it stands and is not placed under
    [dir t].

    Ends the process through {!Mutaml_common.fail_and_exit}, with a
    message that names the file, when the file cannot be written. *)

val record_muts_file : t -> string -> unit
(** [record_muts_file t name] adds [name] to the list of [.muts] files
    that the runner reads. [name] is what {!write_muts} returned.

    The list holds the files of the current build alone. Each build
    empties it once, before the first name of that build goes in, and
    a name that is in the list already is not added twice. Two source
    files are instrumented by two separate runs of the instrumentation,
    possibly at the same time, so the runs take a lock on the directory
    and the first of them does the emptying.

    Ends the process through {!Mutaml_common.fail_and_exit}, with a
    message that names the file, when the list cannot be read or
    written. *)
