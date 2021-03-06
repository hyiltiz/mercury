//
// Copyright (C) 2001-2003, 2009 The University of Melbourne.
// This file may only be copied under the terms of the GNU Library General
// Public License - see the file COPYING.LIB in the Mercury distribution.
//
//
// All modifications to this file will require changes to:
// compiler/mlds_to_java.m
// 
//
// At the moment this class is used to store the main module's name (progname),
// command line arguments and the exit status.  We can't put them in one of the
// library modules because we need to hold them in a class variable in a top
// level class.   
//

package jmercury.runtime;

public class JavaInternal {
	public static java.lang.String		progname;
	public static java.lang.String[]	args;
	public static int			exit_status;

        private static java.util.List<Runnable> finalisers
		= new java.util.ArrayList<Runnable>();

	public static void register_finaliser(Runnable hook) {
		finalisers.add(hook);
	}

	public static void run_finalisers() {
		for (Runnable r : finalisers) {
			r.run();
		}
	}
}
