/*
** Copyright (C) 1998-2001 The University of Melbourne.
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
#include "mercury_deep_copy.h"

#include "mercury_trace_browse.h"
#include "mercury_trace_util.h"
#include "mercury_trace_internal.h"
#include "mercury_trace_external.h"

#include "mdb.browse.h"
#include "mdb.browser_info.h"
#include "mdb.interactive_query.h"
#ifdef MR_HIGHLEVEL_CODE
  #include "mercury.std_util.h"
#else
  #include "std_util.h"
#endif

#include <stdio.h>

static	MR_Word		MR_trace_browser_persistent_state;
static	MR_TypeInfo	MR_trace_browser_persistent_state_type;

static	void		MR_trace_browse_ensure_init(void);

static	bool		MR_trace_is_portray_format(const char *str,
				MR_Browse_Format *format);

static void
MR_c_file_to_mercury_file(FILE *c_file, MercuryFile *mercury_file)
{
	MR_mercuryfile_init(c_file, 1, mercury_file);
}

void
MR_trace_browse(MR_Word type_info, MR_Word value, MR_Browse_Format format)
{
	MercuryFile mdb_in, mdb_out;

	MR_trace_browse_ensure_init();

	MR_c_file_to_mercury_file(MR_mdb_in, &mdb_in);
	MR_c_file_to_mercury_file(MR_mdb_out, &mdb_out);

	if (format != MR_BROWSE_DEFAULT_FORMAT) {
		MR_TRACE_CALL_MERCURY(
			ML_BROWSE_browse_format(type_info, value,
				(MR_Word) &mdb_in, (MR_Word) &mdb_out,
				(MR_Word) format,
				MR_trace_browser_persistent_state,
				&MR_trace_browser_persistent_state);
		);
	} else {
		MR_TRACE_CALL_MERCURY(
			ML_BROWSE_browse(type_info, value,
				(MR_Word) &mdb_in, (MR_Word) &mdb_out,
				MR_trace_browser_persistent_state,
				&MR_trace_browser_persistent_state);
		);
	}
	MR_trace_browser_persistent_state =
			MR_make_permanent(MR_trace_browser_persistent_state,
				MR_trace_browser_persistent_state_type);
}

/*
** MR_trace_browse_external() is the same as MR_trace_browse() except it 
** uses debugger_socket_in and debugger_socket_out to read program-readable 
** terms, whereas MR_trace_browse() uses mdb_in and mdb_out to read
** human-readable strings.
*/

#ifdef MR_USE_EXTERNAL_DEBUGGER

void
MR_trace_browse_external(MR_Word type_info, MR_Word value,
		MR_Browse_Caller_Type caller, MR_Browse_Format format)
{
	MR_trace_browse_ensure_init();

	MR_TRACE_CALL_MERCURY(
		ML_BROWSE_browse_external(type_info, value,
			(MR_Word) &MR_debugger_socket_in, 
			(MR_Word) &MR_debugger_socket_out,
			MR_trace_browser_persistent_state,
			&MR_trace_browser_persistent_state);
	);
	MR_trace_browser_persistent_state =
			MR_make_permanent(MR_trace_browser_persistent_state,
				MR_trace_browser_persistent_state_type);
}

#endif

void
MR_trace_print(MR_Word type_info, MR_Word value, MR_Browse_Caller_Type caller,
		MR_Browse_Format format)
{
	MercuryFile mdb_out;

	MR_trace_browse_ensure_init();

	MR_c_file_to_mercury_file(MR_mdb_out, &mdb_out);

	if (format != MR_BROWSE_DEFAULT_FORMAT) {
		MR_TRACE_CALL_MERCURY(
			ML_BROWSE_print_format(type_info, value,
				(MR_Word) &mdb_out, (MR_Word) caller,
				(MR_Word) format,
				MR_trace_browser_persistent_state);
		);
	} else {
		MR_TRACE_CALL_MERCURY(
			ML_BROWSE_print(type_info, value,
				(MR_Word) &mdb_out, (MR_Word) caller,
				MR_trace_browser_persistent_state);
		);
	}
}

