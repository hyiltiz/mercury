%-----------------------------------------------------------------------------%
% Copyright (C) 1994-1998 The University of Melbourne.
% This file may only be copied under the terms of the GNU General
% Public License - see the file COPYING in the Mercury distribution.
%-----------------------------------------------------------------------------%

% File: mode_errors.m.
% Main author: fjh.

% This module contains all the error-reporting routines for the
% mode-checker.

%-----------------------------------------------------------------------------%
%-----------------------------------------------------------------------------%

:- module mode_errors.

:- interface.

:- import_module hlds_data, hlds_goal, hlds_pred, hlds_module.
:- import_module prog_data, mode_info, (inst).
:- import_module set, assoc_list, list, term, bool.

%-----------------------------------------------------------------------------%

:- type merge_context
	---> disj
	;    if_then_else.

:- type merge_errors == assoc_list(var, list(inst)).

:- type delayed_goal
	--->	delayed_goal(
			set(var),	% The vars it's waiting on
			mode_error_info,% The reason it can't be scheduled
			hlds_goal	% The goal itself
		).

:- type mode_error
	--->	mode_error_disj(merge_context, merge_errors)
			% different arms of a disjunction result in
			% different insts for some non-local variables
	;	mode_error_higher_order_pred_var(pred_or_func, var, inst, arity)
			% the predicate variable in a higher-order predicate
			% or function call didn't have a higher-order
			% predicate or function inst of the appropriate arity
	;	mode_error_var_is_live(var)
			% call to a predicate which will clobber its argument,
			% but the argument is still live
	;	mode_error_var_has_inst(var, inst, inst)
			% call to a predicate with an insufficiently
			% instantiated variable (for preds with one mode)
	;	mode_error_unify_pred(var, mode_error_unify_rhs, type,
				pred_or_func)
			% an attempt was made to unify two higher-order
			% predicate or function variables.
	;	mode_error_implied_mode(var, inst, inst)
			% a call to a predicate with an overly
			% instantiated variable would use an implied
			% mode of the predicate.  XXX This is temporary - 
			% once we've implemented implied modes we can
			% get rid of it.
	;	mode_error_no_mode_decl
			% a call to a predicate for which there are
			% no mode declarations
	;	mode_error_no_matching_mode(list(var), list(inst))
			% call to a predicate with an insufficiently
			% instantiated variable (for preds with >1 mode)
	;	mode_error_bind_var(var_lock_reason, var, inst, inst)
			% attempt to bind a non-local variable inside
			% a negated context
	;	mode_error_non_local_lambda_var(var, inst)
			% attempt to pass a live non-ground var as a
			% non-local variable to a lambda goal
	;	mode_error_unify_var_var(var, var, inst, inst)
			% attempt to unify two free variables
	;	mode_error_unify_var_functor(var, cons_id, list(var),
							inst, list(inst))
			% attempt to unify a free var with a functor containing
			% free arguments
	;	mode_error_unify_var_lambda(var, inst, inst)
			% some sort of error in
			% attempt to unify a variable with lambda expression
	;	mode_error_conj(list(delayed_goal), schedule_culprit)
			% a conjunction contains one or more unscheduleable
			% goals; schedule_culprit gives the reason why
			% they couldn't be scheduled.
	;	mode_error_final_inst(int, var, inst, inst, final_inst_error)
			% one of the head variables did not have the
			% expected final inst on exit from the proc
	;	mode_error_undefined_mode_in_lambda.
			% This is a dummy error - the actual message
			% is output by module_qual.m.

:- type schedule_culprit
	--->	goal_itself_was_impure
	;	goals_followed_by_impure_goal(hlds_goal)
	;	conj_floundered. % we've reached the end of a conjunction
				% and there were still delayed goals

:- type final_inst_error
	--->	too_instantiated
	;	not_instantiated_enough
	;	wrongly_instantiated.	% a catchall for anything that doesn't
					% fit into the above two categories.

:- type mode_error_unify_rhs
	--->	error_at_var(var)
	;	error_at_functor(cons_id, list(var))
	;	error_at_lambda(list(var), list(mode)).

:- type mode_error_info
	---> mode_error_info(
		set(var),	% the variables which caused the error
				% (we will attempt to reschedule the goal
				% if the one of these variables becomes
				% more instantiated)
		mode_error,	% the nature of the error
		inst_table,	% The contemporary inst_table
		term__context,	% where the error occurred
		mode_context	% where the error occurred
	).

%-----------------------------------------------------------------------------%

        % If there were any errors recorded in the mode_info,
        % report them to the user now.
        %
:- pred report_mode_errors(mode_info, mode_info).
:- mode report_mode_errors(mode_info_di, mode_info_uo) is det.

	% report an error for a predicate with no mode declarations
	% unless mode inference is enabled and the predicate is local.

:- pred maybe_report_error_no_modes(pred_id, pred_info, module_info,
				io__state, io__state).
:- mode maybe_report_error_no_modes(in, in, in, di, uo) is det.

	% initialize the mode_context.

:- pred mode_context_init(mode_context).
:- mode mode_context_init(out) is det.

	% Write out the inferred `mode' declarations for a list of pred_ids.
	% The bool indicates whether or not to write out determinism
	% annotations on the modes (it should only be set to `yes' _after_
	% determinism analysis).

:- pred write_mode_inference_messages(list(pred_id), bool, module_info,
				io__state, io__state).
:- mode write_mode_inference_messages(in, in, in, di, uo) is det.

	% report an error for the case when two mode declarations
	% declare indistinguishable modes

:- pred report_indistinguishable_modes_error(proc_id, proc_id,
		pred_id, pred_info, module_info, io__state, io__state).
:- mode report_indistinguishable_modes_error(in, in, in, in, in, di, uo) is det.

%-----------------------------------------------------------------------------%
%-----------------------------------------------------------------------------%

:- implementation.

