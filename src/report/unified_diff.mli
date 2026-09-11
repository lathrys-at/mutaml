(** The diff of one mutation, in the unified format.

    A mutation replaces one run of bytes in a source file with another
    text. This module writes the difference between the file and the
    mutated file in the format that [diff -u] prints.

    The diff holds one hunk, with at most three lines of context on
    each side of the change. It carries no colour, and it has no marker
    for a file that does not end with a newline. The text is the same
    on every system, because no other program makes it. *)

val unified :
  old_label:string ->
  new_label:string ->
  contents:string ->
  start:int ->
  stop:int ->
  repl:string ->
  string
(** [unified ~old_label ~new_label ~contents ~start ~stop ~repl] is the
    unified diff between [contents] and the text that [contents]
    becomes when the bytes from [start] up to but not including [stop]
    are replaced by [repl].

    [old_label] names the file on the [---] line and [new_label] names
    it on the [+++] line.

    The result ends with a newline, and it is the empty string when the
    replacement leaves the text as it was.

    @raise Invalid_argument when [start] and [stop] are not a run of
    bytes inside [contents], that is, when [0 <= start <= stop <=
    String.length contents] does not hold. *)
