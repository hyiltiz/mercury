%---------------------------------------------------------------------------%
% Copyright (C) 1996-1997 The University of Melbourne.
% This file may only be copied under the terms of the GNU General
% Public License - see the file COPYING in the Mercury distribution.
%---------------------------------------------------------------------------%
%
% Code generation - convert from HLDS to LLDS.
%
% Main author: conway.
%
% Notes:
%
%	code_gen forwards most of the actual construction of intruction
%	sequences to code_info, and other modules. The generation of
%	calls is done by call_gen, switches by switch_gen, if-then-elses
%	by ite_gen, unifications by unify_gen, disjunctions by disj_gen,
%	and pragma_c_codes by pragma_c_gen.
%
%	The general scheme for generating semideterministic code is
%	to treat it as deterministic code, and have a fall-through
%	point for failure.  Semideterministic procedures leave a 'true'
%	in register r(1) to indicate success, and 'false' to indicate
%	failure.
%
%---------------------------------------------------------------------------%
%---------------------------------------------------------------------------%

:- module code_gen.

:- interface.

:- import_module hlds_module, hlds_pred, hlds_goal, llds, code_info.
:- import_module continuation_info.
:- import_module list, assoc_list, io.

		% Translate a HLDS structure into an LLDS

:- pred generate_code(module_info, module_info, list(c_procedure),
						io__state, io__state).
:- mode generate_code(in, out, out, di, uo) is det.

:- pred generate_proc_code(proc_info, proc_id, pred_id, module_info, globals,
	continuation_info, int, continuation_info, int, c_procedure).
:- mode generate_proc_code(in, in, in, in, in, in, in, out, out, out) is det.

		% This predicate generates code for a goal.

:- pred code_gen__generate_goal(code_model, hlds_goal, code_tree,
						code_info, code_info).
:- mode code_gen__generate_goal(in, in, out, in, out) is det.

:- pred code_gen__output_args(assoc_list(var, arg_info), set(lval)).
:- mode code_gen__output_args(in, out) is det.

%---------------------------------------------------------------------------%
%---------------------------------------------------------------------------%

:- implementation.

:- import_module call_gen, unify_gen, ite_gen, switch_gen, disj_gen.
:- import_module pragma_c_gen, trace, globals, options, hlds_out.
:- import_module code_aux, middle_rec, passes_aux, llds_out.
:- import_module code_util, type_util, mode_util.
:- import_module prog_data, instmap.
:- import_module bool, char, int, string, list, term.
:- import_module map, tree, std_util, require, set, varset.

%---------------------------------------------------------------------------%

% For a set of high level data structures and associated data, given in
% ModuleInfo, generate a list of c_procedure structures.

generate_code(ModuleInfo0, ModuleInfo, Procedures) -->
		% get a list of all the predicate ids
		% for which we are going to generate code.
	{ module_info_predids(ModuleInfo0, PredIds) },
		% now generate the code for each predicate
	generate_pred_list_code(ModuleInfo0, ModuleInfo, PredIds, Procedures).

% Generate a list of c_procedure structures for each mode of each
% predicate given in ModuleInfo

:- pred generate_pred_list_code(module_info, module_info, list(pred_id), 
				list(c_procedure), io__state, io__state).
:- mode generate_pred_list_code(in, out, in, out, di, uo) is det.

generate_pred_list_code(ModuleInfo, ModuleInfo, [], []) --> [].
generate_pred_list_code(ModuleInfo0, ModuleInfo, [PredId | PredIds],
				Predicates) -->
	{ module_info_preds(ModuleInfo0, PredInfos) },
		% get the pred_info structure for this predicate
	{ map__lookup(PredInfos, PredId, PredInfo) },
		% extract a list of all the procedure ids for this
		% predicate and generate code for them
	{ pred_info_non_imported_procids(PredInfo, ProcIds) },
	( { ProcIds = [] } ->
		{ Predicates0 = [] },
		{ ModuleInfo1 = ModuleInfo0 } 
	;
		generate_pred_code(ModuleInfo0, ModuleInfo1, PredId,
					PredInfo, ProcIds, Predicates0) 
	),
	{ list__append(Predicates0, Predicates1, Predicates) },
		% and generate the code for the rest of the predicates
	generate_pred_list_code(ModuleInfo1, ModuleInfo, PredIds, Predicates1).

% For the predicate identified by PredId, with the the associated
% data in ModuleInfo, generate a code_tree.

:- pred generate_pred_code(module_info, module_info, pred_id, pred_info,
		list(proc_id), list(c_procedure), io__state, io__state).
:- mode generate_pred_code(in, out, in, in, in, out, di, uo) is det.

generate_pred_code(ModuleInfo0, ModuleInfo, PredId, PredInfo, ProcIds, Code) -->
	globals__io_lookup_bool_option(very_verbose, VeryVerbose),
	( { VeryVerbose = yes } ->
		io__write_string("% Generating code for "),
		hlds_out__write_pred_id(ModuleInfo0, PredId),
		io__write_string("\n"),
		globals__io_lookup_bool_option(statistics, Statistics),
		maybe_report_stats(Statistics)
	;
		[]
	),
		% generate all the procedures for this predicate
	{ module_info_get_continuation_info(ModuleInfo0, ContInfo0) },
	{ module_info_get_cell_count(ModuleInfo0, CellCount0) },
	globals__io_get_globals(Globals),
	{ generate_proc_list_code(ProcIds, PredId, PredInfo, ModuleInfo0,
		Globals, ContInfo0, ContInfo, CellCount0, CellCount,
		[], Code) },
	{ module_info_set_cell_count(ModuleInfo0, CellCount, ModuleInfo1) },
	{ module_info_set_continuation_info(ModuleInfo1, ContInfo, 
		ModuleInfo) }.

