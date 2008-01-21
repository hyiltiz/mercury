%-----------------------------------------------------------------------------%
% vim: ft=mercury ts=4 sw=4 et
%-----------------------------------------------------------------------------%
% Copyright (C) 1999-2008 The University of Melbourne.
% This file may only be copied under the terms of the GNU General
% Public License - see the file COPYING in the Mercury distribution.
%-----------------------------------------------------------------------------%
%
% File: ml_tailcall.m
% Main author: fjh
%
% This module is an MLDS-to-MLDS transformation that marks function calls
% as tail calls whenever it is safe to do so, based on the assumptions
% described below.
%
% This module also contains a pass over the MLDS that detects functions
% which are directly recursive, but not tail-recursive, and warns about them.
%
% A function call can safely be marked as a tail call if all three of the
% following conditions are satisfied:
%
% 1 it occurs in a position which would fall through into the end of the
%   function body or to a `return' statement,
%
% 2 the lvalues in which the return value(s) from the `call' will be placed
%   are the same as the value(s) returned by the `return', and these lvalues
%   are all local variables,
%
% 3 the function's local variables do not need to be live for that call.
%
% For (2), we just assume (rather than checking) that any variables returned
% by the `return' statement are local variables. This assumption is true
% for the MLDS code generated by ml_code_gen.m.
%
% For (3), we assume that the addresses of local variables and nested functions
% are only ever passed down to other functions (and used to assign to the local
% variable or to call the nested function), so that here we only need to check
% if the potential tail call uses such addresses, not whether such addresses
% were taken in earlier calls. That is, if the addresses of locals were taken
% in earlier calls from the same function, we assume that these addresses
% will not be saved (on the heap, or in global variables, etc.) and used after
% those earlier calls have returned. This assumption is true for the MLDS code
% generated by ml_code_gen.m.
%
% We just mark tailcalls in this module here. The actual tailcall optimization
% (turn self-tailcalls into loops) is done in ml_optimize. Individual backends
% may wish to treat tailcalls separately if there is any backend support
% for them.
%
% Note that ml_call_gen.m will also mark calls to procedures with determinism
% `erroneous' as `no_return_call's (a special case of tail calls)
% when it generates them.
%
%-----------------------------------------------------------------------------%

:- module ml_backend.ml_tailcall.
:- interface.

:- import_module ml_backend.mlds.
:- import_module libs.globals.

:- import_module io.

%-----------------------------------------------------------------------------%

    % Traverse the MLDS, marking all optimizable tail calls as tail calls.
    %
:- pred ml_mark_tailcalls(mlds::in, mlds::out, io::di, io::uo) is det.

    % Traverse the MLDS, warning about all directly recursive calls
    % that are not marked as tail calls.
    %
:- pred ml_warn_tailcalls(globals::in, mlds::in, io::di, io::uo) is det.

%-----------------------------------------------------------------------------%
%-----------------------------------------------------------------------------%

:- implementation.

:- import_module hlds.hlds_pred.
:- import_module mdbcomp.prim_data.
:- import_module ml_backend.ml_util.
:- import_module parse_tree.error_util.
:- import_module parse_tree.prog_data.

:- import_module int.
:- import_module list.
:- import_module maybe.
:- import_module solutions.

%-----------------------------------------------------------------------------%

ml_mark_tailcalls(MLDS0, MLDS, !IO) :-
    MLDS = MLDS0 ^ defns := mark_tailcalls_in_defns(MLDS0 ^ defns).

%-----------------------------------------------------------------------------%

    % The `at_tail' type indicates whether or not a subgoal is at a tail
    % position, i.e. is followed by a return statement or the end of the
    % function, and if so, specifies the return values (if any) in the return
    % statement.
:- type at_tail == maybe(list(mlds_rval)).

    % The `locals' type contains a list of local definitions
    % which are in scope.
:- type locals == list(local_defns).
:- type local_defns
    --->    params(mlds_arguments)
    ;       defns(mlds_defns).

