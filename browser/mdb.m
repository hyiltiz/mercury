%---------------------------------------------------------------------------%
% Copyright (C) 1998-2000 The University of Melbourne.
% This file may only be copied under the terms of the GNU Library General
% Public License - see the file COPYING.LIB in the Mercury distribution.
%---------------------------------------------------------------------------%

:- module mdb.

:- interface.

:- pred mdb__version(string::out) is det.

	% These interface modules are used directly by the test programs
	% or the libmer_trace library.
:- include_module browser_info, browse, help.
:- include_module interactive_query.
:- include_module debugger_interface, collect_lib.
:- include_module declarative_debugger, declarative_execution.
:- include_module program_representation.

:- implementation.

:- include_module frame, parse, util.
:- include_module declarative_analyser, declarative_oracle, declarative_user.

	% XXX these modules are more generally useful, but the
	% dynamic linking library is not yet installed anywhere.
:- include_module dl, name_mangle.

% See library/library.m for why we implement this predicate this way.

:- pragma c_code(mdb__version(Version::out),
		will_not_call_mercury, "
	MR_ConstString version_string = 
		MR_VERSION "", configured for "" MR_FULLARCH;
	/*
	** Cast away const needed here, because Mercury declares Version
	** with type MR_String rather than MR_ConstString.
	*/
	Version = (MR_String) (MR_Word) version_string;
").

%---------------------------------------------------------------------------%