% For all the modes of predicate PredId, generate the appropriate
% code (deterministic, semideterministic, or nondeterministic).

:- pred generate_proc_list_code(list(proc_id), pred_id, pred_info, module_info,
	globals, continuation_info, continuation_info, int, int,
	list(c_procedure), list(c_procedure)).
% :- mode generate_proc_list_code(in, in, in, in, in, di, uo, di, uo)
%	is det.
:- mode generate_proc_list_code(in, in, in, in, in, in, out, in, out, in, out)
	is det.

generate_proc_list_code([], _PredId, _PredInfo, _ModuleInfo, _Globals,
		ContInfo, ContInfo, CellCount, CellCount, Procs, Procs).
generate_proc_list_code([ProcId | ProcIds], PredId, PredInfo, ModuleInfo0,
		Globals, ContInfo0, ContInfo, CellCount0, CellCount,
		Procs0, Procs) :-
	pred_info_procedures(PredInfo, ProcInfos),
		% locate the proc_info structure for this mode of the predicate
	map__lookup(ProcInfos, ProcId, ProcInfo),
		% find out if the proc is deterministic/etc
	generate_proc_code(ProcInfo, ProcId, PredId, ModuleInfo0, Globals,
		ContInfo0, CellCount0, ContInfo1, CellCount1, Proc),
	generate_proc_list_code(ProcIds, PredId, PredInfo, ModuleInfo0,
		Globals, ContInfo1, ContInfo, CellCount1, CellCount,
		[Proc | Procs0], Procs).

%---------------------------------------------------------------------------%

	% Values of this type hold information about stack frames that is
	% generated when generating prologs and is used in generating epilogs
	% and when massaging the code generated for the procedure.

:- type frame_info	--->	frame(
					int, 	    % number of slots in frame
					maybe(int)  % slot number of succip
						    % if succip is present
				).

%---------------------------------------------------------------------------%

generate_proc_code(ProcInfo, ProcId, PredId, ModuleInfo, Globals,
		ContInfo0, CellCount0, ContInfo, CellCount, Proc) :-
		% find out if the proc is deterministic/etc
	proc_info_interface_code_model(ProcInfo, CodeModel),
		% get the goal for this procedure
	proc_info_goal(ProcInfo, Goal),
		% get the information about this procedure that we need.
	proc_info_variables(ProcInfo, VarInfo),
	proc_info_liveness_info(ProcInfo, Liveness),
	proc_info_stack_slots(ProcInfo, StackSlots),
	proc_info_get_initial_instmap(ProcInfo, ModuleInfo, InitialInst),
	Goal = _ - GoalInfo,
	goal_info_get_follow_vars(GoalInfo, MaybeFollowVars),
	(
		MaybeFollowVars = yes(FollowVars)
	;
		MaybeFollowVars = no,
		map__init(FollowVars)
	),
	globals__get_gc_method(Globals, GC_Method),
	( GC_Method = accurate ->
		SaveSuccip = yes
	;
		SaveSuccip = no
	),
		% initialise the code_info structure 
	code_info__init(VarInfo, Liveness, StackSlots, SaveSuccip, Globals,
		PredId, ProcId, ProcInfo, InitialInst, FollowVars,
		ModuleInfo, CellCount0, ContInfo0, CodeInfo0),
		% generate code for the procedure
	globals__lookup_bool_option(Globals, generate_trace, Trace),
	( Trace = yes ->
		trace__setup(CodeInfo0, CodeInfo1)
	;
		CodeInfo1 = CodeInfo0
	),
	generate_category_code(CodeModel, Goal, CodeTree, FrameInfo,
		CodeInfo1, CodeInfo),
		% extract the new continuation_info and cell count
	code_info__get_continuation_info(ContInfo1, CodeInfo, _CodeInfo1),
	code_info__get_cell_count(CellCount, CodeInfo, _CodeInfo2),

		% turn the code tree into a list
	tree__flatten(CodeTree, FragmentList),
		% now the code is a list of code fragments (== list(instr)),
		% so we need to do a level of unwinding to get a flat list.
	list__condense(FragmentList, Instructions0),
	(
		FrameInfo = frame(_TotalSlots, MaybeSuccipSlot),
		MaybeSuccipSlot = yes(SuccipSlot)
	->
		code_gen__add_saved_succip(Instructions0,
			SuccipSlot, Instructions),

		( GC_Method = accurate ->
			code_info__get_total_stackslot_count(StackSize,
				CodeInfo, _),
			code_util__make_proc_label(ModuleInfo, 
				PredId, ProcId, ProcLabel),
			continuation_info__add_proc_info(Instructions, 
				ProcLabel, StackSize, CodeModel,
				SuccipSlot, ContInfo1, ContInfo)
		;
			ContInfo = ContInfo1
		)
	;
		ContInfo = ContInfo1,
		Instructions = Instructions0
	),

		% get the name and arity of this predicate
	predicate_name(ModuleInfo, PredId, Name),
	predicate_arity(ModuleInfo, PredId, Arity),
		% construct a c_procedure structure with all the information
	proc_id_to_int(ProcId, LldsProcId),
	Proc = c_procedure(Name, Arity, LldsProcId, Instructions).

:- pred generate_category_code(code_model, hlds_goal, code_tree, frame_info,
				code_info, code_info).
:- mode generate_category_code(in, in, out, out, in, out) is det.