%-----------------------------------------------------------------------------%

% mark_tailcalls_in_defns:
% mark_tailcalls_in_defn:
%   Recursively process the definition(s),
%   marking each optimizable tail call in them as a tail call.
%
% mark_tailcalls_in_maybe_statement:
% mark_tailcalls_in_statements:
% mark_tailcalls_in_statement:
% mark_tailcalls_in_stmt:
% mark_tailcalls_in_case:
% mark_tailcalls_in_default:
%   Recursively process the statement(s),
%   marking each optimizable tail call in them as a tail call.
%   The `AtTail' argument indicates whether or not this
%   construct is in a tail call position.
%   The `Locals' argument contains a list of the
%   local definitions which are in scope at this point.

:- func mark_tailcalls_in_defns(mlds_defns) = mlds_defns.

mark_tailcalls_in_defns(Defns) = list.map(mark_tailcalls_in_defn, Defns).

:- func mark_tailcalls_in_defn(mlds_defn) = mlds_defn.

mark_tailcalls_in_defn(Defn0) = Defn :-
    Defn0 = mlds_defn(Name, Context, Flags, DefnBody0),
    (
        DefnBody0 = mlds_function(PredProcId, Params, FuncBody0, Attributes,
            EnvVarNames),
        % Compute the initial value of the `Locals' and `AtTail' arguments.
        Params = mlds_func_params(Args, RetTypes),
        Locals = [params(Args)],
        (
            RetTypes = [],
            AtTail = yes([])
        ;
            RetTypes = [_ | _],
            AtTail = no
        ),
        FuncBody = mark_tailcalls_in_function_body(FuncBody0, AtTail, Locals),
        DefnBody = mlds_function(PredProcId, Params, FuncBody, Attributes,
            EnvVarNames),
        Defn = mlds_defn(Name, Context, Flags, DefnBody)
    ;
        DefnBody0 = mlds_data(_, _, _),
        Defn = Defn0
    ;
        DefnBody0 = mlds_class(ClassDefn0),
        ClassDefn0 = mlds_class_defn(Kind, Imports, BaseClasses, Implements,
            CtorDefns0, MemberDefns0),
        CtorDefns = mark_tailcalls_in_defns(CtorDefns0),
        MemberDefns = mark_tailcalls_in_defns(MemberDefns0),
        ClassDefn = mlds_class_defn(Kind, Imports, BaseClasses, Implements,
            CtorDefns, MemberDefns),
        DefnBody = mlds_class(ClassDefn),
        Defn = mlds_defn(Name, Context, Flags, DefnBody)
    ).

:- func mark_tailcalls_in_function_body(mlds_function_body, at_tail, locals)
    = mlds_function_body.

mark_tailcalls_in_function_body(body_external, _, _) = body_external.
mark_tailcalls_in_function_body(body_defined_here(Statement0), AtTail, Locals)
        = body_defined_here(Statement) :-
    Statement = mark_tailcalls_in_statement(Statement0, AtTail, Locals).

:- func mark_tailcalls_in_maybe_statement(maybe(statement), at_tail, locals)
    = maybe(statement).

mark_tailcalls_in_maybe_statement(no, _, _) = no.
mark_tailcalls_in_maybe_statement(yes(Statement0), AtTail, Locals) =
        yes(Statement) :-
    Statement = mark_tailcalls_in_statement(Statement0, AtTail, Locals).

:- func mark_tailcalls_in_statements(statements, at_tail, locals)
    = statements.

