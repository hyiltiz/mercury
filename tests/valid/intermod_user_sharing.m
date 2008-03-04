% Test that we can write out and read back in `no_sharing', `unknown_sharing'
% and `sharing' annotations on foreign_procs.

:- module intermod_user_sharing.
:- interface.

:- import_module io.

:- pred main(io::di, io::uo) is det.

%-----------------------------------------------------------------------------%
%-----------------------------------------------------------------------------%

:- implementation.

:- import_module intermod_user_sharing_2.
:- import_module io.

%-----------------------------------------------------------------------------%

main(!IO) :-
    p_no_sharing(!IO),
    p_unknown_sharing("bar", Bar),
    io.write(Bar, !IO),
    p_sharing(1, "foo", Array),
    io.write(Array, !IO).

%-----------------------------------------------------------------------------%
% vim: ft=mercury ts=8 sw=4 et wm=0 tw=0