:- import_module hlds_module, hlds_pred, hlds_goal, hlds_out.
:- import_module mode_info, mode_util, prog_out, mercury_to_mercury.
:- import_module options, globals.
:- import_module bool, int, list, map, io, term, term_io, varset.
:- import_module std_util, require.

	% print an error message describing a mode error
	% just dispatch on the diffferent sorts of mode errors

:- pred report_mode_error(mode_error, inst_table, mode_info,
			io__state, io__state).
:- mode report_mode_error(in, in, mode_info_no_io,
			di, uo) is det.

report_mode_error(mode_error_disj(MergeContext, ErrorList), InstTable,
		ModeInfo) -->
	report_mode_error_disj(InstTable, ModeInfo, MergeContext, ErrorList).
report_mode_error(mode_error_higher_order_pred_var(PredOrFunc, Var, Inst,
		Arity), InstTable, ModeInfo) -->
	report_mode_error_higher_order_pred_var(InstTable, ModeInfo, PredOrFunc,
		Var, Inst, Arity).
report_mode_error(mode_error_var_is_live(Var), _InstTable, ModeInfo) -->
	report_mode_error_var_is_live(ModeInfo, Var).
report_mode_error(mode_error_var_has_inst(Var, InstA, InstB), InstTable,
		ModeInfo) -->
	report_mode_error_var_has_inst(InstTable, ModeInfo, Var, InstA, InstB).
report_mode_error(mode_error_unify_pred(Var, RHS, Type, PredOrFunc),
		InstTable, ModeInfo) -->
	report_mode_error_unify_pred(InstTable, ModeInfo, Var, RHS, Type,
		PredOrFunc).
report_mode_error(mode_error_implied_mode(Var, InstA, InstB), InstTable,
		ModeInfo) -->
	report_mode_error_implied_mode(InstTable, ModeInfo, Var, InstA, InstB).
report_mode_error(mode_error_no_mode_decl, _InstTable, ModeInfo) -->
	report_mode_error_no_mode_decl(ModeInfo).
report_mode_error(mode_error_bind_var(Reason, Var, InstA, InstB), InstTable,
		ModeInfo) -->
	report_mode_error_bind_var(InstTable, ModeInfo,
		Reason, Var, InstA, InstB).
report_mode_error(mode_error_non_local_lambda_var(Var, Inst), InstTable,
		ModeInfo) -->
	report_mode_error_non_local_lambda_var(InstTable, ModeInfo, Var, Inst).
report_mode_error(mode_error_unify_var_var(VarA, VarB, InstA, InstB),
		InstTable, ModeInfo) -->
	report_mode_error_unify_var_var(InstTable, ModeInfo, VarA, VarB,
		InstA, InstB).
report_mode_error(mode_error_unify_var_lambda(VarA, InstA, InstB),
		InstTable, ModeInfo) -->
	report_mode_error_unify_var_lambda(InstTable, ModeInfo, VarA,
		InstA, InstB).
report_mode_error(mode_error_unify_var_functor(Var, Name, Args, Inst,
			ArgInsts), InstTable, ModeInfo) -->
	report_mode_error_unify_var_functor(InstTable, ModeInfo, Var, Name,
			Args, Inst, ArgInsts).
report_mode_error(mode_error_conj(Errors, Culprit), InstTable, ModeInfo) -->
	report_mode_error_conj(InstTable, ModeInfo, Errors, Culprit).
report_mode_error(mode_error_no_matching_mode(Vars, Insts), InstTable,
			ModeInfo) -->
	report_mode_error_no_matching_mode(InstTable, ModeInfo, Vars, Insts).
report_mode_error(mode_error_final_inst(ArgNum, Var, VarInst, Inst, Reason),
		InstTable, ModeInfo) -->
	report_mode_error_final_inst(InstTable, ModeInfo, ArgNum, Var,
		VarInst, Inst, Reason).
report_mode_error(mode_error_undefined_mode_in_lambda, _InstTable, _ModeInfo)
		--> [].

%-----------------------------------------------------------------------------%

:- pred report_mode_error_conj(inst_table, mode_info, list(delayed_goal),
				schedule_culprit, io__state, io__state).
:- mode report_mode_error_conj(in, mode_info_no_io, in, in, di, uo) is det.

report_mode_error_conj(InstTable, ModeInfo, Errors, Culprit) -->
	{ mode_info_get_context(ModeInfo, Context) },
	{ mode_info_get_varset(ModeInfo, VarSet) },
	{ find_important_errors(Errors, ImportantErrors, OtherErrors) },

	% if there's more than one error, and we have verbose-errors
	% enabled, report them all
	globals__io_lookup_bool_option(verbose_errors, VerboseErrors),
	( { VerboseErrors = yes, Errors = [_, _ | _] } ->
		mode_info_write_context(ModeInfo),
		prog_out__write_context(Context),
		io__write_string("  mode error in conjunction. The next "),
		{ list__length(Errors, NumErrors) },
		io__write_int(NumErrors),
		io__write_string(" error messages\n"),
		prog_out__write_context(Context),
		io__write_string("  indicate possible causes of this error.\n"),
		report_mode_error_conj_2(ImportantErrors, VarSet, Context,
			InstTable, ModeInfo),
		report_mode_error_conj_2(OtherErrors, VarSet, Context,
			InstTable, ModeInfo)
	;
		% in the normal case, only report the first error
		{ ImportantErrors = [FirstImportantError | _] }
	->
		report_mode_error_conj_2([FirstImportantError], VarSet, Context,
			InstTable, ModeInfo)
	;
		{ OtherErrors = [FirstOtherError | _] }
	->
		report_mode_error_conj_2([FirstOtherError], VarSet, Context,
			InstTable, ModeInfo)
	;
		% There wasn't any error to report!  This can't happen.
		{ error("report_mode_error_conj") }
	),

	% if the goal(s) couldn't be scheduled because we couldn't
	% reorder things past an impure goal, then report that.
	( { Culprit = conj_floundered },
		{ true } % we've already reported everything we can
	; { Culprit = goal_itself_was_impure },
		prog_out__write_context(Context),
		io__write_string(
		"  The goal could not be reordered, because it was impure.\n")
	; { Culprit = goals_followed_by_impure_goal(ImpureGoal) },
		prog_out__write_context(Context),
		io__write_string(
			"  The goal could not be reordered, because\n"),
		prog_out__write_context(Context),
		io__write_string(
			"  it was followed by an impure goal.\n"),
		{ ImpureGoal = _ - ImpureGoalInfo },
		{ goal_info_get_context(ImpureGoalInfo, ImpureGoalContext) },
		prog_out__write_context(ImpureGoalContext),
		io__write_string(
			"  This is the location of the impure goal.\n")
	).

