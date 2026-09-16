(* [is_directory path] says whether [path] is a directory now. A name
   that another process took away between the two questions is not a
   directory, and is not an error either. *)
let is_directory path =
  try Sys.is_directory path with Sys_error _ -> false

let rec ensure path =
  if Sys.file_exists path
  then
    (if not (is_directory path)
     then raise (Sys_error (path ^ " is there and is not a directory")))
  else
    begin
      let parent = Filename.dirname path in
      if not (String.equal parent path) then ensure parent;
      (* Another process may make the same directory in between. *)
      try Sys.mkdir path 0o755 with
      | Sys_error _ when is_directory path -> ()
    end