generate_category_code(model_det, Goal, Code, FrameInfo) -->
		% generate the code for the body of the clause
	(
		code_info__get_globals(Globals),
		{ globals__lookup_bool_option(Globals, middle_rec, yes) },
		middle_rec__match_and_generate(Goal, MiddleRecCode)
	->
		{ Code = MiddleRecCode },
		{ FrameInfo = frame(0, no) }
	;
		% make a new failure cont (not model_non);
		% this continuation is never actually used,
		% but is a place holder
		code_info__manufacture_failure_cont(no),

		code_gen__generate_goal(model_det, Goal, BodyCode),
		code_info__get_instmap(Instmap),

		code_gen__generate_prolog(model_det, FrameInfo, PrologCode),
		(
			{ instmap__is_reachable(Instmap) }
		->
			code_gen__generate_epilog(model_det,
				FrameInfo, EpilogCode)
		;
			{ EpilogCode = empty }
		),

		{ Code = tree(PrologCode, tree(BodyCode, EpilogCode)) }
	).

generate_category_code(model_semi, Goal, Code, FrameInfo) -->
		% make a new failure cont (not model_non)
	code_info__manufacture_failure_cont(no),

		% generate the code for the body of the clause
	code_gen__generate_goal(model_semi, Goal, BodyCode),
	code_gen__generate_prolog(model_semi, FrameInfo, PrologCode),
	code_gen__generate_epilog(model_semi, FrameInfo, EpilogCode),
	{ Code = tree(PrologCode, tree(BodyCode, EpilogCode)) }.

generate_category_code(model_non, Goal, Code, FrameInfo) -->
		% make a new failure cont (yes, it is model_non)
	code_info__manufacture_failure_cont(yes),
		% we must arrange the tracing of failure out of this proc
	code_info__get_maybe_trace_info(MaybeTraceInfo),
	( { MaybeTraceInfo = yes(TraceInfo) } ->
		{ set__init(ResumeVars) },
		code_info__make_known_failure_cont(ResumeVars, stack_only, yes,
			SetupCode),

			% generate the code for the body of the clause
		code_info__push_resume_point_vars(ResumeVars),
		code_gen__generate_goal(model_non, Goal, BodyCode),
		code_gen__generate_prolog(model_non, FrameInfo, PrologCode),
		code_gen__generate_epilog(model_non, FrameInfo, EpilogCode),
		code_info__pop_resume_point_vars,
		{ MainCode = tree(PrologCode, tree(BodyCode, EpilogCode)) },

		code_info__restore_failure_cont(RestoreCode),
		trace__generate_event_code(fail, TraceInfo, TraceEventCode),
		code_info__generate_failure(FailCode),
		{ Code =
			tree(MainCode,
			tree(SetupCode,
			tree(RestoreCode,
			tree(TraceEventCode,
			     FailCode))))
		}
	;
			% generate the code for the body of the clause
		code_gen__generate_goal(model_non, Goal, BodyCode),
		code_gen__generate_prolog(model_non, FrameInfo, PrologCode),
		code_gen__generate_epilog(model_non, FrameInfo, EpilogCode),
		{ Code = tree(PrologCode, tree(BodyCode, EpilogCode)) }
	).

%---------------------------------------------------------------------------%

	% Generate the prolog for a procedure.
	%
	% The prolog will contain
	%
	%	a comment to mark prolog start
	%	a comment explaining the stack layout
	%	the procedure entry label
	%	code to allocate a stack frame
	%	code to fill in some special slots in the stack frame
	%	a comment to mark prolog end
	%
	% At the moment the only special slot is the succip slot.
	%
	% Not all frames will have all these components. For example, the code
	% to allocate a stack frame will be missing if the procedure doesn't
	% need a stack frame, and if the procedure is nondet, then the code
	% to fill in the succip slot is subsumed by the mkframe.

:- pred code_gen__generate_prolog(code_model, frame_info, code_tree, 
	code_info, code_info).
:- mode code_gen__generate_prolog(in, out, out, in, out) is det.

code_gen__generate_prolog(CodeModel, FrameInfo, PrologCode) -->
	code_info__get_stack_slots(StackSlots),
	code_info__get_varset(VarSet),
	{ code_aux__explain_stack_slots(StackSlots, VarSet, SlotsComment) },
	{ StartComment = node([
		comment("Start of procedure prologue") - "",
		comment(SlotsComment) - ""
	]) },
	code_info__get_total_stackslot_count(MainSlots),
	code_info__get_pred_id(PredId),
	code_info__get_proc_id(ProcId),
	code_info__get_module_info(ModuleInfo),
	{ code_util__make_local_entry_label(ModuleInfo, PredId, ProcId, no,
		Entry) },
	{ LabelCode = node([
		label(Entry) - "Procedure entry point"
	]) },
	code_info__get_succip_used(Used),
	(
		% Do we need to save the succip across calls?
		{ Used = yes },
		% Do we need to use a general slot for storing succip?
		{ CodeModel \= model_non }
	->
		{ SuccipSlot is MainSlots + 1 },
		{ SaveSuccipCode = node([
			assign(stackvar(SuccipSlot), lval(succip)) -
				"Save the success ip"
		]) },
		{ TotalSlots = SuccipSlot },
		{ MaybeSuccipSlot = yes(SuccipSlot) }
	;
		{ SaveSuccipCode = empty },
		{ TotalSlots = MainSlots },
		{ MaybeSuccipSlot = no }
	),
	{ FrameInfo = frame(TotalSlots, MaybeSuccipSlot) },
	code_info__get_maybe_trace_info(MaybeTraceInfo),
	( { MaybeTraceInfo = yes(TraceInfo) } ->
		{ trace__generate_slot_fill_code(TraceInfo, TraceFillCode) },
		trace__generate_event_code(call, TraceInfo, TraceEventCode),
		{ TraceCode = tree(TraceFillCode, TraceEventCode) }
	;
		{ TraceCode = empty }
	),
	{ predicate_module(ModuleInfo, PredId, ModuleName) },
	{ predicate_name(ModuleInfo, PredId, PredName) },
	{ predicate_arity(ModuleInfo, PredId, Arity) },
	{ string__int_to_string(Arity, ArityStr) },
	{ string__append_list([ModuleName, ":", PredName, "/", ArityStr],
		PushMsg) },
	(
		{ CodeModel = model_non }
	->
		{ AllocCode = node([
			mkframe(PushMsg, TotalSlots, do_fail) -
				"Allocate stack frame"
		]) }
	;
		{ TotalSlots > 0 }
	->
		{ AllocCode = node([
			incr_sp(TotalSlots, PushMsg) -
				"Allocate stack frame"
		]) }
	;
		{ AllocCode = empty }
	),
	{ EndComment = node([
		comment("End of procedure prologue") - ""
	]) },
	{ PrologCode =
		tree(StartComment,
		tree(LabelCode,
		tree(AllocCode,
		tree(SaveSuccipCode,
		tree(TraceCode,
		     EndComment)))))
	}.

