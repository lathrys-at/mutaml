(** The lines that the project changed since a revision.

    [mutaml-runner --changed-since <rev>] tests only the mutations that
    sit on a line that the project changed since [<rev>]. This module
    asks git which lines those are. It is the only part of the runner
    that runs git. *)

type t
(** The lines that the change touched, one set for each source file
    that it touched. Get one from {!since}. It holds no open file and
    no process, and it needs no release. *)

type error =
  | Cannot_run of string
      (** git could not be started at all. The text says why. *)
  | Refused of string list
      (** git ran and answered that it could not do the work. The list
          holds the arguments it was given, without the word "git". *)

val error_message : error -> string
(** [error_message error] is a message for the person who runs the
    tool. It says what the runner asked git to do and what to look at.
    The caller owns the text. *)

val since : rev:string -> (t, error) result
(** [since ~rev] asks git which lines of the project changed between
    the revision [rev] and the files as they are now.

    It runs three commands in the working directory, each without a
    shell, so that a [rev] holding a character that a shell reads is
    still one argument:

    - [git rev-parse --show-prefix], to learn where the working
      directory sits in the repository;
    - [git diff --unified=0 <rev> --], to learn the lines;
    - [git ls-files --others --exclude-standard], to learn the files
      that git does not track. A diff against a revision says nothing
      about such a file, so every line of one counts as changed. A new
      source file that nobody has added to git is the code that most
      wants testing, and it would otherwise be tested not at all.

    Each command carries the settings and the options that make git
    write the one form of output that this module reads, whatever the
    person's own git configuration holds. A configuration that changed
    the form would leave this module finding no changed line, and the
    runner would then test nothing and say that nothing changed.

    git names a file from the root of the repository, and a [.muts]
    file names a file from the root of the project that dune built.
    {!touches} therefore puts the path of the working directory in the
    repository in front of the name it is given. The root of the
    project must be the root of the repository, or a directory under
    it; it cannot be a directory above it.

    A file that the change did not touch is not in the result. Neither
    is a file that the change took away, because there is no file left
    to hold a mutation.

    A file that git tracks but that is only in the working directory
    and not in the index counts as changed, because [git diff <rev>]
    compares [rev] with the files as they are now.

    The result is an error when git cannot be started, which is what
    [Cannot_run] says, and when git refuses the work, which is what
    [Refused] says. git refuses a revision it does not know, and it
    refuses every command when the working directory is in no
    repository. *)

val touches : t -> file:string -> first:int -> last:int -> bool
(** [touches t ~file ~first ~last] says whether the change touched any
    line of [file] from [first] to [last], counting the lines of a file
    from 1.

    [file] is the name of a source file as a [.muts] file holds it,
    which is a name from the root of the project. A name that is not
    relative, such as a path from the root of the file system, is used
    as it stands.

    A [last] below [first] names no line, and the answer is [false].

    Every line of a file that git does not track counts as changed, so
    the answer is [true] for any line of such a file.

    A hunk that only takes lines away adds no line to the file. Such a
    hunk marks the line that the removal follows, and the first line
    when the removal took the start of the file, so that a change which
    only takes code away does not leave every mutation of the file
    untested. *)
