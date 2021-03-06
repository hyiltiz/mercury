%---------------------------------------------------------------------------%
% vim: ft=mercury ts=4 sw=4 et
%---------------------------------------------------------------------------%
% Copyright (C) 1995-2012 The University of Melbourne.
% This file may only be copied under the terms of the GNU General
% Public License - see the file COPYING in the Mercury distribution.
%---------------------------------------------------------------------------%
%
% File: common.m.
% Original author: squirrel (Jane Anna Langley).
% Some bugs fixed by fjh.
% Extensive revision by zs.
% More revision by stayl.
%
% This module attempts to optimise out instances where a variable is
% decomposed and then soon after reconstructed from the parts. If possible we
% would like to "short-circuit" this process.  It also optimizes
% deconstructions of known cells, replacing them with assignments to the
% arguments where this is guaranteed to not increase the number of stack slots
% required by the goal.  Repeated calls to predicates with the same input
% arguments are replaced by assignments and warnings are returned.
%
% IMPORTANT: This module does a small subset of the job of compile-time
% garbage collection, but it does so without paying attention to uniqueness
% information, since the compiler does not yet have such information.  Once we
% implement ctgc, the assumptions made by this module will have to be
% revisited.
%
%---------------------------------------------------------------------------%

:- module check_hlds.common.
:- interface.

:- import_module check_hlds.simplify.
:- import_module hlds.
:- import_module hlds.hlds_goal.
:- import_module hlds.hlds_pred.
:- import_module parse_tree.
:- import_module parse_tree.prog_data.

:- import_module list.

%---------------------------------------------------------------------------%

    % If we find a deconstruction or a construction we cannot optimize, record
    % the details of the memory cell in CommonInfo.
    %
    % If we find a construction that constructs a cell identical to one we
    % have seen before, replace the construction with an assignment from the
    % variable unified with that cell.
    %
:- pred common_optimise_unification(unification::in, unify_mode::in,
    hlds_goal_expr::in, hlds_goal_expr::out,
    hlds_goal_info::in, hlds_goal_info::out,
    simplify_info::in, simplify_info::out) is det.

    % Check whether this call has been seen before and is replaceable, if
    % so produce assignment unification for the non-local output variables,
    % and give a warning.
    % A call is considered replaceable if it has no uniquely moded outputs
    % and no destructive inputs.
    % It is the caller's responsibility to check that the call is pure.
    %
:- pred common_optimise_call(pred_id::in, proc_id::in, list(prog_var)::in,
    hlds_goal_info::in, hlds_goal_expr::in, hlds_goal_expr::out,
    simplify_info::in, simplify_info::out) is det.

:- pred common_optimise_higher_order_call(prog_var::in, list(prog_var)::in,
    list(mer_mode)::in, determinism::in, hlds_goal_info::in,
    hlds_goal_expr::in, hlds_goal_expr::out,
    simplify_info::in, simplify_info::out) is det.

    % Succeeds if the two variables are equivalent according to the specified
    % equivalence class.
    %
:- pred common_vars_are_equivalent(prog_var::in, prog_var::in,
    common_info::in) is semidet.

    % Assorted stuff used here that simplify.m doesn't need to know about.
    %
:- type common_info.
:- func common_info_init = common_info.

    % Clear the list of structs seen since the last stack flush.
    %
:- pred common_info_clear_structs(common_info::in, common_info::out) is det.

%---------------------------------------------------------------------------%
%---------------------------------------------------------------------------%

:- implementation.

:- import_module check_hlds.det_report.
:- import_module check_hlds.inst_match.
:- import_module check_hlds.mode_util.
:- import_module hlds.hlds_module.
:- import_module hlds.hlds_rtti.
:- import_module hlds.instmap.
:- import_module libs.
:- import_module libs.options.
:- import_module parse_tree.error_util.
:- import_module parse_tree.prog_type.
:- import_module parse_tree.set_of_var.
:- import_module transform_hlds.
:- import_module transform_hlds.pd_cost.

:- import_module bool.
:- import_module eqvclass.
:- import_module map.
:- import_module maybe.
:- import_module pair.
:- import_module require.
:- import_module set.
:- import_module term.

