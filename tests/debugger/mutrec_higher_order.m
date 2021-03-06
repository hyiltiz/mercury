%----------------------------------------------------------------------------%
% vim: ts=4 sw=4 et ft=mercury
%----------------------------------------------------------------------------%

:- module mutrec_higher_order.

:- interface.

:- import_module io.

:- pred main(io::di, io::uo) is det.

:- implementation.

%----------------------------------------------------------------------------%

:- import_module int.
:- import_module list.

:- type step
    --->    self
    ;       mut(int)
    ;       rep(int)
    ;       down.

main(!IO) :-
    Steps1 = [self, mut(1), mut(3), self, mut(2), mut(2), self, rep(2),
        mut(1), mut(3), mut(3), mut(3), mut(3), self, self, rep(1),
        self, mut(2), mut(2), self, mut(3), self, down],
    Steps2 = [self, mut(1), mut(3), self, mut(2), mut(2), self, rep(3),
        mut(1), mut(3), mut(3), mut(3), mut(3), self, self, rep(4),
        self, self, self, self, mut(3), self, down],

    test(Steps1, RevStrs1),
    test(Steps2, RevStrs2),

    test_output(RevStrs1, !IO),
    test_output(RevStrs2, !IO).

:- pred test(list(step)::in, list(string)::out) is det.

test(Steps, RevStrs) :-
    p1(Steps, [], RevStrs).

:- pred test_output(list(string)::in, io::di, io::uo) is det.

test_output(RevStrs, !IO) :-
    list.reverse(RevStrs, Strs),
    (
        Strs = [],
        io.write_string("[]\n", !IO)
    ;
        Strs = [HeadStr | TailStrs],
        io.write_string("[", !IO),
        io.write_string(HeadStr, !IO),
        write_comma_strings(TailStrs, !IO),
        io.write_string("]\n", !IO)
    ).

:- pred write_comma_strings(list(string)::in, io::di, io::uo) is det.

write_comma_strings([], !IO).
write_comma_strings([Str | Strs], !IO) :-
    io.write_string(", ", !IO),
    io.write_string(Str, !IO),
    write_comma_strings(Strs, !IO).

%----------------------------------------------------------------------------%

:- pred repeat_steps(
    pred(list(step), list(string), list(string))::in(pred(in, in, out) is det),
    list(step)::in, int::in, list(string)::in, list(string)::out) is det.

repeat_steps(P, Steps, N, A, R) :-
    ( N =< 0 ->
        R = A
    ;
        P(Steps, A, B),
        repeat_steps(P, Steps, N-1, B, R)
    ).

%----------------------------------------------------------------------------%

:- pred p1(list(step)::in, list(string)::in, list(string)::out) is det.

p1([], A, A).
p1([Step | Steps], A, R) :-
    B = ["p1" | A],
    (
        Step = self,
        p1(Steps, B, R)
    ;
        Step = mut(N),
        ( N = 2 ->
            p2(Steps, B, R)
        ;
            p3(Steps, B, R)
        )
    ;
        Step = rep(N),
        ( N = 1 ->
            repeat_steps(q1, Steps, 1, A, R)
        ; N = 2 ->
            repeat_steps(q2, Steps, 2, A, R)
        ;
            repeat_steps(q3, Steps, 3, A, R)
        )
    ;
        Step = down,
        q1(Steps, B, R)
    ).

:- pred p2(list(step)::in, list(string)::in, list(string)::out) is det.

p2([], A, A).
p2([Step | Steps], A, R) :-
    B = ["p2" | A],
    (
        Step = self,
        p2(Steps, B, R)
    ;
        Step = mut(N),
        ( N = 1 ->
            p1(Steps, B, R)
        ;
            p3(Steps, B, R)
        )
    ;
        Step = rep(N),
        ( N = 1 ->
            repeat_steps(q1, Steps, 1, A, R)
        ; N = 2 ->
            repeat_steps(q2, Steps, 2, A, R)
        ;
            repeat_steps(q3, Steps, 3, A, R)
        )
    ;
        Step = down,
        q1(Steps, B, R)
    ).

:- pred p3(list(step)::in, list(string)::in, list(string)::out) is det.

p3([], A, A).
p3([Step | Steps], A, R) :-
    B = ["p3" | A],
    (
        Step = self,
        p3(Steps, B, R)
    ;
        Step = mut(N),
        ( N = 1 ->
            p1(Steps, B, R)
        ;
            p2(Steps, B, R)
        )
    ;
        Step = rep(N),
        ( N = 1 ->
            repeat_steps(q1, Steps, 1, A, R)
        ; N = 2 ->
            repeat_steps(q2, Steps, 2, A, R)
        ;
            repeat_steps(q3, Steps, 3, A, R)
        )
    ;
        Step = down,
        q1(Steps, B, R)
    ).

