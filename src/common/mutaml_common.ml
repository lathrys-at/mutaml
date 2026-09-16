type defaults =
  {
    ppx_output_prefix  : string;
    output_file_prefix : string;
    mutaml_mut_file    : string;
    mutaml_report_file : string;
  }

let defaults =
  {
    (* filenames to communicate through *)
    ppx_output_prefix   = Filename.concat "_build" "default";
    output_file_prefix  = "_mutations";
    mutaml_mut_file     = "mutaml-mut-files.txt";
    mutaml_report_file  = "mutaml-report.json"
  }

(* The preprocessor writes its side files beside the build context
   directory, not inside it, because dune deletes unknown files from a
   context directory. [side_file_dir "_build/default"] is therefore
   "_build/.mutaml/default". *)
let side_file_dir build_ctx =
  Filename.concat
    (Filename.concat (Filename.dirname build_ctx) ".mutaml")
    (Filename.basename build_ctx)

let full_ppx_path ppx_output_prefix fname =
  if Filename.is_implicit fname
  then Filename.concat (side_file_dir ppx_output_prefix) fname
  else fname

let full_path fname =
  if Filename.is_implicit fname
  then Filename.concat defaults.output_file_prefix fname
  else fname

let output_file_name file_name number =
  let file_name = Printf.sprintf "%s-mutant%i.output" file_name number in
  full_path file_name
    (* (String.map (function '/' -> '_' | c -> c) file_name (*Filename.(remove_extension file_name)*))
    number *)

(** The mutation operators of the tool.

    Each operator has a name that does not change. A tool that reads
    the output of mutaml uses the name to group mutants by operator,
    and a person uses it to turn one operator on or off. Add a
    constructor here when you add an operator; do not rename one. *)
type kind =
  (* the operators that upstream mutaml has *)
  | Bool_constant       (** [true] becomes [false], and the reverse *)
  | Int_constant        (** [1] becomes [0]; any other integer [i] becomes [i+1] *)
  | Space_string        (** the string [" "] becomes [""] *)
  | Arith_operator      (** [+] becomes [-], [*] becomes [+], and so on *)
  | Arith_identity      (** [1 + e], [e + 1] and [e - 1] become [e] *)
  | If_condition        (** the condition of an [if] is negated *)
  | Sequence            (** in [e0; e1], the expression [e0] becomes [()] *)
  | Omit_case           (** a case of a pattern match never fires *)
  | Merge_cases         (** two neighbouring cases become one or-pattern *)
  (* the operators that this fork adds *)
  | Compare_boundary    (** [<] becomes [<=], [>] becomes [>=], and the reverse *)
  | Compare_negation    (** [=] becomes [<>], and the reverse *)
  | Equal_function      (** [Int.equal a b] becomes [not (Int.equal a b)] *)
  | Connective          (** [&&] becomes [||], and the reverse *)
  | Not_expression      (** [not e] becomes [e] *)
  | Some_to_none        (** [Some e] becomes [None] *)
  | Argument_off_by_one (** an integer argument [a] becomes [a + 1] or [a - 1] *)
  | Guard_always_true   (** a [when] guard of a case always holds *)
  | String_literal      (** a string literal becomes [""] *)

(** Every operator, in the order this file declares them. Nothing in
    the preprocessor reads this list: an operator that has a switch is
    named in [Mutaml_ppx.Options.switches] instead. The list is here
    for a reader of the report, which walks it to name every operator
    the tool has, whether or not the run made a mutant of that kind. *)
let all_kinds = [
  Bool_constant; Int_constant; Space_string; Arith_operator;
  Arith_identity; If_condition; Sequence; Omit_case; Merge_cases;
  Compare_boundary; Compare_negation; Equal_function; Connective;
  Not_expression; Some_to_none; Argument_off_by_one;
  Guard_always_true; String_literal;
]

(** [kind_name k] is the name of the operator [k]. The name holds only
    lower case letters and the hyphen, so that it reads the same in a
    report, on a command line, and in a file. It does not change from
    one release to the next.

    The name of the command line option that turns an operator on or
    off is the name of the operator with a hyphen in front of it. The
    name of the environment variable that does the same is
    [kind_env_var k]. *)