%---------------------------------------------------------------------------%

	% Generate the epilog for a procedure.
	%
	% The epilog will contain
	%
	%	a comment to mark epilog start
	%	code to place the output arguments where their caller expects
	%	the success continuation
	%	the faulure continuation (for semidet procedures only)
	%	a comment to mark epilog end.
	%
	% The success continuation will contain
	%
	%	code to restore registers from some special slots
	%	code to deallocate the stack frame
	%	code to set r1 to TRUE (for semidet procedures only)
	%	a jump back to the caller, including livevals information
	%
	% The failure continuation will contain
	%
	%	code that sets up the failure resumption point
	%	code to restore registers from some special slots
	%	code to deallocate the stack frame
	%	code to set r1 to FALSE
	%	a jump back to the caller, including livevals information
	%
	% At the moment the only special slot is the succip slot.
	%
	% Not all frames will have all these components. For example, for
	% nondet procedures we don't deallocate the stack frame before
	% success.

:- pred code_gen__generate_epilog(code_model, frame_info, code_tree,
	code_info, code_info).
:- mode code_gen__generate_epilog(in, in, out, in, out) is det.

code_gen__generate_epilog(CodeModel, FrameInfo, EpilogCode) -->
	{ StartComment = node([
		comment("Start of procedure epilogue") - ""
	]) },
	code_info__get_instmap(Instmap),
	code_info__get_arginfo(ArgModes),
	code_info__get_headvars(HeadVars),
	{ assoc_list__from_corresponding_lists(HeadVars, ArgModes, Args)},
	(
		{ instmap__is_unreachable(Instmap) }
	->
		{ FlushCode = empty }
	;
		code_info__setup_call(Args, callee, FlushCode)
	),
	{ FrameInfo = frame(TotalSlots, MaybeSuccipSlot) },
	(
		{ MaybeSuccipSlot = yes(SuccipSlot) }
	->
		{ RestoreSuccipCode = node([
			assign(succip, lval(stackvar(SuccipSlot))) -
				"restore the success ip"
		]) }
	;
		{ RestoreSuccipCode = empty }
	),
	(
		{ TotalSlots = 0 ; CodeModel = model_non }
	->
		{ DeallocCode = empty }
	;
		{ DeallocCode = node([
			decr_sp(TotalSlots) - "Deallocate stack frame"
		]) }
	),
	{ RestoreDeallocCode = tree(RestoreSuccipCode, DeallocCode ) },
	{ code_gen__output_args(Args, LiveArgs) },
	code_info__get_maybe_trace_info(MaybeTraceInfo),
	( { MaybeTraceInfo = yes(TraceInfo) } ->
		trace__generate_event_code(exit, TraceInfo, SuccessTraceCode),
		( { CodeModel = model_semi } ->
			trace__generate_event_code(fail, TraceInfo,
				FailureTraceCode)
		;
			{ FailureTraceCode = empty }
		)
	;
		{ SuccessTraceCode = empty },
		{ FailureTraceCode = empty }
	),
	(
		{ CodeModel = model_det },
		{ SuccessCode = node([
			livevals(LiveArgs) - "",
			goto(succip) - "Return from procedure call"
		]) },
		{ AllSuccessCode =
			tree(SuccessTraceCode,
			tree(RestoreDeallocCode,
			     SuccessCode))
		},
		{ AllFailureCode = empty }
	;
		{ CodeModel = model_semi },
		code_info__restore_failure_cont(ResumeCode),
		{ set__insert(LiveArgs, reg(r, 1), SuccessLiveRegs) },
		{ SuccessCode = node([
			assign(reg(r, 1), const(true)) - "Succeed",
			livevals(SuccessLiveRegs) - "",
			goto(succip) - "Return from procedure call"
		]) },
		{ AllSuccessCode =
			tree(SuccessTraceCode,
			tree(RestoreDeallocCode,
			     SuccessCode))
		},
		{ set__singleton_set(FailureLiveRegs, reg(r, 1)) },
		{ FailureCode = node([
			assign(reg(r, 1), const(false)) - "Fail",
			livevals(FailureLiveRegs) - "",
			goto(succip) - "Return from procedure call"
		]) },
		{ AllFailureCode =
			tree(ResumeCode,
			tree(FailureTraceCode,
			tree(RestoreDeallocCode,
			     FailureCode)))
		}
	;
		{ CodeModel = model_non },
		{ SuccessCode = node([
			livevals(LiveArgs) - "",
			goto(do_succeed(no)) - "Return from procedure call"
		]) },
		{ AllSuccessCode =
			tree(SuccessTraceCode,
			     SuccessCode)
		},
		{ AllFailureCode = empty }
	),
	{ EndComment = node([
		comment("End of procedure epilogue") - ""
	]) },
	{ EpilogCode =
		tree(StartComment,
		tree(FlushCode,
		tree(AllSuccessCode,
		tree(AllFailureCode,
		     EndComment))))
	}.

