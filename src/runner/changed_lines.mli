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

    It runs two commands in the working directory, each without a
    shell, so that a [rev] holding a character that a shell reads is
    still one argument:

    - [git rev-parse --show-prefix], to learn where the working
      directory sits in the repository;
    - [git diff --unified=0 <rev> --], to learn the lines.

    git names a file from the root of the repository, and a [.muts]
    file names a file from the root of the project that dune built.
    {!touches} therefore puts the path of the working directory in the
    repository in front of the name it is given. The root of the
    project must be the root of the repository, or a directory under
    it; it cannot be a directory above it.

    A file that the change did not touch is not in the result. Neither
    is a file that the change took away, because there is no file left
    to hold a mutation.

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

    A hunk that only takes lines away adds no line to the file. Such a
    hunk marks the line that the removal follows, and the first line
    when the removal took the start of the file, so that a change which
    only takes code away does not leave every mutation of the file
    untested. *)