:- pred find_important_errors(list(delayed_goal), list(delayed_goal),
			list(delayed_goal)).
:- mode find_important_errors(in, out, out) is det.

find_important_errors([], [], []).
find_important_errors([Error | Errors], ImportantErrors, OtherErrors) :-
	Error = delayed_goal(_,
			mode_error_info(_, ModeError, _, _, ModeContext), _),
	(
		% an error is important unless it is a non-explicit unification,
		% i.e. a head unification or a call argument unification
		ModeContext = unify(unify_context(UnifyContext, _), _),
		UnifyContext \= explicit,
		% except that errors in lambda goals are important even
		% if the unification that creates the lambda goal is
		% an implicit one
		ModeError \= mode_error_non_local_lambda_var(_, _)
	->
		ImportantErrors1 = ImportantErrors,
		OtherErrors = [Error | OtherErrors1]
	;
		ImportantErrors = [Error | ImportantErrors1],
		OtherErrors1 = OtherErrors
	),
	find_important_errors(Errors, ImportantErrors1, OtherErrors1).

:- pred report_mode_error_conj_2(list(delayed_goal), varset, term__context,
				inst_table, mode_info, io__state, io__state).
:- mode report_mode_error_conj_2(in, in, in, in, mode_info_no_io,
				di, uo) is det.

report_mode_error_conj_2([], _, _, _, _) --> [].
report_mode_error_conj_2([delayed_goal(Vars, Error, Goal) | Rest],
			VarSet, Context, InstTable, ModeInfo) -->
	globals__io_lookup_bool_option(debug_modes, Debug),
	( { Debug = yes } ->
		prog_out__write_context(Context),
		io__write_string("Floundered goal, waiting on { "),
		{ set__to_sorted_list(Vars, VarList) },
		mercury_output_vars(VarList, VarSet, no),
		io__write_string(" } :\n")
	;
		[]
	),
	globals__io_lookup_bool_option(very_verbose, VeryVerbose),
	( { VeryVerbose = yes } ->
		io__write_string("\t\t"),
		{ mode_info_get_module_info(ModeInfo, ModuleInfo) },
		hlds_out__write_goal(Goal, InstTable, ModuleInfo, VarSet, no,
			2, ".")
	;
		[]
	),
	{ Error = mode_error_info(_, ModeError, _, ErrorContext, ModeContext) },
	{ mode_info_set_context(ErrorContext, ModeInfo, ModeInfo1) },
	{ mode_info_set_mode_context(ModeContext, ModeInfo1, ModeInfo2) },
	report_mode_error(ModeError, InstTable, ModeInfo2),
	report_mode_error_conj_2(Rest, VarSet, Context, InstTable, ModeInfo2).

%-----------------------------------------------------------------------------%

:- pred report_mode_error_disj(inst_table, mode_info, merge_context,
				merge_errors, io__state, io__state).
:- mode report_mode_error_disj(in, mode_info_no_io, in, in, di, uo) is det.

report_mode_error_disj(InstTable, ModeInfo, MergeContext, ErrorList) -->
	{ mode_info_get_context(ModeInfo, Context) },
	mode_info_write_context(ModeInfo),
	prog_out__write_context(Context),
	io__write_string("  mode mismatch in "),
	write_merge_context(MergeContext),
	io__write_string(".\n"),
	write_merge_error_list(ErrorList, InstTable, ModeInfo).

:- pred write_merge_error_list(merge_errors, inst_table, mode_info,
				io__state, io__state).
:- mode write_merge_error_list(in, in, mode_info_no_io, di, uo) is det.

write_merge_error_list([], _, _) --> [].
write_merge_error_list([Var - Insts | Errors], InstTable, ModeInfo) -->
	{ mode_info_get_context(ModeInfo, Context) },
	{ mode_info_get_varset(ModeInfo, VarSet) },
	{ mode_info_get_instvarset(ModeInfo, InstVarSet) },
	prog_out__write_context(Context),
	io__write_string("  `"),
	mercury_output_var(Var, VarSet, no),
	io__write_string("' :: "),
	output_inst_list(Insts, InstVarSet, InstTable),
	io__write_string(".\n"),
	write_merge_error_list(Errors, InstTable, ModeInfo).

:- pred write_merge_context(merge_context, io__state, io__state).
:- mode write_merge_context(in, di, uo) is det.

write_merge_context(disj) -->
	io__write_string("disjunction").
write_merge_context(if_then_else) -->
	io__write_string("if-then-else").

%-----------------------------------------------------------------------------%

:- pred report_mode_error_bind_var(inst_table, mode_info, var_lock_reason,
				var, inst, inst, io__state, io__state).
:- mode report_mode_error_bind_var(in, mode_info_ui, in, in, in, in,
				di, uo) is det.