%---------------------------------------------------------------------------%

% Generate a goal. This predicate arranges for the necessary updates of
% the generic data structures before and after the actual code generation,
% which is delegated to context-specific predicates.

code_gen__generate_goal(ContextModel, Goal - GoalInfo, Code) -->
		% Make any changes to liveness before Goal
	{ goal_is_atomic(Goal) ->
		IsAtomic = yes
	;
		IsAtomic = no
	},
	code_info__pre_goal_update(GoalInfo, IsAtomic),
	code_info__get_instmap(Instmap),
	(
		{ instmap__is_reachable(Instmap) }
	->
		{ goal_info_get_code_model(GoalInfo, CodeModel) },
		(
			{ CodeModel = model_det },
			code_gen__generate_det_goal_2(Goal, GoalInfo, Code0)
		;
			{ CodeModel = model_semi },
			( { ContextModel \= model_det } ->
				code_gen__generate_semi_goal_2(Goal, GoalInfo,
					Code0)
			;
				{ error("semidet model in det context") }
			)
		;
			{ CodeModel = model_non },
			( { ContextModel = model_non } ->
				code_gen__generate_non_goal_2(Goal, GoalInfo,
					Code0)
			;
				{ error("nondet model in det/semidet context") }
			)
		),
			% Make live any variables which subsequent goals
			% will expect to be live, but were not generated
		code_info__set_instmap(Instmap),
		code_info__post_goal_update(GoalInfo),
		code_info__get_globals(Options),
		(
			{ globals__lookup_bool_option(Options, lazy_code, yes) }
		->
			{ Code1 = empty }
		;
			{ error("Eager code unavailable") }
%%%			code_info__generate_eager_flush(Code1)
		),
		{ Code = tree(Code0, Code1) }
	;
		{ Code = empty }
	),
	!.

%---------------------------------------------------------------------------%

% Generate a conjoined series of goals.
% Note of course, that with a conjunction, state information
% flows directly from one conjunct to the next.

:- pred code_gen__generate_goals(hlds_goals, code_model, code_tree,
							code_info, code_info).
:- mode code_gen__generate_goals(in, in, out, in, out) is det.

code_gen__generate_goals([], _, empty) --> [].
code_gen__generate_goals([Goal | Goals], CodeModel, Instr) -->
	code_gen__generate_goal(CodeModel, Goal, Instr1),
	code_info__get_instmap(Instmap),
	(
		{ instmap__is_unreachable(Instmap) }
	->
		{ Instr = Instr1 }
	;
		code_gen__generate_goals(Goals, CodeModel, Instr2),
		{ Instr = tree(Instr1, Instr2) }
	).

%---------------------------------------------------------------------------%

:- pred code_gen__generate_det_goal_2(hlds_goal_expr, hlds_goal_info,
					code_tree, code_info, code_info).
:- mode code_gen__generate_det_goal_2(in, in, out, in, out) is det.

code_gen__generate_det_goal_2(conj(Goals), _GoalInfo, Instr) -->
	code_gen__generate_goals(Goals, model_det, Instr).
code_gen__generate_det_goal_2(some(_Vars, Goal), _GoalInfo, Instr) -->
	{ Goal = _ - InnerGoalInfo },
	{ goal_info_get_code_model(InnerGoalInfo, CodeModel) },
	(
		{ CodeModel = model_det },
		code_gen__generate_goal(model_det, Goal, Instr)
	;
		{ CodeModel = model_semi },
		{ error("semidet model in det context") }
	;
		{ CodeModel = model_non },
		code_info__generate_det_pre_commit(Slots, PreCommit),
		code_gen__generate_goal(model_non, Goal, GoalCode),
		code_info__generate_det_commit(Slots, Commit),
		{ Instr = tree(PreCommit, tree(GoalCode, Commit)) }
	).
code_gen__generate_det_goal_2(disj(Goals, StoreMap), _GoalInfo, Instr) -->
	disj_gen__generate_det_disj(Goals, StoreMap, Instr).
code_gen__generate_det_goal_2(not(Goal), _GoalInfo, Instr) -->
	code_gen__generate_negation(model_det, Goal, Instr).
code_gen__generate_det_goal_2(higher_order_call(PredVar, Args, Types,
		Modes, Det, _PredOrFunc),
		GoalInfo, Instr) -->
	call_gen__generate_higher_order_call(model_det, PredVar, Args,
		Types, Modes, Det, GoalInfo, Instr).
code_gen__generate_det_goal_2(call(PredId, ProcId, Args, BuiltinState, _, _),
		GoalInfo, Instr) -->
	(
		{ BuiltinState = not_builtin }
	->
		code_info__succip_is_used,
		call_gen__generate_call(model_det, PredId, ProcId, Args,
			GoalInfo, Instr)
	;
		call_gen__generate_det_builtin(PredId, ProcId, Args, Instr)
	).
