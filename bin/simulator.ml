open Base
open Stdio
open React_trace
open Simulator.React
module Uint = Univ.Make_univ (Int)
module Ustring = Univ.Make_univ (String)
module Uunit = Univ.Make_univ (Unit)

module Uint_to_unit = Univ.Make_univ (struct
  type t = int -> unit

  let ( = ) _ _ = false
end)

(* let component () =
     let count, setCount = useState (Uint.create 0) in
     let text, setText = useState (Ustring.create "") in

     useEffect0 (fun () -> printf "render\n");
     useEffect (fun () -> printf "no deps\n") [];
     useEffect (fun () -> printf "count\n") [ (count, Uint.( = )) ];
     useEffect (fun () -> printf "text\n") [ (text, Ustring.( = )) ];
     useEffect
       (fun () -> printf "all deps\n")
       [ (count, Uint.( = )); (text, Ustring.( = )) ];

     object
       method render =
         let count, text = (Uint.match_exn count, Ustring.match_exn text) in
         printf "{ count : %d ; text : \"%s\" }\n" count text

       method click =
         let count = Uint.match_exn count in
         setCount (Uint.create (count + 1))

       method write s =
         let text = Ustring.match_exn text in
         setText (Ustring.create (text ^ s))
     end

   let () =
     printf "=== Deps test ===\n";
     reset ();
     let c = render component in
     c#click;
     let c = render component in
     c#click;
     c#write "Hello, ";
     let c = render component in
     c#click;
     let c = render component in
     c#write "React!";
     render component |> ignore *)

let great_grandchild =
  Composite
    {
      name = "GGC";
      body =
        (fun _unit ->
          useEffect0 (fun () -> printf "great-grandchild\n");
          [ { component = Null; props = Uunit.create () } ]);
    }

let grandchild =
  Composite
    {
      name = "GC";
      body =
        (fun f ->
          let show, setShow = useState (Uint.create 0) in
          useEffect0 (fun () ->
              printf "grandchild\n";
              (Uint_to_unit.match_exn f) 0;
              setShow (Uint.create 1));
          if Uint.match_exn show = 0 then
            [ { component = Null; props = Uunit.create () } ]
          else [ { component = great_grandchild; props = Uunit.create () } ]);
    }

let child =
  Composite
    {
      name = "C";
      body =
        (fun f ->
          useEffect0 (fun () ->
              printf "child\n";
              (Uint_to_unit.match_exn f) 1);
          [ { component = grandchild; props = f } ]);
    }

let parent =
  Composite
    {
      name = "P";
      body =
        (fun _unit ->
          let show, setShow = useState (Uint.create 1) in
          useEffect0 (fun () -> printf "parent\n");
          if Uint.match_exn show = 0 then
            [ { component = Null; props = Uunit.create () } ]
          else
            [
              {
                component = child;
                props = Uint_to_unit.create (fun x -> setShow (Uint.create x));
              };
            ]);
    }

let () =
  reset ();
  printf "=== Chain test [WIP] ===\n";
  let e = render { component = parent; props = Uunit.create () } in
  let e = render e in
  render e |> ignore
