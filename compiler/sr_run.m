%-----------------------------------------------------------------------------%
% Copyright (C) 1996-2001 The University of Melbourne.
% This file may only be copied under the terms of the GNU General
% Public License - see the file COPYING in the Mercury distribution.
%-----------------------------------------------------------------------------%

% module sr_run: implements the process of annotating each procedure with
%		 information regarding structure reuse. 
% all modules sr_* are related to this compiler-pass.
% main author: nancy

:- module sr_run.

:- interface.

%-------------------------------------------------------------------%

:- import_module io, list.
:- import_module hlds_module, hlds_pred.

	% the main pass
:- pred sr_run__structure_reuse_pass( module_info, module_info, 
		io__state, io__state).
:- mode sr_run__structure_reuse_pass( in, out, di, uo) is det.

	% write the sr_reuse_info pragma for the given pred_id (only
	% if that pred_id is not a member of the given list of pred_id's)
:- pred sr_run__write_pred_sr_reuse_info( module_info, list(pred_id),
		pred_id, io__state, io__state).
:- mode sr_run__write_pred_sr_reuse_info( in, in, in, di, uo) is det.


%-------------------------------------------------------------------%
%-------------------------------------------------------------------%

:- implementation. 

% The structure reuse pass consists of several passes:
% pass 1: annotate each goal with Local Forward Use (LFU) information
%	  (sr_lfu.m)
% pass 2: annotate each goal with Local Backward Use (LBU) information
% pass 3: derive liveness information based on Alias Information (derived in 
%	  separate independent pass), LFU, LBU
% pass 4: derive reuse information based on liveness information

% current status: none of the passes is actually implemented.

% compiler modules
:- import_module sr_lfu.
:- import_module sr_lbu.
:- import_module sr_reuse_run.

sr_run__structure_reuse_pass( HLDSin, HLDSout ) --> 
	sr_lfu__lfu_pass( HLDSin, HLDS1 ), 
	sr_lbu__lbu_pass( HLDS1, HLDS2),
	sr_reuse_run__reuse_pass( HLDS2, HLDSout ).

sr_run__write_pred_sr_reuse_info( HLDS, SpecPredIds, PredId) --> 
	{ module_info_pred_info( HLDS, PredId, PredInfo ) },
	(
		{ pred_info_is_exported( PredInfo ) }
	->
		( 
			{ list__member( PredId, SpecPredIds ) }
		->
			[]
		;
			{ pred_info_procids(PredInfo, ProcIds) },
			list__foldl( 
				write_pred_proc_sr_reuse_info(HLDS, PredId),
					ProcIds )
		)
	;
		[]
	).

% library modules 
:- import_module varset, map, int, bool, std_util.

% compiler modules
:- import_module sr_reuse.
:- import_module mercury_to_mercury, prog_data.

:- pred write_pred_proc_sr_reuse_info( module_info, pred_id,
                                proc_id, io__state, io__state).
:- mode write_pred_proc_sr_reuse_info( in, in, in, di, uo) is det.

write_pred_proc_sr_reuse_info( HLDS, PredId, ProcId) -->
	{ module_info_pred_proc_info(HLDS, PredId, ProcId,
			PredInfo, ProcInfo) },

	io__write_string(":- pragma sr_reuse_info("),

		% write a simple predicate declaration

	{ varset__init( InitVarSet ) },
	{ pred_info_name( PredInfo, PredName ) },
	{ pred_info_get_is_pred_or_func( PredInfo, PredOrFunc ) },
	{ pred_info_module( PredInfo, ModuleName ) },
	{ pred_info_context( PredInfo, Context ) },
	{ SymName = qualified( ModuleName, PredName ) },

	{ proc_info_declared_argmodes( ProcInfo, Modes ) },

	(
		{ PredOrFunc = predicate },
		mercury_output_pred_mode_subdecl( InitVarSet, SymName, Modes,
			std_util__no, Context )
	;
		{ PredOrFunc = function },
		{ pred_args_to_func_args( Modes, FuncModes, RetMode ) },
		mercury_output_func_mode_subdecl( InitVarSet, SymName, 
			FuncModes, RetMode, std_util__no, Context )
	),

	io__write_string(", "),

		% write headvars vars(HeadVar__1, ... HeadVar__n)

	{ pred_info_arg_types(PredInfo, DeclTVarset, _, _) },
	{ TVars = varset__vars(DeclTVarset) },

	{ proc_info_varset(ProcInfo, ProgVarset) },
	{ proc_info_headvars(ProcInfo, HeadVars) },
	{ list__delete_elems( HeadVars, TVars, RealHeadVars ) }, 
	{ proc_info_vartypes( ProcInfo, VarTypes) }, 
	{ pred_info_typevarset( PredInfo, TypeVarSet ) },

	pa_sr_util__trans_opt_output_vars_and_types(
			ProgVarset, 
			VarTypes, 
			TypeVarSet, 
			RealHeadVars ),

	io__write_string(", "),

		% write reuse information
	{ module_info_structure_reuse_info(HLDS, ReuseInfo) },
	{ ReuseInfo = structure_reuse_info(ReuseMap) },
	{ 
		map__search(ReuseMap, proc(PredId, ProcId), Result)
	->
		Result = proc(ReusePredId, ReuseProcId) - ReuseName
	;
		ReusePredId = PredId,
		ReuseProcId = ProcId,
		ReuseName = SymName
	},
	{ module_info_pred_proc_info(HLDS, ReusePredId, ReuseProcId,
			_ReusePredInfo, ReuseProcInfo) },
	{ proc_info_reuse_information_obsolete(ReuseProcInfo, TREUSE) },
	sr_reuse__tabled_reuse_print( TREUSE, ReuseName, ReuseProcInfo) ,

	io__write_string(").\n").

	% list_drop_det(Len,List,End):
	% 	deterministic version of list__drop.
	%	If `List' has less than `Len' elements, return the 
	% 	entire list.

:- pred list_drop_det(int,list(T),list(T)).
:- mode list_drop_det(in,in,out) is det.

list_drop_det(Len,List,End):-
	(
		list__drop(Len,List,End0)
	->
		End = End0
	;
		End = List
	).


%-------------------------------------------------------------------%
%-------------------------------------------------------------------%