code_gen__generate_det_goal_2(switch(Var, CanFail, CaseList, StoreMap),
		GoalInfo, Instr) -->
	switch_gen__generate_switch(model_det, Var, CanFail, CaseList,
		StoreMap, GoalInfo, Instr).
code_gen__generate_det_goal_2(
		if_then_else(_Vars, CondGoal, ThenGoal, ElseGoal, StoreMap),
							_GoalInfo, Instr) -->
	ite_gen__generate_det_ite(CondGoal, ThenGoal, ElseGoal, StoreMap,
		Instr).
code_gen__generate_det_goal_2(unify(_L, _R, _U, Uni, _C), _GoalInfo, Instr) -->
	(
		{ Uni = assign(Left, Right) },
		unify_gen__generate_assignment(Left, Right, Instr)
	;
		{ Uni = construct(Var, ConsId, Args, Modes) },
		unify_gen__generate_construction(Var, ConsId, Args,
								Modes, Instr)
	;
		{ Uni = deconstruct(Var, ConsId, Args, Modes, _Det) },
		unify_gen__generate_det_deconstruction(Var, ConsId, Args,
								Modes, Instr)
	;
		% These should have been transformed into calls by
		% polymorphism.m.
		{ Uni = complicated_unify(_UniMode, _CanFail) },
		{ error("code_gen__generate_det_goal_2 - complicated unify") }
	;
		{ Uni = simple_test(_, _) },
		{ error("generate_det_goal_2: cannot have det simple_test") }
	).

code_gen__generate_det_goal_2(pragma_c_code(C_Code, MayCallMercury,
		PredId, ModeId, Args, ArgNames, OrigArgTypes, Extra),
		GoalInfo, Instr) -->
	(
		{ Extra = none },
		pragma_c_gen__generate_pragma_c_code(model_det, C_Code,
			MayCallMercury, PredId, ModeId, Args, ArgNames,
			OrigArgTypes, GoalInfo, Instr)
	;
		{ Extra = extra_pragma_info(_, _) },
		{ error("det pragma has non-empty extras field") }
	).

%---------------------------------------------------------------------------%

:- pred code_gen__generate_semi_goal_2(hlds_goal_expr, hlds_goal_info,
					code_tree, code_info, code_info).
:- mode code_gen__generate_semi_goal_2(in, in, out, in, out) is det.

code_gen__generate_semi_goal_2(conj(Goals), _GoalInfo, Code) -->
	code_gen__generate_goals(Goals, model_semi, Code).
code_gen__generate_semi_goal_2(some(_Vars, Goal), _GoalInfo, Code) -->
	{ Goal = _ - InnerGoalInfo },
	{ goal_info_get_code_model(InnerGoalInfo, CodeModel) },
	(
		{ CodeModel = model_det },
		code_gen__generate_goal(model_det, Goal, Code)
	;
		{ CodeModel = model_semi },
		code_gen__generate_goal(model_semi, Goal, Code)
	;
		{ CodeModel = model_non },
		code_info__generate_semi_pre_commit(Label, Slots, PreCommit),
		code_gen__generate_goal(model_non, Goal, GoalCode),
		code_info__generate_semi_commit(Label, Slots, Commit),
		{ Code = tree(PreCommit, tree(GoalCode, Commit)) }
	).
code_gen__generate_semi_goal_2(disj(Goals, StoreMap), _GoalInfo, Code) -->
	disj_gen__generate_semi_disj(Goals, StoreMap, Code).
code_gen__generate_semi_goal_2(not(Goal), _GoalInfo, Code) -->
	code_gen__generate_negation(model_semi, Goal, Code).
code_gen__generate_semi_goal_2(higher_order_call(PredVar, Args, Types, Modes,
		Det, _PredOrFunc), GoalInfo, Code) -->
	call_gen__generate_higher_order_call(model_semi, PredVar, Args,
		Types, Modes, Det, GoalInfo, Code).
code_gen__generate_semi_goal_2(call(PredId, ProcId, Args, BuiltinState, _, _),
							GoalInfo, Code) -->
	(
		{ BuiltinState = not_builtin }
	->
		code_info__succip_is_used,
		call_gen__generate_call(model_semi, PredId, ProcId, Args,
			GoalInfo, Code)
	;
		call_gen__generate_semidet_builtin(PredId, ProcId, Args, Code)
	).
code_gen__generate_semi_goal_2(switch(Var, CanFail, CaseList, StoreMap),
		GoalInfo, Instr) -->
	switch_gen__generate_switch(model_semi, Var, CanFail,
		CaseList, StoreMap, GoalInfo, Instr).
code_gen__generate_semi_goal_2(
		if_then_else(_Vars, CondGoal, ThenGoal, ElseGoal, StoreMap),
							_GoalInfo, Instr) -->
	ite_gen__generate_semidet_ite(CondGoal, ThenGoal, ElseGoal, StoreMap,
		Instr).
code_gen__generate_semi_goal_2(unify(_L, _R, _U, Uni, _C),
							_GoalInfo, Code) -->
	(
		{ Uni = assign(Left, Right) },
		unify_gen__generate_assignment(Left, Right, Code)
	;
		{ Uni = construct(Var, ConsId, Args, Modes) },
		unify_gen__generate_construction(Var, ConsId, Args,
								Modes, Code)
	;
		{ Uni = deconstruct(Var, ConsId, Args, Modes, _) },
		unify_gen__generate_semi_deconstruction(Var, ConsId, Args,
								Modes, Code)
	;
		{ Uni = simple_test(Var1, Var2) },
		unify_gen__generate_test(Var1, Var2, Code)
	;
		{ Uni = complicated_unify(_UniMode, _CanFail) },
		{ error("code_gen__generate_semi_goal_2 - complicated_unify") }
	).

