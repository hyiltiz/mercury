/*
** Copyright (C) 1998-2000 The University of Melbourne.
** This file may only be copied under the terms of the GNU Library General
** Public License - see the file COPYING.LIB in the Mercury distribution.
*/

/*
** mercury_trace_browse.h
**
** Defines the interface of the term browser and the interactive query
** facility for the internal and external debuggers.
*/

#ifndef	MERCURY_TRACE_BROWSE_H
#define MERCURY_TRACE_BROWSE_H

#include "mercury_conf.h"	/* for MR_USE_EXTERNAL_DEBUGGER */
#include "mercury_types.h"	/* for MR_Word, MR_String */

/*
** The following types must correspond with browse_caller_type and
** portray_format in browser/browser_info.m.
*/
typedef enum {
	MR_BROWSE_CALLER_PRINT,
	MR_BROWSE_CALLER_BROWSE,
	MR_BROWSE_CALLER_PRINT_ALL
} MR_Browse_Caller_Type;

typedef enum {
	MR_BROWSE_FORMAT_FLAT,
	MR_BROWSE_FORMAT_PRETTY,
	MR_BROWSE_FORMAT_VERBOSE
} MR_Browse_Format;

/*
** This value must be different from any of the MR_BROWSE_FORMAT_* values.
*/
#define MR_BROWSE_DEFAULT_FORMAT	-1

/*
** Interactively browse a term.
*/
extern 	void	MR_trace_browse(MR_Word type_info, MR_Word value,
			MR_Browse_Format format);
#ifdef MR_USE_EXTERNAL_DEBUGGER
extern 	void	MR_trace_browse_external(MR_Word type_info, MR_Word value,
			MR_Browse_Caller_Type caller, MR_Browse_Format format);
#endif

/*
** Display a term (non-interactively).
*/
extern	void	MR_trace_print(MR_Word type_info, MR_Word value,
			MR_Browse_Caller_Type caller, MR_Browse_Format format);

/*
** Set browser parameters.
*/
extern	bool	MR_trace_set_browser_param(MR_Bool print, MR_Bool browse,
			MR_Bool print_all, MR_Bool flat, MR_Bool pretty,
			MR_Bool verbose, const char *param, const char *value);

/*
** Invoke an interactive query.
*/

/* This must kept in sync with query_type in browser/interactive.m. */
typedef enum { MR_NORMAL_QUERY, MR_CC_QUERY, MR_IO_QUERY } MR_Query_Type;

extern	void	MR_trace_query(MR_Query_Type type, const char *options,
			int num_imports, /* const */ char *imports[]);

#ifdef MR_USE_EXTERNAL_DEBUGGER
extern	void	MR_trace_query_external(MR_Query_Type type, MR_String options,
			int num_imports, MR_Word imports_list);
#endif

#endif	/* MERCURY_TRACE_BROWSE_H */
