/*
** Copyright (C) 1998-2000 The University of Melbourne.
** This file may only be copied under the terms of the GNU Library General
** Public License - see the file COPYING.LIB in the Mercury distribution.
*/

/*
** mercury_trace_help.c
**
** Main author: Zoltan Somogyi.
**
** Help system for the internal debugger.
** Most of the implementation is in browser/help.m;
** this is only the interface.
*/

/*
** Some header files refer to files automatically generated by the Mercury
** compiler for modules in the browser and library directories.
**
** XXX figure out how to prevent these names from encroaching on the user's
** name space.
*/

#include "mercury_imp.h"
#include "mercury_layout_util.h"
#include "mercury_array_macros.h"
#include "mercury_deep_copy.h"

#include "mercury_trace_help.h"
#include "mercury_trace_util.h"

#ifdef MR_HIGHLEVEL_CODE
  #include "mercury.std_util.h"
  #include "mercury.io.h"
#else
  #include "std_util.h"
  #include "io.h"
#endif
#include "mdb.help.h"

#include <stdio.h>

static	MR_Word		MR_trace_help_system;
static	MR_TypeInfo	MR_trace_help_system_type;
static	MR_Word		MR_trace_help_stdout;

static	const char	*MR_trace_help_add_node(MR_Word path, const char *name,
				int slot, const char *text);
static	void		MR_trace_help_ensure_init(void);

const char *
MR_trace_add_cat(const char *category, int slot, const char *text)
{
	MR_Word	path;

	MR_trace_help_ensure_init();
	MR_TRACE_USE_HP(
		path = MR_list_empty();
	);
	return MR_trace_help_add_node(path, category, slot, text);
}

const char *
MR_trace_add_item(const char *category, const char *item, int slot,
	const char *text)
{
	MR_Word	path;
	char	*category_on_heap;
	const char *result;

	MR_trace_help_ensure_init();

	MR_TRACE_USE_HP(
		MR_make_aligned_string_copy(category_on_heap, category);
		path = MR_list_empty();
		path = MR_list_cons(category_on_heap, path);
	);

	return MR_trace_help_add_node(path, item, slot, text);
}

static const char *
MR_trace_help_add_node(MR_Word path, const char *name, int slot, const char *text)
{
	MR_Word	result;
	char	*msg;
	char	*name_on_heap;
	char	*text_on_heap;
	bool	error;

	MR_TRACE_USE_HP(
		MR_make_aligned_string_copy(name_on_heap, name);
		MR_make_aligned_string_copy(text_on_heap, text);
	);

	MR_TRACE_CALL_MERCURY(
		ML_HELP_add_help_node(MR_trace_help_system, path, slot,
			name_on_heap, text_on_heap, &result,
			&MR_trace_help_system);
		error = ML_HELP_result_is_error(result, &msg);
	);

	MR_trace_help_system = MR_make_permanent(MR_trace_help_system,
				MR_trace_help_system_type);

	return (error ? msg : NULL);
}

void
MR_trace_help(void)
{
	MR_trace_help_ensure_init();

	MR_TRACE_CALL_MERCURY(
		ML_HELP_help(MR_trace_help_system, MR_trace_help_stdout);
	);
}

void
MR_trace_help_word(const char *word)
{
	char	*word_on_heap;

	MR_trace_help_ensure_init();

	MR_TRACE_USE_HP(
		MR_make_aligned_string_copy(word_on_heap, word);
	);

	MR_TRACE_CALL_MERCURY(
		ML_HELP_name(MR_trace_help_system, word_on_heap,
			MR_trace_help_stdout);
	);
}

void
MR_trace_help_cat_item(const char *category, const char *item)
{
	MR_Word	path;
	MR_Word	result;
	char	*msg;
	char	*category_on_heap;
	char	*item_on_heap;
	bool	error;

	MR_trace_help_ensure_init();

	MR_TRACE_USE_HP(
		MR_make_aligned_string_copy(category_on_heap, category);
		MR_make_aligned_string_copy(item_on_heap, item);
		path = MR_list_empty();
		path = MR_list_cons(item_on_heap, path);
		path = MR_list_cons(category_on_heap, path);
	);

	MR_TRACE_CALL_MERCURY(
		ML_HELP_path(MR_trace_help_system, path, MR_trace_help_stdout, &result);
		error = ML_HELP_result_is_error(result, &msg);
	);

	if (error) {
		printf("internal error in the trace help system: %s\n", msg);
	}
}

static void
MR_trace_help_ensure_init(void)
{
	static	bool	done = FALSE;
	MR_Word		typeinfo_type;
	MR_Word		output_stream_type;
	MR_Word		MR_trace_help_system_type_word;

	if (! done) {
		MR_TRACE_CALL_MERCURY(
			ML_get_type_info_for_type_info(&typeinfo_type);
			ML_HELP_help_system_type(
				&MR_trace_help_system_type_word);
			MR_trace_help_system_type =
				(MR_TypeInfo) MR_trace_help_system_type_word;
			ML_HELP_init(&MR_trace_help_system);
			ML_io_output_stream_type(&output_stream_type);
			ML_io_stdout_stream(&MR_trace_help_stdout);
		);

		MR_trace_help_system_type = (MR_TypeInfo) MR_make_permanent(
					(MR_Word) MR_trace_help_system_type,
					(MR_TypeInfo) typeinfo_type);
		MR_trace_help_system = MR_make_permanent(MR_trace_help_system,
					MR_trace_help_system_type);
		MR_trace_help_stdout = MR_make_permanent(MR_trace_help_stdout,
					(MR_TypeInfo) output_stream_type);

		done = TRUE;
	}
}
