/*
** Copyright (C) 1998-1999 The University of Melbourne.
** This file may only be copied under the terms of the GNU Library General
** Public License - see the file COPYING.LIB in the Mercury distribution.
*/

/*
** mercury_trace_browse.c
**
** Main author: fjh
**
** This file provides the C interface to browser/browse.m
** and browser/interactive_query.m.
*/

/*
** Some header files refer to files automatically generated by the Mercury
** compiler for modules in the browser and library directories.
**
** XXX figure out how to prevent these names from encroaching on the user's
** name space.
*/

#include "mercury_imp.h"
#include "mercury_trace_browse.h"
#include "mercury_trace_util.h"
#include "mercury_trace_internal.h"
#include "mercury_deep_copy.h"
#include "browse.h"
#include "interactive_query.h"
#include "std_util.h"
#include "mercury_trace_external.h"
#include <stdio.h>

static	Word		MR_trace_browser_state;
static	Word		MR_trace_browser_state_type;

static	void		MR_trace_browse_ensure_init(void);

static void
MR_c_file_to_mercury_file(FILE *c_file, MercuryFile *mercury_file)
{
	mercury_file->file = c_file;
	mercury_file->line_number = 1;
}

void
MR_trace_browse(Word type_info, Word value)
{
	MercuryFile mdb_in, mdb_out;

	MR_trace_browse_ensure_init();

	MR_c_file_to_mercury_file(MR_mdb_in, &mdb_in);
	MR_c_file_to_mercury_file(MR_mdb_out, &mdb_out);

	MR_TRACE_CALL_MERCURY(
		ML_BROWSE_browse(type_info, value,
			(Word) &mdb_in, (Word) &mdb_out,
			MR_trace_browser_state, &MR_trace_browser_state);
	);
	MR_trace_browser_state = MR_make_permanent(MR_trace_browser_state,
				(Word *) MR_trace_browser_state_type);
}

	
/*
** MR_trace_browse_external() is the same as MR_trace_browse() except it 
** uses debugger_socket_in and debugger_socket_out to read program-readable 
** terms, whereas MR_trace_browse() uses mdb_in and mdb_out to read
** human-readable strings.
*/

void
MR_trace_browse_external(Word type_info, Word value)
{
	MR_trace_browse_ensure_init();

	MR_TRACE_CALL_MERCURY(
		ML_BROWSE_browse_external(type_info, value,
			(Word) &MR_debugger_socket_in, 
			(Word) &MR_debugger_socket_out,
			MR_trace_browser_state, &MR_trace_browser_state);
	);
	MR_trace_browser_state = MR_make_permanent(MR_trace_browser_state,
				(Word *) MR_trace_browser_state_type);
}

void
MR_trace_print(Word type_info, Word value)
{
	MercuryFile mdb_out;

	MR_trace_browse_ensure_init();

	MR_c_file_to_mercury_file(MR_mdb_out, &mdb_out);

	MR_TRACE_CALL_MERCURY(
		ML_BROWSE_print(type_info, value, (Word) &mdb_out,
			MR_trace_browser_state);
	);
}

static void
MR_trace_browse_ensure_init(void)
{
	static	bool	done = FALSE;
	Word		typeinfo_type;

	if (! done) {
		MR_TRACE_CALL_MERCURY(
			ML_get_type_info_for_type_info(&typeinfo_type);
			ML_BROWSE_browser_state_type(
				&MR_trace_browser_state_type);
			ML_BROWSE_init_state(&MR_trace_browser_state);
		);

		MR_trace_browser_state_type = MR_make_permanent(
					MR_trace_browser_state_type,
					(Word *) typeinfo_type);
		MR_trace_browser_state = MR_make_permanent(
					MR_trace_browser_state,
					(Word *) MR_trace_browser_state_type);
		done = TRUE;
	}
}

void
MR_trace_query(MR_Query_Type type, const char *options, int num_imports,
	char *imports[])
{
	ConstString options_on_heap;
	Word imports_list;
	MercuryFile mdb_in, mdb_out;
	int i;

	MR_c_file_to_mercury_file(MR_mdb_in, &mdb_in);
	MR_c_file_to_mercury_file(MR_mdb_out, &mdb_out);

	if (options == NULL) options = "";

        MR_TRACE_USE_HP(
		make_aligned_string(options_on_heap, options);

		imports_list = list_empty();
		for (i = num_imports; i > 0; i--) {
			ConstString this_import;
			make_aligned_string(this_import, imports[i - 1]);
			imports_list = list_cons(this_import, imports_list);
		}
	);

	MR_TRACE_CALL_MERCURY(
		ML_query(type, imports_list, (String) options_on_heap,
			(Word) &mdb_in, (Word) &mdb_out);
	);
}

void
MR_trace_query_external(MR_Query_Type type, String options, int num_imports,
	Word imports_list)
{
	MR_TRACE_CALL_MERCURY(
		ML_query_external(type, imports_list,  options,
			(Word) &MR_debugger_socket_in, 
			(Word) &MR_debugger_socket_out);
	);
}
