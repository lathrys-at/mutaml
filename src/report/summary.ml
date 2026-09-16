open Mutaml_common

type t =
  {
    total     : int;
    passed    : test_result list;
    failed    : test_result list;
    crashed   : test_result list;
    timed_out : test_result list;
    not_run   : test_result list;
  }

let of_results results =
  let empty =
    { total = 0; passed = []; failed = []; crashed = []; timed_out = [];
      not_run = [] } in
  let add t (res : test_result) =
    let t = { t with total = t.total + 1 } in
    (* A mutation that did not run has no exit status, so the field that
       says it did not run is asked first. *)
    if res.not_run then { t with not_run = res :: t.not_run }
    else
      match outcome_of_status res.status with
      | Passed    -> { t with passed    = res :: t.passed }
      | Failed    -> { t with failed    = res :: t.failed }
      | Crashed   -> { t with crashed   = res :: t.crashed }
      | Timed_out -> { t with timed_out = res :: t.timed_out }
      | Not_run   -> { t with not_run   = res :: t.not_run }
  in
  let t = List.fold_left add empty results in
  { t with
    passed    = List.rev t.passed;
    failed    = List.rev t.failed;
    crashed   = List.rev t.crashed;
    timed_out = List.rev t.timed_out;
    not_run   = List.rev t.not_run }

let total t = t.total

let with_outcome t = function
  | Passed    -> t.passed
  | Failed    -> t.failed
  | Crashed   -> t.crashed
  | Timed_out -> t.timed_out
  | Not_run   -> t.not_run

let count t outcome = List.length (with_outcome t outcome)

let scored t = t.total - List.length t.not_run

let detected t = scored t - List.length t.passed

let score t =
  if scored t = 0
  then invalid_arg "Summary.score: no mutation ran"
  else 100. *. float_of_int (detected t) /. float_of_int (scored t)

let group_by_file file_of items =
  let files = List.sort_uniq String.compare (List.map file_of items) in
  List.map
    (fun file ->
       (file, List.filter (fun item -> String.equal file (file_of item)) items))
    files

let source_file res = res.mutant.loc.loc_start.pos_fname

let by_file results = group_by_file source_file results

let skipped_file (s : skipped) = s.loc.loc_start.pos_fname

let skipped_by_file skipped = group_by_file skipped_file skipped