bool
MR_trace_set_browser_param(MR_Bool print, MR_Bool browse, MR_Bool print_all,
		MR_Bool flat, MR_Bool raw_pretty, MR_Bool verbose, 
		MR_Bool pretty, const char *param, const char *value)
{
	int			depth, size, width, lines;
	MR_Browse_Format	new_format;

	MR_trace_browse_ensure_init();

	if (streq(param, "format") &&
			MR_trace_is_portray_format(value, &new_format))
	{
		MR_TRACE_CALL_MERCURY(
			ML_BROWSE_set_param_format(print, browse, print_all,
				new_format, MR_trace_browser_persistent_state,
				&MR_trace_browser_persistent_state);
		);
	}
	else if (streq(param, "depth") && MR_trace_is_number(value, &depth))
	{
		MR_TRACE_CALL_MERCURY(
			ML_BROWSE_set_param_depth(print, browse, print_all,
				flat, raw_pretty, verbose, pretty, depth,
				MR_trace_browser_persistent_state,
				&MR_trace_browser_persistent_state);
		);
	}
	else if (streq(param, "size") && MR_trace_is_number(value, &size))
	{
		MR_TRACE_CALL_MERCURY(
			ML_BROWSE_set_param_size(print, browse, print_all,
				flat, raw_pretty, verbose, pretty, size,
				MR_trace_browser_persistent_state,
				&MR_trace_browser_persistent_state);
		);
	}
	else if (streq(param, "width") && MR_trace_is_number(value, &width))
	{
		MR_TRACE_CALL_MERCURY(
			ML_BROWSE_set_param_width(print, browse, print_all,
				flat, raw_pretty, verbose, pretty, width,
				MR_trace_browser_persistent_state,
				&MR_trace_browser_persistent_state);
		);
	}
	else if (streq(param, "lines") && MR_trace_is_number(value, &lines))
	{
		MR_TRACE_CALL_MERCURY(
			ML_BROWSE_set_param_lines(print, browse, print_all,
				flat, raw_pretty, verbose, pretty, lines,
				MR_trace_browser_persistent_state,
				&MR_trace_browser_persistent_state);
		);
	}
	else
	{
		return FALSE;
	}

	MR_trace_browser_persistent_state =
			MR_make_permanent(MR_trace_browser_persistent_state,
				MR_trace_browser_persistent_state_type);
	return TRUE;
}

static bool
MR_trace_is_portray_format(const char *str, MR_Browse_Format *format)
{
	*format = MR_BROWSE_DEFAULT_FORMAT;

	if (streq(str, "flat")) {
		*format = MR_BROWSE_FORMAT_FLAT;
		return TRUE;
	} else if (streq(str, "raw_pretty")) {
		*format = MR_BROWSE_FORMAT_RAW_PRETTY;
		return TRUE;
	} else if (streq(str, "verbose")) {
		*format = MR_BROWSE_FORMAT_VERBOSE;
		return TRUE;
	} else if (streq(str, "pretty")) {
		*format = MR_BROWSE_FORMAT_PRETTY;
		return TRUE;
	}
	return FALSE;
}

static void
MR_trace_browse_ensure_init(void)
{
	static	bool	done = FALSE;
	MR_Word		typeinfo_type_word;
	MR_Word		MR_trace_browser_persistent_state_type_word;

	if (! done) {
		MR_TRACE_CALL_MERCURY(
			ML_get_type_info_for_type_info(&typeinfo_type_word);
			ML_BROWSE_browser_persistent_state_type(
				&MR_trace_browser_persistent_state_type_word);
			ML_BROWSE_init_persistent_state(
				&MR_trace_browser_persistent_state);
		);

		MR_trace_browser_persistent_state_type =
			(MR_TypeInfo) MR_make_permanent(
				MR_trace_browser_persistent_state_type_word,
				(MR_TypeInfo) typeinfo_type_word);
		MR_trace_browser_persistent_state = MR_make_permanent(
				MR_trace_browser_persistent_state,
				MR_trace_browser_persistent_state_type);
		done = TRUE;
	}
}

void
MR_trace_query(MR_Query_Type type, const char *options, int num_imports,
	char *imports[])
{
	MR_ConstString options_on_heap;
	MR_Word imports_list;
	MercuryFile mdb_in, mdb_out;
	int i;

	MR_c_file_to_mercury_file(MR_mdb_in, &mdb_in);
	MR_c_file_to_mercury_file(MR_mdb_out, &mdb_out);

	if (options == NULL) options = "";

        MR_TRACE_USE_HP(
		MR_make_aligned_string(options_on_heap, options);

		imports_list = MR_list_empty();
		for (i = num_imports; i > 0; i--) {
			MR_ConstString this_import;
			MR_make_aligned_string(this_import, imports[i - 1]);
			imports_list = MR_list_cons((MR_Word) this_import,
				imports_list);
		}
	);

	MR_TRACE_CALL_MERCURY(
		ML_query(type, imports_list, (MR_String) options_on_heap,
			(MR_Word) &mdb_in, (MR_Word) &mdb_out);
	);
}

#ifdef MR_USE_EXTERNAL_DEBUGGER

void
MR_trace_query_external(MR_Query_Type type, MR_String options, int num_imports,
	MR_Word imports_list)
{
	MR_TRACE_CALL_MERCURY(
		ML_query_external(type, imports_list,  options,
			(MR_Word) &MR_debugger_socket_in, 
			(MR_Word) &MR_debugger_socket_out);
	);
}

#endif