code_gen__generate_semi_goal_2(pragma_c_code(C_Code, MayCallMercury,
		PredId, ModeId, Args, ArgNameMap, OrigArgTypes, Extra),
		GoalInfo, Instr) -->
	(
		{ Extra = none },
		pragma_c_gen__generate_pragma_c_code(model_semi, C_Code,
			MayCallMercury, PredId, ModeId, Args, ArgNameMap,
			OrigArgTypes, GoalInfo, Instr)
	;
		{ Extra = extra_pragma_info(_, _) },
		{ error("semidet pragma has non-empty extras field") }
	).

%---------------------------------------------------------------------------%
%---------------------------------------------------------------------------%

:- pred code_gen__generate_negation(code_model, hlds_goal, code_tree,
	code_info, code_info).
:- mode code_gen__generate_negation(in, in, out, in, out) is det.

code_gen__generate_negation(CodeModel, Goal0, Code) -->
	{ Goal0 = GoalExpr - GoalInfo0 },
	{ goal_info_get_resume_point(GoalInfo0, Resume) },
	(
		{ Resume = resume_point(ResumeVarsPrime, ResumeLocsPrime) }
	->
		{ ResumeVars = ResumeVarsPrime},
		{ ResumeLocs = ResumeLocsPrime}
	;
		{ error("negated goal has no resume point") }
	),
	code_info__push_resume_point_vars(ResumeVars),
		% The next line is to enable Goal to pass the
		% pre_goal_update sanity check
	{ goal_info_set_resume_point(GoalInfo0, no_resume_point, GoalInfo) },
	{ Goal = GoalExpr - GoalInfo },

		% for a negated simple test, we can generate better code
		% than the general mechanism, because we don't have to
		% flush the cache.
	(
		{ CodeModel = model_semi },
		{ GoalExpr = unify(_, _, _, simple_test(L, R), _) },
		code_info__failure_is_direct_branch(CodeAddr),
		code_info__get_globals(Globals),
		{ globals__lookup_bool_option(Globals, simple_neg, yes) }
	->
			% Because we're generating a goal
			% (special-cased, though it may be)
			% we need to apply the pre- and post-
			% updates.
		code_info__pre_goal_update(GoalInfo, yes),
		code_info__produce_variable(L, CodeL, ValL),
		code_info__produce_variable(R, CodeR, ValR),
		code_info__variable_type(L, Type),
		{ Type = term__functor(term__atom("string"), [], _) ->
			Op = str_eq
		; Type = term__functor(term__atom("float"), [], _) ->
			Op = float_eq
		;
			Op = eq
		},
		{ TestCode = node([
			if_val(binop(Op, ValL, ValR), CodeAddr) -
				"test inequality"
		]) },
		code_info__post_goal_update(GoalInfo),
		{ Code = tree(tree(CodeL, CodeR), TestCode) }
	;
		code_gen__generate_negation_general(CodeModel, Goal,
			ResumeVars, ResumeLocs, Code)
	),
	code_info__pop_resume_point_vars.

:- pred code_gen__generate_negation_general(code_model, hlds_goal,
	set(var), resume_locs, code_tree, code_info, code_info).
:- mode code_gen__generate_negation_general(in, in, in, in, out, in, out)
	is det.

code_gen__generate_negation_general(CodeModel, Goal, ResumeVars, ResumeLocs,
		Code) -->
		% This code is a cut-down version of the code for semidet
		% if-then-elses.

	code_info__make_known_failure_cont(ResumeVars, ResumeLocs, no,
		ModContCode),

		% Maybe save the heap state current before the condition;
		% this ought to be after we make the failure continuation
		% because that causes the cache to get flushed
	code_info__get_globals(Globals),
	{
		globals__lookup_bool_option(Globals,
			reclaim_heap_on_semidet_failure, yes),
		code_util__goal_may_allocate_heap(Goal)
	->
		ReclaimHeap = yes
	;
		ReclaimHeap = no
	},
	code_info__maybe_save_hp(ReclaimHeap, SaveHpCode, MaybeHpSlot),

	{ globals__lookup_bool_option(Globals, use_trail, UseTrail) },
	code_info__maybe_save_ticket(UseTrail, SaveTicketCode,
		MaybeTicketSlot),

		% Generate the condition as a semi-deterministic goal;
		% it cannot be nondet, since mode correctness requires it
		% to have no output vars
	code_gen__generate_goal(model_semi, Goal, GoalCode),

	( { CodeModel = model_det } ->
		{ DiscardTicketCode = empty },
		{ FailCode = empty }
	;
		code_info__grab_code_info(CodeInfo),
		code_info__pop_failure_cont,
		% The call to reset_ticket(..., commit) here is necessary
		% in order to properly detect floundering.
		code_info__maybe_reset_and_discard_ticket(MaybeTicketSlot,
			commit, DiscardTicketCode),
		code_info__generate_failure(FailCode),
		code_info__slap_code_info(CodeInfo)
	),
	code_info__restore_failure_cont(RestoreContCode),
	code_info__maybe_reset_and_discard_ticket(MaybeTicketSlot, undo,
		RestoreTicketCode),
	code_info__maybe_restore_and_discard_hp(MaybeHpSlot, RestoreHpCode),
	{ Code = tree(ModContCode,
		 tree(SaveHpCode,
		 tree(SaveTicketCode,
		 tree(GoalCode,
		 tree(DiscardTicketCode, % is this necessary?
		 tree(FailCode,
		 tree(RestoreContCode,
		 tree(RestoreTicketCode,
		      RestoreHpCode)))))))) }.

