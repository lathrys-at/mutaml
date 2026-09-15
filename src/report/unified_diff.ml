(* Lines of context on each side of the change, as [diff -u] uses. *)
let context = 3

(* The lines of [s], without the newline that ends each of them. A
   newline at the end of [s] ends the last line; it does not start an
   empty one. The empty text has no line. *)
let split_lines s =
  if String.equal s "" then []
  else
    let parts = String.split_on_char '\n' s in
    match List.rev parts with
    | "" :: rest -> List.rev rest
    | _          -> parts

(* The number of newlines in the first [upto] bytes of [s], which is the
   index of the line that byte [upto] belongs to, counting from 0. *)
let line_index s upto =
  let rec count i acc =
    if i >= upto then acc
    else count (i+1) (if Char.equal s.[i] '\n' then acc + 1 else acc)
  in
  count 0 0

(* The elements of [l] from index [first] up to and including index
   [last]. The result is empty when [last] is below [first]. *)
let slice l ~first ~last =
  List.filteri (fun i _ -> first <= i && i <= last) l

(* The line range of a hunk, in the form that a unified diff prints
   after [-] or [+]. [start] counts from 1. A range of one line is the
   line alone; an empty range names the line before it, as [diff] does. *)
let range ~start ~count =
  if count = 1 then string_of_int start
  else Printf.sprintf "%i,%i" (if count = 0 then start - 1 else start) count

let unified ~old_label ~new_label ~contents ~start ~stop ~repl =
  let length = String.length contents in
  if not (Mutaml_common.range_fits ~start ~stop ~length)
  then
    invalid_arg
      (Printf.sprintf
         "Unified_diff.unified: the range %i to %i is not inside a text of %i bytes"
         start stop length);
  let mutated =
    String.sub contents 0 start ^ repl
    ^ String.sub contents stop (length - stop) in
  if String.equal contents mutated then "" else
  let old_lines = split_lines contents in
  let new_lines = split_lines mutated in
  let old_count = List.length old_lines in
  let new_count = List.length new_lines in
  (* The lines that the replacement touches run from [first] to [last]
     in the file, counting from 0. The byte before [stop] is the last
     byte that goes away, so its line is the last line touched. An
     empty range touches the line that it sits on. *)
  let first = line_index contents start in
  let last = line_index contents (if stop > start then stop - 1 else start) in
  (* Every line after the touched ones is the same in both texts, so the
     replacement wrote as many lines as the file gained or lost. *)
  let tail = old_count - last - 1 in
  let new_last = new_count - tail - 1 in
  let ctx_first = max 0 (first - context) in
  let ctx_last = min (old_count - 1) (last + context) in
  let before = slice old_lines ~first:ctx_first ~last:(first - 1) in
  let after  = slice old_lines ~first:(last + 1) ~last:ctx_last in
  let removed = slice old_lines ~first ~last in
  let added   = slice new_lines ~first ~last:new_last in
  let buf = Buffer.create 256 in
  let line prefix text =
    Buffer.add_string buf prefix;
    Buffer.add_string buf text;
    Buffer.add_char buf '\n' in
  Buffer.add_string buf (Printf.sprintf "--- %s\n" old_label);
  Buffer.add_string buf (Printf.sprintf "+++ %s\n" new_label);
  let shown_before = List.length before and shown_after = List.length after in
  Buffer.add_string buf
    (Printf.sprintf "@@ -%s +%s @@\n"
       (range ~start:(ctx_first + 1)
          ~count:(shown_before + List.length removed + shown_after))
       (range ~start:(ctx_first + 1)
          ~count:(shown_before + List.length added + shown_after)));
  List.iter (line " ") before;
  List.iter (line "-") removed;
  List.iter (line "+") added;
  List.iter (line " ") after;
  Buffer.contents buf