let kind_name = function
  | Bool_constant       -> "bool-constant"
  | Int_constant        -> "int-constant"
  | Space_string        -> "space-string"
  | Arith_operator      -> "arith-operator"
  | Arith_identity      -> "arith-identity"
  | If_condition        -> "if-condition"
  | Sequence            -> "sequence"
  | Omit_case           -> "omit-case"
  | Merge_cases         -> "merge-cases"
  | Compare_boundary    -> "compare-boundary"
  | Compare_negation    -> "compare-negation"
  | Equal_function      -> "equal-function"
  | Connective          -> "connective"
  | Not_expression      -> "not-expression"
  | Some_to_none        -> "some-to-none"
  | Argument_off_by_one -> "argument-off-by-one"
  | Guard_always_true   -> "guard-always-true"
  | String_literal      -> "string-literal"

(** [kind_env_var k] is the name of the environment variable that
    turns the operator [k] on or off. It is the name of the operator
    in capitals, with each hyphen changed to an underscore, after the
    prefix [MUTAML_]. So the operator [compare-boundary] reads
    [MUTAML_COMPARE_BOUNDARY]. *)
let kind_env_var k =
  "MUTAML_" ^ String.uppercase_ascii
    (String.map (function '-' -> '_' | c -> c) (kind_name k))

(** [kind_of_name name] is the operator whose [kind_name] is [name], and
    [None] when no operator has that name. *)
let kind_of_name name = List.find_opt (fun k -> kind_name k = name) all_kinds

(** The JSON of an operator is its [kind_name], so that a file this tool
    writes holds "compare-boundary" and not the name of a constructor.
    A reader of the file then needs no table of our constructors, and
    renaming a constructor does not change a file. *)
let kind_to_yojson k = `String (kind_name k)

(** [kind_of_yojson json] is the operator that [json] names. It is an
    error when [json] is not a string, and when the string names no
    operator that this release has. *)
let kind_of_yojson = function
  | `String name ->
    (match kind_of_name name with
     | Some k -> Ok k
     | None   -> Error ("unknown mutation operator: " ^ name))
  | _ -> Error "expected the name of a mutation operator, as a string"

let fail_and_exit s =
  print_endline s;
  exit 1

(** The outcome of one test run, read from the exit status of the test
    process. [Crashed] means that a signal ended the test process, which
    the shell reports as a status above 128. [Timed_out] means that the
    [timeout] command stopped the test process. *)
type outcome = Passed | Failed | Crashed | Timed_out

let outcome_of_status status =
  if status = 0 then Passed
  else if status = 124 then Timed_out
  else if status > 128 && status <= 128 + 64 then Crashed
  else Failed

(** The word that the tools print for an outcome. *)
let outcome_word = function
  | Passed    -> "passed"
  | Failed    -> "failed"
  | Crashed   -> "crashed"
  | Timed_out -> "timeout"

