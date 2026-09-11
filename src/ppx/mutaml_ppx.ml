open Ppxlib

module Base_exp_context = Ppxlib.Expansion_context.Base
module Pprintast = Ppxlib_ast.Pprintast
module Const = Ppxlib.Ast_helper.Const
module Exp   = Ppxlib.Ast_helper.Exp
module Pat   = Ppxlib.Ast_helper.Pat
module Vb    = Ppxlib.Ast_helper.Vb

(* Mutaml works by transforming an expression

     [%expr e+1]

   into a test

     [%expr
      if __is_mutaml_mutant__ "src/lib:42"
      then e
      else e+1]

   thus effectively turning [%expr e+1] into [%expr e]
   for mutant number 42 of source file src/lib.ml.

   In addition, it records that mutant number 42 in 'src/lib.ml'
   is associated with this transformation:

     (src/lib,42) -> (loc, e+1, e)

   To do so we need
   - a generation-time counter (42)
   - a reserved OCaml variable __MUTAML_MUTANT__, containing the value of
   - an environment variable MUTAML_MUTANT
   - a predicate __is_mutaml_mutant
   - a store of mutations for each instrumented file
*)

(** Returns a new structure with an added mutaml preamble *)
let add_preamble structure input_name =
  let loc = Location.in_file input_name in
  [%stri let __MUTAML_MUTANT__ = Stdlib.Sys.getenv_opt "MUTAML_MUTANT"]::
  [%stri let __is_mutaml_mutant__ m = match __MUTAML_MUTANT__ with None -> false | Some mutant -> String.equal m mutant]::
  structure

(** Write mutations of a file 'src/lib.ml' to a 'src/lib.muts', and add
    that name to the list of .muts files that the runner reads.
    Mutaml_side_files chooses the directory both go in. *)
