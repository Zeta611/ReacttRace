open Base
(* open Stdio *)

exception Invalid_hook_call
exception Incompatible_useEffect

module React = struct
  type state = Univ.t
  type props = Univ.t
  type state_eq = state -> state -> bool

  type component = Null | Composite of composite_component
  and composite_component = { name : string; body : props -> ui_element list }
  and ui_element = { component : component; props : props }

  type dependencies = Dependencies of state list | No_dependencies
  type state_list = (int, state) Hashtbl.t
  type effect = unit -> unit
  type effect_list = (int, dependencies) Hashtbl.t
  type effect_queue = effect list

  type view_tree =
    | Leaf_node
    | Tree of {
        name : string;
        children : view_tree list;
        states : state_list;
        effects : effect_list;
      }

  let view_tree : view_tree option ref = ref None
  let current_states : state_list option ref = ref None
  let current_effects : effect_list option ref = ref None
  let queued_effects : effect_queue ref = ref []
  let state_index = ref 0
  let effect_index = ref 0
  let create_state_list () = Hashtbl.create (module Int)
  let create_effect_list () = Hashtbl.create (module Int)

  let set_states_effects states effects =
    state_index := 0;
    effect_index := 0;
    current_states := Some states;
    current_effects := Some effects

  let run_effects () =
    List.iter !queued_effects ~f:(fun f -> f ());
    queued_effects := []

  let render (element : ui_element) : ui_element =
    let rec children_tree ?prev_bundle { name; body } props =
      let prev_children, states, effects =
        match prev_bundle with
        | None -> (None, create_state_list (), create_effect_list ())
        | Some (prev_children, states, effects) ->
            (Some prev_children, states, effects)
      in
      set_states_effects states effects;

      let children = body props in
      let child_trees =
        match prev_children with
        | None -> List.map ~f:(fun child -> get_view_tree child None) children
        | Some prev_children ->
            List.mapi
              ~f:(fun i child -> get_view_tree child (List.nth prev_children i))
              children
      in
      Tree { name; children = child_trees; states; effects }
    and get_view_tree { component; props } view_tree =
      match component with
      | Null -> Leaf_node
      | Composite ({ name; _ } as c) ->
          let prev_bundle =
            match view_tree with
            | None (* Initial render *) | Some Leaf_node -> None
            | Some (Tree { name = prev_name; children; states; effects }) ->
                (* Re-render *)
                if String.(name <> prev_name) then
                  (* Replaced; previous tree is obsolete *)
                  None
                else
                  (* Keep track of the previous tree structure to mirror the recursion *)
                  Some (children, states, effects)
          in
          children_tree ?prev_bundle c props
    in
    view_tree := Some (get_view_tree element !view_tree);
    run_effects ();
    element

  let useState (init : state) : state * (state -> unit) =
    match !current_states with
    | None -> raise Invalid_hook_call
    | Some states ->
        let state =
          match Hashtbl.find states !state_index with
          | Some state -> state
          | None -> init
        in
        let index_curr = !state_index in
        let setState new_val =
          Hashtbl.set states ~key:index_curr ~data:new_val
        in
        Int.incr state_index;
        (state, setState)

  let useEffect (f : effect) ?(dependencies : (state * state_eq) list option) ()
      : unit =
    match !current_effects with
    | None -> raise Invalid_hook_call
    | Some effects ->
        let old_deps = Hashtbl.find effects !effect_index in
        let has_changed =
          match (old_deps, dependencies) with
          | Some (Dependencies old_deps), Some dependencies
            when List.length old_deps
                 = List.length dependencies (* Re-render with useEffect *) ->
              List.existsi dependencies ~f:(fun i (new_state, compare) ->
                  not (compare new_state (List.nth_exn old_deps i)))
          | Some No_dependencies, None (* Re-render with useEffect0 *)
          | None, None (* Initial render with useEffect0 *)
          | None, Some _ (* Initial render with useEffect *) ->
              true
          | _, _ -> raise Incompatible_useEffect
        in
        if has_changed then queued_effects := f :: !queued_effects;
        let new_dependencies =
          match dependencies with
          | Some dependencies -> Dependencies (List.map dependencies ~f:fst)
          | None -> No_dependencies
        in
        Hashtbl.set effects ~key:!effect_index ~data:new_dependencies;
        Int.incr effect_index

  let reset () =
    view_tree := None;
    current_states := None;
    current_effects := None;
    state_index := 0;
    effect_index := 0
end