mark_tailcalls_in_statements([], _, _) = [].
mark_tailcalls_in_statements([First0 | Rest0], AtTail, Locals) =
        [First | Rest] :-
    % If there are no statements after the first, then the first statement
    % is in a tail call position iff the statement list is in a tail call
    % position. If the First statement is followed by a `return' statement,
    % then it is in a tailcall position. Otherwise, i.e. if the first statement
    % is followed by anything other than a `return' statement, then
    % the first statement is not in a tail call position.
    (
        Rest = [],
        FirstAtTail = AtTail
    ;
        Rest = [FirstRest | _],
        ( FirstRest = statement(ml_stmt_return(ReturnVals), _) ->
            FirstAtTail = yes(ReturnVals)
        ;
            FirstAtTail = no
        )
    ),
    First = mark_tailcalls_in_statement(First0, FirstAtTail, Locals),
    Rest = mark_tailcalls_in_statements(Rest0, AtTail, Locals).

:- func mark_tailcalls_in_statement(statement, at_tail, locals) = statement.

mark_tailcalls_in_statement(Statement0, AtTail, Locals) = Statement :-
    Statement0 = statement(Stmt0, Context),
    Stmt = mark_tailcalls_in_stmt(Stmt0, AtTail, Locals),
    Statement = statement(Stmt, Context).

:- func mark_tailcalls_in_stmt(mlds_stmt, at_tail, locals) = mlds_stmt.