report_mode_error_bind_var(InstTable, ModeInfo, Reason, Var, VarInst, Inst) -->
	{ mode_info_get_context(ModeInfo, Context) },
	{ mode_info_get_varset(ModeInfo, VarSet) },
	{ mode_info_get_instvarset(ModeInfo, InstVarSet) },
	mode_info_write_context(ModeInfo),
	prog_out__write_context(Context),
	io__write_string("  scope error: "),
	( { Reason = negation },
		io__write_string("attempt to bind a variable inside a negation.\n")
	; { Reason = if_then_else },
		io__write_string("attempt to bind a non-local variable\n"),
		prog_out__write_context(Context),
		io__write_string("  inside the condition of an if-then-else.\n")
	; { Reason = lambda(PredOrFunc) },
		{ hlds_out__pred_or_func_to_str(PredOrFunc, PredOrFuncS) },
		io__write_string("attempt to bind a non-local variable inside\n"),
		prog_out__write_context(Context),
		io__write_strings(["  a ", PredOrFuncS, " lambda goal.\n"])
	),
	prog_out__write_context(Context),
	io__write_string("  Variable `"),
	mercury_output_var(Var, VarSet, no),
	io__write_string("' has instantiatedness `"),
	output_inst(VarInst, InstVarSet, InstTable),
	io__write_string("',\n"),
	prog_out__write_context(Context),
	io__write_string("  expected instantiatedness was `"),
	output_inst(Inst, InstVarSet, InstTable),
	io__write_string("'.\n"),
	globals__io_lookup_bool_option(verbose_errors, VerboseErrors),
	( { VerboseErrors = yes } ->
		( { Reason = negation },
			io__write_string("\tA negation is only allowed to bind variables which are local to the\n"),
			io__write_string("\tnegation, i.e. those which are implicitly existentially quantified\n"),
			io__write_string("\tinside the scope of the negation.\n")
		; { Reason = if_then_else },
			io__write_string("\tThe condition of an if-then-else is only allowed\n"),
			io__write_string("\tto bind variables which are local to the condition\n"),
			io__write_string("\tor which occur only in the condition and the `then' part.\n")
		; { Reason = lambda(_) },
			io__write_string("\tA lambda goal is only allowed to bind its arguments\n"),
			io__write_string("\tand variables local to the lambda expression.\n")
		)
	;
		[]
	).

%-----------------------------------------------------------------------------%

:- pred report_mode_error_non_local_lambda_var(inst_table, mode_info, var, inst,
					io__state, io__state).
:- mode report_mode_error_non_local_lambda_var(in, mode_info_ui, in, in,
					di, uo) is det.

report_mode_error_non_local_lambda_var(InstTable, ModeInfo, Var, VarInst) -->
	{ mode_info_get_context(ModeInfo, Context) },
	{ mode_info_get_varset(ModeInfo, VarSet) },
	{ mode_info_get_instvarset(ModeInfo, InstVarSet) },
	mode_info_write_context(ModeInfo),
	prog_out__write_context(Context),
	io__write_string("  mode error: variable `"),
	mercury_output_var(Var, VarSet, no),
	io__write_string("' has instantiatedness `"),
	output_inst(VarInst, InstVarSet, InstTable),
	io__write_string("',\n"),
	prog_out__write_context(Context),
	io__write_string("  expected instantiatedness for non-local variables\n"),
	prog_out__write_context(Context),
	io__write_string("  of lambda goals is `ground'.\n").

%-----------------------------------------------------------------------------%

:- pred report_mode_error_no_matching_mode(inst_table, mode_info,
				list(var), list(inst), io__state, io__state).
:- mode report_mode_error_no_matching_mode(in, mode_info_ui, in, in,
				di, uo) is det.

report_mode_error_no_matching_mode(InstTable, ModeInfo, Vars, Insts) -->
	{ mode_info_get_context(ModeInfo, Context) },
	{ mode_info_get_varset(ModeInfo, VarSet) },
	{ mode_info_get_instvarset(ModeInfo, InstVarSet) },
	{ mode_info_get_module_info(ModeInfo, ModuleInfo) },
	mode_info_write_context(ModeInfo),
	prog_out__write_context(Context),
	io__write_string("  mode error: arguments `"),
	mercury_output_vars(Vars, VarSet, no),
	io__write_string("'\n"),
	prog_out__write_context(Context),
	io__write_string("  have insts `"),
	output_inst_list(Insts, InstVarSet, InstTable),
	io__write_string("',\n"),
	prog_out__write_context(Context),
	io__write_string("  which does not match any of the modes for "),
	{ mode_info_get_mode_context(ModeInfo, ModeContext) },
	( { ModeContext = call(PredId, _) } ->
		hlds_out__write_pred_id(ModuleInfo, PredId)
	;
		{ error("report_mode_error_no_matching_mode: invalid context") }
	),
	io__write_string(".\n").

:- pred report_mode_error_higher_order_pred_var(inst_table, mode_info,
					pred_or_func, var, inst, arity,
					io__state, io__state).
:- mode report_mode_error_higher_order_pred_var(in, mode_info_ui, in, in, in,
					in, di, uo) is det.

report_mode_error_higher_order_pred_var(InstTable, ModeInfo, PredOrFunc, Var,
		VarInst, Arity) -->
	{ mode_info_get_context(ModeInfo, Context) },
	{ mode_info_get_varset(ModeInfo, VarSet) },
	{ mode_info_get_instvarset(ModeInfo, InstVarSet) },
	mode_info_write_context(ModeInfo),
	prog_out__write_context(Context),
	io__write_string("  mode error: variable `"),
	mercury_output_var(Var, VarSet, no),
	io__write_string("' has instantiatedness `"),
	output_inst(VarInst, InstVarSet, InstTable),
	io__write_string("',\n"),
	prog_out__write_context(Context),
	(	{ PredOrFunc = predicate },
		io__write_string("  expecting higher-order pred inst (of arity "),
		io__write_int(Arity)
	;	{ PredOrFunc = function },
		io__write_string("  expecting higher-order func inst (of arity "),
		{ Arity1 is Arity - 1 },
		io__write_int(Arity1)
	),
	io__write_string(").\n").

:- pred report_mode_error_var_is_live(mode_info, var, io__state, io__state).
:- mode report_mode_error_var_is_live(mode_info_ui, in, di, uo) is det.

report_mode_error_var_is_live(ModeInfo, Var) -->
	{ mode_info_get_context(ModeInfo, Context) },
	{ mode_info_get_varset(ModeInfo, VarSet) },
	mode_info_write_context(ModeInfo),
	prog_out__write_context(Context),
	io__write_string("  unique-mode error: the called procedure would clobber\n"),
	prog_out__write_context(Context),
	io__write_string("  its argument, but variable `"),
	mercury_output_var(Var, VarSet, no),
	io__write_string("' is still live.\n").

