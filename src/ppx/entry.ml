(** Helper module for command line interface *)
module CLI =
struct
  (* this part is primarily for the CLI *)
  let seed     = ref None
  let mut_rate = ref None
  let gadt     = ref None

  let invalid_rate rate = rate < 0 || rate > 100
  let set_seed s = (seed := Some s)
  let set_rate rate =
    if invalid_rate rate
    then raise (Arg.Bad (Printf.sprintf "Invalid mutation rate: %i" rate))
    else mut_rate := Some rate
  let set_gadt s = (gadt := Some s)

  (* One entry for each mutation operator that this fork adds:
     the operator, the switch the preprocessor reads, the default of
     that switch, and the value the command line gave, if any. The
     default is the value the switch holds now, before anything has
     set it. *)
  let operators =
    List.map
      (fun (kind,switch) -> (kind, switch, !switch, ref None))
      Mutaml_ppx.Options.switches

  (* An option for each operator: "-compare-boundary false" turns the
     compare-boundary operator off. *)
  let operator_arg_spec =
    List.map
      (fun (kind,_switch,default,cli_arg) ->
         ("-" ^ Mutaml_common.kind_name kind,
          Arg.Bool (fun b -> cli_arg := Some b),
          Printf.sprintf " Use the %s mutation operator (default: %b)"
            (Mutaml_common.kind_name kind) default))
      operators

  let arg_spec = [
    ("-seed",     Arg.Int set_seed,  " Set randomness seed for mutaml's instrumentation");
    ("-mut-rate", Arg.Int set_rate,  " Set probability in % of mutating a syntax tree node (default: 50%)");
    ("-gadt",     Arg.Bool set_gadt, " Allow only pattern mutations compatible with GADTs (default: true)");
  ] @ operator_arg_spec
end

(** Helper module for environment variables *)
module Env =
struct
  (* select a CLI-arg, an environment variable, or a default value -- in that order *)
  let select_param cli_arg env_var conversion init_default =
    let env_opt = Option.map conversion (Sys.getenv_opt env_var) in
    match cli_arg, env_opt with
    | Some v, _      -> v
    | None  , Some s -> s
    | None  , None   -> init_default()

  let parse_seed s = match int_of_string_opt s with
    | None   -> Mutaml_common.fail_and_exit (Printf.sprintf "Invalid randomness seed: %s" s)
    | Some s -> s

  let parse_mut_rate r = match int_of_string_opt r with
    | None   -> Mutaml_common.fail_and_exit (Printf.sprintf "Invalid mutation rate: %s" r)
    | Some r ->
      if CLI.invalid_rate r
      then Mutaml_common.fail_and_exit (Printf.sprintf "Invalid mutation rate: %i" r)
      else r

  let parse_gadt g = match bool_of_string_opt g with
    | None   -> Mutaml_common.fail_and_exit (Printf.sprintf "Invalid gadt string: %s" g)
    | Some b -> b

  (* [parse_operator var b] reads the value [b] that the environment
     variable [var] holds. A value that is neither "true" nor "false"
     ends the preprocessor with a message that names the variable. *)
  let parse_operator var b = match bool_of_string_opt b with
    | None   -> Mutaml_common.fail_and_exit
                  (Printf.sprintf "Invalid %s string: %s" var b)
    | Some b -> b

  (* Set each operator switch from the command line option, or from
     the environment variable, or from the default, in that order. *)
  let set_operators () =
    List.iter
      (fun (kind,switch,default,cli_arg) ->
         let var = Mutaml_common.kind_env_var kind in
         switch :=
           select_param !cli_arg var (parse_operator var) (fun () -> default))
      CLI.operators
end

let () =
  List.iter (fun (opt,spec,doc) -> Ppxlib.Driver.add_arg opt spec ~doc) (Arg.align CLI.arg_spec)

let instrumentation =
  let impl_mapper ctx ast =
    Mutaml_ppx.Options.seed :=
      Env.select_param !CLI.seed "MUTAML_SEED" Env.parse_seed RS.make_random_seed;
    Mutaml_ppx.Options.mut_rate :=
      Env.select_param !CLI.mut_rate "MUTAML_MUT_RATE" Env.parse_mut_rate (fun () -> 50);
    Mutaml_ppx.Options.gadt :=
      Env.select_param !CLI.gadt "MUTAML_GADT" Env.parse_gadt (fun () -> true);
    Env.set_operators ();
    let mapper_obj = new Mutaml_ppx.mutate_mapper (RS.init !Mutaml_ppx.Options.seed) in
    mapper_obj#transform_impl_file ctx ast in
  Ppxlib.Driver.Instrument.V2.make ~position:Before impl_mapper

let () = Ppxlib.Driver.V2.register_transformation ~instrument:instrumentation "mutaml"
