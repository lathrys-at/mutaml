open Mutaml_common

type t =
  {
    total     : int;
    passed    : test_result list;
    failed    : test_result list;
    crashed   : test_result list;
    timed_out : test_result list;
  }

let of_results results =
  let empty = { total = 0; passed = []; failed = []; crashed = []; timed_out = [] } in
  let add t res =
    let t = { t with total = t.total + 1 } in
    match outcome_of_status res.status with
    | Passed    -> { t with passed    = res :: t.passed }
    | Failed    -> { t with failed    = res :: t.failed }
    | Crashed   -> { t with crashed   = res :: t.crashed }
    | Timed_out -> { t with timed_out = res :: t.timed_out }
  in
  let t = List.fold_left add empty results in
  { t with
    passed    = List.rev t.passed;
    failed    = List.rev t.failed;
    crashed   = List.rev t.crashed;
    timed_out = List.rev t.timed_out }

let total t = t.total

let with_outcome t = function
  | Passed    -> t.passed
  | Failed    -> t.failed
  | Crashed   -> t.crashed
  | Timed_out -> t.timed_out

let count t outcome = List.length (with_outcome t outcome)

let detected t = t.total - List.length t.passed

let score t =
  if t.total = 0
  then invalid_arg "Summary.score: no test results"
  else 100. *. float_of_int (detected t) /. float_of_int t.total

let source_file res = res.mutant.loc.loc_start.pos_fname

let by_file results =
  let files = List.sort_uniq String.compare (List.map source_file results) in
  List.map
    (fun file -> (file, List.filter (fun res -> String.equal file (source_file res)) results))
    files