%---------------------------------------------------------------------------%

    % The var_eqv field records information about which sets of variables are
    % known to be equivalent, usually because they have been unified.  This is
    % useful when eliminating duplicate unifications and when eliminating
    % duplicate calls.
    %
    % The all_structs and since_call_structs fields record information about
    % the memory cells available for reuse. The all_structs field has info
    % about all the cells available at the current program point.  The
    % since_call_structs field contains info about the subset of these cells
    % that have been seen since the last stack flush, which is usually a call.
    %
    % The reason why we make the distinction between structs seen before the
    % last call and structs seen after is best explained by these two program
    % fragments:
    %
    % fragment 1:
    %   X => f(A1, A2, A3, A4),
    %   X => f(B1, B2, B3, B4),
    %
    % fragment 2:
    %   X => f(A1, A2, A3, A4),
    %   p(...),
    %   X => f(B1, B2, B3, B4),
    %
    % In fragment 1, we want to replace the second deconstruction with
    % the assignments B1 = A1, ... B4 = A4, since this can avoid the
    % second check of X's function symbol. (If the inst of X at the start
    % of the second unification is `bound(f(...))', we can dispense with
    % this test anyway, but if the two unifications are brought together
    % by inlining, then X's inst then may simply be `ground'.)
    %
    % In fragment 2, we don't want make the same transformation, because
    % doing so would require storing A1 ... A4 across the call instead of
    % just X.
    %
    % If the second unification were a construction instead of a
    % deconstruction, we want to make the transformation in both cases,
    % because the heap allocation we thus avoid is quite expensive,
    % and because it actually reduces the number of stack slots we need
    % across the call (X instead of A1 .. A4). The exception is
    % constructions using function symbols of arity zero, which we
    % never need to eliminate. We process unifications with constants
    % only to update our information about variable equivalences: after
    % X = c and Y = c, X and Y are equivalent.
    %
    % The seen_calls field records which calls we have seen, which we use
    % to eliminate duplicate calls.