(* hack to derive yojson for ppxlib types *)
(* https://github.com/ocaml-ppx/ppx_deriving#working-with-existing-types *)
module Loc =
struct
  type position = Lexing.position =
    { pos_fname : string
    ; pos_lnum  : int
    ; pos_bol   : int
    ; pos_cnum  : int
    }

  and location = Location.t = {
    loc_start : position;
    loc_end   : position;
    loc_ghost : bool;
  } [@@deriving yojson]
end


(** [range_fits ~start ~stop ~length] says whether the bytes from
    [start] up to but not including [stop] are a run of bytes inside a
    text of [length] bytes. An empty run, where [stop] is [start], fits
    at any point of the text and at its end.

    A location comes from the preprocessor and the text comes from the
    file as it is now, so the two can disagree: a source file that
    changed after a run makes this false. Ask it before you read a run
    of bytes that a location names. *)
let range_fits ~start ~stop ~length =
  0 <= start && start <= stop && stop <= length

(** [span_fits text loc] says whether the run of bytes that [loc] covers
    lies inside [text]. It is [range_fits] over the two byte offsets of
    [loc] and the length of [text]. *)
let span_fits text (loc : Loc.location) =
  range_fits
    ~start:loc.loc_start.pos_cnum
    ~stop:loc.loc_end.pos_cnum
    ~length:(String.length text)

(** One mutation of one source file.

    [number] counts the mutations of a file in the order the
    preprocessor made them, from 0. It names the file that holds the
    output of the test run, and nothing else: it moves when the source
    file changes above the mutation, so it is not a name.
    [Mutaml_common.mutant_name] gives the name that does not move.

    [binding] is the top-level binding that holds the mutation: the
    name the [let] binds, with the path of the modules around it, or
    "toplevel" for a mutation outside every top-level binding.

    [kind] is the operator that made the mutation.

    [original] is the text of the source file that the mutation
    replaces, as the file writes it. [repl] is the text that replaces
    it, and [None] means that the mutation takes the text away.

    [ordinal] counts, from 0, the mutations of the file whose
    [mutant_key] is this one's. Two mutations of a file therefore never
    take one [mutant_name].

    [loc] is the span of the source file that [original] comes from. *)
type mutant =
  {
    number   : int;
    binding  : string;
    kind     : kind;
    original : string;
    ordinal  : int;
    repl     : string option;
    loc      : Loc.location;
  } [@@deriving yojson { exn = true }]

(* The characters a rendered name may hold. A name goes into a command
   line, into an environment variable, and into a file name, so it holds
   no character that a shell reads as anything but itself. *)
let is_name_char = function
  | 'A'..'Z' | 'a'..'z' | '0'..'9' | '_' | '.' | '-' | '/' -> true
  | _ -> false

(* [safe text] is [text] with every other character turned into "_", and
   "_" for the empty text. *)
let safe text =
  if text = ""
  then "_"
  else String.map (fun c -> if is_name_char c then c else '_') text

(* [squeeze text] is [text] with each run of space, tab, carriage return
   and newline turned into one space, and with no space at either end.
   The digest below reads the squeezed text, so that a source file laid
   out again over more lines keeps the names it had. *)
let squeeze text =
  let is_space = function ' ' | '\t' | '\r' | '\n' -> true | _ -> false in
  let buf = Buffer.create (String.length text) in
  let pending = ref false in
  String.iter
    (fun c ->
       if is_space c
       then (if Buffer.length buf > 0 then pending := true)
       else
         begin
           if !pending then Buffer.add_char buf ' ';
           pending := false;
           Buffer.add_char buf c
         end)
    text;
  Buffer.contents buf

(* [field text] is [text] with its length in front of it, so that two
   fields joined together can be read apart again. *)
let field text = Printf.sprintf "%i:%s" (String.length text) text

(** [mutant_digest m] is the short digest that stands for the original
    text and the replacement text of [m] in its name. It holds 8
    characters, each a digit or a letter from a to f.

    Two mutations with different text almost never share a digest. The
    preprocessor stops with an error when two mutations of one file
    would take the same name, so a shared digest cannot pass unseen. *)
let mutant_digest (m : mutant) =
  let original = field (squeeze m.original) in
  let replacement = match m.repl with
    | None      -> "delete"
    | Some text -> field (squeeze text) in
  String.sub (Digest.to_hex (Digest.string (original ^ replacement))) 0 8

(** [mutant_key m] is the name of the mutation [m] without its ordinal:
    the source file, the top-level binding, the operator, and the
    digest, each made safe and joined with ":". It does not read
    [m.ordinal], so the preprocessor can build it before it knows the
    ordinal.

    Two mutations of one file that share a key are exactly the
    mutations that the ordinal must tell apart. *)
let mutant_key (m : mutant) =
  Printf.sprintf "%s:%s:%s:%s"
    (safe m.loc.loc_start.pos_fname)
    (safe m.binding)
    (kind_name m.kind)
    (mutant_digest m)

(** [mutant_name m] is the name of the mutation [m]. The preprocessor
    writes the name into the program it instruments, and the runner puts
    it in MUTAML_MUTANT to turn that one mutation on, so the two must
    read the same function. They do: this one.

    The name holds five fields, with ":" between them:

    - the source file, as the preprocessor was given it;
    - the top-level binding that holds the mutation;
    - the name of the mutation operator;
    - the digest of the original text and the replacement text;
    - the ordinal among the mutations that agree in the four fields
      above.

    So [mutant_name] of the first mutation of the boundary of a
    comparison in the binding [classify] of [src/lib.ml] reads

      src/lib.ml:classify:compare-boundary:a3f9c1d4:0

    The name does not hold the line or the column, so it does not change
    when a source file gains or loses lines above the mutation. It does
    change when the file is renamed, when the binding is renamed, and
    when the mutated text or the text that replaces it changes.

    Every character of the name is a letter, a digit, or one of "_", ".",
    "-", "/" and ":". A character of the source file that is not one of
    those becomes "_". *)
let mutant_name (m : mutant) = Printf.sprintf "%s:%i" (mutant_key m) m.ordinal

(** One place in a source file that [[@mutaml.skip "reason"]] took out
    of the mutation run. The preprocessor makes no mutation there, so a
    skipped place is not a mutation and never reaches a test run. The
    reports name it, with its reason, and leave it out of the score.

    [binding] is the top-level binding that holds the place, in the same
    form as the [binding] of a mutation.

    [reason] is the text that the attribute carries. The preprocessor
    refuses an attribute that carries none, so this is never empty.

    [original] is the text of the source file that the place covers, as
    the file writes it.

    [ordinal] counts, from 0, the skipped places of the file whose
    [skip_key] is this one's, so that two places of a file never take one
    [skip_name].

    [kinds] holds the mutation operators that the preprocessor would
    have used inside the place, in the order it would have used them. It
    is empty when the preprocessor would have made no mutation there,
    which says that the attribute takes nothing away.

    [loc] is the span of the source file that [original] comes from. *)
type skipped =
  {
    binding  : string;
    reason   : string;
    original : string;
    ordinal  : int;
    kinds    : kind list;
    loc      : Loc.location;
  } [@@deriving yojson { exn = true }]

(** [skip_digest s] is the short digest that stands for the skipped text
    and the reason of [s] in its name. It holds 8 characters, each a
    digit or a letter from a to f. It is the digest that
    {!mutant_digest} would give if the reason were the replacement
    text, so the two names read alike. *)
let skip_digest (s : skipped) =
  let original = field (squeeze s.original) in
  let reason = field (squeeze s.reason) in
  String.sub (Digest.to_hex (Digest.string (original ^ reason))) 0 8

(** [skip_key s] is the name of the skipped place [s] without its
    ordinal: the source file, the top-level binding, the word "skip",
    and the digest, each made safe and joined with ":". It does not read
    [s.ordinal], so the preprocessor can build it before it knows the
    ordinal. *)
let skip_key (s : skipped) =
  Printf.sprintf "%s:%s:skip:%s"
    (safe s.loc.loc_start.pos_fname)
    (safe s.binding)
    (skip_digest s)

(** [skip_name s] is the name of the skipped place [s]. It holds the
    same five fields as {!mutant_name}, with the word "skip" where the
    name of the mutation operator stands:

      src/lib.ml:classify:skip:a3f9c1d4:0

    A skipped place never runs, so no environment variable ever carries
    this name. It is there so that a report can name one place of a file
    among several, and so that two reports of one program name the same
    place alike. Like {!mutant_name}, it does not hold the line or the
    column, so it does not change when the file gains or loses lines
    above the place. *)
let skip_name (s : skipped) = Printf.sprintf "%s:%i" (skip_key s) s.ordinal

(** [skip_operators s] is the sentence that a report prints for the
    mutation operators that the attribute takes out of the place [s].
    It ends with a full stop and holds no newline. *)
let skip_operators (s : skipped) = match s.kinds with
  | []    -> "The attribute takes no operator out of this place."
  | kinds ->
    Printf.sprintf
      "The attribute takes these operators out of this place: %s."
      (String.concat ", " (List.map kind_name kinds))

(** What the preprocessor writes in the [.muts] file of one source
    file: every mutation it made there, and every place that
    [[@mutaml.skip "reason"]] took out.

    The file holds a JSON object with these two fields. A file whose
    [skipped] field is absent reads as a file with no skipped place, so
    a [.muts] file that another writer made still reads. A [.muts] file
    of a release before the skip attribute holds a JSON list and not an
    object, and does not read: build the program again. *)
type muts_file =
  {
    mutants : mutant list;
    skipped : skipped list [@default []];
  } [@@deriving yojson { exn = true }]


(** A common type to represent test results.
    [status] is the exit status of the test process. [test_env] holds the
    variables that the runner set in that process, in the order it set
    them. For a mutant that the test suite killed, [test_env] is the
    environment that killed it. *)
type test_result =
  {
    status   : int;
    mutant   : mutant;
    test_env : (string * string) list [@default []];
  } [@@deriving yojson { exn = true }]

(** What the runner writes in its report file, and what the report tool
    reads from it: the result of every test run, and every place that
    [[@mutaml.skip "reason"]] took out, gathered from the [.muts] files
    of the run.

    The file holds a JSON object with these two fields. A file whose
    [skipped] field is absent reads as a run with no skipped place. A
    report file of a release before the skip attribute holds a JSON
    list and not an object, and does not read: run the runner again. *)
type report =
  {
    results : test_result list;
    skipped : skipped list [@default []];
  } [@@deriving yojson { exn = true }]
