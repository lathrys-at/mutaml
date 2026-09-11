(** The diff of one mutation, in the unified format.

    A mutation replaces one run of bytes in a source file with another
    text. This module writes the difference between the file and the
    mutated file as a unified diff, the format that [diff -u] prints and
    that a code viewer colours.

    The console report asks the [diff] command of the system for its
    diffs. This module exists for the Markdown summary, which needs a
    diff inside the file that it writes. Two reasons stand behind the
    second way of making a diff. The [diff] command writes to the
    terminal, and the default command adds colour escapes, which do not
    belong in a Markdown file. And [diff] commands differ: the one of
    macOS and the one of GNU choose different lines to show for the
    same change, so a recorded test of the Markdown summary would hold
    a different text on each system. The diff of this module is the
    same everywhere.

    The diff holds one hunk, with at most three lines of context on
    each side of the change. There is no marker for a file that does
    not end with a newline. *)

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
