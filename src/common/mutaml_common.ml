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

let make_mut_id file_name number =
  Printf.sprintf "%s:%i" Filename.(remove_extension file_name) number

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


(** A common type to represent mutations *)
type mutant =
  {
    number : int;
    repl   : string option;
    loc    : Loc.location;
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