:- type common_info
    --->    common_info(
                var_eqv                 :: eqvclass(prog_var),
                all_structs             :: struct_map,
                since_call_structs      :: struct_map,
                seen_calls              :: seen_calls
            ).

    % A struct_map maps a principal type constructor and a cons_id of that
    % type to information about cells involving that cons_id.
    %
    % The reason why we need the principal type constructors is that two
    % syntactically identical structures have compatible representations if and
    % only if their principal type constructors are the same.  For example, if
    % we have:
    %
    %   :- type maybe_err(T) ---> ok(T) ; err(string).
    %
    %   :- pred p(maybe_err(foo)::in, maybe_err(bar)::out) is semidet.
    %   p(err(X), err(X)).
    %
    % then we want to reuse the `err(X)' in the first arg rather than
    % constructing a new copy of it for the second arg.
    % The two occurrences of `err(X)' have types `maybe_err(int)'
    % and `maybe(float)', but we know that they have the same
    % representation.
    %
    % We put the cons_id first in the pair because there are more cons_ids
    % than type constructors, and hence comparisons involving cons_ids are
    % more likely to fail. This should ensure that failed comparisons in map
    % searches fail as soon as possible.

:- type cons_id_map  ==  map(cons_id, structures).
:- type struct_map  ==  map(type_ctor, cons_id_map).

    % Given a unification X = f(Y1, ... Yn), we record its availability for
    % reuse by creating structure(X, [Y1, ... Yn]), and putting it at the
    % front of the list of structures for the entry for f and X's type_ctor.

:- type structures == list(structure).
:- type structure
    --->    structure(prog_var, list(prog_var)).

:- type seen_calls  ==  map(seen_call_id, list(call_args)).

:- type call_args
    --->    call_args(
                % The context of the call, for use in warnings about
                % duplicate calls.
                prog_context,

                % The input arguments. For higher-order calls, the closure
                % is the first input argument.
                list(prog_var),

                % The output arguments.
                list(prog_var)
            ).

%---------------------------------------------------------------------------%

common_info_init = CommonInfo :-
    eqvclass.init(VarEqv0),
    map.init(StructMap0),
    map.init(SeenCalls0),
    CommonInfo = common_info(VarEqv0, StructMap0, StructMap0, SeenCalls0).

common_info_clear_structs(!Info) :-
    !Info ^ since_call_structs := map.init.

%---------------------------------------------------------------------------%

common_optimise_unification(Unification0, Mode,
        GoalExpr0, GoalExpr, GoalInfo0, GoalInfo, !Info) :-
    (
        Unification0 = construct(Var, ConsId, ArgVars, _, _, _, SubInfo),
        (
            SubInfo = construct_sub_info(MaybeTakeAddr, _),
            MaybeTakeAddr = yes(_)
        ->
            GoalExpr = GoalExpr0,
            GoalInfo = GoalInfo0
        ;
            common_optimise_construct(Var, ConsId, ArgVars, Mode,
                GoalExpr0, GoalExpr, GoalInfo0, GoalInfo, !Info)
        )
    ;
        Unification0 = deconstruct(Var, ConsId, ArgVars, UniModes, CanFail, _),
        common_optimise_deconstruct(Var, ConsId, ArgVars, UniModes, CanFail,
            Mode, GoalExpr0, GoalExpr, GoalInfo0, GoalInfo, !Info)
    ;
        Unification0 = assign(Var1, Var2),
        record_equivalence(Var1, Var2, !Info),
        GoalExpr = GoalExpr0,
        GoalInfo = GoalInfo0
    ;
        Unification0 = simple_test(Var1, Var2),
        record_equivalence(Var1, Var2, !Info),
        GoalExpr = GoalExpr0,
        GoalInfo = GoalInfo0
    ;
        Unification0 = complicated_unify(_, _, _),
        GoalExpr = GoalExpr0,
        GoalInfo = GoalInfo0
    ).

:- pred common_optimise_construct(prog_var::in, cons_id::in,
    list(prog_var)::in, unify_mode::in,
    hlds_goal_expr::in, hlds_goal_expr::out,
    hlds_goal_info::in, hlds_goal_info::out,
    simplify_info::in, simplify_info::out) is det.

common_optimise_construct(Var, ConsId, ArgVars, Mode, GoalExpr0, GoalExpr,
        GoalInfo0, GoalInfo, !Info) :-
    Mode = LVarMode - _,
    simplify_info_get_module_info(!.Info, ModuleInfo),
    mode_get_insts(ModuleInfo, LVarMode, _, Inst),
    % Don't optimise partially instantiated construction unifications,
    % because it would be tricky to work out how to mode the replacement
    % assignment unifications. In the vast majority of cases, the variable
    % is ground.
    ( inst_is_ground(ModuleInfo, Inst) ->
        TypeCtor = lookup_var_type_ctor(!.Info, Var),
        simplify_info_get_common_info(!.Info, CommonInfo0),
        VarEqv0 = CommonInfo0 ^ var_eqv,
        list.map_foldl(eqvclass.ensure_element_partition_id,
            ArgVars, ArgVarIds, VarEqv0, VarEqv1),
        AllStructMap0 = CommonInfo0 ^ all_structs,
        (
            % generate_assign assumes that the output variable
            % is in the instmap_delta, which will not be true if the
            % variable is local to the unification. The optimization
            % is pointless in that case.
            InstMapDelta = goal_info_get_instmap_delta(GoalInfo0),
            instmap_delta_search_var(InstMapDelta, Var, _),

            map.search(AllStructMap0, TypeCtor, ConsIdMap0),
            map.search(ConsIdMap0, ConsId, Structs),
            find_matching_cell_construct(Structs, VarEqv1, ArgVarIds,
                OldStruct)
        ->
            OldStruct = structure(OldVar, _),
            eqvclass.ensure_equivalence(Var, OldVar, VarEqv1, VarEqv),
            CommonInfo = CommonInfo0 ^ var_eqv := VarEqv,
            simplify_info_set_common_info(CommonInfo, !Info),
            (
                ArgVars = [],
                % Constants don't use memory, so there's no point in
                % optimizing away their construction; in fact, doing so
                % could cause more stack usage.
                GoalExpr = GoalExpr0,
                GoalInfo = GoalInfo0
            ;
                ArgVars = [_ | _],
                UniMode = ((free - Inst) -> (Inst - Inst)),
                generate_assign(Var, OldVar, UniMode, GoalInfo0,
                    GoalExpr, GoalInfo, !Info),
                simplify_info_set_requantify(!Info),
                goal_cost(hlds_goal(GoalExpr0, GoalInfo0), Cost),
                simplify_info_incr_cost_delta(Cost, !Info)
            )
        ;
            GoalExpr = GoalExpr0,
            GoalInfo = GoalInfo0,
            Struct = structure(Var, ArgVars),
            record_cell_in_maps(TypeCtor, ConsId, Struct, VarEqv1, !Info)
        )
    ;
        GoalExpr = GoalExpr0,
        GoalInfo = GoalInfo0
    ).

:- pred common_optimise_deconstruct(prog_var::in, cons_id::in,
    list(prog_var)::in, list(uni_mode)::in, can_fail::in, unify_mode::in,
    hlds_goal_expr::in, hlds_goal_expr::out,
    hlds_goal_info::in, hlds_goal_info::out,
    simplify_info::in, simplify_info::out) is det.

common_optimise_deconstruct(Var, ConsId, ArgVars, UniModes, CanFail, Mode,
        GoalExpr0, GoalExpr, GoalInfo0, GoalInfo, !Info) :-
    simplify_info_get_module_info(!.Info, ModuleInfo),
    (
        % Don't optimise partially instantiated deconstruction unifications,
        % because it would be tricky to work out how to mode the replacement
        % assignment unifications. In the vast majority of cases, the variable
        % is ground.
        Mode = LVarMode - _,
        mode_get_insts(ModuleInfo, LVarMode, Inst0, _),
        \+ inst_is_ground(ModuleInfo, Inst0)
    ->
        GoalExpr = GoalExpr0
    ;
        TypeCtor = lookup_var_type_ctor(!.Info, Var),
        simplify_info_get_common_info(!.Info, CommonInfo0),
        VarEqv0 = CommonInfo0 ^ var_eqv,
        eqvclass.ensure_element_partition_id(Var, VarId, VarEqv0, VarEqv1),
        SinceCallStructMap0 = CommonInfo0 ^ since_call_structs,
        (
            % Do not delete deconstruction unifications inserted by
            % stack_opt.m or tupling.m, which have done a more comprehensive
            % cost analysis than common.m can do.
            \+ goal_info_has_feature(GoalInfo, feature_stack_opt),
            \+ goal_info_has_feature(GoalInfo, feature_tuple_opt),

            map.search(SinceCallStructMap0, TypeCtor, ConsIdMap0),
            map.search(ConsIdMap0, ConsId, Structs),
            find_matching_cell_deconstruct(Structs, VarEqv1, VarId, OldStruct)
        ->
            OldStruct = structure(_, OldArgVars),
            eqvclass.ensure_corresponding_equivalences(ArgVars,
                OldArgVars, VarEqv1, VarEqv),
            CommonInfo = CommonInfo0 ^ var_eqv := VarEqv,
            simplify_info_set_common_info(CommonInfo, !Info),
            create_output_unifications(GoalInfo0, ArgVars, OldArgVars,
                UniModes, Goals, !Info),
            GoalExpr = conj(plain_conj, Goals),
            goal_cost(hlds_goal(GoalExpr0, GoalInfo0), Cost),
            simplify_info_incr_cost_delta(Cost, !Info),
            simplify_info_set_requantify(!Info),
            (
                CanFail = can_fail,
                simplify_info_set_rerun_det(!Info)
            ;
                CanFail = cannot_fail
            )
        ;
            GoalExpr = GoalExpr0,
            Struct = structure(Var, ArgVars),
            record_cell_in_maps(TypeCtor, ConsId, Struct, VarEqv1, !Info)
        )
    ),
    GoalInfo = GoalInfo0.

:- func lookup_var_type_ctor(simplify_info, prog_var) = type_ctor.

lookup_var_type_ctor(Info, Var) = TypeCtor :-
    simplify_info_get_var_types(Info, VarTypes),
    lookup_var_type(VarTypes, Var, Type),
    % If we unify a variable with a function symbol, we *must* know
    % what the principal type constructor of its type is.
    type_to_ctor_det(Type, TypeCtor).

%---------------------------------------------------------------------------%

:- pred find_matching_cell_construct(structures::in, eqvclass(prog_var)::in,
    list(partition_id)::in, structure::out) is semidet.

find_matching_cell_construct([Struct | Structs], VarEqv, ArgVarIds, Match) :-
    Struct = structure(_Var, Vars),
    ( ids_vars_match(ArgVarIds, Vars, VarEqv) ->
        Match = Struct
    ;
        find_matching_cell_construct(Structs, VarEqv, ArgVarIds, Match)
    ).

:- pred find_matching_cell_deconstruct(structures::in, eqvclass(prog_var)::in,
    partition_id::in, structure::out) is semidet.

find_matching_cell_deconstruct([Struct | Structs], VarEqv, VarId, Match) :-
    Struct = structure(Var, _Vars),
    ( id_var_match(VarId, Var, VarEqv) ->
        Match = Struct
    ;
        find_matching_cell_deconstruct(Structs, VarEqv, VarId, Match)
    ).

:- pred ids_vars_match(list(partition_id)::in, list(prog_var)::in,
    eqvclass(prog_var)::in) is semidet.

ids_vars_match([], [], _VarEqv).
ids_vars_match([Id | Ids], [Var | Vars], VarEqv) :-
    id_var_match(Id, Var, VarEqv),
    ids_vars_match(Ids, Vars, VarEqv).

:- pred id_var_match(partition_id::in, prog_var::in, eqvclass(prog_var)::in)
    is semidet.
:- pragma inline(id_var_match/3).

id_var_match(Id, Var, VarEqv) :-
    eqvclass.partition_id(VarEqv, Var, VarId),
    Id = VarId.

%---------------------------------------------------------------------------%

:- pred record_cell_in_maps(type_ctor::in, cons_id::in, structure::in,
    eqvclass(prog_var)::in, simplify_info::in, simplify_info::out) is det.

record_cell_in_maps(TypeCtor, ConsId, Struct, VarEqv, !Info) :-
    some [!CommonInfo] (
        simplify_info_get_common_info(!.Info, !:CommonInfo),
        AllStructMap0 = !.CommonInfo ^ all_structs,
        SinceCallStructMap0 = !.CommonInfo ^ since_call_structs,
        do_record_cell_in_struct_map(TypeCtor, ConsId, Struct,
            AllStructMap0, AllStructMap),
        do_record_cell_in_struct_map(TypeCtor, ConsId, Struct,
            SinceCallStructMap0, SinceCallStructMap),
        !CommonInfo ^ var_eqv := VarEqv,
        !CommonInfo ^ all_structs := AllStructMap,
        !CommonInfo ^ since_call_structs := SinceCallStructMap,
        simplify_info_set_common_info(!.CommonInfo, !Info)
    ).

:- pred do_record_cell_in_struct_map(type_ctor::in, cons_id::in,
    structure::in, struct_map::in, struct_map::out) is det.

do_record_cell_in_struct_map(TypeCtor, ConsId, Struct, !StructMap) :-
    ( map.search(!.StructMap, TypeCtor, ConsIdMap0) ->
        ( map.search(ConsIdMap0, ConsId, Structs0) ->
            Structs = [Struct | Structs0],
            map.det_update(ConsId, Structs, ConsIdMap0, ConsIdMap)
        ;
            map.det_insert(ConsId, [Struct], ConsIdMap0, ConsIdMap)
        ),
        map.det_update(TypeCtor, ConsIdMap, !StructMap)
    ;
        ConsIdMap = map.singleton(ConsId, [Struct]),
        map.det_insert(TypeCtor, ConsIdMap, !StructMap)
    ).

%---------------------------------------------------------------------------%

:- pred record_equivalence(prog_var::in, prog_var::in,
    simplify_info::in, simplify_info::out) is det.

record_equivalence(Var1, Var2, !Info) :-
    simplify_info_get_common_info(!.Info, CommonInfo0),
    VarEqv0 = CommonInfo0 ^ var_eqv,
    eqvclass.ensure_equivalence(Var1, Var2, VarEqv0, VarEqv),
    CommonInfo = CommonInfo0 ^ var_eqv := VarEqv,
    simplify_info_set_common_info(CommonInfo, !Info).

%---------------------------------------------------------------------------%
%---------------------------------------------------------------------------%

common_optimise_call(PredId, ProcId, Args, GoalInfo, GoalExpr0, GoalExpr,
        !Info) :-
    (
        Det = goal_info_get_determinism(GoalInfo),
        check_call_detism(Det),
        simplify_info_get_var_types(!.Info, VarTypes),
        simplify_info_get_module_info(!.Info, ModuleInfo),
        module_info_pred_proc_info(ModuleInfo, PredId, ProcId, _, ProcInfo),
        proc_info_get_argmodes(ProcInfo, ArgModes),
        partition_call_args(VarTypes, ModuleInfo, ArgModes, Args,
            InputArgs, OutputArgs, OutputModes)
    ->
        common_optimise_call_2(seen_call(PredId, ProcId), InputArgs,
            OutputArgs, OutputModes, GoalInfo, GoalExpr0, GoalExpr, !Info)
    ;
        GoalExpr = GoalExpr0
    ).

common_optimise_higher_order_call(Closure, Args, Modes, Det, GoalInfo,
        GoalExpr0, GoalExpr, !Info) :-
    (
        check_call_detism(Det),
        simplify_info_get_var_types(!.Info, VarTypes),
        simplify_info_get_module_info(!.Info, ModuleInfo),
        partition_call_args(VarTypes, ModuleInfo, Modes, Args,
            InputArgs, OutputArgs, OutputModes)
    ->
        common_optimise_call_2(higher_order_call, [Closure | InputArgs],
            OutputArgs, OutputModes, GoalInfo, GoalExpr0, GoalExpr, !Info)
    ;
        GoalExpr = GoalExpr0
    ).

:- pred check_call_detism(determinism::in) is semidet.

check_call_detism(Det) :-
    determinism_components(Det, _, SolnCount),
    % Replacing nondet or multi calls would cause loss of solutions.
    ( SolnCount = at_most_one
    ; SolnCount = at_most_many_cc
    ).

:- pred common_optimise_call_2(seen_call_id::in, list(prog_var)::in,
    list(prog_var)::in, list(mer_mode)::in, hlds_goal_info::in,
    hlds_goal_expr::in, hlds_goal_expr::out,
    simplify_info::in, simplify_info::out) is det.

common_optimise_call_2(SeenCall, InputArgs, OutputArgs, Modes, GoalInfo,
        GoalExpr0, GoalExpr, !Info) :-
    simplify_info_get_common_info(!.Info, CommonInfo0),
    Eqv0 = CommonInfo0 ^ var_eqv,
    SeenCalls0 = CommonInfo0 ^ seen_calls,
    ( map.search(SeenCalls0, SeenCall, SeenCallsList0) ->
        (
            find_previous_call(SeenCallsList0, InputArgs, Eqv0,
                OutputArgs2, PrevContext)
        ->
            simplify_info_get_module_info(!.Info, ModuleInfo),
            modes_to_uni_modes(ModuleInfo, Modes, Modes, UniModes),
            create_output_unifications(GoalInfo, OutputArgs, OutputArgs2,
                UniModes, Goals, !Info),
            GoalExpr = conj(plain_conj, Goals),
            simplify_info_get_var_types(!.Info, VarTypes),
            (
                simplify_do_warn_duplicate_calls(!.Info),
                % Don't warn for cases such as:
                % set.init(Set1 : set(int)),
                % set.init(Set2 : set(float)).
                lookup_var_types(VarTypes, OutputArgs, OutputArgTypes1),
                lookup_var_types(VarTypes, OutputArgs2, OutputArgTypes2),
                types_match_exactly_list(OutputArgTypes1, OutputArgTypes2)
            ->
                Context = goal_info_get_context(GoalInfo),
                CallPieces = det_report_seen_call_id(ModuleInfo, SeenCall),
                CurPieces = [words("Warning: redundant") | CallPieces]
                    ++ [suffix(".")],
                PrevPieces = [words("Here is the previous") | CallPieces]
                    ++ [suffix(".")],
                Severity = severity_conditional(warn_duplicate_calls, yes,
                    severity_warning, no),
                Msg = simple_msg(Context,
                    [option_is_set(warn_duplicate_calls, yes,
                        [always(CurPieces)])]),
                PrevMsg = error_msg(yes(PrevContext), treat_as_first, 0,
                    [option_is_set(warn_duplicate_calls, yes,
                        [always(PrevPieces)])]),
                Spec = error_spec(Severity, phase_simplify(report_in_any_mode),
                    [Msg, PrevMsg]),
                simplify_info_add_error_spec(Spec, !Info)
            ;
                true
            ),
            CommonInfo = CommonInfo0,
            goal_cost(hlds_goal(GoalExpr0, GoalInfo), Cost),
            simplify_info_incr_cost_delta(Cost, !Info),
            simplify_info_set_requantify(!Info),
            Detism0 = goal_info_get_determinism(GoalInfo),
            (
                Detism0 = detism_det
            ;
                ( Detism0 = detism_semi
                ; Detism0 = detism_non
                ; Detism0 = detism_multi
                ; Detism0 = detism_failure
                ; Detism0 = detism_erroneous
                ; Detism0 = detism_cc_non
                ; Detism0 = detism_cc_multi
                ),
                simplify_info_set_rerun_det(!Info)
            )
        ;
            Context = goal_info_get_context(GoalInfo),
            ThisCall = call_args(Context, InputArgs, OutputArgs),
            map.det_update(SeenCall, [ThisCall | SeenCallsList0],
                SeenCalls0, SeenCalls),
            CommonInfo = CommonInfo0 ^ seen_calls := SeenCalls,
            GoalExpr = GoalExpr0
        )
    ;
        Context = goal_info_get_context(GoalInfo),
        ThisCall = call_args(Context, InputArgs, OutputArgs),
        map.det_insert(SeenCall, [ThisCall], SeenCalls0, SeenCalls),
        CommonInfo = CommonInfo0 ^ seen_calls := SeenCalls,
        GoalExpr = GoalExpr0
    ),
    simplify_info_set_common_info(CommonInfo, !Info).

%---------------------------------------------------------------------------%

    % Partition the arguments of a call into inputs and outputs,
    % failing if any of the outputs have a unique component
    % or if any of the outputs contain any `any' insts.
    %
