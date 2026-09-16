let placeholder = "{}"

(* [replace ~pattern ~by text] is [text] with every run of characters
   equal to [pattern] replaced by [by]. [pattern] holds at least one
   character. *)
let replace ~pattern ~by text =
  let plen = String.length pattern in
  let tlen = String.length text in
  let buf = Buffer.create tlen in
  let rec scan i =
    if i >= tlen
    then ()
    else if i + plen <= tlen && String.sub text i plen = pattern
    then (Buffer.add_string buf by; scan (i + plen))
    else (Buffer.add_char buf text.[i]; scan (i + 1))
  in
  scan 0;
  Buffer.contents buf

let expand ~run env =
  let number = string_of_int run in
  List.map
    (fun (name, value) -> (name, replace ~pattern:placeholder ~by:number value))
    env
