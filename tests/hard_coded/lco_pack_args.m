%-----------------------------------------------------------------------------%

:- module lco_pack_args.
:- interface.

:- import_module io.

:- pred main(io::di, io::uo) is det.

%-----------------------------------------------------------------------------%
%-----------------------------------------------------------------------------%

:- implementation.

:- import_module list.

:- type thing
    --->    thing(enum, enum, thing, enum, enum)    % 5 words -> 3 words
    ;       nil.

:- type enum
    --->    enum1
    ;       enum2
    ;       enum3.

:- pred gen(list(enum)::in, thing::out) is det.

gen([], nil).
gen([E | Es], T) :-
    gen(Es, Tail),
    T = thing(E, E, Tail, E, E).

main(!IO) :-
    gen([enum1, enum2, enum3], T),
    io.write(T, !IO),
    io.nl(!IO).

%-----------------------------------------------------------------------------%
% vim: ft=mercury ts=4 sts=4 sw=4 et