:- pred partition_call_args(vartypes::in, module_info::in,
    list(mer_mode)::in, list(prog_var)::in, list(prog_var)::out,
    list(prog_var)::out, list(mer_mode)::out) is semidet.

partition_call_args(_, _, [], [], [], [], []).
partition_call_args(_, _, [], [_ | _], _, _, _) :-
    unexpected($module, $pred, "length mismatch (1)").
partition_call_args(_, _, [_ | _], [], _, _, _) :-
    unexpected($module, $pred, "length mismatch (2)").
partition_call_args(VarTypes, ModuleInfo, [ArgMode | ArgModes],
        [Arg | Args], InputArgs, OutputArgs, OutputModes) :-
    partition_call_args(VarTypes, ModuleInfo, ArgModes, Args,
        InputArgs1, OutputArgs1, OutputModes1),
    mode_get_insts(ModuleInfo, ArgMode, InitialInst, FinalInst),
    lookup_var_type(VarTypes, Arg, Type),
    ( inst_matches_binding(InitialInst, FinalInst, Type, ModuleInfo) ->
        InputArgs = [Arg | InputArgs1],
        OutputArgs = OutputArgs1,
        OutputModes = OutputModes1
    ;
        % Calls with partly unique outputs cannot be replaced,
        % since a unique copy of the outputs must be produced.
        inst_is_not_partly_unique(ModuleInfo, FinalInst),

        % Don't optimize calls whose outputs include any `any' insts, since
        % that would create false aliasing between the different variables.
        % (inst_matches_binding applied to identical insts fails only for
        % `any' insts.)
        inst_matches_binding(FinalInst, FinalInst, Type, ModuleInfo),

        % Don't optimize calls where a partially instantiated variable is
        % further instantiated. That case is difficult to test properly
        % because mode analysis currently rejects most potential test cases.
        inst_is_free(ModuleInfo, InitialInst),

        InputArgs = InputArgs1,
        OutputArgs = [Arg | OutputArgs1],
        OutputModes = [ArgMode | OutputModes1]
    ).

%---------------------------------------------------------------------------%

:- pred find_previous_call(list(call_args)::in, list(prog_var)::in,
    eqvclass(prog_var)::in, list(prog_var)::out,
    prog_context::out) is semidet.

find_previous_call([SeenCall | SeenCalls], InputArgs, Eqv, OutputArgs,
        PrevContext) :-
    SeenCall = call_args(PrevContext, InputArgs1, OutputArgs1),
    ( common_var_lists_are_equiv(InputArgs, InputArgs1, Eqv) ->
        OutputArgs = OutputArgs1
    ;
        find_previous_call(SeenCalls, InputArgs, Eqv, OutputArgs, PrevContext)
    ).

%---------------------------------------------------------------------------%

    % Succeeds if the two lists of variables are equivalent
    % according to the specified equivalence class.
    %
:- pred common_var_lists_are_equiv(list(prog_var)::in, list(prog_var)::in,
    eqvclass(prog_var)::in) is semidet.

common_var_lists_are_equiv([], [], _VarEqv).
common_var_lists_are_equiv([X | Xs], [Y | Ys], VarEqv) :-
    common_vars_are_equiv(X, Y, VarEqv),
    common_var_lists_are_equiv(Xs, Ys, VarEqv).

common_vars_are_equivalent(X, Y, CommonInfo) :-
    EqvVars = CommonInfo ^ var_eqv,
    common_vars_are_equiv(X, Y, EqvVars).

    % Succeeds if the two variables are equivalent according to the
    % specified equivalence class.
    %
:- pred common_vars_are_equiv(prog_var::in, prog_var::in,
    eqvclass(prog_var)::in) is semidet.

common_vars_are_equiv(X, Y, VarEqv) :-
    (
        X = Y
    ;
        eqvclass.partition_id(VarEqv, X, Id),
        eqvclass.partition_id(VarEqv, Y, Id)
    ).

%---------------------------------------------------------------------------%

    % Create unifications to assign the vars in OutputArgs from the
    % corresponding var in OldOutputArgs. This needs to be done even if
    % OutputArg is not a nonlocal in the original goal, because later goals
    % in the conjunction may match against the cell and need all the output
    % arguments. The unneeded assignments will be removed later.
    %
:- pred create_output_unifications(hlds_goal_info::in, list(prog_var)::in,
    list(prog_var)::in, list(uni_mode)::in, list(hlds_goal)::out,
    simplify_info::in, simplify_info::out) is det.

create_output_unifications(OldGoalInfo, OutputArgs, OldOutputArgs, UniModes,
        Goals, !Info) :-
    (
        OutputArgs = [OutputArg | OutputArgsTail],
        OldOutputArgs = [OldOutputArg | OldOutputArgsTail],
        UniModes = [UniMode | UniModesTail]
    ->
        (
            % This can happen if the first cell was created
            % with a partially instantiated deconstruction.
            OutputArg \= OldOutputArg
        ->
            generate_assign(OutputArg, OldOutputArg, UniMode, OldGoalInfo,
                GoalExpr, GoalInfo, !Info),
            Goal = hlds_goal(GoalExpr, GoalInfo),
            create_output_unifications(OldGoalInfo,
                OutputArgsTail, OldOutputArgsTail, UniModesTail,
                GoalsTail, !Info),
            Goals = [Goal | GoalsTail]
        ;
            create_output_unifications(OldGoalInfo,
                OutputArgsTail, OldOutputArgsTail, UniModesTail, Goals, !Info)
        )
    ;
        OutputArgs = [],
        OldOutputArgs = [],
        UniModes = []
    ->
        Goals = []
    ;
        unexpected($module, $pred, "mode mismatch")
    ).

%---------------------------------------------------------------------------%

:- pred generate_assign(prog_var::in, prog_var::in, uni_mode::in,
    hlds_goal_info::in, hlds_goal_expr::out, hlds_goal_info::out,
    simplify_info::in, simplify_info::out) is det.

generate_assign(ToVar, FromVar, UniMode, OldGoalInfo, GoalExpr, GoalInfo,
        !Info) :-
    apply_induced_substitutions(ToVar, FromVar, !Info),
    simplify_info_get_var_types(!.Info, VarTypes),
    lookup_var_type(VarTypes, ToVar, ToVarType),
    lookup_var_type(VarTypes, FromVar, FromVarType),

    set_of_var.list_to_set([ToVar, FromVar], NonLocals),
    UniMode = ((_ - ToVarInst0) -> (_ - ToVarInst)),
    ( types_match_exactly(ToVarType, FromVarType) ->
        UnifyMode = (ToVarInst0 -> ToVarInst) - (ToVarInst -> ToVarInst),
        UnifyContext = unify_context(umc_explicit, []),
        GoalExpr = unify(ToVar, rhs_var(FromVar), UnifyMode,
            assign(ToVar, FromVar), UnifyContext)
    ;
        % If the cells we are optimizing don't have exactly the same type,
        % we insert explicit type casts to ensure type correctness.
        % This avoids problems with HLDS optimizations such as inlining
        % which expect the HLDS to be well-typed. Unfortunately, this loses
        % information for other optimizations, since the cast hides the
        % equivalence of the input and output.
        Modes = [(ToVarInst -> ToVarInst), (free -> ToVarInst)],
        GoalExpr = generic_call(cast(unsafe_type_cast), [FromVar, ToVar],
            Modes, arg_reg_types_unset, detism_det)
    ),

    % `ToVar' may not appear in the original instmap_delta, so we can't just
    % use instmap_delta_restrict on the original instmap_delta here.
    InstMapDelta = instmap_delta_from_assoc_list([ToVar - ToVarInst]),

    goal_info_init(NonLocals, InstMapDelta, detism_det, purity_pure,
        GoalInfo0),
    Context = goal_info_get_context(OldGoalInfo),
    goal_info_set_context(Context, GoalInfo0, GoalInfo),
    record_equivalence(ToVar, FromVar, !Info).

:- pred types_match_exactly(mer_type::in, mer_type::in) is semidet.

types_match_exactly(type_variable(TVar, _), type_variable(TVar, _)).
types_match_exactly(defined_type(Name, As, _), defined_type(Name, Bs, _)) :-
    types_match_exactly_list(As, Bs).
types_match_exactly(builtin_type(BuiltinType), builtin_type(BuiltinType)).
types_match_exactly(higher_order_type(As, AR, P, E),
        higher_order_type(Bs, BR, P, E)) :-
    types_match_exactly_list(As, Bs),
    (
        AR = yes(A),
        BR = yes(B),
        types_match_exactly(A, B)
    ;
        AR = no,
        BR = no
    ).
types_match_exactly(tuple_type(As, _), tuple_type(Bs, _)) :-
    types_match_exactly_list(As, Bs).
types_match_exactly(apply_n_type(TVar, As, _), apply_n_type(TVar, Bs, _)) :-
    types_match_exactly_list(As, Bs).
types_match_exactly(kinded_type(_, _), _) :-
    unexpected($module, $pred, "kind annotation").

:- pred types_match_exactly_list(list(mer_type)::in, list(mer_type)::in)
    is semidet.

types_match_exactly_list([], []).
types_match_exactly_list([Type1 | Types1], [Type2 | Types2]) :-
    types_match_exactly(Type1, Type2),
    types_match_exactly_list(Types1, Types2).

%---------------------------------------------------------------------------%

    % Two existentially quantified type variables may become aliased if two
    % calls or two deconstructions are merged together.  We detect this
    % situation here and apply the appropriate tsubst to the vartypes and
    % rtti_varmaps.  This allows us to avoid an unsafe cast, and also may
    % allow more opportunities for simplification.
    %
    % If we do need to apply a type substitution, then we also apply the
    % substituion ToVar -> FromVar to the RttiVarMaps, then duplicate
    % FromVar's information for ToVar.  This ensures we always refer to the
    % "original" variables, not the copies created by generate_assign.
    %
    % Note that this relies on the assignments for type_infos and
    % typeclass_infos to be generated before other arguments with these
    % existential types are processed.  In other words, the arguments of
    % calls and deconstructions must be processed in left to right order.
    %
:- pred apply_induced_substitutions(prog_var::in, prog_var::in,
    simplify_info::in, simplify_info::out) is det.

apply_induced_substitutions(ToVar, FromVar, !Info) :-
    simplify_info_get_rtti_varmaps(!.Info, RttiVarMaps0),
    rtti_varmaps_var_info(RttiVarMaps0, FromVar, FromVarRttiInfo),
    rtti_varmaps_var_info(RttiVarMaps0, ToVar, ToVarRttiInfo),
    ( calculate_induced_tsubst(ToVarRttiInfo, FromVarRttiInfo, TSubst) ->
        ( map.is_empty(TSubst) ->
            true
        ;
            simplify_info_apply_substitutions_and_duplicate(ToVar, FromVar,
                TSubst, !Info)
        )
    ;
        % Update the rtti_varmaps with new information if only one of the
        % variables has rtti_var_info recorded.  This can happen if a new
        % variable has been introduced, eg in quantification, without
        % being recorded in the rtti_varmaps.
        (
            FromVarRttiInfo = non_rtti_var,
            rtti_var_info_duplicate(ToVar, FromVar,
                RttiVarMaps0, RttiVarMaps),
            simplify_info_set_rtti_varmaps(RttiVarMaps, !Info)
        ;
            ( FromVarRttiInfo = type_info_var(_)
            ; FromVarRttiInfo = typeclass_info_var(_)
            ),
            (
                ToVarRttiInfo = non_rtti_var,
                rtti_var_info_duplicate(FromVar, ToVar,
                    RttiVarMaps0, RttiVarMaps),
                simplify_info_set_rtti_varmaps(RttiVarMaps, !Info)
            ;
                ( ToVarRttiInfo = type_info_var(_)
                ; ToVarRttiInfo = typeclass_info_var(_)
                ),
                % Calculate_induced_tsubst failed for a different reason,
                % either because unification failed or because one variable
                % was a type_info and the other was a typeclass_info.
                unexpected($module, $pred, "inconsistent info")
            )
        )
    ).

    % Calculate the induced substitution by unifying the types or constraints,
    % if they exist.  Fail if given non-matching rtti_var_infos.
    %
:- pred calculate_induced_tsubst(rtti_var_info::in, rtti_var_info::in,
    tsubst::out) is semidet.

calculate_induced_tsubst(ToVarRttiInfo, FromVarRttiInfo, TSubst) :-
    (
        FromVarRttiInfo = type_info_var(FromVarTypeInfoType),
        ToVarRttiInfo = type_info_var(ToVarTypeInfoType),
        type_list_subsumes([ToVarTypeInfoType], [FromVarTypeInfoType], TSubst)
    ;
        FromVarRttiInfo = typeclass_info_var(FromVarConstraint),
        ToVarRttiInfo = typeclass_info_var(ToVarConstraint),
        FromVarConstraint = constraint(Name, FromArgs),
        ToVarConstraint = constraint(Name, ToArgs),
        type_list_subsumes(ToArgs, FromArgs, TSubst)
    ;
        FromVarRttiInfo = non_rtti_var,
        ToVarRttiInfo = non_rtti_var,
        map.init(TSubst)
    ).

%---------------------------------------------------------------------------%
:- end_module check_hlds.common.
%---------------------------------------------------------------------------%