%---------------------------------------------------------------------------%
%---------------------------------------------------------------------------%

:- pred code_gen__generate_non_goal_2(hlds_goal_expr, hlds_goal_info,
					code_tree, code_info, code_info).
:- mode code_gen__generate_non_goal_2(in, in, out, in, out) is det.

code_gen__generate_non_goal_2(conj(Goals), _GoalInfo, Code) -->
	code_gen__generate_goals(Goals, model_non, Code).
code_gen__generate_non_goal_2(some(_Vars, Goal), _GoalInfo, Code) -->
	{ Goal = _ - InnerGoalInfo },
	{ goal_info_get_code_model(InnerGoalInfo, CodeModel) },
	code_gen__generate_goal(CodeModel, Goal, Code).
code_gen__generate_non_goal_2(disj(Goals, StoreMap), _GoalInfo, Code) -->
	disj_gen__generate_non_disj(Goals, StoreMap, Code).
code_gen__generate_non_goal_2(not(_Goal), _GoalInfo, _Code) -->
	{ error("Cannot have a nondet negation.") }.
code_gen__generate_non_goal_2(higher_order_call(PredVar, Args, Types, Modes,
		Det, _PredOrFunc),
		GoalInfo, Code) -->
	call_gen__generate_higher_order_call(model_non, PredVar, Args, Types,
		Modes, Det, GoalInfo, Code).
code_gen__generate_non_goal_2(call(PredId, ProcId, Args, BuiltinState, _, _),
							GoalInfo, Code) -->
	(
		{ BuiltinState = not_builtin }
	->
		code_info__succip_is_used,
		call_gen__generate_call(model_non, PredId, ProcId, Args,
			GoalInfo, Code)
	;
		call_gen__generate_nondet_builtin(PredId, ProcId, Args, Code)
	).
code_gen__generate_non_goal_2(switch(Var, CanFail, CaseList, StoreMap),
		GoalInfo, Instr) -->
	switch_gen__generate_switch(model_non, Var, CanFail,
		CaseList, StoreMap, GoalInfo, Instr).
code_gen__generate_non_goal_2(
		if_then_else(_Vars, CondGoal, ThenGoal, ElseGoal, StoreMap),
							_GoalInfo, Instr) -->
	ite_gen__generate_nondet_ite(CondGoal, ThenGoal, ElseGoal,
		StoreMap, Instr).
code_gen__generate_non_goal_2(unify(_L, _R, _U, _Uni, _C),
							_GoalInfo, _Code) -->
	{ error("Cannot have a nondet unification.") }.
code_gen__generate_non_goal_2(pragma_c_code(C_Code, MayCallMercury,
		PredId, ModeId, Args, ArgNameMap, OrigArgTypes, Extra),
		GoalInfo, Instr) -->
	(
		{ Extra = none },
		% Error disabled for bootstrapping. string.m uses this form,
		% and we can't change it to the new form until the new form
		% is completed, and even then we must wait until that compiler
		% is installed on all our machines.
		% { error("nondet pragma has empty extras field") }
		pragma_c_gen__generate_pragma_c_code(model_semi, C_Code,
			MayCallMercury, PredId, ModeId, Args, ArgNameMap,
			OrigArgTypes, GoalInfo, Instr)
	;
		{ Extra = extra_pragma_info(SavedVars, LabelNames) },
		pragma_c_gen__generate_backtrack_pragma_c_code(model_semi,
			C_Code, MayCallMercury, PredId, ModeId, Args,
			ArgNameMap, OrigArgTypes, SavedVars, LabelNames,
			GoalInfo, Instr)
	).

%---------------------------------------------------------------------------%

code_gen__output_args([], LiveVals) :-
	set__init(LiveVals).
code_gen__output_args([_V - arg_info(Loc, Mode) | Args], Vs) :-
	code_gen__output_args(Args, Vs0),
	(
		Mode = top_out
	->
		code_util__arg_loc_to_register(Loc, Reg),
		set__insert(Vs0, Reg, Vs)
	;
		Vs = Vs0
	).

%---------------------------------------------------------------------------%

% Add the succip to the livevals before and after calls.
% Traverses the list of instructions looking for livevals and calls,
% adding succip in the stackvar number given as an argument.

:- pred code_gen__add_saved_succip(list(instruction), int, list(instruction)).
:- mode code_gen__add_saved_succip(in, in, out) is det.

code_gen__add_saved_succip([], _StackLoc, []).
code_gen__add_saved_succip([Instrn0 - Comment | Instrns0 ], StackLoc, 
		[Instrn - Comment | Instrns]) :-
	(
		Instrn0 = livevals(LiveVals0),
		Instrns0 \= [goto(succip) - _ | _]
		% XXX we should also test for tailcalls
		% once we start generating them directly
	->
		set__insert(LiveVals0, stackvar(StackLoc), LiveVals1),
		Instrn = livevals(LiveVals1)
        ;
		Instrn0 = call(Target, ReturnLabel, LiveVals0, CM)
	->
		Instrn  = call(Target, ReturnLabel, 
			[live_lvalue(stackvar(StackLoc), succip, []) |
			LiveVals0], CM)
	;
		Instrn = Instrn0
	),
	code_gen__add_saved_succip(Instrns0, StackLoc, Instrns).

%---------------------------------------------------------------------------%
%---------------------------------------------------------------------------%