%----------------------------------------------------------------------------%

:- pred q1(list(step)::in, list(string)::in, list(string)::out) is det.

q1([], A, A).
q1([Step | Steps], A, R) :-
    B = ["q1" | A],
    (
        Step = self,
        q1(Steps, B, R)
    ;
        Step = mut(N),
        ( N = 2 ->
            q2(Steps, B, R)
        ;
            q3(Steps, B, R)
        )
    ;
        Step = rep(N),
        ( N = 1 ->
            repeat_steps(r1, Steps, 1, A, R)
        ; N = 2 ->
            repeat_steps(r2, Steps, 2, A, R)
        ;
            repeat_steps(r3, Steps, 3, A, R)
        )
    ;
        Step = down,
        r0a(Steps, B, R)
    ).

:- pred q2(list(step)::in, list(string)::in, list(string)::out) is det.

q2([], A, A).
q2([Step | Steps], A, R) :-
    B = ["q2" | A],
    (
        Step = self,
        q2(Steps, B, R)
    ;
        Step = mut(N),
        ( N = 1 ->
            q1(Steps, B, R)
        ;
            q3(Steps, B, R)
        )
    ;
        Step = rep(N),
        ( N = 1 ->
            repeat_steps(r1, Steps, 1, A, R)
        ; N = 2 ->
            repeat_steps(r2, Steps, 2, A, R)
        ;
            repeat_steps(r3, Steps, 3, A, R)
        )
    ;
        Step = down,
        r0b(Steps, B, R)
    ).

:- pred q3(list(step)::in, list(string)::in, list(string)::out) is det.

q3([], A, A).
q3([Step | Steps], A, R) :-
    B = ["q3" | A],
    (
        Step = self,
        q3(Steps, B, R)
    ;
        Step = mut(N),
        ( N = 1 ->
            q1(Steps, B, R)
        ;
            q2(Steps, B, R)
        )
    ;
        Step = rep(N),
        ( N = 1 ->
            repeat_steps(r1, Steps, 1, A, R)
        ; N = 2 ->
            repeat_steps(r2, Steps, 2, A, R)
        ;
            repeat_steps(r3, Steps, 3, A, R)
        )
    ;
        Step = down,
        r0c(Steps, B, R)
    ).

%----------------------------------------------------------------------------%

:- pred r0a(list(step)::in, list(string)::in, list(string)::out) is det.

r0a(Steps, A, R) :-
    B = ["r0a" | A],
    r0b(Steps, B, R).

:- pred r0b(list(step)::in, list(string)::in, list(string)::out) is det.

r0b(Steps, A, R) :-
    B = ["r0b" | A],
    r0c(Steps, B, R).

:- pred r0c(list(step)::in, list(string)::in, list(string)::out) is det.

r0c(Steps, A, R) :-
    B = ["r0c" | A],
    r1(Steps, B, R).

:- pred r1(list(step)::in, list(string)::in, list(string)::out) is det.

r1([], A, A).
r1([Step | Steps], A, R) :-
    B = ["r1" | A],
    (
        Step = self,
        r1(Steps, B, R)
    ;
        Step = mut(N),
        ( N = 2 ->
            r2(Steps, B, R)
        ;
            r3(Steps, B, R)
        )
    ;
        Step = rep(_),
        R = B
    ;
        Step = down,
        R = B
    ).

:- pred r2(list(step)::in, list(string)::in, list(string)::out) is det.

r2([], A, A).
r2([Step | Steps], A, R) :-
    B = ["r2" | A],
    (
        Step = self,
        r2(Steps, B, R)
    ;
        Step = mut(N),
        ( N = 1 ->
            r1(Steps, B, R)
        ;
            r3(Steps, B, R)
        )
    ;
        Step = rep(_),
        R = B
    ;
        Step = down,
        s(1, B, R)
    ).

:- pred r3(list(step)::in, list(string)::in, list(string)::out) is det.

r3([], A, A).
r3([Step | Steps], A, R) :-
    B = ["r3" | A],
    (
        Step = self,
        r3(Steps, B, R)
    ;
        Step = mut(N),
        ( N = 1 ->
            r1(Steps, B, R)
        ;
            r2(Steps, B, R)
        )
    ;
        Step = rep(_),
        R = B
    ;
        Step = down,
        s(3, B, R)
    ).

%----------------------------------------------------------------------------%

:- pred s(int::in, list(string)::in, list(string)::out) is det.

s(N, A, R) :-
    B = ["s" | A],
    ( N > 0 ->
        s(N-1, B, R)
    ;
        R = B
    ).

%----------------------------------------------------------------------------%
