:- module foreign_enum_mod2.
:- interface.

:- type instrument.

:- type ingredient
	--->	eggs
	;	sugar
	;	flour
	;	milk.

:- func my_instrument = instrument.

:- implementation.

:- type instrument
	--->	violin
	;	piano
	;	xylophone.

:- type foo
	--->	foo
	;	bar
	;	baz.

my_instrument = piano.
	
	% This should end up in the .int file.
	%
:- pragma foreign_enum("C", ingredient/0, [
	foreign_enum_mod2.eggs  - "EGGS",
	foreign_enum_mod2.sugar - "SUGAR",
	foreign_enum_mod2.flour - "FLOUR",
	foreign_enum_mod2.milk  - "MILK"
]).

	% As should this.
	%
:- pragma foreign_enum("Java", ingredient/0, [
	eggs  - "Ingredient.EGGS",
	sugar - "Ingredient.SUGAR",
	flour - "Ingredient.FLOUR",
	milk  - "Ingredient.MILK"
]).

	% This shouldn't since the type is not exported.
	%
:- pragma foreign_enum("C", foo/0, [
	foo - "3",
	bar - "4",
	baz - "5"
]).

	% This shouldn't since the type is abstract.
	%
:- pragma foreign_enum("C", instrument/0, [
	violin - "100",
	piano  - "200",
	xylophone - "300"
]).

:- pragma foreign_decl("C", "

#define	EGGS 	10
#define	SUGAR	20
#define FLOUR	30
#define MILK	40

").

