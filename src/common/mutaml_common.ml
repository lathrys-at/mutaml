open Ppx_yojson_conv_lib.Yojson_conv.Primitives

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
  } [@@deriving yojson]


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
  } [@@deriving yojson]