:- pred report_mode_error_var_has_inst(inst_table, mode_info, var, inst, inst,
					io__state, io__state).
:- mode report_mode_error_var_has_inst(in, mode_info_ui, in, in, in,
					di, uo) is det.

report_mode_error_var_has_inst(InstTable, ModeInfo, Var, VarInst, Inst) -->
	{ mode_info_get_context(ModeInfo, Context) },
	{ mode_info_get_varset(ModeInfo, VarSet) },
	{ mode_info_get_instvarset(ModeInfo, InstVarSet) },
	mode_info_write_context(ModeInfo),
	prog_out__write_context(Context),
	io__write_string("  mode error: variable `"),
	mercury_output_var(Var, VarSet, no),
	io__write_string("' has instantiatedness `"),
	output_inst(VarInst, InstVarSet, InstTable),
	io__write_string("',\n"),
	prog_out__write_context(Context),
	io__write_string("  expected instantiatedness was `"),
	output_inst(Inst, InstVarSet, InstTable),
	io__write_string("'.\n").

:- pred report_mode_error_implied_mode(inst_table, mode_info, var, inst, inst,
					io__state, io__state).
:- mode report_mode_error_implied_mode(in, mode_info_ui, in, in, in,
					di, uo) is det.

report_mode_error_implied_mode(InstTable, ModeInfo, Var, VarInst, Inst) -->
		% This "error" message is really a "sorry, not implemented"
		% message.  We only print the message if we are actually
		% going to generating code.
	globals__io_lookup_bool_option(errorcheck_only, ErrorcheckOnly),
	( { ErrorcheckOnly = no } ->
		{ mode_info_get_context(ModeInfo, Context) },
		{ mode_info_get_varset(ModeInfo, VarSet) },
		{ mode_info_get_instvarset(ModeInfo, InstVarSet) },
		mode_info_write_context(ModeInfo),
		prog_out__write_context(Context),
		io__write_string("  sorry, implied modes not implemented.\n"),
		prog_out__write_context(Context),
		io__write_string("  Variable `"),
		mercury_output_var(Var, VarSet, no),
		io__write_string("' has instantiatedness `"),
		output_inst(VarInst, InstVarSet, InstTable),
		io__write_string("',\n"),
		prog_out__write_context(Context),
		io__write_string("  expected instantiatedness was `"),
		output_inst(Inst, InstVarSet, InstTable),
		io__write_string("'.\n")
	;
		[]
	).

:- pred report_mode_error_no_mode_decl(mode_info, io__state, io__state).
:- mode report_mode_error_no_mode_decl(mode_info_ui, di, uo) is det.

report_mode_error_no_mode_decl(ModeInfo) -->
	{ mode_info_get_context(ModeInfo, Context) },
	mode_info_write_context(ModeInfo),
	prog_out__write_context(Context),
	io__write_string("  no mode declaration for called predicate.\n").

:- pred report_mode_error_unify_pred(inst_table, mode_info, var,
					mode_error_unify_rhs,
					type, pred_or_func,
					io__state, io__state).
:- mode report_mode_error_unify_pred(in, mode_info_ui, in, in, in, in,
					di, uo) is det.

report_mode_error_unify_pred(InstTable, ModeInfo, X, RHS, Type, PredOrFunc) -->
	{ mode_info_get_context(ModeInfo, Context) },
	{ mode_info_get_varset(ModeInfo, VarSet) },
	mode_info_write_context(ModeInfo),
	prog_out__write_context(Context),
	io__write_string("  In unification of `"),
	mercury_output_var(X, VarSet, no),
	io__write_string("' with `"),
	(
		{ RHS = error_at_var(Y) },
		mercury_output_var(Y, VarSet, no)
	;
		{ RHS = error_at_functor(ConsId, ArgVars) },
		hlds_out__write_functor_cons_id(ConsId, ArgVars, VarSet, no)
	;
		{ RHS = error_at_lambda(ArgVars, ArgModes) },
		io__write_string("lambda(["),
		hlds_out__write_var_modes(ArgVars, ArgModes, VarSet, no,
			InstTable),
		io__write_string("] ... )")
	),
	io__write_string("':\n"),
	prog_out__write_context(Context),
	io__write_string("  mode error: attempt at higher-order unification.\n"),
	prog_out__write_context(Context),
	io__write_string("  Cannot unify two terms of type `"),
	{ varset__init(TypeVarSet) },
	mercury_output_term(Type, TypeVarSet, no),
	io__write_string("'.\n"),
	globals__io_lookup_bool_option(verbose_errors, VerboseErrors),
	( { VerboseErrors = yes } ->
		io__write_string("\tYour code is trying to test whether two "),
		hlds_out__write_pred_or_func(PredOrFunc),
		io__write_string("s are equal,\n"),
		io__write_string("\tby unifying them.  In the general case, testing equivalence\n"),
		io__write_string("\tof "),
		hlds_out__write_pred_or_func(PredOrFunc),
		io__write_string("s is an undecidable problem,\n"),
		io__write_string("\tand so this is not allowed by the Mercury mode system.\n"),
		io__write_string("\tIn some cases, you can achieve the same effect by\n"),
		io__write_string("\twriting an explicit universal quantification,\n"),
		io__write_string("\te.g. `all [X] call(P, X) <=> call(Q, X)',"),
		io__write_string(" instead of `P = Q'.\n")
	;
		[]
	).

%-----------------------------------------------------------------------------%

:- pred report_mode_error_unify_var_var(inst_table, mode_info, var, var,
					inst, inst, io__state, io__state).
:- mode report_mode_error_unify_var_var(in, mode_info_ui, in, in, in, in,
					di, uo) is det.