mark_tailcalls_in_stmt(Stmt0, AtTail, Locals) = Stmt :-
    (
        % Whenever we encounter a block statement, we recursively mark
        % tailcalls in any nested functions defined in that block.
        % We also need to add any local definitions in that block to the list
        % of currently visible local declarations before processing the
        % statements in that block. The statement list will be in a tail
        % position iff the block is in a tail position.
        Stmt0 = ml_stmt_block(Defns0, Statements0),
        Defns = mark_tailcalls_in_defns(Defns0),
        NewLocals = [defns(Defns) | Locals],
        Statements = mark_tailcalls_in_statements(Statements0,
            AtTail, NewLocals),
        Stmt = ml_stmt_block(Defns, Statements)
    ;
        % The statement in the body of a while loop is never in a tail
        % position.
        Stmt0 = ml_stmt_while(Rval, Statement0, Once),
        Statement = mark_tailcalls_in_statement(Statement0, no, Locals),
        Stmt = ml_stmt_while(Rval, Statement, Once)
    ;
        % Both the `then' and the `else' parts of an if-then-else are in a
        % tail position iff the if-then-else is in a tail position.
        Stmt0 = ml_stmt_if_then_else(Cond, Then0, MaybeElse0),
        Then = mark_tailcalls_in_statement(Then0, AtTail, Locals),
        MaybeElse = mark_tailcalls_in_maybe_statement(MaybeElse0,
            AtTail, Locals),
        Stmt = ml_stmt_if_then_else(Cond, Then, MaybeElse)
    ;
        % All of the cases of a switch (including the default) are in a
        % tail position iff the switch is in a tail position.
        Stmt0 = ml_stmt_switch(Type, Val, Range, Cases0, Default0),
        Cases = mark_tailcalls_in_cases(Cases0, AtTail, Locals),
        Default = mark_tailcalls_in_default(Default0, AtTail, Locals),
        Stmt = ml_stmt_switch(Type, Val, Range, Cases, Default)
    ;
        Stmt0 = ml_stmt_call(Sig, Func, Obj, Args, ReturnLvals, CallKind0),

        % Check if we can mark this call as a tail call.
        (
            CallKind0 = ordinary_call,

            % We must be in a tail position.
            AtTail = yes(ReturnRvals),

            % The values returned in this call must match those returned
            % by the `return' statement that follows.
            match_return_vals(ReturnRvals, ReturnLvals),

            % The call must not take the address of any local variables
            % or nested functions.
            check_maybe_rval(Obj, Locals) = will_not_yield_dangling_stack_ref,
            check_rvals(Args, Locals) = will_not_yield_dangling_stack_ref,

            % The call must not be to a function nested within this function.
            check_rval(Func, Locals) = will_not_yield_dangling_stack_ref
        ->
            % Mark this call as a tail call.
            CallKind = tail_call,
            Stmt = ml_stmt_call(Sig, Func, Obj, Args, ReturnLvals, CallKind)
        ;
            % Leave this call unchanged.
            Stmt = Stmt0
        )
    ;
        Stmt0 = ml_stmt_try_commit(Ref, Statement0, Handler0),
        % Both the statement inside a `try_commit' and the handler are in
        % tail call position iff the `try_commit' statement is in a tail call
        % position.
        Statement = mark_tailcalls_in_statement(Statement0, AtTail, Locals),
        Handler = mark_tailcalls_in_statement(Handler0, AtTail, Locals),
        Stmt = ml_stmt_try_commit(Ref, Statement, Handler)
    ;
        ( Stmt0 = ml_stmt_label(_)
        ; Stmt0 = ml_stmt_goto(_)
        ; Stmt0 = ml_stmt_computed_goto(_, _)
        ; Stmt0 = ml_stmt_return(_Rvals)
        ; Stmt0 = ml_stmt_do_commit(_Ref)
        ; Stmt0 = ml_stmt_atomic(_)
        ),
        Stmt = Stmt0
    ).

:- func mark_tailcalls_in_cases(list(mlds_switch_case), at_tail, locals) =
    list(mlds_switch_case).

mark_tailcalls_in_cases([], _, _) = [].
mark_tailcalls_in_cases([Case0 | Cases0], AtTail, Locals) = [Case | Cases] :-
    Case = mark_tailcalls_in_case(Case0, AtTail, Locals),
    Cases = mark_tailcalls_in_cases(Cases0, AtTail, Locals).

:- func mark_tailcalls_in_case(mlds_switch_case, at_tail, locals) =
    mlds_switch_case.

mark_tailcalls_in_case(Case0, AtTail, Locals) = Case :-
    Case0 = mlds_switch_case(Cond, Statement0),
    Statement = mark_tailcalls_in_statement(Statement0, AtTail, Locals),
    Case = mlds_switch_case(Cond, Statement).

:- func mark_tailcalls_in_default(mlds_switch_default, at_tail, locals) =
    mlds_switch_default.

mark_tailcalls_in_default(Default0, AtTail, Locals) = Default :-
    (
        ( Default0 = default_is_unreachable
        ; Default0 = default_do_nothing
        ),
        Default = Default0
    ;
        Default0 = default_case(Statement0),
        Statement = mark_tailcalls_in_statement(Statement0, AtTail, Locals),
        Default = default_case(Statement)
    ).

%-----------------------------------------------------------------------------%

% match_return_vals(Rvals, Lvals):
% match_return_val(Rval, Lval):
%   Check that the Lval(s) returned by a call match
%   the Rval(s) in the `return' statement that follows,
%   and those Lvals are local variables
%   (so that assignments to them won't have any side effects),
%   so that we can optimize the call into a tailcall.

:- pred match_return_vals(list(mlds_rval)::in, list(mlds_lval)::in) is semidet.

match_return_vals([], []).
match_return_vals([Rval|Rvals], [Lval|Lvals]) :-
    match_return_val(Rval, Lval),
    match_return_vals(Rvals, Lvals).

:- pred match_return_val(mlds_rval::in, mlds_lval::in) is semidet.

match_return_val(lval(Lval), Lval) :-
    lval_is_local(Lval) = is_local.

:- type is_local
    --->    is_local
    ;       is_not_local.

:- func lval_is_local(mlds_lval) = is_local.

lval_is_local(Lval) = IsLocal :-
    (
        Lval = var(_, _),
        % We just assume it is local. (This assumption is true for the code
        % generated by ml_code_gen.m.)
        IsLocal = is_local
    ;
        Lval = field(_Tag, Rval, _Field, _, _),
        % A field of a local variable is local.
        ( Rval = mem_addr(BaseLval) ->
            IsLocal = lval_is_local(BaseLval)
        ;
            IsLocal = is_not_local
        )
    ;
        ( Lval = mem_ref(_Rval, _Type)
        ; Lval = global_var_ref(_)
        ),
        IsLocal = is_not_local
    ).

%-----------------------------------------------------------------------------%

:- type may_yield_dangling_stack_ref
    --->    may_yield_dangling_stack_ref
    ;       will_not_yield_dangling_stack_ref.

% check_rvals:
% check_maybe_rval:
% check_rval:
%   Find out if the specified rval(s) might evaluate to the addresses of
%   local variables (or fields of local variables) or nested functions.

:- func check_rvals(list(mlds_rval), locals) = may_yield_dangling_stack_ref.

check_rvals([], _) = will_not_yield_dangling_stack_ref.
check_rvals([Rval | Rvals], Locals) = MayYieldDanglingStackRef :-
    ( check_rval(Rval, Locals) = may_yield_dangling_stack_ref ->
        MayYieldDanglingStackRef = may_yield_dangling_stack_ref
    ;
        MayYieldDanglingStackRef = check_rvals(Rvals, Locals)
    ).

:- func check_maybe_rval(maybe(mlds_rval), locals)
    = may_yield_dangling_stack_ref.

check_maybe_rval(no, _) = will_not_yield_dangling_stack_ref.
check_maybe_rval(yes(Rval), Locals) = check_rval(Rval, Locals).

:- func check_rval(mlds_rval, locals) = may_yield_dangling_stack_ref.

check_rval(Rval, Locals) = MayYieldDanglingStackRef :-
    (
        Rval = lval(_Lval),
        % Passing the _value_ of an lval is fine.
        MayYieldDanglingStackRef = will_not_yield_dangling_stack_ref
    ;
        Rval = mkword(_Tag, SubRval),
        MayYieldDanglingStackRef = check_rval(SubRval, Locals)
    ;
        Rval = const(Const),
        MayYieldDanglingStackRef = check_const(Const, Locals)
    ;
        Rval = unop(_Op, XRval),
        MayYieldDanglingStackRef = check_rval(XRval, Locals)
    ;
        Rval = binop(_Op, XRval, YRval),
        ( check_rval(XRval, Locals) = may_yield_dangling_stack_ref ->
            MayYieldDanglingStackRef = may_yield_dangling_stack_ref
        ;
            MayYieldDanglingStackRef = check_rval(YRval, Locals)
        )
    ;
        Rval = mem_addr(Lval),
        % Passing the address of an lval is a problem,
        % if that lval names a local variable.
        MayYieldDanglingStackRef = check_lval(Lval, Locals)
    ;
        Rval = self(_),
        MayYieldDanglingStackRef = may_yield_dangling_stack_ref
    ).

    % Find out if the specified lval might be a local variable
    % (or a field of a local variable).
    %
:- func check_lval(mlds_lval, locals) = may_yield_dangling_stack_ref.

check_lval(Lval, Locals) = MayYieldDanglingStackRef :-
    (
        Lval = var(Var0, _),
        ( var_is_local(Var0, Locals) ->
            MayYieldDanglingStackRef = may_yield_dangling_stack_ref
        ;
            MayYieldDanglingStackRef = will_not_yield_dangling_stack_ref
        )
    ;
        Lval = field(_MaybeTag, Rval, _FieldId, _, _),
        MayYieldDanglingStackRef = check_rval(Rval, Locals)
    ;
        ( Lval = mem_ref(_, _)
        ; Lval = global_var_ref(_)
        ),
        % We assume that the addresses of local variables are only ever
        % passed down to other functions, or assigned to, so a mem_ref lval
        % can never refer to a local variable.
        MayYieldDanglingStackRef = will_not_yield_dangling_stack_ref
    ).

    % Find out if the specified const might be the address of a local variable
    % or nested function.
    %
    % The addresses of local variables are probably not consts, at least
    % not unless those variables are declared as static (i.e. `one_copy'),
    % so it might be safe to allow all data_addr_consts here, but currently
    % we just take a conservative approach.
    %
:- func check_const(mlds_rval_const, locals) = may_yield_dangling_stack_ref.

check_const(Const, Locals) = MayYieldDanglingStackRef :-
    ( Const = mlconst_code_addr(CodeAddr) ->
        ( function_is_local(CodeAddr, Locals) ->
            MayYieldDanglingStackRef = may_yield_dangling_stack_ref
        ;
            MayYieldDanglingStackRef = will_not_yield_dangling_stack_ref
        )
    ; Const = mlconst_data_addr(DataAddr) ->
        DataAddr = data_addr(ModuleName, DataName),
        ( DataName = var(VarName) ->
            ( var_is_local(qual(ModuleName, module_qual, VarName), Locals) ->
                MayYieldDanglingStackRef = may_yield_dangling_stack_ref
            ;
                MayYieldDanglingStackRef = will_not_yield_dangling_stack_ref
            )
        ;
            MayYieldDanglingStackRef = will_not_yield_dangling_stack_ref
        )
    ;
        MayYieldDanglingStackRef = will_not_yield_dangling_stack_ref
    ).

    % Check whether the specified variable is defined locally, i.e. in storage
    % that might no longer exist when the function returns or does a tail call.
    %
    % It would be safe to fail for variables declared static (i.e. `one_copy'),
    % but currently we just take a conservative approach.
    %
:- pred var_is_local(mlds_var::in, locals::in) is semidet.

var_is_local(Var, Locals) :-
    % XXX we ignore the ModuleName -- that is safe, but overly conservative.
    Var = qual(_ModuleName, _QualKind, VarName),
    some [Local] (
        locals_member(Local, Locals),
        Local = entity_data(var(VarName))
    ).

    % Check whether the specified function is defined locally (i.e. as a
    % nested function).
    %
:- pred function_is_local(mlds_code_addr::in, locals::in) is semidet.

function_is_local(CodeAddr, Locals) :-
    (
        CodeAddr = code_addr_proc(QualifiedProcLabel, _Sig),
        MaybeSeqNum = no
    ;
        CodeAddr = code_addr_internal(QualifiedProcLabel, SeqNum, _Sig),
        MaybeSeqNum = yes(SeqNum)
    ),
    % XXX we ignore the ModuleName -- that is safe, but might be
    % overly conservative.
    QualifiedProcLabel = qual(_ModuleName, _QualKind, ProcLabel),
    ProcLabel = mlds_proc_label(PredLabel, ProcId),
    some [Local] (
        locals_member(Local, Locals),
        Local = entity_function(PredLabel, ProcId, MaybeSeqNum, _PredId)
    ).

    % locals_member(Name, Locals):
    %
    % Nondeterministically enumerates the names of all the entities in Locals.
    %
:- pred locals_member(mlds_entity_name::out, locals::in) is nondet.

locals_member(Name, LocalsList) :-
    list.member(Locals, LocalsList),
    (
        Locals = defns(Defns),
        list.member(Defn, Defns),
        Defn = mlds_defn(Name, _, _, _)
    ;
        Locals = params(Params),
        list.member(Param, Params),
        Param = mlds_argument(Name, _, _)
    ).

%-----------------------------------------------------------------------------%

ml_warn_tailcalls(Globals, MLDS, !IO) :-
    solutions.solutions(nontailcall_in_mlds(MLDS), Warnings),
    list.foldl(report_nontailcall_warning(Globals), Warnings, !IO).

:- type tailcall_warning
    --->    tailcall_warning(
                mlds_pred_label,
                proc_id,
                mlds_context
            ).

:- pred nontailcall_in_mlds(mlds::in, tailcall_warning::out) is nondet.

nontailcall_in_mlds(MLDS, Warning) :-
    MLDS = mlds(ModuleName, _ForeignCode, _Imports, Defns, _InitPreds,
        _FinalPreds, _ExportedEnums),
    MLDS_ModuleName = mercury_module_name_to_mlds(ModuleName),
    nontailcall_in_defns(MLDS_ModuleName, Defns, Warning).

:- pred nontailcall_in_defns(mlds_module_name::in, mlds_defns::in,
    tailcall_warning::out) is nondet.

nontailcall_in_defns(ModuleName, Defns, Warning) :-
    list.member(Defn, Defns),
    nontailcall_in_defn(ModuleName, Defn, Warning).

:- pred nontailcall_in_defn(mlds_module_name::in, mlds_defn::in,
    tailcall_warning::out) is nondet.

nontailcall_in_defn(ModuleName, Defn, Warning) :-
    Defn = mlds_defn(Name, _Context, _Flags, DefnBody),
    (
        DefnBody = mlds_function(_PredProcId, _Params, FuncBody,
            _Attributes, _EnvVarNames),
        FuncBody = body_defined_here(Body),
        nontailcall_in_statement(ModuleName, Name, Body, Warning)
    ;
        DefnBody = mlds_class(ClassDefn),
        ClassDefn = mlds_class_defn(_Kind, _Imports, _BaseClasses,
            _Implements, CtorDefns, MemberDefns),
        ( nontailcall_in_defns(ModuleName, CtorDefns, Warning)
        ; nontailcall_in_defns(ModuleName, MemberDefns, Warning)
        )
    ).

:- pred nontailcall_in_statement(mlds_module_name::in, mlds_entity_name::in,
    statement::in, tailcall_warning::out) is nondet.

nontailcall_in_statement(CallerModule, CallerFuncName, Statement, Warning) :-
    % Nondeterministically find a non-tail call.
    statement_contains_statement(Statement, SubStatement),
    SubStatement = statement(SubStmt, Context),
    SubStmt = ml_stmt_call(_CallSig, Func, _This, _Args, _RetVals, CallKind),
    CallKind = ordinary_call,
    % Check if this call is a directly recursive call.
    Func = const(mlconst_code_addr(CodeAddr)),
    (
        CodeAddr = code_addr_proc(QualProcLabel, _Sig),
        MaybeSeqNum = no
    ;
        CodeAddr = code_addr_internal(QualProcLabel, SeqNum, _Sig),
        MaybeSeqNum = yes(SeqNum)
    ),
    ProcLabel = mlds_proc_label(PredLabel, ProcId),
    QualProcLabel = qual(CallerModule, module_qual, ProcLabel),
    CallerFuncName = entity_function(PredLabel, ProcId, MaybeSeqNum, _PredId),
    % If so, construct an appropriate warning.
    Warning = tailcall_warning(PredLabel, ProcId, Context).

:- pred report_nontailcall_warning(globals::in, tailcall_warning::in,
    io::di, io::uo) is det.

report_nontailcall_warning(Globals, Warning, !IO) :-
    Warning = tailcall_warning(PredLabel, ProcId, Context),
    (
        PredLabel = mlds_user_pred_label(PredOrFunc, _MaybeModule, Name, Arity,
            _CodeModel, _NonOutputFunc),
        SimpleCallId = simple_call_id(PredOrFunc, unqualified(Name), Arity),
        proc_id_to_int(ProcId, ProcNumber0),
        ProcNumber = ProcNumber0 + 1,
        Pieces =
            [words("In mode number"), int_fixed(ProcNumber),
            words("of"), simple_call(SimpleCallId), suffix(":"), nl,
            words("warning: recursive call is not tail recursive."), nl],
        Msg = simple_msg(mlds_get_prog_context(Context), [always(Pieces)]),
        Spec = error_spec(severity_warning, phase_code_gen, [Msg]),
        write_error_spec(Spec, Globals, 0, _NumWarnings, 0, _NumErrors, !IO)
    ;
        PredLabel = mlds_special_pred_label(_, _, _, _)
        % Don't warn about these.
    ).

%-----------------------------------------------------------------------------%