let write_muts_file input_name mutations =
  let out = Mutaml_side_files.resolve () in
  let ys = mutations |> List.rev |> List.map Mutaml_common.mutant_to_yojson in
  let output_name = Mutaml_side_files.write_muts out ~input_name (`List ys) in
  Printf.printf "Writing mutation info to %s\n%!" output_name;
  Mutaml_side_files.record_muts_file out output_name

(** Shorthand to ease string-conversion of surface changes *)
let string_of_exp = Pprintast.string_of_expression

module Options =
struct
  let seed = ref 0
  let mut_rate = ref 100
  let gadt = ref false

  (* One switch for each mutation operator. The value each [ref] holds
     here is the default of that operator. [entry.ml] reads the
     defaults once, when the program starts, and then overwrites each
     switch from the command line or from the environment. *)

  (* the operators that upstream mutaml has. Each is on by default, so
     a project that sets nothing sees what it saw before. *)
  let bool_constant       = ref true
  let int_constant        = ref true
  let space_string        = ref true
  let arith_operator      = ref true
  let arith_identity      = ref true
  let if_condition        = ref true
  let sequence            = ref true
  let omit_case           = ref true
  let merge_cases         = ref true

  (* the operators that this fork adds *)
  let compare_boundary    = ref true
  let compare_negation    = ref true
  let equal_function      = ref true
  let connective          = ref true
  let not_expression      = ref true
  let some_to_none        = ref true
  let argument_off_by_one = ref true
  let guard_always_true   = ref false
  let string_literal      = ref false

  (* Every switch, paired with the operator that names it. [entry.ml]
     walks this list to build one command line option and one
     environment variable for each switch, so a new operator needs no
     change there. *)
  let switches = Mutaml_common.[
    Bool_constant,       bool_constant;
    Int_constant,        int_constant;
    Space_string,        space_string;
    Arith_operator,      arith_operator;
    Arith_identity,      arith_identity;
    If_condition,        if_condition;
    Sequence,            sequence;
    Omit_case,           omit_case;
    Merge_cases,         merge_cases;
    Compare_boundary,    compare_boundary;
    Compare_negation,    compare_negation;
    Equal_function,      equal_function;
    Connective,          connective;
    Not_expression,      not_expression;
    Some_to_none,        some_to_none;
    Argument_off_by_one, argument_off_by_one;
    Guard_always_true,   guard_always_true;
    String_literal,      string_literal;
  ]
end

module Match =
  struct
    (* exception patterns are only allowed as top-level pattern or inside a top-level or-pattern *)
    (* https://ocaml.org/manual/patterns.html#sss:exception-match *)
    let rec pat_matches_exception pat = match pat.ppat_desc with
        | Ppat_any | Ppat_var _ | Ppat_constant _ | Ppat_interval _ | Ppat_construct _
        | Ppat_variant _ | Ppat_alias _ | Ppat_tuple _ | Ppat_record _ | Ppat_array _
        | Ppat_constraint _ | Ppat_type _ | Ppat_lazy _ | Ppat_unpack _ | Ppat_extension _
        | Ppat_open _ -> false
        | Ppat_exception _ -> true
        | Ppat_or (p,p') -> pat_matches_exception p || pat_matches_exception p'

    let rec pat_is_catch_all pat = match pat.ppat_desc with
        | Ppat_constant _ | Ppat_interval _ | Ppat_construct _ | Ppat_variant _
        | Ppat_array _ | Ppat_type _ | Ppat_unpack _ | Ppat_exception _ (* exceptions already filtered *)
        | Ppat_extension _ -> false  (* safe fallback for extention nodes *)
        | Ppat_any | Ppat_var _ -> true (* can act as a catch all at top-level and in tuples+records *)
        | Ppat_tuple ps -> List.for_all pat_is_catch_all ps
        | Ppat_record (entries,_flag) -> List.for_all (fun (_,p) -> pat_is_catch_all p) entries
        | Ppat_or (p,p') -> pat_is_catch_all p || pat_is_catch_all p'
        | Ppat_alias (p,_)
        | Ppat_constraint (p,_)
        | Ppat_lazy p
        | Ppat_open (_,p) -> pat_is_catch_all p

    let case_is_catch_all case = (* lhs when guard -> rhs *)
      pat_is_catch_all case.pc_lhs && case.pc_guard = None && case.pc_rhs.pexp_desc<>Pexp_unreachable
    let cases_contain_catch_all = List.exists case_is_catch_all

    let rec pat_bind_free p = match p.ppat_desc with
        | Ppat_any | Ppat_constant _ | Ppat_interval _
        | Ppat_type _ | Ppat_construct (_,None) -> true
        | Ppat_var _ | Ppat_alias _ | Ppat_unpack _
        | Ppat_variant _ (* No mutation of polymophic variants for now *)
        | Ppat_extension _ -> false (* safe fall back? *)
        | Ppat_tuple ps
        | Ppat_array ps -> List.for_all pat_bind_free ps
        | Ppat_record (es,_) -> List.for_all (fun (_,p) -> pat_bind_free p) es
        | Ppat_or (p1,p2) -> pat_bind_free p1 && pat_bind_free p2
        | Ppat_construct (_,Some (_,p'))
        | Ppat_constraint (p',_)
        | Ppat_lazy p'
        | Ppat_exception p'  (* exceptions should have been filtered *)
        | Ppat_open (_,p') -> pat_bind_free p'

    (* Two patterns agree for this mutation rewriting  (sans GADTs)
        - if they do not bind any variables  -or-
        - if they bind the same variables:
           (x,0) and (x,1) agree
           0::xs and 1::xs agree
           None and Some [] agree
           None and Some _ agree
       With GADTs enabled constructors must also agree (only the two first above) *)
    let rec patterns_agree p1 p2 =
      (not !Options.gadt &&  (* only enabled with GADTs *)
       pat_bind_free p1 &&
       pat_bind_free p2)
      ||
      match p1.ppat_desc, p2.ppat_desc with
      | (Ppat_any | Ppat_constant _ | Ppat_interval _),
        (Ppat_any | Ppat_constant _ | Ppat_interval _) -> true

      | Ppat_any, Ppat_tuple ps -> List.for_all (fun p2' -> patterns_agree p1 p2') ps
      | Ppat_tuple ps, Ppat_any -> List.for_all (fun p1' -> patterns_agree p1' p2) ps
      | Ppat_tuple ps, Ppat_tuple ps' ->
         (try List.for_all2 patterns_agree ps ps'
          with Invalid_argument _ -> false)

      | Ppat_var x, Ppat_var y -> x.txt = y.txt
      | Ppat_alias (p,x), Ppat_alias (p',y) ->
        x.txt = y.txt && patterns_agree p p'

      (* GADT constructor can carry existential hidden types *)
      | Ppat_construct (c,Some (_,p1)), Ppat_construct (c',Some (_,p2)) ->
        c.txt = c'.txt && patterns_agree p1 p2

      | Ppat_any, Ppat_record (es,_fl) ->
        List.for_all (fun (_i2,p2') -> patterns_agree p1 p2') es
      | Ppat_record (es,_fl), Ppat_any ->
        List.for_all (fun (_i1,p1') -> patterns_agree p1' p2) es
      | Ppat_record (es,fl), Ppat_record (es',fl') ->
        (* { l1=P1; ...; ln=Pn } or { l1=P1; ...; ln=Pn; _}  *)
        fl=fl' &&
        (try List.for_all2 (fun (i1,p1) (i2,p2) -> i1.txt = i2.txt && patterns_agree p1 p2)
               (List.sort (fun (i,_) (i',_) -> Stdlib.compare i i') es)
               (List.sort (fun (i,_) (i',_) -> Stdlib.compare i i') es')
         with Invalid_argument _ -> false)

       | Ppat_or (p,p'), _ -> patterns_agree p p2 && patterns_agree p' p2
       | _, Ppat_or (p,p') -> patterns_agree p1 p && patterns_agree p2 p'

       | Ppat_array ps, Ppat_array ps' ->
         (* pattern variables do not generally agree:
              | [| (x,_);(0,y) |] -> ...    | [| (y,"");(0,x) |] -> ...
            but they may do so, despite different length:
              | [| (0,_);(x,_);(0,_);_ |] -> ...    | [| (x,"") |] -> ...
            They can also contain GADT constructors:
              | [| Int; x |] -> ...    | [| Bool; x |] -> ...
            We punt and go with a simple condition (same length)
            enabling only few array-pattern collapses. *)
         (try List.for_all2 patterns_agree ps ps'
          with Invalid_argument _ -> false)

       | Ppat_constraint (p,t), Ppat_constraint (p',t') ->
         t.ptyp_desc = t'.ptyp_desc && patterns_agree p p'
       | Ppat_lazy p, Ppat_lazy p' -> patterns_agree p p'
       | Ppat_unpack m, Ppat_unpack m' -> m.txt = m'.txt
       | Ppat_open (m,p), Ppat_open (m',p') ->
         m.txt = m'.txt && patterns_agree p p'
       | Ppat_variant _, Ppat_variant _ (* No mutation of polymophic variants for now *)
       | _ -> false   (* safe fallback *)

    let rec cases_contain_matching_patterns cs = match cs with
      | [] | [_] -> false
      | c1::(c2::_ as cs') ->
        (not (pat_is_catch_all c2.pc_lhs) (* mutation already covered by 'omit-pattern' *)
         && patterns_agree c1.pc_lhs c2.pc_lhs
         && c1.pc_rhs.pexp_desc<>Pexp_unreachable
         && c2.pc_rhs.pexp_desc<>Pexp_unreachable)
        || cases_contain_matching_patterns cs'
  end


(* The modules of the standard library whose [equal] takes two
   arguments and returns a [bool]. The preprocessor has no types, so it
   cannot see the result type of a function; this list is what it knows
   instead. A module outside the list keeps its [equal] unmutated, even
   when that [equal] does return a [bool]. *)
let equal_function_modules =
  [ "Bool"; "Bytes"; "Char"; "Float"; "Int"; "Int32"; "Int64";
    "Nativeint"; "String"; "Unit" ]

(** [is_equal_function path] is [true] when [path] names the [equal]
    function of one of the modules above, with or without the [Stdlib]
    prefix. A local module of the same name shadows the one of the
    standard library, and then the answer is wrong; this is the same
    hole that every other path-matching rule in the tool has. *)
let is_equal_function path = match path with
  | Longident.Ldot (Longident.Lident m, "equal") ->
    List.mem m equal_function_modules
  | Longident.Ldot (Longident.Ldot (Longident.Lident "Stdlib", m), "equal") ->
    List.mem m equal_function_modules
  | _ -> false

(** [path_of_longident lid] is the dotted name [lid] as the list of
    its parts, so that [String.sub] reads as [["String"; "sub"]]. A
    leading [Stdlib] is dropped, so that [Stdlib.String.sub] reads the
    same. The answer is [None] for the application of one module to
    another, which never names a function. *)
let path_of_longident lid =
  let rec parts = function
    | Longident.Lident s      -> Some [s]
    | Longident.Ldot (lid,s)  -> Option.map (fun p -> p @ [s]) (parts lid)
    | Longident.Lapply _      -> None in
  match parts lid with
  | Some ("Stdlib"::rest) -> Some rest
  | answer                -> answer

(** Functions of the standard library that take an argument of type
    [int]. The number beside each path is the position of such an
    argument, counting the first argument of the function as zero. The
    preprocessor has no types, so this list is what keeps an
    off-by-one mutant compiling.

    A module of the program under test that has the same name as one
    of these, and its own function of the same name with another type,
    defeats the list, and the mutant then fails to build. Such a
    program turns the off-by-one operator off. This is the same hole
    that every other rule in the tool that matches a path has. *)
let int_argument_table =
  [ ["String"; "sub"], [1; 2];
    ["String"; "get"], [1];
    ["Bytes";  "sub"], [1; 2];
    ["Bytes";  "get"], [1];
    ["List";   "nth"], [1] ]

(** Functions of the standard library whose result has type [int], so
    that the result itself takes an off-by-one. The same hole applies. *)
let int_result_table = [ ["String"; "length"] ]

(** [int_argument_positions lid] is the list of positions of the
    arguments of [lid] that have type [int]. It is the empty list when
    the table does not hold [lid]. *)
let int_argument_positions lid = match path_of_longident lid with
  | None      -> []
  | Some path ->
    (match List.assoc_opt path int_argument_table with
     | None           -> []
     | Some positions -> positions)

(** [has_int_result lid] is [true] when the result of [lid] has type
    [int] by the table above. *)
let has_int_result lid = match path_of_longident lid with
  | None      -> false
  | Some path -> List.mem path int_result_table

(* Monadic Ppxlib error handling *)
let return = Ppxlib.With_errors.return
let (>>=) = Ppxlib.With_errors.(>>=)
let (>>|) = Ppxlib.With_errors.(>>|)

class mutate_mapper (rs : RS.t) =
  object (self)
  inherit Ppxlib.Ast_traverse.map_with_expansion_context_and_errors as super

  val mutable mut_count     = 0
  val mutable mutations     = []
  val mutable tmp_var_count = 0

  method choose_to_mutate = RS.int rs 100 <= !Options.mut_rate

  (* [self#enabled k] says whether the mutation operator [k] is on.
     Every operator has a switch in [Options.switches], so the second
     case never runs; it is there so that the method stays total if an
     operator is ever added to [Mutaml_common.kind] and not to the
     list. *)
  method enabled kind = match List.assoc_opt kind Options.switches with
    | Some switch -> !switch
    | None        -> true

  method incr_count =
    let old_count = mut_count in
    mut_count <- mut_count + 1;
    old_count

  method make_tmp_var () =
    let old = tmp_var_count in
    tmp_var_count <- tmp_var_count + 1;
    Printf.sprintf "__MUTAML_TMP%i__" old

  method let_bind ~loc exp = match exp.pexp_desc with
    | Pexp_ident _       (* already an identifier - no need to introduce a new one *)
    | Pexp_constant _ -> (* no need to let-bind constants either *)
      Fun.id, exp
    | _ ->
      let tmp = self#make_tmp_var () in
      let tmp_id = Exp.ident { txt = Lident tmp; loc } in
      let cont e =
        Exp.let_ ~loc Nonrecursive [Vb.mk (Pat.var { txt = tmp; loc }) exp] e in (*let tmp=[%e exp] in e *)
      cont, tmp_id

  method make_mut_number_and_id loc ctx =
    let mut_no = self#incr_count in
    let mut_id = Mutaml_common.make_mut_id (Base_exp_context.input_name ctx) mut_no in
    mut_no, Ast_builder.Default.estring ~loc mut_id

  method mutaml_mutant ctx loc e_new e_rec repl_str =
    let mut_no,mut_id_exp = self#make_mut_number_and_id loc ctx in
    let mutation = Mutaml_common.{ number = mut_no; repl = Some repl_str; loc } in
    mutations <- mutation::mutations;
    [%expr
      if __is_mutaml_mutant__ [%e mut_id_exp]
      then [%e e_new]
      else [%e e_rec]]

  method! constant _ctx e = return e
  method mutate_constant _ctx c = match c with
    | Pconst_integer (i,None) when self#enabled Mutaml_common.Int_constant ->
      (match i with
       (* replace 1 with 0 *)
       | "1" -> Const.integer "0"  (*FIXME: choose between this mutation and the below by coin flip *)
       (* replace literal i with [1+i] - but not l,L,n literals *)
       | _   -> Const.int (1 + int_of_string i))
    (* replace " " strings with "" *)
    | Pconst_string (" ",loc,None)
      when self#enabled Mutaml_common.Space_string -> Const.string ~loc ""
    (* Any other string literal becomes "", and "" becomes " ". This
       operator is off by default: most string literals of a program
       are messages that no test reads, so most of its mutants are
       equivalent and only add noise to a report.

       A literal that holds a '%' is left alone. Such a literal may
       stand where a format is wanted, and there its type is not
       [string] but [format], and [""] does not typecheck. A format
       with no conversion in it, such as [Format.asprintf "hello"],
       does typecheck as [""], so the rule loses nothing that matters
       and it needs no types. *)
    | Pconst_string ("",loc,_)
      when self#enabled Mutaml_common.String_literal -> Const.string ~loc " "
    | Pconst_string (str,loc,_)
      when self#enabled Mutaml_common.String_literal
        && not (String.contains str '%') -> Const.string ~loc ""
    (* FIXME: add more constant mutations over char,float,int32,int64 *)
    | _ -> c

  method mutate_arithmetic ctx e =
    let loc = e.pexp_loc in
    (* arithmetic operator mutations *)
    (* problem:  duplication between the recursively mutated e' (exp1 + exp2')
                 and the original e (exp + exp')
       solution: let-name locally:
                 let __mutaml_tmp25 = exp2 in
                 let __mutaml_tmp26 = exp1 in
                 if __is_mutaml_mutant__ 17
                 then __mutaml_tmp26 - __mutaml_tmp25
                 else __mutaml_tmp26 + __mutaml_tmp25  *)
    match e with
    (* A special case mutations: omit 1+ *)
    | [%expr 1 + [%e? exp]] when self#enabled Mutaml_common.Arith_identity ->
      super#expression ctx exp >>| fun exp' -> (* super avoids mut of exp in  1 + exp *)
      let k, tmp_var = self#let_bind ~loc:exp.pexp_loc exp' in
      k (self#mutaml_mutant ctx loc
           { e with pexp_desc = tmp_var.pexp_desc }
           { e with pexp_desc = [%expr 1 + [%e tmp_var]].pexp_desc }
           (string_of_exp exp))
    (* Two special case mutations: omit +1/-1 *)
    | [%expr [%e? exp] + 1]
    | [%expr [%e? exp] - 1] when self#enabled Mutaml_common.Arith_identity ->
      let op = (match e.pexp_desc with | Pexp_apply (op, _args) -> op | _ -> assert false) in
      super#expression ctx exp >>| fun exp' -> (* super avoids mut of exp in  exp +/- 1 *)
      let k, tmp_var = self#let_bind ~loc:exp.pexp_loc exp' in
      k (self#mutaml_mutant ctx loc
           { e with pexp_desc = tmp_var.pexp_desc }
           { e with pexp_desc = [%expr [%e op] [%e tmp_var] 1].pexp_desc }
           (string_of_exp exp))
    (* General binary operator mutations:
        turn "+" into "-", "-" into "+", "*" into "+", "/" into "mod", "mod" into "/",
        "<" into "<=", "<=" into "<", ">" into ">=", ">=" into ">",
        "=" into "<>", and "<>" into "=".
       The six comparisons all have type ['a -> 'a -> bool], so a swap
       inside that family keeps the type of the whole expression. *)
    | [%expr [%e? op] [%e? exp1] [%e? exp2]] ->
      (* Each row gives the operator to swap in and the mutation
         operator that row belongs to, so that the row answers to the
         right switch. The three arithmetic rows and the six
         comparison rows are three different mutation operators. *)
      let swapped, kind = (match op.pexp_desc with
          | Pexp_ident ({ txt = Lident "+";   loc }) -> Pexp_ident { txt = Lident "-"; loc },   Mutaml_common.Arith_operator
          | Pexp_ident ({ txt = Lident "-";   loc }) -> Pexp_ident { txt = Lident "+"; loc },   Mutaml_common.Arith_operator
          | Pexp_ident ({ txt = Lident "*";   loc }) -> Pexp_ident { txt = Lident "+"; loc },   Mutaml_common.Arith_operator
          | Pexp_ident ({ txt = Lident "/";   loc }) -> Pexp_ident { txt = Lident "mod"; loc }, Mutaml_common.Arith_operator
          | Pexp_ident ({ txt = Lident "mod"; loc }) -> Pexp_ident { txt = Lident "/"; loc },   Mutaml_common.Arith_operator
          | Pexp_ident ({ txt = Lident "<";   loc }) -> Pexp_ident { txt = Lident "<="; loc },  Mutaml_common.Compare_boundary
          | Pexp_ident ({ txt = Lident "<=";  loc }) -> Pexp_ident { txt = Lident "<";  loc },  Mutaml_common.Compare_boundary
          | Pexp_ident ({ txt = Lident ">";   loc }) -> Pexp_ident { txt = Lident ">="; loc },  Mutaml_common.Compare_boundary
          | Pexp_ident ({ txt = Lident ">=";  loc }) -> Pexp_ident { txt = Lident ">";  loc },  Mutaml_common.Compare_boundary
          | Pexp_ident ({ txt = Lident "=";   loc }) -> Pexp_ident { txt = Lident "<>"; loc },  Mutaml_common.Compare_negation
          | Pexp_ident ({ txt = Lident "<>";  loc }) -> Pexp_ident { txt = Lident "=";  loc },  Mutaml_common.Compare_negation
          | _ ->
            failwith ("mutaml_ppx, mutate_arithmetic: found some other operator case: " ^  (string_of_exp op))) in
      (* When the operator of this row is off we make no mutant here,
         but we must still walk into the operands, or they lose the
         mutants of every other operator. *)
      if not (self#enabled kind) then super#expression ctx e else
      let mut_op = { op with pexp_desc = swapped } in
         (* Note: we bind exp2 before exp1 to preserve the current (unspecified) OCaml evaluation order. *)
         self#expression ctx exp2 >>= fun exp2' ->
         let k2, tmp_var2 = self#let_bind ~loc:exp2.pexp_loc exp2' in
         self#expression ctx exp1 >>| fun exp1' ->
         let k1, tmp_var1 = self#let_bind ~loc:exp1.pexp_loc exp1' in
         k2 (k1 (self#mutaml_mutant ctx loc
                   { e with pexp_desc = [%expr [%e mut_op] [%e tmp_var1] [%e tmp_var2]].pexp_desc }
                   { e with pexp_desc = [%expr [%e op]     [%e tmp_var1] [%e tmp_var2]].pexp_desc }
                         (string_of_exp [%expr [%e mut_op] [%e exp1]     [%e exp2]])))
    | _ -> super#expression ctx e

  (* Short-circuit connectives: "&&" becomes "||", and "||" becomes "&&".

     We must not let-bind the right operand, as mutate_arithmetic does
     for its operands. That would evaluate the right operand even when
     the connective does not ask for it, and it would evaluate it
     before the left one. Both are changes to the program with no
     mutant active, which the tool must never make.

     We bind the left operand and we delay the right one instead:

       let __MUTAML_TMP0__ = exp1 in
       let __MUTAML_TMP1__ = fun () -> exp2 in
       if __is_mutaml_mutant__ "src/lib:42"
       then __MUTAML_TMP0__ || __MUTAML_TMP1__ ()
       else __MUTAML_TMP0__ && __MUTAML_TMP1__ ()

     Each branch is still an application of a connective, which the
     compiler still compiles as a short circuit, so the delayed right
     operand runs only when the connective asks for it. *)
  method mutate_shortcircuit ctx e =
    let loc = e.pexp_loc in
    let exp1,exp2,op_name,mut_name = match e with
      | [%expr [%e? exp1] && [%e? exp2]] -> exp1,exp2,"&&","||"
      | [%expr [%e? exp1] || [%e? exp2]] -> exp1,exp2,"||","&&"
      | _ -> failwith "mutaml_ppx, mutate_shortcircuit: pattern matching on case is was not applied to" in
    let connective name = Exp.ident ~loc { txt = Lident name; loc } in
    self#expression ctx exp1 >>= fun exp1' ->
    self#expression ctx exp2 >>| fun exp2' ->
    let k1, tmp_var1 = self#let_bind ~loc:exp1.pexp_loc exp1' in
    let thunk = self#make_tmp_var () in
    let demand = [%expr [%e Exp.ident ~loc { txt = Lident thunk; loc }] ()] in
    let body =
      self#mutaml_mutant ctx loc
        { e with pexp_desc = [%expr [%e connective mut_name] [%e tmp_var1] [%e demand]].pexp_desc }
        { e with pexp_desc = [%expr [%e connective op_name]  [%e tmp_var1] [%e demand]].pexp_desc }
        (string_of_exp [%expr [%e connective mut_name] [%e exp1] [%e exp2]]) in
    k1 (Exp.let_ ~loc Nonrecursive
          [Vb.mk (Pat.var { txt = thunk; loc }) [%expr fun () -> [%e exp2']]]
          body)

  (* "not exp" becomes "exp":

       let __MUTAML_TMP0__ = exp in
       if __is_mutaml_mutant__ "src/lib:42"
       then __MUTAML_TMP0__
       else not __MUTAML_TMP0__

     Both [exp] and [not exp] have type [bool], so the type of the
     whole expression does not change. *)
  method mutate_not ctx e exp =
    let loc = e.pexp_loc in
    self#expression ctx exp >>| fun exp' ->
    let k, tmp_var = self#let_bind ~loc:exp.pexp_loc exp' in
    k (self#mutaml_mutant ctx loc
         { e with pexp_desc = tmp_var.pexp_desc }
         { e with pexp_desc = [%expr not [%e tmp_var]].pexp_desc }
         (string_of_exp exp))

  (* "String.equal a b" becomes "not (String.equal a b)", for the
     modules that [equal_function_modules] names. The negation is the
     same mutation that "=" to "<>" makes, for code that calls the
     typed equality function instead of the polymorphic operator.

     The application has type [bool], and so does its negation, so the
     type of the whole expression does not change. *)
  method mutate_equal_function ctx e =
    let loc = e.pexp_loc in
    super#expression ctx e >>| fun e' -> (* super: mutate the arguments, not the call again *)
    let k, tmp_var = self#let_bind ~loc e' in
    k (self#mutaml_mutant ctx loc
         { e with pexp_desc = [%expr not [%e tmp_var]].pexp_desc }
         { e with pexp_desc = tmp_var.pexp_desc }
         (string_of_exp [%expr not [%e e]]))

  (* [self#off_by_one ctx ~loc ~original recursed] wraps an expression
     of type [int] in two mutants: one that adds one to it and one
     that takes one from it. [recursed] is the expression after the
     preprocessor has walked inside it, and [original] is the
     expression as the source file writes it, which the record of the
     mutation shows. The expression is bound to a name first, so that
     it is written once and evaluated once, whichever mutant is on. *)
  method off_by_one ctx ~loc ~original recursed =
    let k, tmp = self#let_bind ~loc recursed in
    let minus =
      self#mutaml_mutant ctx loc
        [%expr [%e tmp] - 1] tmp (string_of_exp [%expr [%e original] - 1]) in
    k (self#mutaml_mutant ctx loc
         [%expr [%e tmp] + 1] minus (string_of_exp [%expr [%e original] + 1]))

  (* Off by one on each argument of a call that the table says has
     type [int]. Every other argument is walked as usual. The
     arguments keep their places, so the order in which the program
     evaluates them does not change. *)
  method mutate_int_arguments ctx e fn positions args =
    let rec walk position acc args = match args with
      | [] -> return (List.rev acc)
      | (Nolabel, arg)::rest when List.mem position positions ->
        self#expression ctx arg >>= fun arg' ->
        let arg'' =
          self#off_by_one ctx ~loc:arg.pexp_loc ~original:arg arg' in
        walk (position+1) ((Nolabel, arg'')::acc) rest
      | (Nolabel, arg)::rest ->
        self#expression ctx arg >>= fun arg' ->
        walk (position+1) ((Nolabel, arg')::acc) rest
      | (label, arg)::rest ->
        (* a labelled argument has no position among the others *)
        self#expression ctx arg >>= fun arg' ->
        walk position ((label, arg')::acc) rest in
    walk 0 [] args >>| fun args' ->
    { e with pexp_desc = Pexp_apply (fn, args') }

  (* Off by one on the result of a call that the table says has type
     [int], such as [String.length s]. *)
  method mutate_int_result ctx e =
    super#expression ctx e >>| fun e' ->
    self#off_by_one ctx ~loc:e.pexp_loc ~original:e e'

  (* [self#mutate_guards ctx cases] gives each case that has a [when]
     guard a mutant that makes the guard always hold:

       | pat when guard        ~~>  | pat when __is_mutaml_mutant__ id || guard

     so that the case fires where the program says it must not. This
     is the opposite of the mutation that mutaml already had, which
     makes a guarded case fire never; the two find different defects.

     The guard stays a Boolean expression, so the mutant typechecks,
     and the case still has a guard, so the compiler still treats the
     case as one that can fail and reports no new warning.

     The record of the mutation covers the text from the end of the
     pattern to the end of the guard, which is the text "when guard",
     and deletes it, so that a report shows the guard taken away.

     This operator is off by default. A guard that always holds is
     often an equivalent mutant, because a later case does the same
     thing. *)
  method mutate_guards ctx cases =
    List.map
      (fun case -> match case.pc_guard with
         | None -> case
         | Some guard ->
           if not (self#enabled Mutaml_common.Guard_always_true
                   && self#choose_to_mutate)
           then case
           else
             let loc = guard.pexp_loc in
             let span =
               { case.pc_lhs.ppat_loc with
                 loc_start = case.pc_lhs.ppat_loc.loc_end;
                 loc_end   = guard.pexp_loc.loc_end } in
             let mut_no, mut_id_exp = self#make_mut_number_and_id loc ctx in
             let mutation =
               Mutaml_common.{ number = mut_no; repl = None; loc = span } in
             mutations <- mutation::mutations;
             { case with
               pc_guard =
                 Some [%expr __is_mutaml_mutant__ [%e mut_id_exp] || [%e guard]] })
      cases

  method! cases ctx cases =
    super#cases ctx cases >>| fun cases -> (* visit individual cases first *)
    let cases = self#mutate_guards ctx cases in
    let cases_exc, cases_pure =
      List.partition (fun c -> Match.pat_matches_exception c.pc_lhs) cases in
    let cases_contain_catch_all
      = Match.cases_contain_catch_all cases_pure && List.length cases_pure >= 3 in
    if cases_contain_catch_all || Match.cases_contain_matching_patterns cases_pure
    then
      let instr_cases = self#mutate_pure_cases ctx cases_pure ~cases_contain_catch_all in
      instr_cases @ cases_exc
    else cases

  method mutate_pure_cases ctx cases ~cases_contain_catch_all = match cases with
    | []
    | [_] -> cases
    | case1::(case2::_ as cases') ->
      let cases' = self#mutate_pure_cases ctx cases' ~cases_contain_catch_all in
      if Match.pat_is_catch_all case1.pc_lhs
      then case1::cases' (* neither match for omit-pattern or merge-consecutive *)
      else
      (* The two mutations below are two different operators, and each
         has its own switch. Which of the two this case takes is
         settled here, before the mutation is made, so that a case
         whose operator is off draws no random number and leaves the
         mutants of every other operator where they were. *)
      let takes_omit_case = cases_contain_catch_all || case1.pc_guard <> None in
      let kind =
        if takes_omit_case
        then Mutaml_common.Omit_case
        else Mutaml_common.Merge_cases in
      if (not cases_contain_catch_all
      && (not (Match.patterns_agree case1.pc_lhs case2.pc_lhs)
          || Match.pat_is_catch_all case2.pc_lhs))
      || not (self#enabled kind)
      || not self#choose_to_mutate
      then case1::cases'
      else
        (* Only allocate mutation if we are going to use it *)
        let loc = { case1.pc_lhs.ppat_loc with (* location of entire case: lhs with guard -> rhs *)
                    loc_end = case1.pc_rhs.pexp_loc.loc_end } in
        let mut_no,mut_id_exp = self#make_mut_number_and_id loc ctx in
        let mut_guard = [%expr not (__is_mutaml_mutant__ [%e mut_id_exp]) ] in
        let guard = (match case1.pc_guard with
            | None   -> Some mut_guard
            | Some g -> Some [%expr [%e g] && [%e mut_guard] ]) in
        let case1' = { case1 with pc_guard = guard } in

        if takes_omit_case
        then
          (* drop case from pattern-match when there is a '_'-catch all case and >1 additional cases *)
          (* match f x with             match f x with
              | A -> g y                 | A when not (__is_mutaml_mutant__ "test:27") -> g y
              | B -> h z        ~~>      | B when not (__is_mutaml_mutant__ "test:45") -> h z
              | _ -> i q                 | _ -> i q   *)
          (* or if there is pattern containing a 'when'-clause to drop *)
          (* match f x with             match f x with
              | B when c -> h z   ~~>    | B when c && not (__is_mutaml_mutant__ "test:45") -> h z
              | B        -> i q          | B -> i q   *)
          let mutation = Mutaml_common.{ number = mut_no; repl = None;
                                         loc = { loc with loc_end = case2.pc_lhs.ppat_loc.loc_start }} in
          (* | pat1 when guard1 -> rhs1  | pat2 when guard2 -> rhs2
               ^---------------------------^
               replaced with (i.e. omitted):
             |                             pat2 when guard2 -> rhs2 *)
          mutations <- mutation::mutations;
          case1'::cases'
        else
          (* merge consecutive cases into an or-pattern  | p1 -> r1 | p2 -> r2  ~~> |p1|p2 -> r2 *)
          (* when no/same variables are bound in each pattern *)
          (* match f x with           match f x with
              | A -> g y               | A when not (__is_mutaml_mutant__ "test:27") -> g y
              | B -> h z      ~~>      | A | B when not (__is_mutaml_mutant__ "test:45") -> h z
              | C -> i q               | B | C -> i q *)
          (match cases' with (* recurse and glue or-pattern on case2' *)
           | [] -> failwith "mutaml_ppx, mutate_pure_cases: recursing on a non-empty list yielded back an empty one"
           | case2'::cs' ->
             let or_pat = [%pat? [%p case1.pc_lhs] | [%p case2.pc_lhs]] in
             let repl_str =
               Pprintast.pattern Format.str_formatter or_pat;
               Format.flush_str_formatter () in
             (* | pat1 when guard1 -> rhs1  | pat2        when guard2 -> rhs2
                  ^------------------------------^
                          replaced with:
                | pat1                      | pat2        when guard2 -> rhs2  *)
             let mutation = Mutaml_common.{ number = mut_no;
                                            repl = Some repl_str;  (* diff spans to end of pat2 *)
                                            loc = { loc with loc_end = case2.pc_lhs.ppat_loc.loc_end }} in
             mutations <- mutation::mutations;
             let lhs = { case2'.pc_lhs with ppat_desc = Ppat_or (case1.pc_lhs, case2'.pc_lhs) } in
             let case2'_with_or = { case2' with pc_lhs = lhs } in
             case1'::case2'_with_or::cs')

  method! expression ctx e =
    let loc = e.pexp_loc in
    match e, e.pexp_desc with

    (* asserts represent inline sanity checks/tests - so don't mutate their expressions *)
    (* Furthermore, [assert false] is recognized as a special case and rewritten
       to [raise (Assert_failure ...)] - which is polymorphic:
         https://ocaml.org/manual/expr.html#sss:expr-assertion
       All other forms of 'assert' have [unit] return type.
       This means we can break typing by mutating 'assert false'
       when it is used in a "this-should-never-happen"-case:
         match something with
          | Some x -> i+1
          | None   -> assert false
       which is another reason to avoid mutating that particular form. *)
    | [%expr assert [%e? _]], _-> return e

    (* swap bool constructors *)
    | [%expr true],_
      when self#enabled Mutaml_common.Bool_constant && self#choose_to_mutate ->
      let false_exp = { e with pexp_desc = [%expr false].pexp_desc } in
      return (self#mutaml_mutant ctx loc false_exp e (string_of_exp false_exp))
    | [%expr false],_
      when self#enabled Mutaml_common.Bool_constant && self#choose_to_mutate ->
      let true_exp = { e with pexp_desc = [%expr true].pexp_desc } in
      return (self#mutaml_mutant ctx loc true_exp e (string_of_exp true_exp))

    | [%expr [%e? _] + [%e? _]],_
    | [%expr [%e? _] - [%e? _]],_
    | [%expr [%e? _] * [%e? _]],_
    | [%expr [%e? _] / [%e? _]],_
    | [%expr [%e? _] mod [%e? _]],_
      when (self#enabled Mutaml_common.Arith_operator
            || self#enabled Mutaml_common.Arith_identity)
        && self#choose_to_mutate ->
      self#mutate_arithmetic ctx e

    (* move a comparison by one boundary *)
    | [%expr [%e? _] <  [%e? _]],_
    | [%expr [%e? _] <= [%e? _]],_
    | [%expr [%e? _] >  [%e? _]],_
    | [%expr [%e? _] >= [%e? _]],_
      when self#enabled Mutaml_common.Compare_boundary && self#choose_to_mutate ->
      self#mutate_arithmetic ctx e

    (* negate an equality test *)
    | [%expr [%e? _] =  [%e? _]],_
    | [%expr [%e? _] <> [%e? _]],_
      when self#enabled Mutaml_common.Compare_negation && self#choose_to_mutate ->
      self#mutate_arithmetic ctx e

    (* swap a Boolean connective, keeping its short-circuit behaviour *)
    | [%expr [%e? _] && [%e? _]],_
    | [%expr [%e? _] || [%e? _]],_
      when self#enabled Mutaml_common.Connective && self#choose_to_mutate ->
      self#mutate_shortcircuit ctx e

    (* drop a negation *)
    | [%expr not [%e? exp]],_
      when self#enabled Mutaml_common.Not_expression && self#choose_to_mutate ->
      self#mutate_not ctx e exp

    (* negate a call of a typed equality function, such as String.equal *)
    | _, Pexp_apply ({ pexp_desc = Pexp_ident { txt = path; _ }; _ },
                     [(Nolabel,_); (Nolabel,_)])
      when is_equal_function path
        && self#enabled Mutaml_common.Equal_function && self#choose_to_mutate ->
      self#mutate_equal_function ctx e

    | _, Pexp_constant c when self#choose_to_mutate ->
      let c' = self#mutate_constant ctx c in
      if c = c' then return e else
        let e_new = { e with pexp_desc = Pexp_constant c' } in
        return (self#mutaml_mutant ctx loc e_new e (string_of_exp e_new))

    (* [Some e] becomes [None]. Both have type ['a option], so the
       mutant compiles, unless the program defines its own constructor
       named [Some] in a type that has no [None]. The preprocessor
       cannot see that, so a program that does so must turn this
       operator off with -some-to-none false. *)
    | _, Pexp_construct ({ txt = Lident "Some"; _ }, Some _)
      when self#enabled Mutaml_common.Some_to_none && self#choose_to_mutate ->
      super#expression ctx e >>| fun e' ->
      let none_exp = { e with pexp_desc = [%expr None].pexp_desc } in
      self#mutaml_mutant ctx loc none_exp e' (string_of_exp none_exp)

    (* off by one on an integer argument of a call whose argument
       types the table knows *)
    | _, Pexp_apply (({ pexp_desc = Pexp_ident { txt = path; _ }; _ } as fn), args)
      when self#enabled Mutaml_common.Argument_off_by_one
        && int_argument_positions path <> []
        && self#choose_to_mutate ->
      self#mutate_int_arguments ctx e fn (int_argument_positions path) args

    (* off by one on the integer result of a call whose result type
       the table knows *)
    | _, Pexp_apply ({ pexp_desc = Pexp_ident { txt = path; _ }; _ }, _)
      when self#enabled Mutaml_common.Argument_off_by_one
        && has_int_result path
        && self#choose_to_mutate ->
      self#mutate_int_result ctx e

    (* we negate an if's condition rather than swapping its branches:
        * it avoids duplication
        * it works for 1-armed ifs too
                                           if
                                             (let __MUTAML_TMP__ = e0 in
           if e0 then e1 else e2     ~~>      if __is_mutaml_mutant__ [%e mut_id_exp]
                                              then not __MUTAML_TMP__ else __MUTAML_TMP__)
                                           then e1
                                           else e2       *)
    | _, Pexp_ifthenelse (e0,e1,e2_opt)
      when self#enabled Mutaml_common.If_condition && self#choose_to_mutate ->
      self#expression ctx e0 >>= fun e0' ->
      self#expression ctx e1 >>= fun e1' ->
      let cont e2_opt' =
      let k, tmp_var = self#let_bind ~loc:e0.pexp_loc e0' in
      let e0'_guarded =
        k (self#mutaml_mutant ctx e0.pexp_loc (*loc*)
             [%expr not [%e tmp_var]]
             [%expr [%e tmp_var]]
             (string_of_exp [%expr not [%e e0]])) in
        { e with pexp_desc = Pexp_ifthenelse (e0'_guarded,e1',e2_opt') }
      in
      (match e2_opt with
       | None -> return (cont None)
       | Some e2 -> self#expression ctx e2 >>| fun e2' -> cont (Some e2'))

    (* omit a unit-expression in a sequence:

                             (if __is_mutaml_mutant__ [%e mut_id_exp]
       e0; e1  ~~>            then ()
                              else e0'); e'  *)
    | _, Pexp_sequence (e0,e1)
      when self#enabled Mutaml_common.Sequence && self#choose_to_mutate ->
      self#expression ctx e0 >>= fun e0' ->
      self#expression ctx e1 >>| fun e1' ->
      let e0'' =
        self#mutaml_mutant ctx loc(*e0.pexp_loc*) [%expr ()] e0' (string_of_exp e1) in
      { e0 with pexp_desc = Pexp_sequence (e0'',e1') }

    (* From ppxlib 0.36 on, one constructor holds both 'fun p -> e' and
       'function | ...'. The third field says which: [Pfunction_body] for
       the first, [Pfunction_cases] for the second. Only the case form
       needs the treatment below, so the body form falls through to the
       default branch. Walk the parameters as well, so that the default
       value of an optional parameter is still mutated. *)
    | _, Pexp_function (params, constr, Pfunction_cases (cases, cases_loc, cases_attrs)) ->
      self#list self#function_param ctx params >>= fun params ->
      self#cases ctx cases >>| fun cases_pure -> (* all cases are pure in 'function' *)
      let body = Pfunction_cases (cases_pure, cases_loc, cases_attrs) in
      let function_ = { e with pexp_desc = Pexp_function (params, constr, body) } in
      if Match.cases_contain_matching_patterns cases_pure
      then
        Exp.attr function_ (* disable pattern-match warning *)
          { attr_name = {txt = "ocaml.warning"; loc};
            attr_payload = PStr [[%stri "-8"]];
            attr_loc = loc }
      else function_

    | _, Pexp_match (me,cases) ->
      super#expression ctx me >>= fun me ->
      self#cases ctx cases >>| fun cases ->
      let cases_pure = List.filter (fun c -> not (Match.pat_matches_exception c.pc_lhs)) cases in
      let match_ = { e with pexp_desc = Pexp_match (me, cases) } in
      if Match.cases_contain_matching_patterns cases_pure
      then
        Exp.attr match_ (* disable pattern-match warning *)
          { attr_name = {txt = "ocaml.warning"; loc};
            attr_payload = PStr [[%stri "-8"]];
            attr_loc = loc }
      else match_
    | _ ->
      super#expression ctx e

  (* don't mutate attribute parameters such as 'false' in [@@deriving show {with_path=false}] *)
  method! attributes _ctx attrs = return attrs

  method transform_impl_file ctx impl_ast =
    let input_name = Base_exp_context.input_name ctx in
    Printf.printf "Running mutaml instrumentation on \"%s\"\n%!" input_name;
    Printf.printf "Randomness seed: %i   %!" !Options.seed;
    Printf.printf "Mutation rate: %i   %!"   !Options.mut_rate;
    Printf.printf "GADTs enabled: %s\n%!"    (Bool.to_string !Options.gadt);

    let instrumented_ast,errs = super#structure ctx impl_ast in
    let errs =
      List.map (fun error ->
          Ast_builder.Default.pstr_extension
            ~loc:(Location.Error.get_location error)
            (Location.Error.to_extension error)
            []) errs in
    let mut_count = List.length mutations in
    Printf.printf "Created %i mutation%s of %s\n%!" mut_count (if mut_count=1 then "" else "s") input_name;

    let () = write_muts_file input_name mutations in
    errs @ (add_preamble instrumented_ast input_name)
end