report_mode_error_unify_var_var(InstTable, ModeInfo, X, Y, InstX, InstY) -->
	{ mode_info_get_context(ModeInfo, Context) },
	{ mode_info_get_varset(ModeInfo, VarSet) },
	{ mode_info_get_instvarset(ModeInfo, InstVarSet) },
	mode_info_write_context(ModeInfo),
	prog_out__write_context(Context),
	io__write_string("  mode error in unification of `"),
	mercury_output_var(X, VarSet, no),
	io__write_string("' and `"),
	mercury_output_var(Y, VarSet, no),
	io__write_string("'.\n"),
	prog_out__write_context(Context),
	io__write_string("  Variable `"),
	mercury_output_var(X, VarSet, no),
	io__write_string("' has instantiatedness `"),
	output_inst(InstX, InstVarSet, InstTable),
	io__write_string("',\n"),
	prog_out__write_context(Context),
	io__write_string("  variable `"),
	mercury_output_var(Y, VarSet, no),
	io__write_string("' has instantiatedness `"),
	output_inst(InstY, InstVarSet, InstTable),
	io__write_string("'.\n").

%-----------------------------------------------------------------------------%

:- pred report_mode_error_unify_var_lambda(inst_table, mode_info,
					var, inst, inst, io__state, io__state).
:- mode report_mode_error_unify_var_lambda(in, mode_info_ui, in, in, in,
					di, uo) is det.

report_mode_error_unify_var_lambda(InstTable, ModeInfo, X, InstX, InstY) -->
	{ mode_info_get_context(ModeInfo, Context) },
	{ mode_info_get_varset(ModeInfo, VarSet) },
	{ mode_info_get_instvarset(ModeInfo, InstVarSet) },
	mode_info_write_context(ModeInfo),
	prog_out__write_context(Context),
	io__write_string("  mode error in unification of `"),
	mercury_output_var(X, VarSet, no),
	io__write_string("' and lambda expression.\n"),
	prog_out__write_context(Context),
	io__write_string("  Variable `"),
	mercury_output_var(X, VarSet, no),
	io__write_string("' has instantiatedness `"),
	output_inst(InstX, InstVarSet, InstTable),
	io__write_string("',\n"),
	prog_out__write_context(Context),
	io__write_string("  lambda expression has instantiatedness `"),
	output_inst(InstY, InstVarSet, InstTable),
	io__write_string("'.\n").

%-----------------------------------------------------------------------------%

:- pred report_mode_error_unify_var_functor(inst_table, mode_info, var,
					cons_id, list(var), inst, list(inst),
					io__state, io__state).
:- mode report_mode_error_unify_var_functor(in, mode_info_ui, in, in, in,
					in, in, di, uo) is det.

report_mode_error_unify_var_functor(InstTable, ModeInfo, X, ConsId, Args,
		InstX, ArgInsts) -->
	{ mode_info_get_context(ModeInfo, Context) },
	{ mode_info_get_varset(ModeInfo, VarSet) },
	{ mode_info_get_instvarset(ModeInfo, InstVarSet) },
	mode_info_write_context(ModeInfo),
	prog_out__write_context(Context),
	io__write_string("  mode error in unification of `"),
	mercury_output_var(X, VarSet, no),
	io__write_string("' and `"),
	hlds_out__write_functor_cons_id(ConsId, Args, VarSet, no),
	io__write_string("'.\n"),
	prog_out__write_context(Context),
	io__write_string("  Variable `"),
	mercury_output_var(X, VarSet, no),
	io__write_string("' has instantiatedness `"),
	output_inst(InstX, InstVarSet, InstTable),
	io__write_string("',\n"),
	prog_out__write_context(Context),
	io__write_string("  term `"),
	hlds_out__write_functor_cons_id(ConsId, Args, VarSet, no),
	( { Args \= [] } ->
		io__write_string("'\n"),
		prog_out__write_context(Context),
		io__write_string("  has instantiatedness `"),
		mercury_output_cons_id(ConsId, no),
		io__write_string("("),
		output_inst_list(ArgInsts, InstVarSet, InstTable),
		io__write_string(")")
	;
		io__write_string("' has instantiatedness `"),
		mercury_output_cons_id(ConsId, no)
	),
	io__write_string("'.\n").

%-----------------------------------------------------------------------------%

:- pred mode_info_write_context(mode_info, io__state, io__state).
:- mode mode_info_write_context(mode_info_no_io, di, uo) is det.

mode_info_write_context(ModeInfo) -->
	{ mode_info_get_module_info(ModeInfo, ModuleInfo) },
	{ mode_info_get_context(ModeInfo, Context) },
	{ mode_info_get_predid(ModeInfo, PredId) },
	{ mode_info_get_procid(ModeInfo, ProcId) },
	{ module_info_preds(ModuleInfo, Preds) },
	{ map__lookup(Preds, PredId, PredInfo) },
	{ pred_info_procedures(PredInfo, Procs) },
	{ pred_info_get_is_pred_or_func(PredInfo, PredOrFunc) },
	{ map__lookup(Procs, ProcId, ProcInfo) },
	{ proc_info_declared_argmodes(ProcInfo,
		argument_modes(InstTable, Modes0)) },
	{ strip_builtin_qualifiers_from_mode_list(Modes0, Modes) },
	{ pred_info_name(PredInfo, Name0) },
	{ Name = unqualified(Name0) },
	{ mode_info_get_instvarset(ModeInfo, InstVarSet) },
	{ MaybeDet = no },

	prog_out__write_context(Context),
	io__write_string("In clause for `"),
	mercury_output_mode_subdecl(PredOrFunc, InstVarSet, Name, Modes,
				MaybeDet, Context, InstTable),
	io__write_string("':\n"),
	{ mode_info_get_mode_context(ModeInfo, ModeContext) },
	write_mode_context(ModeContext, Context, ModuleInfo).

%-----------------------------------------------------------------------------%

:- pred report_mode_error_final_inst(inst_table, mode_info, int, var,
			inst, inst, final_inst_error, io__state, io__state).
