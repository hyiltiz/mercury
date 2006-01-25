%---------------------------------------------------------------------------%
% vim: ft=mercury ts=4 sw=4 et
%---------------------------------------------------------------------------%
% Copyright (C) 2005 The University of Melbourne.
% This file may only be copied under the terms of the GNU Library General
% Public License - see the file COPYING.LIB in the Mercury distribution.
%---------------------------------------------------------------------------%

% This module computes diffs between terms.

:- module mdb.diff.

:- interface.

:- import_module int.
:- import_module io.
:- import_module std_util.

:- pred report_diffs(int::in, int::in, univ::in, univ::in, io::di, io::uo)
    is cc_multi.

%---------------------------------------------------------------------------%

:- implementation.

:- import_module mdbcomp.program_representation.

:- import_module deconstruct.
:- import_module list.
:- import_module require.
:- import_module string.
:- import_module type_desc.

:- pragma export(report_diffs(in, in, in, in, di, uo), "ML_report_diffs").

report_diffs(Drop, Max, Univ1, Univ2, !IO) :-
    (
        Type1 = univ_type(Univ1),
        Type2 = univ_type(Univ2),
        Type1 = Type2
    ->
        compute_diffs(Univ1, Univ2, [], [], RevDiffs),
        list__reverse(RevDiffs, AllDiffs),
        list__length(AllDiffs, NumAllDiffs),
        (
            list__drop(Drop, AllDiffs, Diffs),
            Diffs = [_ | _]
        ->
            FirstShown = Drop + 1,
            LastShown = min(Drop + Max, NumAllDiffs),
            ( FirstShown = LastShown ->
                io__format("There are %d diffs, showing diff %d:\n",
                    [i(NumAllDiffs), i(FirstShown)], !IO)
            ;
                io__format("There are %d diffs, showing diffs %d-%d:\n",
                    [i(NumAllDiffs), i(FirstShown), i(LastShown)], !IO)
            ),
            list__take_upto(Max, Diffs, ShowDiffs),
            list__foldl2(show_diff, ShowDiffs, Drop, _, !IO)
        ;
            ( NumAllDiffs = 0 ->
                io__write_string("There are no diffs.\n", !IO)
            ; NumAllDiffs = 1 ->
                io__write_string("There is only one diff.\n", !IO)
            ;
                io__format("There are only %d diffs.\n", [i(NumAllDiffs)], !IO)
            )
        )
    ;
        io__write_string("The two values are of different types.\n", !IO)
    ).

:- type term_path_diff
    --->    term_path_diff(term_path, univ, univ).

:- pred compute_diffs(univ::in, univ::in, term_path::in,
    list(term_path_diff)::in, list(term_path_diff)::out) is cc_multi.

compute_diffs(Univ1, Univ2, !.RevPath, !RevDiffs) :-
    deconstruct(univ_value(Univ1), include_details_cc, Functor1, _, Args1),
    deconstruct(univ_value(Univ2), include_details_cc, Functor2, _, Args2),
    ( Functor1 = Functor2 ->
        compute_arg_diffs(Args1, Args2, !.RevPath, 1, !RevDiffs)
    ;
        list__reverse(!.RevPath, Path),
        !:RevDiffs = [term_path_diff(Path, Univ1, Univ2) | !.RevDiffs]
    ).

:- pred compute_arg_diffs(list(univ)::in, list(univ)::in, term_path::in,
    int::in, list(term_path_diff)::in, list(term_path_diff)::out) is cc_multi.

compute_arg_diffs([], [], _, _, !RevDiffs).
compute_arg_diffs([], [_ | _], _, _, !RevDiffs) :-
    error("compute_arg_diffs: argument list mismatch").
compute_arg_diffs([_ | _], [], _, _, !RevDiffs) :-
    error("compute_arg_diffs: argument list mismatch").
compute_arg_diffs([Arg1 | Args1], [Arg2 | Args2], !.RevPath, ArgNum,
        !RevDiffs) :-
    compute_diffs(Arg1, Arg2, [ArgNum | !.RevPath], !RevDiffs),
    compute_arg_diffs(Args1, Args2, !.RevPath, ArgNum + 1, !RevDiffs).

:- pred show_diff(term_path_diff::in, int::in, int::out, io::di, io::uo)
    is cc_multi.

show_diff(Diff, !DiffNum, !IO) :-
    !:DiffNum = !.DiffNum + 1,
    io__format("%d: ", [i(!.DiffNum)], !IO),
    Diff = term_path_diff(Path, Univ1, Univ2),
    (
        Path = [],
        io__write_string("mismatch at root", !IO)
    ;
        Path = [Posn | Posns],
        io__write_int(Posn, !IO),
        show_path_rest(Posns, !IO)
    ),
    io__write_string(": ", !IO),
    functor(univ_value(Univ1), include_details_cc, Functor1, Arity1),
    functor(univ_value(Univ2), include_details_cc, Functor2, Arity2),
    io__format("%s/%d vs %s/%d\n",
        [s(Functor1), i(Arity1), s(Functor2), i(Arity2)], !IO).

:- pred show_path_rest(list(int)::in, io::di, io::uo) is det.

show_path_rest([], !IO).
show_path_rest([Posn | Posns], !IO) :-
    io__write_string("/", !IO),
    io__write_int(Posn, !IO),
    show_path_rest(Posns, !IO).