:- mode report_mode_error_final_inst(in, mode_info_ui, in, in, in, in, in,
			di, uo) is det.

report_mode_error_final_inst(InstTable, ModeInfo, ArgNum, Var, VarInst, Inst,
			Reason) -->
	{ mode_info_get_context(ModeInfo, Context) },
	{ mode_info_get_varset(ModeInfo, VarSet) },
	{ mode_info_get_instvarset(ModeInfo, InstVarSet) },
	mode_info_write_context(ModeInfo),
	prog_out__write_context(Context),
	io__write_string("  mode error: argument "),
	io__write_int(ArgNum),
	( { Reason = too_instantiated } ->
		io__write_string(" became too instantiated")
	; { Reason = not_instantiated_enough } ->
		io__write_string(" did not get sufficiently instantiated")
	;
		% I don't think this can happen.  But just in case...
		io__write_string(" had the wrong instantiatedness")
	),
	io__write_string(".\n"),

	prog_out__write_context(Context),
	io__write_string("  Final instantiatedness of `"),
	mercury_output_var(Var, VarSet, no),
	io__write_string("' was `"),
	output_inst(VarInst, InstVarSet, InstTable),
	io__write_string("',\n"),

	prog_out__write_context(Context),
	io__write_string("  expected final instantiatedness was `"),
	output_inst(Inst, InstVarSet, InstTable),
	io__write_string("'.\n").


%-----------------------------------------------------------------------------%
%-----------------------------------------------------------------------------%

mode_context_init(uninitialized).

%-----------------------------------------------------------------------------%

	% XXX some parts of the mode context never get set up

:- pred write_mode_context(mode_context, term__context, module_info,
				io__state, io__state).
:- mode write_mode_context(in, in, in, di, uo) is det.

write_mode_context(uninitialized, _Context, _ModuleInfo) -->
	[].

write_mode_context(higher_order_call(PredOrFunc, ArgNum), Context, _ModuleInfo)
		-->
	prog_out__write_context(Context),
	io__write_string("  in "),
	( { ArgNum = 0 } ->
		io__write_string("higher-order "),
		hlds_out__write_pred_or_func(PredOrFunc),
		io__write_string(" call:\n")
	;
		io__write_string("argument "),
		io__write_int(ArgNum),
		io__write_string(" of higher-order "),
		hlds_out__write_pred_or_func(PredOrFunc),
		io__write_string(" call\n"),
		prog_out__write_context(Context),
		io__write_string("  (i.e. in "),
		( { ArgNum = 1 } ->
			io__write_string("the "),
			hlds_out__write_pred_or_func(PredOrFunc),
			io__write_string(" term")
		;
			io__write_string("argument "),
			{ ArgNum1 is ArgNum - 1 },
			io__write_int(ArgNum1),
			io__write_string(" of the called "),
			hlds_out__write_pred_or_func(PredOrFunc)
		),
		io__write_string("):\n")
	).

write_mode_context(call(PredId, ArgNum), Context, ModuleInfo) -->
	prog_out__write_context(Context),
	io__write_string("  in "),
	( { ArgNum = 0 } ->
		[]
	;
		io__write_string("argument "),
		io__write_int(ArgNum),
		io__write_string(" of ")
	),
	io__write_string("call to "),
	hlds_out__write_pred_id(ModuleInfo, PredId),
	io__write_string(":\n").

write_mode_context(unify(UnifyContext, _Side), Context, _ModuleInfo) -->
	hlds_out__write_unify_context(UnifyContext, Context).

%-----------------------------------------------------------------------------%

maybe_report_error_no_modes(PredId, PredInfo, ModuleInfo) -->
	{ pred_info_import_status(PredInfo, ImportStatus) },
	( { ImportStatus = local } ->
		globals__io_lookup_bool_option(infer_modes, InferModesOpt),
		( { InferModesOpt = yes } ->
			[]
		;
			io__set_exit_status(1),
			{ pred_info_context(PredInfo, Context) },
			prog_out__write_context(Context),
			io__write_string("Error: no mode declaration for "),
			hlds_out__write_pred_id(ModuleInfo, PredId),
			io__write_string(".\n"),
			globals__io_lookup_bool_option(verbose_errors,
				VerboseErrors),
			( { VerboseErrors = yes } ->
				prog_out__write_context(Context),
				io__write_string(
			"  (Use `--infer-modes' to enable mode inference.)\n")
			;
				[]
			)
		)
	;
		io__set_exit_status(1),
		{ pred_info_context(PredInfo, Context) },
		prog_out__write_context(Context),
		io__write_string("Error: no mode declaration for exported\n"),
		prog_out__write_context(Context),
		io__write_string("  "),
		hlds_out__write_pred_id(ModuleInfo, PredId),
		io__write_string(".\n")
	
	).

%-----------------------------------------------------------------------------%

	% write out the inferred `mode' declarations for a list of pred_ids.

write_mode_inference_messages([], _, _) --> [].
write_mode_inference_messages([PredId | PredIds], OutputDetism, ModuleInfo) -->
	{ module_info_pred_info(ModuleInfo, PredId, PredInfo) },
	{ pred_info_get_markers(PredInfo, Markers) },
	( { check_marker(Markers, infer_modes) } ->
		{ pred_info_procedures(PredInfo, Procs) },
		{ map__keys(Procs, ProcIds) },
		write_mode_inference_messages_2(ProcIds, Procs, PredInfo,
			OutputDetism)
	;
		[]
	),
	write_mode_inference_messages(PredIds, OutputDetism, ModuleInfo).

	% write out the inferred `mode' declarations for a list of
	% proc_ids

:- pred write_mode_inference_messages_2(list(proc_id), proc_table, pred_info,
				bool, io__state, io__state).
:- mode write_mode_inference_messages_2(in, in, in, in, di, uo) is det.

write_mode_inference_messages_2([], _, _, _) --> [].
write_mode_inference_messages_2([ProcId | ProcIds], Procs, PredInfo,
		OutputDetism) -->
	{ map__lookup(Procs, ProcId, ProcInfo) },
	write_mode_inference_message(PredInfo, ProcInfo, OutputDetism),
	write_mode_inference_messages_2(ProcIds, Procs, PredInfo, OutputDetism).

	% write out the inferred `mode' declaration
	% for a single function or predicate.

:- pred write_mode_inference_message(pred_info, proc_info, bool,
				io__state, io__state).
:- mode write_mode_inference_message(in, in, in, di, uo) is det.

write_mode_inference_message(PredInfo, ProcInfo, OutputDetism) -->
	{ pred_info_name(PredInfo, PredName) },
	{ Name = unqualified(PredName) },
	{ pred_info_context(PredInfo, Context) },
	{ proc_info_argmodes(ProcInfo, argument_modes(InstTable, Modes0)) },
	{ varset__init(VarSet) },
	{ pred_info_get_is_pred_or_func(PredInfo, PredOrFunc) },
	( { OutputDetism = yes } ->
		{ proc_info_inferred_determinism(ProcInfo, Detism) },
		{ MaybeDet = yes(Detism) }
	;
		{ MaybeDet = no }
	),
	prog_out__write_context(Context),
	{ strip_builtin_qualifiers_from_mode_list(Modes0, Modes) },
	io__write_string("Inferred "),
	(	{ PredOrFunc = predicate },
		mercury_output_pred_mode_decl(VarSet, Name, Modes,
				MaybeDet, Context, InstTable)
	;	{ PredOrFunc = function },
		{ pred_args_to_func_args(Modes, ArgModes, RetMode) },
		mercury_output_func_mode_decl(VarSet, Name, ArgModes, RetMode,
				MaybeDet, Context, InstTable)
	).

%-----------------------------------------------------------------------------%
%-----------------------------------------------------------------------------%

        % If there were any errors recorded in the mode_info,
        % report them to the user now.

report_mode_errors(ModeInfo0, ModeInfo) :-
        mode_info_get_errors(ModeInfo0, Errors),
        ( Errors = [FirstError | _] ->	% XXX Why do we only report the first?
                FirstError = mode_error_info(_, ModeError, InstTable,
                                                Context, ModeContext),
                mode_info_set_context(Context, ModeInfo0, ModeInfo1),
                mode_info_set_mode_context(ModeContext, ModeInfo1, ModeInfo2),
                mode_info_get_io_state(ModeInfo2, IOState0),
                report_mode_error(ModeError, InstTable, ModeInfo2,
                                IOState0, IOState),
                mode_info_set_io_state(ModeInfo2, IOState, ModeInfo)
        ;
                ModeInfo = ModeInfo0
        ).

%-----------------------------------------------------------------------------%

:- pred output_inst((inst), varset, inst_table, io__state, io__state).
:- mode output_inst(in, in, in, di, uo) is det.

output_inst(Inst0, VarSet, InstTable) -->
	{ strip_builtin_qualifiers_from_inst(Inst0, Inst) },
	mercury_output_inst(expand_silently, Inst, VarSet, InstTable).	% YYY

:- pred output_inst_list(list(inst), varset, inst_table,
		io__state, io__state).
:- mode output_inst_list(in, in, in, di, uo) is det.

output_inst_list(Insts0, VarSet, InstTable) -->
	{ strip_builtin_qualifiers_from_inst_list(Insts0, Insts) },
	mercury_output_inst_list(expand_silently, Insts, VarSet, InstTable).	% YYY

%-----------------------------------------------------------------------------%

report_indistinguishable_modes_error(OldProcId, NewProcId,
		PredId, PredInfo, ModuleInfo) -->

	io__set_exit_status(1),

	{ pred_info_procedures(PredInfo, Procs) },
	{ map__lookup(Procs, OldProcId, OldProcInfo) },
	{ map__lookup(Procs, NewProcId, NewProcInfo) },
	{ proc_info_context(OldProcInfo, OldContext) },
	{ proc_info_context(NewProcInfo, NewContext) },

	prog_out__write_context(NewContext),
	io__write_string("In mode declarations for "),
	hlds_out__write_pred_id(ModuleInfo, PredId),
	io__write_string(":\n"),

	prog_out__write_context(NewContext),
	io__write_string("  error: duplicate mode declaration.\n"),

	globals__io_lookup_bool_option(verbose_errors, VerboseErrors),
	( { VerboseErrors = yes } ->
		prog_out__write_context(NewContext),
		io__write_string("  Modes `"),
		output_mode_decl(OldProcId, PredInfo),
		io__write_string("'\n"),

		prog_out__write_context(NewContext),
		io__write_string("  and `"),
		output_mode_decl(NewProcId, PredInfo),
		io__write_string("'\n"),

		prog_out__write_context(NewContext),
		io__write_string("  are indistinguishable.\n")
	;
		[]
	),

	prog_out__write_context(OldContext),
	io__write_string(
		"  Here is the conflicting mode declaration.\n").

:- pred output_mode_decl(proc_id, pred_info, io__state, io__state).
:- mode output_mode_decl(in, in, di, uo) is det.

output_mode_decl(ProcId, PredInfo) -->
	{ pred_info_get_is_pred_or_func(PredInfo, PredOrFunc) },
	{ pred_info_name(PredInfo, Name0) },
	{ pred_info_procedures(PredInfo, Procs) },
	{ map__lookup(Procs, ProcId, ProcInfo) },
	{ proc_info_declared_argmodes(ProcInfo,
		argument_modes(InstTable, Modes0)) },
	{ proc_info_declared_determinism(ProcInfo, MaybeDet) },
	{ proc_info_context(ProcInfo, Context) },
	{ varset__init(InstVarSet) },
	{ Name = unqualified(Name0) },
	{ strip_builtin_qualifiers_from_mode_list(Modes0, Modes) },
	mercury_output_mode_subdecl(PredOrFunc, InstVarSet, Name, Modes,
				MaybeDet, Context, InstTable).

%-----------------------------------------------------------------------------%
%-----------------------------------------------------------------------------%
