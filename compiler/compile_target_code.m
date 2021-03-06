%-----------------------------------------------------------------------------%
% vim: ft=mercury ts=4 sw=4 et
%-----------------------------------------------------------------------------%
% Copyright (C) 2002-2012 The University of Melbourne.
% This file may only be copied under the terms of the GNU General
% Public License - see the file COPYING in the Mercury distribution.
%-----------------------------------------------------------------------------%
%
% File: compile_target_code.m.
% Main authors: fjh, stayl.
%
% Code to compile the generated `.c', `.s', `.o', etc, files.
%
%-----------------------------------------------------------------------------%

:- module backend_libs.compile_target_code.
:- interface.

:- import_module libs.
:- import_module libs.globals.
:- import_module libs.file_util.
:- import_module parse_tree.
:- import_module parse_tree.module_imports.
:- import_module parse_tree.prog_data.
:- import_module mdbcomp.
:- import_module mdbcomp.prim_data.

:- import_module bool.
:- import_module io.
:- import_module list.
:- import_module maybe.

%-----------------------------------------------------------------------------%

    % Are we generating position independent code (for use in a shared
    % library)? On some architectures, pic and non-pic code are incompatible,
    % so we need to generate `.o' and `.pic_o' files.
    %
:- type pic
    --->    pic
    ;       link_with_pic
    ;       non_pic.

    % compile_c_file(ErrorStream, PIC, ModuleName, Globals, Succeeded, !IO)
    %
:- pred compile_c_file(io.output_stream::in, pic::in, module_name::in,
    globals::in, bool::out, io::di, io::uo) is det.

    % do_compile_c_file(Globals, ErrorStream, PIC, CFile, ObjFile, Succeeded,
    %   !IO)
    %
:- pred do_compile_c_file(io.output_stream::in, pic::in,
    string::in, string::in, globals::in, bool::out, io::di, io::uo) is det.

    % assemble(ErrorStream, PIC, ModuleName, Globals, Succeeded, !IO)
    %
:- pred assemble(io.output_stream::in, pic::in, module_name::in,
    globals::in, bool::out, io::di, io::uo) is det.

    % compile_java_files(ErrorStream, JavaFiles, Succeeded, Globals, !IO)
    %
:- pred compile_java_files(io.output_stream::in, list(string)::in,
    globals::in, bool::out, io::di, io::uo) is det.

    % il_assemble(ErrorStream, ModuleName, HasMain, Globals, Succeeded, !IO)
    %
:- pred il_assemble(io.output_stream::in, module_name::in, has_main::in,
    globals::in, bool::out, io::di, io::uo) is det.

    % do_il_assemble(ErrorStream, ILFile, DLLFile, HasMain, Globals, Succeeded,
    %   !IO)
    %
:- pred do_il_assemble(io.output_stream::in, file_name::in, file_name::in,
    has_main::in, globals::in, bool::out, io::di, io::uo) is det.

    % compile_csharp_file(ErrorStream, C#File, DLLFile, Globals, Succeeded,
    %   !IO)
    %
:- pred compile_csharp_file(io.output_stream::in, module_and_imports::in,
    file_name::in, file_name::in, globals::in, bool::out, io::di, io::uo)
    is det.

    % compile_erlang_file(ErrorStream, ErlangFile, Globals, Succeeded, !IO)
    %
:- pred compile_erlang_file(io.output_stream::in, file_name::in,
    globals::in, bool::out, io::di, io::uo) is det.

    % make_library_init_file(Globals, ErrorStream, MainModuleName, ModuleNames,
    %   Succeeded, !IO):
    %
    % Make the `.init' file for a library containing the given modules.
    %
:- pred make_library_init_file(globals::in, io.output_stream::in,
    module_name::in, list(module_name)::in, bool::out, io::di, io::uo) is det.

    % make_erlang_init_library(Globals, ErrorStream, MainModuleName,
    %   ModuleNames, Succeeded, !IO):
    %
    % Make the `.init' file for an Erlang library containing the given
    % modules.
    %
:- pred make_erlang_library_init_file(globals::in, io.output_stream::in,
    module_name::in, list(module_name)::in, bool::out, io::di, io::uo) is det.

    % make_init_obj_file(Globals, ErrorStream, MainModuleName, AllModuleNames,
    %   MaybeInitObjFileName)
    %
:- pred make_init_obj_file(globals::in, io.output_stream::in, module_name::in,
    list(module_name)::in, maybe(file_name)::out, io::di, io::uo) is det.

    % make_erlang_program_init_file(Globals, ErrorStream, MainModuleName,
    %   AllModuleNames, MaybeInitObjFileName, !IO)
    %
:- pred make_erlang_program_init_file(globals::in, io.output_stream::in,
    module_name::in, list(module_name)::in, maybe(file_name)::out,
    io::di, io::uo) is det.

:- type linked_target_type
    --->    executable
    ;       static_library
    ;       shared_library
    ;       csharp_executable
    ;       csharp_library
    ;       java_launcher
    ;       java_archive
    ;       erlang_launcher
    ;       erlang_archive.

    % link(TargetType, MainModuleName, ObjectFileNames, Globals, Succeeded,
    %   !IO)
    %
:- pred link(io.output_stream::in, linked_target_type::in, module_name::in,
    list(string)::in, globals::in, bool::out, io::di, io::uo) is det.

    % post_link_make_symlink_or_copy(TargetType, MainModuleName,
    %   Globals, Succeeded, MadeSymlinkOrCopy, !IO)
    %
    % If `--use-grade-subdirs' is enabled, link or copy the executable or
    % library into the user's directory after having successfully built it,
    % if the target does not exist or is not up-to-date.
    %
:- pred post_link_make_symlink_or_copy(io.output_stream::in,
    linked_target_type::in, module_name::in, globals::in, bool::out, bool::out,
    io::di, io::uo) is det.

    % link_module_list(ModulesToLink, ExtraObjFiles, Globals, Succeeded,
    %   !IO):
    %
    % The elements of ModulesToLink are the output of
    % `module_name_to_filename(ModuleName, "", no, ModuleToLink)'
    % for each module in the program.
    %
:- pred link_module_list(list(string)::in, list(string)::in,
    globals::in, bool::out, io::di, io::uo) is det.

    % shared_libraries_supported(Globals, SharedLibsSupported)
    %
    % Return whether or not shared libraries are supported on the current
    % platform.
    %
:- pred shared_libraries_supported(globals::in, bool::out) is det.

    % get_object_code_type(Globals, TargetType, PIC):
    %
    % Work out whether we should be generating position-independent
    % object code.
    %
:- pred get_object_code_type(globals::in, linked_target_type::in, pic::out)
    is det.

    % get_linked_target_type(Globals, LinkedTargetType):
    %
    % Work out whether we should be generating an executable or a shared
    % object.
    %
:- pred get_linked_target_type(globals::in, linked_target_type::out) is det.

%-----------------------------------------------------------------------------%

    % make_all_module_command(Globals, CommandName, MainModule, AllModuleNames,
    %   CommandString, !IO):
    %
    % Create a command string which passes the source file names
    % for AllModuleNames to CommandName, with MainModule given first.
    %
:- pred make_all_module_command(globals::in, string::in, module_name::in,
    list(module_name)::in, string::out, io::di, io::uo) is det.

%-----------------------------------------------------------------------------%

    % maybe_pic_object_file_extension(Globals, PIC, Ext) is true iff
    % Ext is the extension which should be used on object files according to
    % the value of PIC. The value of PIC should be obtained from a call to
    % `get_object_code_type'. In particular, on architectures for which
    % no special handling for PIC is necessary, only a value of `non_pic'
    % should be used. The `(in, out, in)' mode guarantees that the returned
    % value of PIC meets this requirement.
    %
:- pred maybe_pic_object_file_extension(globals, pic, string).
:- mode maybe_pic_object_file_extension(in, in, out) is det.
:- mode maybe_pic_object_file_extension(in, out, in) is semidet.

%-----------------------------------------------------------------------------%
%
% Stuff used for standalone interfaces.
%

    % make_standalone_interface(Globals, Basename, !IO):
    %
    % Create a standalone interface in the current directory.
    %
:- pred make_standalone_interface(globals::in, string::in, io::di, io::uo)
    is det.

    % Output the C compiler flags to the given stream.
    % This predicate is used to implement the `--output-cflags' option.
    %
:- pred output_c_compiler_flags(globals::in, io.output_stream::in,
    io::di, io::uo) is det.

    % Output the C compiler flags that define the macros used to specify the
    % current compilation grade to the given stream.
    % This predicate is used to implement the `--output-grade-defines' option.
    %
:- pred output_grade_defines(globals::in, io.output_stream::in,
    io::di, io::uo) is det.

    % Output the C compiler flags that specify where the C compiler should
    % search for header files to the given stream.
    % This predicate is used to implement the `--output-c-include-dir-flags'
    % option.
    %
:- pred output_c_include_directory_flags(globals::in, io.output_stream::in,
    io::di, io::uo) is det.

    % Output the list of flags required to link against the selected set
    % of Mercury libraries (the standard libraries, plus any other specified
    % via the --ml option) in the current grade.
    % This predicate is used to implement the `--output-library-link-flags'
    % option.
    %
:- pred output_library_link_flags(globals::in, io.output_stream::in,
    io::di, io::uo) is det.

%-----------------------------------------------------------------------------%
%-----------------------------------------------------------------------------%

:- implementation.

:- import_module libs.globals.
:- import_module libs.handle_options.
:- import_module libs.options.
:- import_module libs.trace_params.
:- import_module parse_tree.error_util.
:- import_module parse_tree.file_names.
:- import_module parse_tree.module_cmds.
:- import_module parse_tree.write_deps_file.
:- import_module parse_tree.prog_foreign.

:- import_module dir.
:- import_module getopt_io.
:- import_module require.
:- import_module string.

%-----------------------------------------------------------------------------%

il_assemble(ErrorStream, ModuleName, HasMain, Globals, Succeeded, !IO) :-
    module_name_to_file_name(Globals, ModuleName, ".il",
        do_not_create_dirs, IL_File, !IO),
    module_name_to_file_name(Globals, ModuleName, ".dll",
        do_create_dirs, DllFile, !IO),

    % If the module contains main/2 then we it should be built as an
    % executable. Unfortunately C# code may refer to the dll
    % so we always need to build the dll.

    do_il_assemble(ErrorStream, IL_File, DllFile, no_main,
        Globals, DllSucceeded, !IO),
    (
        HasMain = has_main,
        module_name_to_file_name(Globals, ModuleName, ".exe",
            do_create_dirs, ExeFile, !IO),
        do_il_assemble(ErrorStream, IL_File, ExeFile, HasMain,
            Globals, ExeSucceeded, !IO),
        Succeeded = DllSucceeded `and` ExeSucceeded
    ;
        HasMain = no_main,
        Succeeded = DllSucceeded
    ).

do_il_assemble(ErrorStream, IL_File, TargetFile, HasMain, Globals, Succeeded,
        !IO) :-
    globals.lookup_bool_option(Globals, verbose, Verbose),
    globals.lookup_bool_option(Globals, sign_assembly, SignAssembly),
    maybe_write_string(Verbose, "% Assembling `", !IO),
    maybe_write_string(Verbose, IL_File, !IO),
    maybe_write_string(Verbose, "':\n", !IO),
    globals.lookup_string_option(Globals, il_assembler, ILASM),
    globals.lookup_accumulating_option(Globals, ilasm_flags, ILASMFlagsList),
    join_string_list(ILASMFlagsList, "", "", " ", ILASMFlags),
    (
        SignAssembly = yes,
        SignOpt = "/keyf=mercury.sn "
    ;
        SignAssembly = no,
        SignOpt = ""
    ),
    (
        Verbose = yes,
        VerboseOpt = ""
    ;
        Verbose = no,
        VerboseOpt = "/quiet "
    ),
    globals.lookup_bool_option(Globals, target_debug, Debug),
    (
        Debug = yes,
        DebugOpt = "/debug "
    ;
        Debug = no,
        DebugOpt = ""
    ),
    (
        HasMain = has_main,
        TargetOpt = ""
    ;
        HasMain = no_main,
        TargetOpt = "/dll "
    ),
    string.append_list([ILASM, " ", SignOpt, VerboseOpt, DebugOpt,
        TargetOpt, ILASMFlags, " /out=", TargetFile, " ", IL_File], Command),
    invoke_system_command(Globals, ErrorStream, cmd_verbose_commands, Command,
        Succeeded, !IO).

compile_csharp_file(ErrorStream, Imports, CSharpFileName0, DLLFileName,
        Globals, Succeeded, !IO) :-
    globals.lookup_bool_option(Globals, verbose, Verbose),
    maybe_write_string(Verbose, "% Compiling `", !IO),
    maybe_write_string(Verbose, CSharpFileName, !IO),
    maybe_write_string(Verbose, "':\n", !IO),
    globals.lookup_string_option(Globals, csharp_compiler, CSC),
    globals.lookup_accumulating_option(Globals, csharp_flags, CSCFlagsList),
    join_string_list(CSCFlagsList, "", "", " ", CSCFlags),

    % XXX This is because the MS C# compiler doesn't understand
    % / as a directory separator.
    CSharpFileName = string.replace_all(CSharpFileName0, "/", "\\\\"),

    globals.lookup_bool_option(Globals, target_debug, Debug),
    (
        Debug = yes,
        % XXX This needs testing before it can be enabled (see the comments
        % for install_debug_library in library/Mmakefile).

        % DebugOpt = "-debug+ -debug:full "
        DebugOpt = ""
    ;
        Debug = no,
        DebugOpt = ""
    ),

    % XXX Should we use a separate dll_directories options?
    % NOTE: we use the -option style options in preference to the /option
    % style in order to avoid problems with POSIX style shells.
    globals.lookup_accumulating_option(Globals, link_library_directories,
        DLLDirs),
    DLLDirOpts = "-lib:Mercury/dlls " ++
        string.append_list(list.condense(list.map(
            (func(DLLDir) = ["-lib:", DLLDir, " "]), DLLDirs))),

    ( mercury_std_library_module_name(Imports ^ mai_module_name) ->
        Prefix = "-addmodule:"
    ;
        Prefix = "-r:"
    ),
    ForeignDeps = list.map(
        (func(M) =
            foreign_import_module_name_from_module(M,
                Imports ^ mai_module_name)),
        Imports ^ mai_foreign_import_modules),
    ReferencedDlls = referenced_dlls(Imports ^ mai_module_name,
        Imports ^ mai_int_deps ++ Imports ^ mai_impl_deps ++ ForeignDeps),
    list.map_foldl(
        (pred(Mod::in, Result::out, IO0::di, IO::uo) is det :-
            module_name_to_file_name(Globals, Mod, ".dll",
                do_not_create_dirs, FileName, IO0, IO),
            Result = [Prefix, FileName, " "]
        ), ReferencedDlls, ReferencedDllsList, !IO),
    ReferencedDllsStr = string.append_list(
        list.condense(ReferencedDllsList)),

    string.append_list([CSC, DebugOpt,
        " -t:library ", DLLDirOpts, CSCFlags, ReferencedDllsStr,
        " -out:", DLLFileName, " ", CSharpFileName], Command),
    invoke_system_command(Globals, ErrorStream, cmd_verbose_commands, Command,
        Succeeded, !IO).

%-----------------------------------------------------------------------------%

% WARNING: The code here duplicates the functionality of scripts/mgnuc.in.
% Any changes there may also require changes here, and vice versa.

compile_c_file(ErrorStream, PIC, ModuleName, Globals, Succeeded, !IO) :-
    module_name_to_file_name(Globals, ModuleName, ".c",
        do_create_dirs, C_File, !IO),
    maybe_pic_object_file_extension(Globals, PIC, ObjExt),
    module_name_to_file_name(Globals, ModuleName, ObjExt,
        do_create_dirs, O_File, !IO),
    do_compile_c_file(ErrorStream, PIC, C_File, O_File, Globals, Succeeded,
        !IO).

do_compile_c_file(ErrorStream, PIC, C_File, O_File, Globals, Succeeded, !IO) :-
    globals.lookup_bool_option(Globals, verbose, Verbose),
    globals.lookup_string_option(Globals, c_flag_to_name_object_file,
        NameObjectFile),
    maybe_write_string(Verbose, "% Compiling `", !IO),
    maybe_write_string(Verbose, C_File, !IO),
    maybe_write_string(Verbose, "':\n", !IO),
    globals.lookup_string_option(Globals, cc, CC),
    gather_c_compiler_flags(Globals, PIC, AllCFlags),
    string.append_list([
        CC, " ",
        AllCFlags,
        " -c ", quote_arg(C_File), " ",
        NameObjectFile, quote_arg(O_File)], Command),
    get_maybe_filtercc_command(Globals, MaybeFilterCmd),
    invoke_system_command_maybe_filter_output(Globals, ErrorStream,
        cmd_verbose_commands, Command, MaybeFilterCmd, Succeeded, !IO).

:- pred gather_c_compiler_flags(globals::in, pic::in, string::out) is det.

gather_c_compiler_flags(Globals, PIC, AllCFlags) :-
    globals.lookup_accumulating_option(Globals, cflags, C_Flags_List),
    join_string_list(C_Flags_List, "", "", " ", CFLAGS),
    gather_compiler_specific_flags(Globals, CC_Specific_CFLAGS),

    globals.lookup_bool_option(Globals, use_subdirs, UseSubdirs),
    (
        UseSubdirs = yes,
        % The source file (foo.c) will be compiled in a subdirectory
        % (either Mercury/cs, foo.dir, or Mercury/dirs/foo.dir, depending
        % on which of these two options is set) so we need to add `-I.'
        % so it can include header files in the source directory.
        SubDirInclOpt = "-I. "
    ;
        UseSubdirs = no,
        SubDirInclOpt = ""
    ),

    gather_c_include_dir_flags(Globals, InclOpt),
    get_framework_directories(Globals, FrameworkInclOpt),
    gather_grade_defines(Globals, PIC, GradeDefinesOpts),

    globals.lookup_bool_option(Globals, gcc_global_registers, GCC_Regs),
    (
        GCC_Regs = yes,
        globals.lookup_string_option(Globals, cflags_for_regs,
            CFLAGS_FOR_REGS)
    ;
        GCC_Regs = no,
        CFLAGS_FOR_REGS = ""
    ),
    globals.lookup_bool_option(Globals, gcc_non_local_gotos, GCC_Gotos),
    (
        GCC_Gotos = yes,
        globals.lookup_string_option(Globals, cflags_for_gotos,
            CFLAGS_FOR_GOTOS)
    ;
        GCC_Gotos = no,
        CFLAGS_FOR_GOTOS = ""
    ),
    globals.lookup_bool_option(Globals, parallel, Parallel),
    (
        Parallel = yes,
        globals.lookup_string_option(Globals, cflags_for_threads,
            CFLAGS_FOR_THREADS)
    ;
        Parallel = no,
        CFLAGS_FOR_THREADS = ""
    ),
    (
        PIC = pic,
        globals.lookup_string_option(Globals, cflags_for_pic, CFLAGS_FOR_PIC)
    ;
        ( PIC = link_with_pic
        ; PIC = non_pic
        ),
        CFLAGS_FOR_PIC = ""
    ),
    globals.lookup_bool_option(Globals, target_debug, Target_Debug),
    (
        Target_Debug = yes,
        globals.lookup_string_option(Globals, cflags_for_debug,
            Target_DebugOpt0),
        Target_DebugOpt = Target_DebugOpt0 ++ " "
    ;
        Target_Debug = no,
        Target_DebugOpt = ""
    ),
    globals.lookup_bool_option(Globals, use_trail, UseTrail),
    (
        UseTrail = yes,
        % With tagged trail entries function trailing will not work unless the
        % C functions stored on the trail are aligned on word boundaries (or a
        % multiple thereof). The assemblers on some systems, and some gcc
        % optimisation settings, do not align functions, so we need to
        % explicitly pass -falign-functions in trailing grades to ensure that
        % C functions are appropriately aligned.
        %
        % Note that this will also affect the untagged version of the trail,
        % but that shouldn't matter.
        %
        globals.get_c_compiler_type(Globals, C_CompilerType),
        (
            C_CompilerType = cc_gcc(_, _, _),
            globals.lookup_int_option(Globals, bytes_per_word, BytesPerWord),
            C_FnAlignOpt = string.format("-falign-functions=%d ",
                [i(BytesPerWord)])
        ;
            % XXX Check whether we need to do anything for these C compilers?
            ( C_CompilerType = cc_clang(_)
            ; C_CompilerType = cc_lcc
            ; C_CompilerType = cc_cl(_)
            ),
            C_FnAlignOpt = ""
        ;
            C_CompilerType = cc_unknown,
            C_FnAlignOpt = ""
        )
    ;
        UseTrail = no,
        C_FnAlignOpt = ""
    ),
    globals.lookup_bool_option(Globals, type_layout, TypeLayoutOption),
    (
        TypeLayoutOption = no,
        TypeLayoutOpt = "-DMR_NO_TYPE_LAYOUT "
    ;
        TypeLayoutOption = yes,
        TypeLayoutOpt = ""
    ),
    globals.lookup_bool_option(Globals, c_optimize, C_optimize),
    (
        C_optimize = yes,
        globals.lookup_string_option(Globals, cflags_for_optimization,
            OptimizeOpt)
    ;
        C_optimize = no,
        OptimizeOpt = ""
    ),
    globals.lookup_bool_option(Globals, ansi_c, Ansi),
    (
        Ansi = yes,
        globals.lookup_string_option(Globals, cflags_for_ansi, AnsiOpt)
    ;
        Ansi = no,
        AnsiOpt = ""
    ),
    globals.lookup_bool_option(Globals, inline_alloc, InlineAlloc),
    (
        InlineAlloc = yes,
        % XXX disabled because inline allocation is broken in gc7.0 alpha6.
        % InlineAllocOpt = "-DMR_INLINE_ALLOC "
        InlineAllocOpt = ""
    ;
        InlineAlloc = no,
        InlineAllocOpt = ""
    ),
    globals.lookup_bool_option(Globals, warn_target_code, Warn),
    (
        Warn = yes,
        globals.lookup_string_option(Globals, cflags_for_warnings, WarningOpt)
    ;
        Warn = no,
        WarningOpt = ""
    ),

    % The -floop-optimize option is incompatible with the global
    % register code we generate on Darwin PowerPC.
    % See the hard_coded/ppc_bug test case for an example
    % program which fails with this optimization.

    globals.lookup_string_option(Globals, fullarch, FullArch),
    (
        globals.lookup_bool_option(Globals, highlevel_code, no),
        globals.lookup_bool_option(Globals, gcc_global_registers, yes),
        string.prefix(FullArch, "powerpc-apple-darwin")
    ->
        AppleGCCRegWorkaroundOpt = "-fno-loop-optimize "
    ;
        AppleGCCRegWorkaroundOpt = ""
    ),

    % Workaround performance problem(s) with gcc that causes the C files
    % generated in debugging grades to compile very slowly at -O1 and above.
    % (Changes here need to be reflected in scripts/mgnuc.in.)
    (
        globals.lookup_bool_option(Globals, exec_trace, yes),
        arch_is_apple_darwin(FullArch)
    ->
        OverrideOpts = "-O0"
    ;
        OverrideOpts = ""
    ),

    % Be careful with the order here!  Some options override others,
    % e.g. CFLAGS_FOR_REGS must come after OptimizeOpt so that
    % it can override -fomit-frame-pointer with -fno-omit-frame-pointer.
    % Also be careful that each option is separated by spaces.
    %
    % In general, user supplied C compiler flags, i.e. CFLAGS and
    % CC_Specific_CFLAGS below, should be able to override those introduced by
    % the Mercury compiler.
    % In some circumstances we want to prevent the user doing this, typically
    % where we know the behaviour of a particular C compiler is buggy; the
    % last option, OverrideOpts, does this -- because of this it must be
    % listed after CFLAGS and CC_Specific_CFLAGS.
    %
    string.append_list([
        SubDirInclOpt, InclOpt, " ",
        FrameworkInclOpt, " ",
        OptimizeOpt, " ",
        GradeDefinesOpts,
        CFLAGS_FOR_REGS, " ", CFLAGS_FOR_GOTOS, " ",
        CFLAGS_FOR_THREADS, " ", CFLAGS_FOR_PIC, " ",
        Target_DebugOpt,
        TypeLayoutOpt,
        InlineAllocOpt,
        AnsiOpt, " ",
        AppleGCCRegWorkaroundOpt,
        C_FnAlignOpt,
        WarningOpt, " ",
        CFLAGS, " ",
        CC_Specific_CFLAGS, " ",
        OverrideOpts], AllCFlags).

%-----------------------------------------------------------------------------%

:- pred gather_grade_defines(globals::in, pic::in, string::out) is det.

gather_grade_defines(Globals, PIC, GradeDefines) :-
    globals.lookup_bool_option(Globals, highlevel_code, HighLevelCode),
    (
        HighLevelCode = yes,
        HighLevelCodeOpt = "-DMR_HIGHLEVEL_CODE "
    ;
        HighLevelCode = no,
        HighLevelCodeOpt = ""
    ),
    globals.lookup_bool_option(Globals, gcc_nested_functions,
        GCC_NestedFunctions),
    (
        GCC_NestedFunctions = yes,
        NestedFunctionsOpt = "-DMR_USE_GCC_NESTED_FUNCTIONS "
    ;
        GCC_NestedFunctions = no,
        NestedFunctionsOpt = ""
    ),
    globals.lookup_bool_option(Globals, highlevel_data, HighLevelData),
    (
        HighLevelData = yes,
        HighLevelDataOpt = "-DMR_HIGHLEVEL_DATA "
    ;
        HighLevelData = no,
        HighLevelDataOpt = ""
    ),
    globals.lookup_bool_option(Globals, gcc_global_registers, GCC_Regs),
    (
        GCC_Regs = yes,
        RegOpt = "-DMR_USE_GCC_GLOBAL_REGISTERS "
    ;
        GCC_Regs = no,
        RegOpt = ""
    ),
    globals.lookup_bool_option(Globals, gcc_non_local_gotos, GCC_Gotos),
    (
        GCC_Gotos = yes,
        GotoOpt = "-DMR_USE_GCC_NONLOCAL_GOTOS "
    ;
        GCC_Gotos = no,
        GotoOpt = ""
    ),
    globals.lookup_bool_option(Globals, asm_labels, ASM_Labels),
    (
        ASM_Labels = yes,
        AsmOpt = "-DMR_USE_ASM_LABELS "
    ;
        ASM_Labels = no,
        AsmOpt = ""
    ),
    globals.lookup_bool_option(Globals, parallel, Parallel),
    (
        Parallel = yes,
        ParallelOpt = "-DMR_THREAD_SAFE "
    ;
        Parallel = no,
        ParallelOpt = ""
    ),
    globals.lookup_bool_option(Globals, threadscope, Threadscope),
    (
        Threadscope = yes,
        ThreadscopeOpt = "-DMR_THREADSCOPE "
    ;
        Threadscope = no,
        ThreadscopeOpt = ""
    ),
    globals.get_gc_method(Globals, GC_Method),
    BoehmGC_Opt = "-DMR_CONSERVATIVE_GC -DMR_BOEHM_GC ",
    (
        GC_Method = gc_automatic,
        GC_Opt = ""
    ;
        GC_Method = gc_none,
        GC_Opt = ""
    ;
        GC_Method = gc_boehm,
        GC_Opt = BoehmGC_Opt
    ;
        GC_Method = gc_boehm_debug,
        GC_Opt = BoehmGC_Opt ++
            "-DMR_BOEHM_GC_DEBUG -DGC_DEBUG -DKEEP_BACKPTRS "
    ;
        GC_Method = gc_hgc,
        GC_Opt = "-DMR_CONSERVATIVE_GC -DMR_HGC "
    ;
        GC_Method = gc_mps,
        GC_Opt = "-DMR_CONSERVATIVE_GC -DMR_MPS_GC "
    ;
        GC_Method = gc_accurate,
        GC_Opt = "-DMR_NATIVE_GC "
    ),
    globals.lookup_bool_option(Globals, profile_calls, ProfileCalls),
    (
        ProfileCalls = yes,
        ProfileCallsOpt = "-DMR_MPROF_PROFILE_CALLS "
    ;
        ProfileCalls = no,
        ProfileCallsOpt = ""
    ),
    globals.lookup_bool_option(Globals, profile_time, ProfileTime),
    (
        ProfileTime = yes,
        ProfileTimeOpt = "-DMR_MPROF_PROFILE_TIME "
    ;
        ProfileTime = no,
        ProfileTimeOpt = ""
    ),
    globals.lookup_bool_option(Globals, profile_memory, ProfileMemory),
    (
        ProfileMemory = yes,
        ProfileMemoryOpt = "-DMR_MPROF_PROFILE_MEMORY "
    ;
        ProfileMemory = no,
        ProfileMemoryOpt = ""
    ),
    globals.lookup_bool_option(Globals, profile_deep, ProfileDeep),
    (
        ProfileDeep = yes,
        ProfileDeepOpt = "-DMR_DEEP_PROFILING "
    ;
        ProfileDeep = no,
        ProfileDeepOpt = ""
    ),
    globals.lookup_bool_option(Globals, record_term_sizes_as_words,
        RecordTermSizesAsWords),
    globals.lookup_bool_option(Globals, record_term_sizes_as_cells,
        RecordTermSizesAsCells),
    (
        RecordTermSizesAsWords = yes,
        RecordTermSizesAsCells = yes,
        % This should have been caught in handle_options.
        unexpected($module, $pred, "inconsistent record term size options")
    ;
        RecordTermSizesAsWords = yes,
        RecordTermSizesAsCells = no,
        RecordTermSizesOpt = "-DMR_RECORD_TERM_SIZES "
    ;
        RecordTermSizesAsWords = no,
        RecordTermSizesAsCells = yes,
        RecordTermSizesOpt = "-DMR_RECORD_TERM_SIZES " ++
            "-DMR_RECORD_TERM_SIZES_AS_CELLS "
    ;
        RecordTermSizesAsWords = no,
        RecordTermSizesAsCells = no,
        RecordTermSizesOpt = ""
    ),
    (
        PIC = pic,
        PIC_Reg = yes
    ;
        PIC = link_with_pic,
        PIC_Reg = yes
    ;
        PIC = non_pic,
        globals.lookup_bool_option(Globals, pic_reg, PIC_Reg)
    ),
    (
        PIC_Reg = yes,
        % This will be ignored for architectures/grades where use of position
        % independent code does not reserve a register.
        PIC_Reg_Opt = "-DMR_PIC_REG "
    ;
        PIC_Reg = no,
        PIC_Reg_Opt = ""
    ),

    globals.get_tags_method(Globals, Tags_Method),
    (
        Tags_Method = tags_high,
        TagsOpt = "-DMR_HIGHTAGS "
    ;
        ( Tags_Method = tags_low
        ; Tags_Method = tags_none
        ),
        TagsOpt = ""
    ),
    globals.lookup_int_option(Globals, num_tag_bits, NumTagBits),
    string.int_to_string(NumTagBits, NumTagBitsString),
    NumTagBitsOpt = "-DMR_TAGBITS=" ++ NumTagBitsString ++ " ",
    globals.lookup_bool_option(Globals, decl_debug, DeclDebug),
    (
        DeclDebug = yes,
        DeclDebugOpt = "-DMR_DECL_DEBUG "
    ;
        DeclDebug = no,
        DeclDebugOpt = ""
    ),
    globals.lookup_bool_option(Globals, source_to_source_debug, SourceDebug),
    (
        SourceDebug = yes,
        SourceDebugOpt = "-DMR_SS_DEBUG "
    ;
        SourceDebug = no,
        SourceDebugOpt = ""
    ),
    globals.lookup_bool_option(Globals, exec_trace, ExecTrace),
    (
        ExecTrace = yes,
        ExecTraceOpt = "-DMR_EXEC_TRACE "
    ;
        ExecTrace = no,
        ExecTraceOpt = ""
    ),
    globals.lookup_bool_option(Globals, extend_stacks_when_needed, Extend),
    globals.lookup_bool_option(Globals, stack_segments, StackSegments),
    (
        Extend = yes,
        StackSegments = no,
        ExtendOpt = "-DMR_EXTEND_STACKS_WHEN_NEEDED "
    ;
        Extend = no,
        StackSegments = yes,
        ExtendOpt = "-DMR_STACK_SEGMENTS "
    ;
        Extend = no,
        StackSegments = no,
        ExtendOpt = ""
    ;
        Extend = yes,
        StackSegments = yes,
        ExtendOpt = unexpected($module, $pred,
            "--extend-stacks-when-needed and --stack-segments")
    ),
    globals.lookup_bool_option(Globals, low_level_debug, LL_Debug),
    (
        LL_Debug = yes,
        LL_DebugOpt = "-DMR_LL_DEBUG "
    ;
        LL_Debug = no,
        LL_DebugOpt = ""
    ),
    globals.lookup_bool_option(Globals, use_trail, UseTrail),
    (
        UseTrail = yes,
        UseTrailOpt = "-DMR_USE_TRAIL ",
        globals.lookup_bool_option(Globals, trail_segments, TrailSegments),
        (
            TrailSegments = yes,
            TrailSegOpt = "-DMR_TRAIL_SEGMENTS "
        ;
            TrailSegments = no,
            TrailSegOpt = ""
        )
    ;
        UseTrail = no,
        UseTrailOpt = "",
        TrailSegOpt = ""
    ),
    globals.lookup_bool_option(Globals, use_minimal_model_stack_copy,
        MinimalModelStackCopy),
    globals.lookup_bool_option(Globals, use_minimal_model_own_stacks,
        MinimalModelOwnStacks),
    (
        MinimalModelStackCopy = yes,
        MinimalModelOwnStacks = yes,
        % this should have been caught in handle_options
        unexpected($module, $pred, "inconsistent minimal model options")
    ;
        MinimalModelStackCopy = yes,
        MinimalModelOwnStacks = no,
        MinimalModelBaseOpt = "-DMR_USE_MINIMAL_MODEL_STACK_COPY "
    ;
        MinimalModelStackCopy = no,
        MinimalModelOwnStacks = yes,
        MinimalModelBaseOpt = "-DMR_USE_MINIMAL_MODEL_OWN_STACKS "
    ;
        MinimalModelStackCopy = no,
        MinimalModelOwnStacks = no,
        MinimalModelBaseOpt = ""
    ),
    globals.lookup_bool_option(Globals, minimal_model_debug,
        MinimalModelDebug),
    (
        MinimalModelDebug = yes,
        ( MinimalModelBaseOpt = "" ->
            % We ignore the debug flag unless one of the base flags is set.
            MinimalModelOpt = MinimalModelBaseOpt
        ;
            MinimalModelOpt = MinimalModelBaseOpt ++
                "-DMR_MINIMAL_MODEL_DEBUG "
        )
    ;
        MinimalModelDebug = no,
        MinimalModelOpt = MinimalModelBaseOpt
    ),

    globals.lookup_bool_option(Globals, pregenerated_dist, PregeneratedDist),
    (
        PregeneratedDist = yes,
        PregeneratedDistOpt = "-DMR_PREGENERATED_DIST "
    ;
        PregeneratedDist = no,
        PregeneratedDistOpt = ""
    ),
    globals.lookup_bool_option(Globals, single_prec_float, SinglePrecFloat),
    (
        SinglePrecFloat = yes,
        SinglePrecFloatOpt = "-DMR_USE_SINGLE_PREC_FLOAT "
    ;
        SinglePrecFloat = no,
        SinglePrecFloatOpt = ""
    ),

    globals.lookup_bool_option(Globals, use_regions, UseRegions),
    (
        UseRegions = yes,
        UseRegionsOpt0 = "-DMR_USE_REGIONS ",
        globals.lookup_bool_option(Globals, use_regions_debug,
            UseRegionsDebug),
        (
            UseRegionsDebug = yes,
            UseRegionsOpt1 = UseRegionsOpt0 ++ "-DMR_RBMM_DEBUG "
        ;
            UseRegionsDebug = no,
            UseRegionsOpt1 = UseRegionsOpt0
        ),
        globals.lookup_bool_option(Globals, use_regions_profiling,
            UseRegionsProfiling),
        (
            UseRegionsProfiling = yes,
            UseRegionsOpt = UseRegionsOpt1 ++ "-DMR_RBMM_PROFILING "
        ;
            UseRegionsProfiling = no,
            UseRegionsOpt = UseRegionsOpt1
        )
    ;
        UseRegions = no,
        UseRegionsOpt = ""
    ),
    string.append_list([
        HighLevelCodeOpt,
        NestedFunctionsOpt,
        HighLevelDataOpt,
        RegOpt, GotoOpt, AsmOpt,
        ParallelOpt,
        ThreadscopeOpt,
        GC_Opt,
        ProfileCallsOpt, ProfileTimeOpt,
        ProfileMemoryOpt, ProfileDeepOpt,
        RecordTermSizesOpt,
        PIC_Reg_Opt,
        TagsOpt, NumTagBitsOpt,
        ExtendOpt,
        LL_DebugOpt, DeclDebugOpt,
        SourceDebugOpt,
        ExecTraceOpt,
        UseTrailOpt,
        TrailSegOpt,
        MinimalModelOpt,
        PregeneratedDistOpt,
        SinglePrecFloatOpt,
        UseRegionsOpt], GradeDefines).

%-----------------------------------------------------------------------------%

:- pred gather_c_include_dir_flags(globals::in, string::out) is det.

gather_c_include_dir_flags(Globals, InclOpt) :-
    globals.lookup_accumulating_option(Globals, c_include_directory,
        C_Incl_Dirs),
    InclOpt = string.append_list(list.condense(list.map(
        (func(C_INCL) = ["-I", quote_arg(C_INCL), " "]), C_Incl_Dirs))).

%-----------------------------------------------------------------------------%

:- pred gather_compiler_specific_flags(globals::in, string::out) is det.

gather_compiler_specific_flags(Globals, Flags) :-
    globals.get_c_compiler_type(Globals, C_CompilerType),
    (
        C_CompilerType = cc_gcc(_, _, _),
        globals.lookup_accumulating_option(Globals, gcc_flags, FlagsList)
    ;
        C_CompilerType = cc_clang(_),
        globals.lookup_accumulating_option(Globals, clang_flags, FlagsList)
    ;
        C_CompilerType = cc_cl(_),
        globals.lookup_accumulating_option(Globals, msvc_flags, FlagsList)
    ;
        ( C_CompilerType = cc_lcc
        ; C_CompilerType = cc_unknown
        ),
        FlagsList = []
    ),
    join_string_list(FlagsList, "", "", " ", Flags).

:- pred get_maybe_filtercc_command(globals::in, maybe(string)::out) is det.

get_maybe_filtercc_command(Globals, MaybeFilterCmd) :-
    % At this time we only need to filter the compiler output when using
    % assembler labels with gcc 4.x. Mercury.config.bootstrap doesn't specify
    % the gcc version so we don't check for it.
    (
        globals.lookup_bool_option(Globals, asm_labels, yes),
        globals.lookup_string_option(Globals, filtercc_command, FilterCmd),
        FilterCmd \= ""
    ->
        MaybeFilterCmd = yes(FilterCmd)
    ;
        MaybeFilterCmd = no
    ).

%-----------------------------------------------------------------------------%

compile_java_files(ErrorStream, JavaFiles, Globals, Succeeded, !IO) :-
    globals.lookup_bool_option(Globals, verbose, Verbose),
    (
        JavaFiles = [JavaFile | MoreFiles],
        (
            Verbose = yes,
            io.write_string("% Compiling `", !IO),
            io.write_string(JavaFile, !IO),
            (
                MoreFiles = [],
                io.write_string("':\n", !IO)
            ;
                MoreFiles = [_ | _],
                io.write_string("', etc.:\n", !IO)
            )
        ;
            Verbose = no
        )
    ;
        JavaFiles = [],
        unexpected($module, $pred, "empty list")
    ),

    globals.lookup_string_option(Globals, java_compiler, JavaCompiler),
    globals.lookup_accumulating_option(Globals, java_flags, JavaFlagsList),
    join_string_list(JavaFlagsList, "", "", " ", JAVAFLAGS),

    get_mercury_std_libs_for_java(Globals, MercuryStdLibs),
    globals.lookup_accumulating_option(Globals, java_classpath, UserClasspath),
    Java_Incl_Dirs = MercuryStdLibs ++ UserClasspath,
    % We prepend the current CLASSPATH (if any) to preserve the accumulating
    % nature of this variable.
    get_env_classpath(EnvClasspath, !IO),
    ( EnvClasspath = "" ->
        ClassPathList = Java_Incl_Dirs
    ;
        ClassPathList = [EnvClasspath | Java_Incl_Dirs]
    ),
    ClassPath = string.join_list(java_classpath_separator, ClassPathList),
    ( ClassPath = "" ->
        InclOpt = ""
    ;
        InclOpt = string.append_list([
            "-classpath ", quote_arg(ClassPath), " "])
    ),

    globals.lookup_bool_option(Globals, target_debug, Target_Debug),
    (
        Target_Debug = yes,
        Target_DebugOpt = "-g "
    ;
        Target_Debug = no,
        Target_DebugOpt = ""
    ),

    globals.lookup_bool_option(Globals, use_subdirs, UseSubdirs),
    globals.lookup_bool_option(Globals, use_grade_subdirs, UseGradeSubdirs),
    globals.lookup_string_option(Globals, fullarch, FullArch),
    (
        UseSubdirs = yes,
        (
            UseGradeSubdirs = yes,
            grade_directory_component(Globals, Grade),
            SourceDirName = "Mercury"/Grade/FullArch/"Mercury"/"javas",
            DestDirName = "Mercury"/Grade/FullArch/"Mercury"/"classs"
        ;
            UseGradeSubdirs = no,
            SourceDirName = "Mercury"/"javas",
            DestDirName = "Mercury"/"classs"
        ),
        % Javac won't create the destination directory for class files,
        % so we need to do it.
        dir.make_directory(DestDirName, _, !IO),
        % Set directories for source and class files.
        DirOpts = string.append_list([
            "-sourcepath ", SourceDirName, " ",
            "-d ", DestDirName, " "
        ])
    ;
        UseSubdirs = no,
        DirOpts = ""
    ),

    globals.lookup_string_option(Globals, filterjavac_command, MFilterJavac),
    ( MFilterJavac = "" ->
        MaybeMFilterJavac = no
    ;
        MaybeMFilterJavac = yes(MFilterJavac)
    ),

    % Be careful with the order here!  Some options may override others.
    % Also be careful that each option is separated by spaces.
    JoinedJavaFiles = string.join_list(" ", JavaFiles),
    string.append_list([InclOpt, DirOpts,
        Target_DebugOpt, JAVAFLAGS, " ", JoinedJavaFiles], CommandArgs),
    invoke_long_system_command_maybe_filter_output(Globals, ErrorStream,
        cmd_verbose_commands, JavaCompiler, CommandArgs, MaybeMFilterJavac,
        Succeeded, !IO).

:- func java_classpath_separator = string.

java_classpath_separator = PathSeparator :-
    (
        ( dir.use_windows_paths
        ; io.have_cygwin
        )
    ->
        PathSeparator = ";"
    ;
        PathSeparator = ":"
    ).

%-----------------------------------------------------------------------------%

assemble(ErrorStream, PIC, ModuleName, Globals, Succeeded, !IO) :-
    (
        PIC = pic,
        AsmExt = ".pic_s",
        GCCFLAGS_FOR_ASM = "-x assembler ",
        GCCFLAGS_FOR_PIC = "-fpic "
    ;
        PIC = link_with_pic,
        % `--target asm' doesn't support any grades for
        % which `.lpic_o' files are needed.
        unexpected($module, $pred, "link_with_pic")
    ;
        PIC = non_pic,
        AsmExt = ".s",
        GCCFLAGS_FOR_ASM = "",
        GCCFLAGS_FOR_PIC = ""
    ),
    module_name_to_file_name(Globals, ModuleName, AsmExt,
        do_not_create_dirs, AsmFile, !IO),
    maybe_pic_object_file_extension(Globals, PIC, ObjExt),
    module_name_to_file_name(Globals, ModuleName, ObjExt,
        do_create_dirs, ObjFile, !IO),

    globals.lookup_bool_option(Globals, verbose, Verbose),
    maybe_write_string(Verbose, "% Assembling `", !IO),
    maybe_write_string(Verbose, AsmFile, !IO),
    maybe_write_string(Verbose, "':\n", !IO),
    % XXX should we use new asm_* options rather than
    % reusing cc, cflags, c_flag_to_name_object_file?
    globals.lookup_string_option(Globals, cc, CC),
    globals.lookup_string_option(Globals, c_flag_to_name_object_file,
        NameObjectFile),
    globals.lookup_accumulating_option(Globals, cflags, C_Flags_List),
    join_string_list(C_Flags_List, "", "", " ", CFLAGS),
    % Be careful with the order here.
    % Also be careful that each option is separated by spaces.
    string.append_list([CC, " ", CFLAGS, " ", GCCFLAGS_FOR_PIC,
        GCCFLAGS_FOR_ASM, "-c ", AsmFile, " ", NameObjectFile, ObjFile],
        Command),
    invoke_system_command(Globals, ErrorStream, cmd_verbose_commands, Command,
        Succeeded, !IO).

%-----------------------------------------------------------------------------%

compile_erlang_file(ErrorStream, ErlangFile, Globals, Succeeded, !IO) :-
    globals.lookup_bool_option(Globals, verbose, Verbose),
    maybe_write_string(Verbose, "% Compiling `", !IO),
    maybe_write_string(Verbose, ErlangFile, !IO),
    maybe_write_string(Verbose, "':\n", !IO),
    globals.lookup_string_option(Globals, erlang_compiler, ErlangCompiler),
    globals.lookup_accumulating_option(Globals, erlang_flags,
        ErlangFlagsList0),
    globals.lookup_bool_option(Globals, erlang_native_code, ErlangNativeCode),
    globals.lookup_bool_option(Globals, erlang_inhibit_trivial_warnings,
        ErlangInhibitTrivialWarnings),
    (
        ErlangNativeCode = yes,
        ErlangFlagsList1 = ["+native" | ErlangFlagsList0]
    ;
        ErlangNativeCode = no,
        ErlangFlagsList1 = ErlangFlagsList0
    ),
    (
        ErlangInhibitTrivialWarnings = yes,
        ErlangFlagsList = ["+nowarn_unused_vars", "+nowarn_unused_function"
            | ErlangFlagsList1]
    ;
        ErlangInhibitTrivialWarnings = no,
        ErlangFlagsList = ErlangFlagsList1
    ),
    ERLANGFLAGS = string.join_list(" ", ErlangFlagsList),

    globals.lookup_accumulating_option(Globals, erlang_include_directory,
        Erlang_Incl_Dirs),
    InclOpt = string.append_list(list.condense(list.map(
        (func(E_INCL) = ["-I", quote_arg(E_INCL), " "]), Erlang_Incl_Dirs))),

    globals.lookup_bool_option(Globals, use_subdirs, UseSubdirs),
    globals.lookup_bool_option(Globals, use_grade_subdirs, UseGradeSubdirs),
    globals.lookup_string_option(Globals, fullarch, FullArch),
    (
        UseSubdirs = yes,
        (
            UseGradeSubdirs = yes,
            grade_directory_component(Globals, Grade),
            DirName = "Mercury"/Grade/FullArch/"Mercury"/"beams"
        ;
            UseGradeSubdirs = no,
            DirName = "Mercury"/"beams"
        ),
        % Create the destination directory.
        dir.make_directory(DirName, _, !IO),
        % Set destination directory for .beam files.
        DestDir = "-o " ++ DirName ++ " "
    ;
        UseSubdirs = no,
        DestDir = ""
    ),

    string.append_list([ErlangCompiler, " ", InclOpt, DestDir, ERLANGFLAGS,
        " ", ErlangFile], Command),
    invoke_system_command(Globals, ErrorStream, cmd_verbose_commands, Command,
        Succeeded, !IO).

%-----------------------------------------------------------------------------%

make_library_init_file(Globals, ErrorStream, MainModuleName, AllModules,
        Succeeded, !IO) :-
    globals.lookup_string_option(Globals, mkinit_command, MkInit),
    make_library_init_file_2(Globals, ErrorStream, MainModuleName, AllModules,
        ".c", MkInit, Succeeded, !IO).

make_erlang_library_init_file(Globals, ErrorStream, MainModuleName, AllModules,
        Succeeded, !IO) :-
    globals.lookup_string_option(Globals, mkinit_erl_command, MkInit),
    make_library_init_file_2(Globals, ErrorStream, MainModuleName, AllModules,
        ".erl", MkInit, Succeeded, !IO).

:- pred make_library_init_file_2(globals::in, io.output_stream::in,
    module_name::in, list(module_name)::in, string::in, string::in,
    bool::out, io::di, io::uo) is det.

make_library_init_file_2(Globals, ErrorStream, MainModuleName, AllModules,
        TargetExt, MkInit, Succeeded, !IO) :-
    module_name_to_file_name(Globals, MainModuleName, ".init.tmp",
        do_create_dirs, TmpInitFileName, !IO),
    io.open_output(TmpInitFileName, InitFileRes, !IO),
    (
        InitFileRes = ok(InitFileStream),
        list.map_foldl(
            module_name_to_file_name_ext(Globals, TargetExt,
                do_not_create_dirs),
            AllModules, AllTargetFilesList, !IO),

        invoke_mkinit(Globals, InitFileStream, cmd_verbose_commands,
            MkInit, " -k ", AllTargetFilesList, MkInitOK, !IO),

        (
            MkInitOK =  yes,
            globals.lookup_maybe_string_option(Globals, extra_init_command,
                MaybeInitFileCommand),
            (
                MaybeInitFileCommand = yes(InitFileCommand),
                make_all_module_command(Globals, InitFileCommand,
                    MainModuleName, AllModules, CommandString, !IO),
                invoke_system_command(Globals, InitFileStream,
                    cmd_verbose_commands, CommandString, Succeeded0, !IO)
            ;
                MaybeInitFileCommand = no,
                Succeeded0 = yes
            )
        ;
            MkInitOK   = no,
            Succeeded0 = no
        ),

        io.close_output(InitFileStream, !IO),
        module_name_to_file_name(Globals, MainModuleName, ".init",
            do_create_dirs, InitFileName, !IO),
        update_interface_return_succeeded(Globals, InitFileName, Succeeded1,
            !IO),
        Succeeded2 = Succeeded0 `and` Succeeded1,
        (
            Succeeded2 = yes,
            % Symlink or copy the .init files to the user's directory
            % if --use-grade-subdirs is enabled.
            globals.lookup_bool_option(Globals, use_grade_subdirs,
                UseGradeSubDirs),
            (
                UseGradeSubDirs = yes,
                io.set_output_stream(ErrorStream, OutputStream, !IO),
                globals.set_option(use_subdirs, bool(no),
                    Globals, NoSubdirGlobals0),
                globals.set_option(use_grade_subdirs, bool(no),
                    NoSubdirGlobals0, NoSubdirGlobals),
                module_name_to_file_name(NoSubdirGlobals, MainModuleName,
                    ".init", do_not_create_dirs, UserDirFileName, !IO),
                % Remove the target of the symlink/copy in case it already
                % exists.
                io.remove_file(UserDirFileName, _, !IO),
                make_symlink_or_copy_file(Globals, InitFileName,
                    UserDirFileName, Succeeded, !IO),
                io.set_output_stream(OutputStream, _, !IO)
            ;
                UseGradeSubDirs = no,
                Succeeded = yes
            )
        ;
            Succeeded2 = no,
            Succeeded  = no
        )
    ;
        InitFileRes = error(Error),
        io.progname_base("mercury_compile", ProgName, !IO),
        io.write_string(ErrorStream, ProgName, !IO),
        io.write_string(ErrorStream, ": can't open `", !IO),
        io.write_string(ErrorStream, TmpInitFileName, !IO),
        io.write_string(ErrorStream, "' for output:\n", !IO),
        io.nl(ErrorStream, !IO),
        io.write_string(ErrorStream, io.error_message(Error), !IO),
        io.nl(ErrorStream, !IO),
        Succeeded = no
    ).

:- pred module_name_to_file_name_ext(globals::in, string::in,
    maybe_create_dirs::in, module_name::in, file_name::out,
    io::di, io::uo) is det.

module_name_to_file_name_ext(Globals, Ext, MkDir, ModuleName, FileName, !IO) :-
    module_name_to_file_name(Globals, ModuleName, Ext, MkDir, FileName, !IO).

:- pred invoke_mkinit(globals::in, io.output_stream::in, command_verbosity::in,
    string::in, string::in, list(file_name)::in, bool::out,
    io::di, io::uo) is det.

invoke_mkinit(Globals, InitFileStream, Verbosity,
        MkInit, Args, FileNames, MkInitOK, !IO) :-
    % mkinit expects unquoted file names.
    join_string_list(FileNames, "", "\n", "", TargetFileNames),

    io.make_temp(TmpFile, !IO),
    io.open_output(TmpFile, OpenResult, !IO),
    (
        OpenResult = ok(TmpStream),
        io.write_string(TmpStream, TargetFileNames, !IO),
        io.close_output(TmpStream, !IO),

        MkInitCmd = string.append_list([MkInit, " ", Args, " -f ", TmpFile]),
        invoke_system_command(Globals, InitFileStream, Verbosity,
            MkInitCmd, MkInitOK0, !IO),

        io.remove_file(TmpFile, RemoveResult, !IO),
        (
            RemoveResult = ok,
            MkInitOK = MkInitOK0
        ;
            RemoveResult = error(_),
            MkInitOK = no
        )
    ;
        OpenResult = error(_),
        MkInitOK = no
    ).

%-----------------------------------------------------------------------------%

link_module_list(Modules, ExtraObjFiles, Globals, Succeeded, !IO) :-
    globals.lookup_string_option(Globals, output_file_name, OutputFileName0),
    ( OutputFileName0 = "" ->
        (
            Modules = [Module | _],
            OutputFileName = Module
        ;
            Modules = [],
            unexpected($module, $pred, "no modules")
        )
    ;
        OutputFileName = OutputFileName0
    ),

    file_name_to_module_name(OutputFileName, MainModuleName),

    globals.lookup_bool_option(Globals, compile_to_shared_lib,
        CompileToSharedLib),
    (
        CompileToSharedLib = yes,
        TargetType = shared_library
    ;
        CompileToSharedLib = no,
        TargetType = executable
    ),
    get_object_code_type(Globals, TargetType, PIC),
    maybe_pic_object_file_extension(Globals, PIC, Obj),

    io.output_stream(OutputStream, !IO),
    join_module_list(Globals, Modules, Obj, ObjectsList, !IO),
    (
        TargetType = executable,
        list.map(
            (pred(ModuleStr::in, ModuleName::out) is det :-
                file_name_to_module_name(dir.det_basename(ModuleStr),
                    ModuleName)
            ), Modules, ModuleNames),
        MustCompile = yes,
        do_make_init_obj_file(Globals, OutputStream, MustCompile,
            MainModuleName, ModuleNames, InitObjResult, !IO)
    ;
        TargetType = shared_library,
        InitObjResult = yes("")
    ),
    (
        InitObjResult = yes(InitObjFileName),
        globals.lookup_accumulating_option(Globals, link_objects,
            ExtraLinkObjectsList),
        AllObjects0 = ObjectsList ++ ExtraLinkObjectsList ++ ExtraObjFiles,
        ( InitObjFileName = "" ->
            AllObjects = AllObjects0
        ;
            AllObjects = [InitObjFileName | AllObjects0]
        ),
        link(OutputStream, TargetType, MainModuleName, AllObjects,
            Globals, Succeeded, !IO)
    ;
        InitObjResult = no,
        Succeeded = no
    ).

%-----------------------------------------------------------------------------%

make_init_obj_file(Globals, ErrorStream, ModuleName, ModuleNames, Result,
        !IO) :-
    globals.lookup_bool_option(Globals, rebuild, MustCompile),
    do_make_init_obj_file(Globals, ErrorStream, MustCompile, ModuleName,
        ModuleNames, Result, !IO).

% WARNING: The code here duplicates the functionality of scripts/c2init.in.
% Any changes there may also require changes here, and vice versa.
% The code of make_standalone_interface/3 may also require updating.

:- pred do_make_init_obj_file(globals::in, io.output_stream::in, bool::in,
    module_name::in, list(module_name)::in, maybe(file_name)::out,
    io::di, io::uo) is det.

do_make_init_obj_file(Globals, ErrorStream, MustCompile, ModuleName,
        ModuleNames, Result, !IO) :-
    globals.lookup_maybe_string_option(Globals,
        mercury_standard_library_directory, MaybeStdLibDir),
    grade_directory_component(Globals, GradeDir),
    (
        MaybeStdLibDir = yes(StdLibDir),
        ToGradeInit = (func(File) = StdLibDir / "modules" / GradeDir / File),
        StdInitFileNames = [
            ToGradeInit("mer_rt.init"),
            ToGradeInit("mer_std.init")
        ],
        StdTraceInitFileNames = [
            ToGradeInit("mer_browser.init"),
            ToGradeInit("mer_mdbcomp.init")
        ],
        SourceDebugInitFileNames = [
            ToGradeInit("mer_ssdb.init")
        ]
    ;
        MaybeStdLibDir = no,
        StdInitFileNames = [],
        StdTraceInitFileNames = [],
        SourceDebugInitFileNames = []
    ),

    globals.lookup_string_option(Globals, mkinit_command, MkInit),
    make_init_target_file(Globals, ErrorStream, MkInit, ModuleName,
        ModuleNames, ".c", StdInitFileNames, StdTraceInitFileNames,
        SourceDebugInitFileNames, "", MaybeInitTargetFile, !IO),

    get_object_code_type(Globals, executable, PIC),
    maybe_pic_object_file_extension(Globals, PIC, ObjExt),

    module_name_to_file_name(Globals, ModuleName, "_init" ++ ObjExt,
        do_create_dirs, InitObjFileName, !IO),
    CompileCInitFile =
        (pred(InitTargetFileName::in, Res::out, IO0::di, IO::uo) is det :-
            do_compile_c_file(ErrorStream, PIC, InitTargetFileName,
                InitObjFileName, Globals, Res, IO0, IO)
        ),
    maybe_compile_init_obj_file(Globals, MaybeInitTargetFile, MustCompile,
        CompileCInitFile, InitObjFileName, Result, !IO).

make_erlang_program_init_file(Globals, ErrorStream, ModuleName, ModuleNames,
        Result, !IO) :-
    globals.lookup_bool_option(Globals, rebuild, MustCompile),

    globals.lookup_maybe_string_option(Globals,
        mercury_standard_library_directory, MaybeStdLibDir),
    grade_directory_component(Globals, GradeDir),
    (
        MaybeStdLibDir = yes(StdLibDir),
        StdInitFileNames = [
            StdLibDir / "modules" / GradeDir / "mer_std.init"
        ],
        SourceDebugInitFileNames = [
            StdLibDir / "modules" / GradeDir / "mer_ssdb.init"
        ]
    ;
        MaybeStdLibDir = no,
        StdInitFileNames = [],
        SourceDebugInitFileNames = []
    ),
    % Tracing is not supported in Erlang backend.
    StdTraceInitFileNames = [],

    % We need to pass the module name to mkinit_erl.
    ErlangModuleName = qualify_mercury_std_library_module_name(ModuleName),
    ModuleNameStr = sym_name_to_string_sep(ErlangModuleName, "__") ++ "_init",
    ModuleNameOption = " -m " ++ quote_arg(ModuleNameStr),

    globals.lookup_string_option(Globals, mkinit_erl_command, MkInitErl),
    make_init_target_file(Globals, ErrorStream, MkInitErl, ModuleName,
        ModuleNames, ".erl", StdInitFileNames, StdTraceInitFileNames,
        SourceDebugInitFileNames, ModuleNameOption, MaybeInitTargetFile, !IO),

    module_name_to_file_name(Globals, ModuleName, "_init.beam",
        do_create_dirs, InitObjFileName, !IO),
    CompileErlangInitFile =
        (pred(InitTargetFileName::in, Res::out, IO0::di, IO::uo) is det :-
            compile_erlang_file(ErrorStream, InitTargetFileName, Globals, Res,
                IO0, IO)
        ),
    maybe_compile_init_obj_file(Globals, MaybeInitTargetFile, MustCompile,
        CompileErlangInitFile, InitObjFileName, Result, !IO).

:- pred make_init_target_file(globals::in, io.output_stream::in, string::in,
    module_name::in, list(module_name)::in, string::in,
    list(file_name)::in, list(file_name)::in, list(file_name)::in,
    string::in, maybe(file_name)::out, io::di, io::uo) is det.

make_init_target_file(Globals, ErrorStream, MkInit, ModuleName, ModuleNames,
        TargetExt, StdInitFileNames, StdTraceInitFileNames,
        SourceDebugInitFileNames, ModuleNameOption, MaybeInitTargetFile,
        !IO) :-
    globals.lookup_bool_option(Globals, verbose, Verbose),
    globals.lookup_bool_option(Globals, statistics, Stats),
    maybe_write_string(Verbose, "% Creating initialization file...\n", !IO),

    compute_grade(Globals, Grade),

    module_name_to_file_name(Globals, ModuleName, "_init" ++ TargetExt,
        do_create_dirs, InitTargetFileName, !IO),

    list.map_foldl(
        module_name_to_file_name_ext(Globals, TargetExt, do_not_create_dirs),
        ModuleNames, TargetFileNameList, !IO),

    globals.lookup_accumulating_option(Globals, init_file_directories,
        InitFileDirsList),
    join_quoted_string_list(InitFileDirsList, "-I ", "", " ", InitFileDirs),

    globals.lookup_accumulating_option(Globals, init_files,
        InitFileNamesList0),
    % If we pass the same .init file to mkinit multiple times we will end
    % up with multiple calls to the functions that write out proc statics
    % in deep profiling grades. This will cause the runtime code that writes
    % out the profile to abort.
    list.remove_dups(InitFileNamesList0, InitFileNamesList1),

    globals.lookup_accumulating_option(Globals, trace_init_files,
        TraceInitFileNamesList0),
    InitFileNamesList2 = StdInitFileNames ++ InitFileNamesList1,
    TraceInitFileNamesList = StdTraceInitFileNames ++ TraceInitFileNamesList0,

    globals.get_trace_level(Globals, TraceLevel),
    ( given_trace_level_is_none(TraceLevel) = no ->
        TraceOpt = "-t",
        InitFileNamesList3 = InitFileNamesList2 ++ TraceInitFileNamesList
    ;
        TraceOpt = "",
        InitFileNamesList3 = InitFileNamesList2
    ),

    globals.lookup_bool_option(Globals, link_ssdb_libs, SourceDebug),
    (
        SourceDebug = yes,
        InitFileNamesList = InitFileNamesList3 ++ SourceDebugInitFileNames
    ;
        SourceDebug = no,
        InitFileNamesList = InitFileNamesList3
    ),

    globals.lookup_accumulating_option(Globals, runtime_flags,
        RuntimeFlagsList),
    join_quoted_string_list(RuntimeFlagsList, "-r ", "", " ", RuntimeFlags),

    globals.lookup_bool_option(Globals, extra_initialization_functions,
        ExtraInits),
    (
        ExtraInits = yes,
        ExtraInitsOpt = "-x"
    ;
        ExtraInits = no,
        ExtraInitsOpt = ""
    ),

    globals.lookup_bool_option(Globals, main, Main),
    (
        Main = no,
        NoMainOpt = "-l"
    ;
        Main = yes,
        NoMainOpt = ""
    ),

    globals.lookup_string_option(Globals, experimental_complexity,
        ExperimentalComplexity),
    ( ExperimentalComplexity = "" ->
        ExperimentalComplexityOpt = ""
    ;
        ExperimentalComplexityOpt = "-X " ++ ExperimentalComplexity
    ),

    TmpInitTargetFileName = InitTargetFileName ++ ".tmp",
    MkInitArgs = string.append_list(
        [   " -g ", Grade,
            " ", TraceOpt,
            " ", ExtraInitsOpt,
            " ", NoMainOpt,
            " ", ExperimentalComplexityOpt,
            " ", RuntimeFlags,
            " -o ", quote_arg(TmpInitTargetFileName),
            " ", InitFileDirs,
            ModuleNameOption
        ]),

    invoke_mkinit(Globals, ErrorStream, cmd_verbose_commands,
        MkInit, MkInitArgs, TargetFileNameList ++ InitFileNamesList,
        MkInitOk, !IO),

    maybe_report_stats(Stats, !IO),
    (
        MkInitOk = yes,
        update_interface_return_succeeded(Globals, InitTargetFileName,
            UpdateOk, !IO),
        (
            UpdateOk = yes,
            MaybeInitTargetFile = yes(InitTargetFileName)
        ;
            UpdateOk = no,
            MaybeInitTargetFile = no
        )
    ;
        MkInitOk = no,
        MaybeInitTargetFile = no
    ).

:- pred maybe_compile_init_obj_file(globals::in, maybe(file_name)::in,
    bool::in, compile_init_file_pred::in(compile_init_file_pred),
    file_name::in, maybe(file_name)::out, io::di, io::uo) is det.

:- type compile_init_file_pred == pred(file_name, bool, io, io).
:- inst compile_init_file_pred == (pred(in, out, di, uo) is det).

maybe_compile_init_obj_file(Globals, MaybeInitTargetFile, MustCompile, Compile,
        InitObjFileName, Result, !IO) :-
    globals.lookup_bool_option(Globals, verbose, Verbose),
    globals.lookup_bool_option(Globals, statistics, Stats),
    (
        MaybeInitTargetFile = yes(InitTargetFileName),
        file_as_new_as(InitObjFileName, Rel, InitTargetFileName, !IO),
        (
            ( MustCompile = yes
            ; Rel = is_not_as_new_as
            ; Rel = missing_timestamp
            )
        ->
            maybe_write_string(Verbose,
                "% Compiling initialization file...\n", !IO),
            Compile(InitTargetFileName, CompileOk, !IO),
            maybe_report_stats(Stats, !IO),
            (
                CompileOk = yes,
                Result = yes(InitObjFileName)
            ;
                CompileOk = no,
                Result = no
            )
        ;
            Result = yes(InitObjFileName)
        )
    ;
        MaybeInitTargetFile = no,
        Result = no
    ).

    % file_as_new_as(FileNameA, Rel, FileNameB, !IO)
    %
    % Check if file A has a timestamp at least as new as the timestamp of
    % file B. Rel is `missing_timestamp' iff either timestamp could not
    % be retrieved.
    %
:- pred file_as_new_as(file_name::in, is_as_new_as::out, file_name::in,
    io::di, io::uo) is det.

:- type is_as_new_as
    --->    is_as_new_as
    ;       is_not_as_new_as
    ;       missing_timestamp.

file_as_new_as(FileNameA, Rel, FileNameB, !IO) :-
    compare_file_timestamps(FileNameA, FileNameB, MaybeCompare, !IO),
    (
        ( MaybeCompare = yes(=)
        ; MaybeCompare = yes(>)
        ),
        Rel = is_as_new_as
    ;
        MaybeCompare = yes(<),
        Rel = is_not_as_new_as
    ;
        MaybeCompare = no,
        Rel = missing_timestamp
    ).

:- pred compare_file_timestamps(file_name::in, file_name::in,
    maybe(comparison_result)::out, io::di, io::uo) is det.

compare_file_timestamps(FileNameA, FileNameB, MaybeCompare, !IO) :-
    io.file_modification_time(FileNameA, TimeResultA, !IO),
    io.file_modification_time(FileNameB, TimeResultB, !IO),
    (
        TimeResultA = ok(TimeA),
        TimeResultB = ok(TimeB)
    ->
        compare(Compare, TimeA, TimeB),
        MaybeCompare = yes(Compare)
    ;
        MaybeCompare = no
    ).

%-----------------------------------------------------------------------------%

% WARNING: The code here duplicates the functionality of scripts/ml.in.
% Any changes there may also require changes here, and vice versa.

link(ErrorStream, LinkTargetType, ModuleName, ObjectsList, Globals, Succeeded,
        !IO) :-
    globals.lookup_bool_option(Globals, verbose, Verbose),
    globals.lookup_bool_option(Globals, statistics, Stats),

    maybe_write_string(Verbose, "% Linking...\n", !IO),
    link_output_filename(Globals, LinkTargetType, ModuleName, _Ext,
        OutputFileName, !IO),
    (
        LinkTargetType = executable,
        link_exe_or_shared_lib(Globals, ErrorStream, LinkTargetType,
            ModuleName, OutputFileName, ObjectsList, LinkSucceeded, !IO)
    ;
        LinkTargetType = static_library,
        create_archive(Globals, ErrorStream, OutputFileName, yes, ObjectsList,
            LinkSucceeded, !IO)
    ;
        LinkTargetType = shared_library,
        link_exe_or_shared_lib(Globals, ErrorStream, LinkTargetType,
            ModuleName, OutputFileName, ObjectsList, LinkSucceeded, !IO)
    ;
        ( LinkTargetType = csharp_executable
        ; LinkTargetType = csharp_library
        ),
        % XXX C# see also older predicate compile_csharp_file
        create_csharp_exe_or_lib(Globals, ErrorStream, LinkTargetType,
            ModuleName, OutputFileName, ObjectsList, LinkSucceeded, !IO)
    ;
        LinkTargetType = java_launcher,
        create_java_shell_script(Globals, ModuleName, LinkSucceeded, !IO)
    ;
        LinkTargetType = java_archive,
        create_java_archive(Globals, ErrorStream, OutputFileName, ObjectsList,
            LinkSucceeded, !IO)
    ;
        LinkTargetType = erlang_launcher,
        create_erlang_shell_script(Globals, ModuleName, LinkSucceeded, !IO)
    ;
        LinkTargetType = erlang_archive,
        create_erlang_archive(Globals, ErrorStream, ModuleName, OutputFileName,
            ObjectsList, LinkSucceeded, !IO)
    ),
    maybe_report_stats(Stats, !IO),
    (
        LinkSucceeded = yes,
        post_link_make_symlink_or_copy(ErrorStream, LinkTargetType,
            ModuleName, Globals, Succeeded, _MadeSymlinkOrCopy, !IO)
    ;
        LinkSucceeded = no,
        Succeeded = no
    ).

:- pred link_output_filename(globals::in, linked_target_type::in,
    module_name::in, string::out, string::out, io::di, io::uo) is det.

link_output_filename(Globals, LinkTargetType, ModuleName, Ext, OutputFileName,
        !IO) :-
    (
        LinkTargetType = executable,
        globals.lookup_string_option(Globals, executable_file_extension, Ext),
        module_name_to_file_name(Globals, ModuleName, Ext, do_create_dirs,
            OutputFileName, !IO)
    ;
        LinkTargetType = static_library,
        globals.lookup_string_option(Globals, library_extension, Ext),
        module_name_to_lib_file_name(Globals, "lib", ModuleName, Ext,
            do_create_dirs, OutputFileName, !IO)
    ;
        LinkTargetType = shared_library,
        globals.lookup_string_option(Globals, shared_library_extension, Ext),
        module_name_to_lib_file_name(Globals, "lib", ModuleName, Ext,
            do_create_dirs, OutputFileName, !IO)
    ;
        LinkTargetType = csharp_executable,
        Ext = ".exe",
        module_name_to_file_name(Globals, ModuleName, Ext,
            do_create_dirs, OutputFileName, !IO)
    ;
        LinkTargetType = csharp_library,
        Ext = ".dll",
        module_name_to_file_name(Globals, ModuleName, Ext,
            do_create_dirs, OutputFileName, !IO)
    ;
        ( LinkTargetType = java_launcher
        ; LinkTargetType = erlang_launcher
        ),
        % These may be shell scripts or batch files.
        globals.get_target_env_type(Globals, TargetEnvType),
        (
            % XXX we should actually generate a .ps1 file for PowerShell.
            ( TargetEnvType = env_type_win_cmd
            ; TargetEnvType = env_type_powershell
            ),
            Ext = ".bat"
        ;
            ( TargetEnvType = env_type_posix
            ; TargetEnvType = env_type_cygwin
            ; TargetEnvType = env_type_msys
            ),
            Ext = ""
        ),
        module_name_to_file_name(Globals, ModuleName, Ext,
            do_create_dirs, OutputFileName, !IO)
    ;
        LinkTargetType = java_archive,
        Ext = ".jar",
        module_name_to_file_name(Globals, ModuleName, Ext,
            do_create_dirs, OutputFileName, !IO)
    ;
        LinkTargetType = erlang_archive,
        Ext = ".beams",
        module_name_to_lib_file_name(Globals, "lib", ModuleName, Ext,
            do_create_dirs, OutputFileName, !IO)
    ).

:- pred link_exe_or_shared_lib(globals::in, io.output_stream::in,
    linked_target_type::in(bound(executable ; shared_library)),
    module_name::in, file_name::in, list(string)::in, bool::out,
    io::di, io::uo) is det.

link_exe_or_shared_lib(Globals, ErrorStream, LinkTargetType, ModuleName,
        OutputFileName, ObjectsList, LinkSucceeded, !IO) :-
    (
        LinkTargetType = shared_library,
        CommandOpt = link_shared_lib_command,
        RpathFlagOpt = shlib_linker_rpath_flag,
        RpathSepOpt = shlib_linker_rpath_separator,
        LDFlagsOpt = ld_libflags,
        ThreadFlagsOpt = shlib_linker_thread_flags,
        DebugFlagsOpt = shlib_linker_debug_flags,
        TraceFlagsOpt = shlib_linker_trace_flags,
        globals.lookup_bool_option(Globals, allow_undefined, AllowUndef),
        (
            AllowUndef = yes,
            globals.lookup_string_option(Globals, linker_allow_undefined_flag,
                UndefOpt)
        ;
            AllowUndef = no,
            globals.lookup_string_option(Globals,
                linker_error_undefined_flag, UndefOpt)
        ),
        ReserveStackSizeOpt = ""
    ;
        LinkTargetType = executable,
        CommandOpt = link_executable_command,
        RpathFlagOpt = linker_rpath_flag,
        RpathSepOpt = linker_rpath_separator,
        LDFlagsOpt = ld_flags,
        ThreadFlagsOpt = linker_thread_flags,
        DebugFlagsOpt = linker_debug_flags,
        TraceFlagsOpt = linker_trace_flags,
        UndefOpt = "",
        ReserveStackSizeOpt = reserve_stack_size_flags(Globals)
    ),

    % Should the executable be stripped?
    globals.lookup_bool_option(Globals, strip, Strip),
    (
        LinkTargetType = executable,
        Strip = yes
    ->
        globals.lookup_string_option(Globals, linker_strip_flag, StripOpt)
    ;
        StripOpt = ""
    ),

    globals.lookup_bool_option(Globals, target_debug, TargetDebug),
    (
        TargetDebug = yes,
        globals.lookup_string_option(Globals, DebugFlagsOpt, DebugOpts)
    ;
        TargetDebug = no,
        DebugOpts = ""
    ),

    % Should the executable be statically linked?
    globals.lookup_string_option(Globals, linkage, Linkage),
    (
        LinkTargetType = executable,
        Linkage = "static"
    ->
        globals.lookup_string_option(Globals, linker_static_flags, StaticOpts)
    ;
        StaticOpts = ""
    ),

    % Are the thread libraries needed?
    use_thread_libs(Globals, UseThreadLibs),
    (
        UseThreadLibs = yes,
        globals.lookup_string_option(Globals, ThreadFlagsOpt, ThreadOpts),

        % Determine which options are needed to link to libhwloc, if libhwloc
        % is used at all.
        globals.lookup_bool_option(Globals, highlevel_code, HighLevelCode),
        (
            HighLevelCode = yes,
            HwlocOpts = ""
        ;
            HighLevelCode = no,
            ( Linkage = "shared" ->
                HwlocFlagsOpt = hwloc_libs
            ; Linkage = "static" ->
                HwlocFlagsOpt = hwloc_static_libs
            ;
                unexpected($module, $pred, "Invalid linkage")
            ),
            globals.lookup_string_option(Globals, HwlocFlagsOpt, HwlocOpts)
        )
    ;
        UseThreadLibs = no,
        ThreadOpts = "",
        HwlocOpts = ""
    ),

    % Find the Mercury standard libraries.
    get_mercury_std_libs(Globals, LinkTargetType, MercuryStdLibs),

    % Find which system libraries are needed.
    get_system_libs(Globals, LinkTargetType, SystemLibs),

    % With --restricted-command-line we may need to some additional
    % options to the linker.
    % (See the comment above get_restricted_command_lin_link_opts/3 for
    % details.)
    get_restricted_command_line_link_opts(Globals, LinkTargetType,
        ResCmdLinkOpts),

    globals.lookup_accumulating_option(Globals, LDFlagsOpt, LDFlagsList),
    join_string_list(LDFlagsList, "", "", " ", LDFlags),
    globals.lookup_accumulating_option(Globals, link_library_directories,
        LinkLibraryDirectoriesList),
    globals.lookup_string_option(Globals, linker_path_flag, LinkerPathFlag),
    join_quoted_string_list(LinkLibraryDirectoriesList, LinkerPathFlag, "",
        " ", LinkLibraryDirectories),

    % Set up the runtime library path.
    get_runtime_library_path_opts(Globals, LinkTargetType,
        RpathFlagOpt, RpathSepOpt, RpathOpts),

    % Set up any framework search paths.
    get_framework_directories(Globals, FrameworkDirectories),

    % Set up the install name for shared libraries.
    globals.lookup_bool_option(Globals, shlib_linker_use_install_name,
        UseInstallName),
    (
        UseInstallName = yes,
        LinkTargetType = shared_library
    ->
        % NOTE: `ShLibFileName' must *not* be prefixed with a directory.
        %       get_install_name_option will prefix it with the correct
        %       directory which is the one where the library is going to
        %       be installed, *not* where it is going to be built.
        %
        BaseFileName = sym_name_to_string(ModuleName),
        globals.lookup_string_option(Globals, shared_library_extension,
            SharedLibExt),
        ShLibFileName = "lib" ++ BaseFileName ++ SharedLibExt,
        get_install_name_option(Globals, ShLibFileName, InstallNameOpt)
    ;
        InstallNameOpt = ""
    ),

    globals.get_trace_level(Globals, TraceLevel),
    ( given_trace_level_is_none(TraceLevel) = yes ->
        TraceOpts = ""
    ;
        globals.lookup_string_option(Globals, TraceFlagsOpt, TraceOpts)
    ),

    get_frameworks(Globals, Frameworks),
    get_link_libraries(Globals, MaybeLinkLibraries, !IO),
    globals.lookup_string_option(Globals, linker_opt_separator, LinkOptSep),
    (
        MaybeLinkLibraries = yes(LinkLibrariesList),
        join_quoted_string_list(LinkLibrariesList, "", "", " ",
            LinkLibraries),

        globals.lookup_bool_option(Globals, restricted_command_line,
            RestrictedCommandLine),
        (
            % If we have a restricted command line then it's possible
            % that following link command will call sub-commands itself
            % and thus overflow the command line, so in this case
            % we first create an archive of all of the object files.
            %
            RestrictedCommandLine = yes,
            io.make_temp(TmpFile, !IO),
            globals.lookup_string_option(Globals, library_extension, LibExt),
            TmpArchive = TmpFile ++ LibExt,
            create_archive(Globals, ErrorStream, TmpArchive, yes, ObjectsList,
                ArchiveSucceeded, !IO),
            MaybeDeleteTmpArchive = yes(TmpArchive),
            Objects = TmpArchive
        ;
            RestrictedCommandLine = no,
            ArchiveSucceeded = yes,
            MaybeDeleteTmpArchive = no,
            join_quoted_string_list(ObjectsList, "", "", " ", Objects)
        ),

        (
            ArchiveSucceeded = yes,

            % Note that LDFlags may contain `-l' options so it should come
            % after Objects.
            globals.lookup_string_option(Globals, CommandOpt, Command),
            get_linker_output_option(Globals, LinkTargetType, OutputOpt),
            string.append_list([
                    Command, " ",
                    StaticOpts, " ",
                    StripOpt, " ",
                    UndefOpt, " ",
                    ThreadOpts, " ",
                    TraceOpts, " ",
                    ReserveStackSizeOpt, " ",
                    OutputOpt, quote_arg(OutputFileName), " ",
                    Objects, " ",
                    LinkOptSep, " ",
                    LinkLibraryDirectories, " ",
                    RpathOpts, " ",
                    FrameworkDirectories, " ",
                    InstallNameOpt, " ",
                    DebugOpts, " ",
                    Frameworks, " ",
                    ResCmdLinkOpts, " ",
                    LDFlags, " ",
                    LinkLibraries, " ",
                    MercuryStdLibs, " ",
                    HwlocOpts, " ",
                    SystemLibs], LinkCmd),

            globals.lookup_bool_option(Globals, demangle, Demangle),
            (
                Demangle = yes,
                globals.lookup_string_option(Globals, demangle_command,
                    DemangleCmd),
                MaybeDemangleCmd = yes(DemangleCmd)
            ;
                Demangle = no,
                MaybeDemangleCmd = no
            ),

            invoke_system_command_maybe_filter_output(Globals, ErrorStream,
                cmd_verbose_commands, LinkCmd, MaybeDemangleCmd,
                LinkSucceeded, !IO)
        ;
            ArchiveSucceeded = no,
            LinkSucceeded = no
        ),
        (
            MaybeDeleteTmpArchive = yes(FileToDelete),
            io.remove_file(FileToDelete, _, !IO)
        ;
            MaybeDeleteTmpArchive = no
        )
    ;
        MaybeLinkLibraries = no,
        LinkSucceeded = no
    ).

    % Find the standard Mercury libraries, and the system
    % libraries needed by them.
    % Return the empty string if --mercury-standard-library-directory
    % is not set.
    % NOTE: changes here may require changes to get_mercury_std_libs_for_java.
    %
:- pred get_mercury_std_libs(globals::in, linked_target_type::in, string::out)
    is det.

get_mercury_std_libs(Globals, TargetType, StdLibs) :-
    globals.lookup_maybe_string_option(Globals,
        mercury_standard_library_directory, MaybeStdlibDir),
    (
        MaybeStdlibDir = yes(StdLibDir),
        globals.get_gc_method(Globals, GCMethod),
        (
            ( TargetType = executable
            ; TargetType = static_library
            ; TargetType = shared_library
            ),
            globals.lookup_string_option(Globals, library_extension, LibExt),
            globals.lookup_string_option(Globals, mercury_linkage,
                MercuryLinkage)
        ;
            ( TargetType = csharp_executable
            ; TargetType = csharp_library
            ),
            LibExt = ".dll",
            MercuryLinkage = "csharp"
        ;
            ( TargetType = java_launcher
            ; TargetType = java_archive
            ; TargetType = erlang_launcher
            ; TargetType = erlang_archive
            ),
            unexpected($module, $pred, string(TargetType))
        ),
        grade_directory_component(Globals, GradeDir),

        % GC libraries.
        % We always compile with hgc since it's home-grown and very small.
        (
            GCMethod = gc_automatic,
            StaticGCLibs = "",
            SharedGCLibs = ""
        ;
            GCMethod = gc_none,
            StaticGCLibs = "",
            SharedGCLibs = ""
        ;
            GCMethod = gc_hgc,
            StaticGCLibs = "",
            SharedGCLibs = ""
        ;
            (
                GCMethod = gc_boehm,
                GCGrade0 = "gc"
            ;
                GCMethod = gc_boehm_debug,
                GCGrade0 = "gc_debug"
            ),
            globals.lookup_bool_option(Globals, low_level_debug, LLDebug),
            (
                LLDebug = yes,
                GCGrade1 = GCGrade0 ++ "_ll_debug"
            ;
                LLDebug = no,
                GCGrade1 = GCGrade0
            ),
            globals.lookup_bool_option(Globals, profile_time, ProfTime),
            globals.lookup_bool_option(Globals, profile_deep, ProfDeep),
            (
                ( ProfTime = yes
                ; ProfDeep = yes
                )
            ->
                GCGrade2 = GCGrade1 ++ "_prof"
            ;
                GCGrade2 = GCGrade1
            ),
            globals.lookup_bool_option(Globals, parallel, Parallel),
            (
                Parallel = yes,
                GCGrade = "par_" ++ GCGrade2
            ;
                Parallel = no,
                GCGrade = GCGrade2
            ),
            link_lib_args(Globals, TargetType, StdLibDir, "", LibExt,
                GCGrade, StaticGCLibs, SharedGCLibs)
        ;
            GCMethod = gc_mps,
            link_lib_args(Globals, TargetType, StdLibDir, "", LibExt,
                "mps", StaticGCLibs, SharedGCLibs)
        ;
            GCMethod = gc_accurate,
            StaticGCLibs = "",
            SharedGCLibs = ""
        ),

        % Trace libraries.
        globals.get_trace_level(Globals, TraceLevel),
        ( given_trace_level_is_none(TraceLevel) = yes ->
            StaticTraceLibs = "",
            SharedTraceLibs = ""
        ;
            link_lib_args(Globals, TargetType, StdLibDir, GradeDir, LibExt,
                "mer_trace", StaticTraceLib, TraceLib),
            link_lib_args(Globals, TargetType, StdLibDir, GradeDir, LibExt,
                "mer_eventspec", StaticEventSpecLib, EventSpecLib),
            link_lib_args(Globals, TargetType, StdLibDir, GradeDir, LibExt,
                "mer_browser", StaticBrowserLib, BrowserLib),
            link_lib_args(Globals, TargetType, StdLibDir, GradeDir, LibExt,
                "mer_mdbcomp", StaticMdbCompLib, MdbCompLib),
            StaticTraceLibs = string.join_list(" ",
                [StaticTraceLib, StaticEventSpecLib, StaticBrowserLib,
                StaticMdbCompLib]),
            SharedTraceLibs = string.join_list(" ",
                [TraceLib, EventSpecLib, BrowserLib, MdbCompLib])
        ),

        % Source-to-source debugging libraries.
        globals.lookup_bool_option(Globals, link_ssdb_libs, SourceDebug),
        (
            SourceDebug = yes,
            link_lib_args(Globals, TargetType, StdLibDir, GradeDir, LibExt,
                "mer_ssdb", StaticSsdbLib, SsdbLib),
            link_lib_args(Globals, TargetType, StdLibDir, GradeDir, LibExt,
                "mer_browser", StaticBrowserLib2, BrowserLib2),
            link_lib_args(Globals, TargetType, StdLibDir, GradeDir, LibExt,
                "mer_mdbcomp", StaticMdbCompLib2, MdbCompLib2),
            StaticSourceDebugLibs = string.join_list(" ",
                [StaticSsdbLib, StaticBrowserLib2, StaticMdbCompLib2]),
            SharedSourceDebugLibs = string.join_list(" ",
                [SsdbLib, BrowserLib2, MdbCompLib2])
        ;
            SourceDebug = no,
            StaticSourceDebugLibs = "",
            SharedSourceDebugLibs = ""
        ),

        link_lib_args(Globals, TargetType, StdLibDir, GradeDir, LibExt,
            "mer_std", StaticStdLib, StdLib),
        link_lib_args(Globals, TargetType, StdLibDir, GradeDir, LibExt,
            "mer_rt", StaticRuntimeLib, RuntimeLib),
        ( MercuryLinkage = "static" ->
            StdLibs = string.join_list(" ", [
                StaticTraceLibs,
                StaticSourceDebugLibs,
                StaticStdLib,
                StaticRuntimeLib,
                StaticGCLibs
            ])
        ; MercuryLinkage = "shared" ->
            StdLibs = string.join_list(" ", [
                SharedTraceLibs,
                SharedSourceDebugLibs,
                StdLib,
                RuntimeLib,
                SharedGCLibs
            ])
        ; MercuryLinkage = "csharp" ->
            StdLibs = string.join_list(" ", [
                SharedTraceLibs,
                SharedSourceDebugLibs,
                StdLib
            ])
        ;
            unexpected($module, $pred, "unknown linkage " ++ MercuryLinkage)
        )
    ;
        MaybeStdlibDir = no,
        StdLibs = ""
    ).

:- pred link_lib_args(globals::in, linked_target_type::in, string::in,
    string::in, string::in, string::in, string::out, string::out) is det.

link_lib_args(Globals, TargetType, StdLibDir, GradeDir, LibExt, Name,
        StaticArg, SharedArg) :-
    (
        ( TargetType = executable
        ; TargetType = shared_library
        ; TargetType = static_library
        ),
        LibPrefix = "lib"
    ;
        ( TargetType = csharp_executable
        ; TargetType = csharp_library
        ),
        LibPrefix = ""
    ;
        ( TargetType = java_launcher
        ; TargetType = java_archive
        ; TargetType = erlang_launcher
        ; TargetType = erlang_archive
        ),
        unexpected($module, $pred, string(TargetType))
    ),
    StaticLibName = LibPrefix ++ Name ++ LibExt,
    StaticArg = quote_arg(StdLibDir/"lib"/GradeDir/StaticLibName),
    make_link_lib(Globals, TargetType, Name, SharedArg).

    % Pass either `-llib' or `PREFIX/lib/GRADE/liblib.a', depending on
    % whether we are linking with static or shared Mercury libraries.
    %
:- pred get_link_libraries(globals::in, maybe(list(string))::out,
    io::di, io::uo) is det.

get_link_libraries(Globals, MaybeLinkLibraries, !IO) :-
    globals.lookup_accumulating_option(Globals, mercury_library_directories,
        MercuryLibDirs0),
    grade_directory_component(Globals, GradeDir),
    MercuryLibDirs = list.map((func(LibDir) = LibDir/"lib"/GradeDir),
        MercuryLibDirs0),
    globals.lookup_accumulating_option(Globals, link_libraries,
        LinkLibrariesList0),
    list.map_foldl2(process_link_library(Globals, MercuryLibDirs),
        LinkLibrariesList0, LinkLibrariesList, yes,
        LibrariesSucceeded, !IO),
    (
        LibrariesSucceeded = yes,
        MaybeLinkLibraries = yes(LinkLibrariesList)
    ;
        LibrariesSucceeded = no,
        MaybeLinkLibraries = no
    ).

:- pred make_link_lib(globals::in, linked_target_type::in,
    string::in, string::out) is det.

make_link_lib(Globals, TargetType, LibName, LinkOpt) :-
    (
        (
            TargetType = executable,
            LinkLibFlag = linker_link_lib_flag,
            LinkLibSuffix = linker_link_lib_suffix
        ;
            TargetType = shared_library,
            LinkLibFlag = shlib_linker_link_lib_flag,
            LinkLibSuffix = shlib_linker_link_lib_suffix
        ),
        globals.lookup_string_option(Globals, LinkLibFlag, LinkLibOpt),
        globals.lookup_string_option(Globals, LinkLibSuffix, Suffix),
        LinkOpt = quote_arg(LinkLibOpt ++ LibName ++ Suffix)
    ;
        ( TargetType = csharp_executable
        ; TargetType = csharp_library
        ),
        LinkLibOpt = "-r:",
        Suffix = ".dll",
        LinkOpt = quote_arg(LinkLibOpt ++ LibName ++ Suffix)
    ;
        ( TargetType = static_library
        ; TargetType = java_launcher
        ; TargetType = java_archive
        ; TargetType = erlang_launcher
        ; TargetType = erlang_archive
        ),
        unexpected($module, $pred, string(TargetType))
    ).

:- pred get_runtime_library_path_opts(globals::in, linked_target_type::in,
    option::in(bound(shlib_linker_rpath_flag ; linker_rpath_flag)),
    option::in(bound(shlib_linker_rpath_separator ; linker_rpath_separator)),
    string::out) is det.

get_runtime_library_path_opts(Globals, LinkTargetType,
        RpathFlagOpt, RpathSepOpt, RpathOpts) :-
    globals.lookup_bool_option(Globals, shlib_linker_use_install_name,
        UseInstallName),
    shared_libraries_supported(Globals, SharedLibsSupported),
    globals.lookup_string_option(Globals, linkage, Linkage),
    (
        UseInstallName = no,
        SharedLibsSupported = yes,
        ( Linkage = "shared"
        ; LinkTargetType = shared_library
        )
    ->
        globals.lookup_accumulating_option(Globals,
            runtime_link_library_directories, RpathDirs0),
        RpathDirs = list.map(quote_arg, RpathDirs0),
        (
            RpathDirs = [],
            RpathOpts = ""
        ;
            RpathDirs = [_ | _],
            globals.lookup_string_option(Globals, RpathSepOpt, RpathSep),
            globals.lookup_string_option(Globals, RpathFlagOpt, RpathFlag),
            RpathOpts0 = string.join_list(RpathSep, RpathDirs),
            RpathOpts = RpathFlag ++ RpathOpts0
        )
    ;
        RpathOpts = ""
    ).

:- pred get_system_libs(globals::in, linked_target_type::in, string::out)
    is det.

get_system_libs(Globals, TargetType, SystemLibs) :-
    % System libraries used when tracing.
    globals.get_trace_level(Globals, TraceLevel),
    ( given_trace_level_is_none(TraceLevel) = yes ->
        SystemTraceLibs = ""
    ;
        globals.lookup_string_option(Globals, trace_libs, SystemTraceLibs0),
        globals.lookup_bool_option(Globals, use_readline, UseReadline),
        (
            UseReadline = yes,
            globals.lookup_string_option(Globals, readline_libs, ReadlineLibs),
            SystemTraceLibs = SystemTraceLibs0 ++ " " ++ ReadlineLibs
        ;
            UseReadline = no,
            SystemTraceLibs = SystemTraceLibs0
        )
    ),

    % Thread libraries
    use_thread_libs(Globals, UseThreadLibs),
    (
        UseThreadLibs = yes,
        globals.lookup_string_option(Globals, thread_libs, ThreadLibs)
    ;
        UseThreadLibs = no,
        ThreadLibs = ""
    ),

    % Other system libraries.
    (
        TargetType = shared_library,
        globals.lookup_string_option(Globals, shared_libs, OtherSystemLibs)
    ;
        TargetType = executable,
        globals.lookup_string_option(Globals, math_lib, OtherSystemLibs)
    ;
        ( TargetType = static_library
        ; TargetType = csharp_executable
        ; TargetType = csharp_library
        ; TargetType = java_launcher
        ; TargetType = java_archive
        ; TargetType = erlang_launcher
        ; TargetType = erlang_archive
        ),
        unexpected($module, $pred, string(TargetType))
    ),

    SystemLibs = string.join_list(" ",
        [SystemTraceLibs, OtherSystemLibs, ThreadLibs]).

:- pred use_thread_libs(globals::in, bool::out) is det.

use_thread_libs(Globals, UseThreadLibs) :-
    globals.lookup_bool_option(Globals, parallel, Parallel),
    globals.get_gc_method(Globals, GCMethod),
    UseThreadLibs = ( ( Parallel = yes ; GCMethod = gc_mps ) -> yes ; no ).

    % When using --restricted-command-line with Visual C we add all the object
    % files to a temporary archive before linking an executable.
    % However, if only .lib files are given on the command line then
    % the linker needs to manually told some details that it usually infers
    % from the object files, for example the program entry point and the
    % target machine type.
    %
:- pred get_restricted_command_line_link_opts(globals::in,
    linked_target_type::in, string::out) is det.

get_restricted_command_line_link_opts(Globals, LinkTargetType,
        ResCmdLinkOpts) :-
    globals.lookup_bool_option(Globals, restricted_command_line,
        RestrictedCommandLine),
    (
        RestrictedCommandLine = yes,
        (
            LinkTargetType = executable,
            get_c_compiler_type(Globals, C_CompilerType),
            (
                C_CompilerType = cc_cl(_),
                % XXX WIN64 - this will need to be revisited when we begin
                % supporting 64-bit Windows.
                ResCmdLinkFlags = [
                    "-nologo",
                    "-subsystem:console",
                    "-machine:x86",
                    "-entry:wmainCRTStartup",
                    "-defaultlib:libcmt"
                ],
                join_string_list(ResCmdLinkFlags, "", "", " ", ResCmdLinkOpts)
            ;
                ( C_CompilerType = cc_gcc(_, _, _)
                ; C_CompilerType = cc_clang(_)
                ; C_CompilerType = cc_lcc
                ; C_CompilerType = cc_unknown
                ),
                ResCmdLinkOpts = ""
            )
        ;
            ( LinkTargetType = static_library
            ; LinkTargetType = shared_library
            ; LinkTargetType = csharp_executable
            ; LinkTargetType = csharp_library
            ; LinkTargetType = java_launcher
            ; LinkTargetType = java_archive
            ; LinkTargetType = erlang_launcher
            ; LinkTargetType = erlang_archive
            ),
            ResCmdLinkOpts = ""
        )
    ;
        RestrictedCommandLine = no,
        ResCmdLinkOpts = ""
    ).

post_link_make_symlink_or_copy(ErrorStream, LinkTargetType, ModuleName,
        Globals, Succeeded, MadeSymlinkOrCopy, !IO) :-
    globals.lookup_bool_option(Globals, use_grade_subdirs, UseGradeSubdirs),
    (
        UseGradeSubdirs = yes,
        link_output_filename(Globals, LinkTargetType, ModuleName, Ext,
            OutputFileName, !IO),
        % Link/copy the executable into the user's directory.
        globals.set_option(use_subdirs, bool(no),
            Globals, NoSubdirGlobals0),
        globals.set_option(use_grade_subdirs, bool(no),
            NoSubdirGlobals0, NoSubdirGlobals),
        (
            ( LinkTargetType = executable
            ; LinkTargetType = csharp_executable
            ; LinkTargetType = csharp_library
            ; LinkTargetType = java_launcher
            ; LinkTargetType = java_archive
            ; LinkTargetType = erlang_launcher
            ),
            module_name_to_file_name(NoSubdirGlobals, ModuleName, Ext,
                do_not_create_dirs, UserDirFileName, !IO)
        ;
            ( LinkTargetType = static_library
            ; LinkTargetType = shared_library
            ; LinkTargetType = erlang_archive
            ),
            module_name_to_lib_file_name(NoSubdirGlobals, "lib", ModuleName,
                Ext, do_not_create_dirs, UserDirFileName, !IO)
        ),

        same_timestamp(OutputFileName, UserDirFileName, SameTimestamp, !IO),
        (
            SameTimestamp = yes,
            Succeeded = yes,
            MadeSymlinkOrCopy = no
        ;
            SameTimestamp = no,
            io.set_output_stream(ErrorStream, OutputStream, !IO),
            % Remove the target of the symlink/copy in case it already exists.
            io.remove_file_recursively(UserDirFileName, _, !IO),

            % Erlang "archives" are just directories of .beam files,
            % so we need to copy them as directories rather than files
            % (on systems on which symbolic links are not available).
            ( if LinkTargetType = erlang_archive then
                make_symlink_or_copy_dir(Globals, OutputFileName,
                    UserDirFileName, Succeeded, !IO)
              else
                make_symlink_or_copy_file(Globals, OutputFileName,
                    UserDirFileName, Succeeded, !IO)
            ),
            io.set_output_stream(OutputStream, _, !IO),
            MadeSymlinkOrCopy = yes
        )
    ;
        UseGradeSubdirs = no,
        Succeeded = yes,
        MadeSymlinkOrCopy = no
    ).

:- pred get_framework_directories(globals::in, string::out) is det.

get_framework_directories(Globals, FrameworkDirs) :-
    globals.lookup_accumulating_option(Globals, framework_directories,
        FrameworkDirs0),
    join_quoted_string_list(FrameworkDirs0, "-F", "", " ", FrameworkDirs).

:- pred get_frameworks(globals::in, string::out) is det.

get_frameworks(Globals, FrameworkOpts) :-
    globals.lookup_accumulating_option(Globals, frameworks, Frameworks),
    join_quoted_string_list(Frameworks, "-framework ", "", " ", FrameworkOpts).

:- pred same_timestamp(string::in, string::in, bool::out, io::di, io::uo)
    is det.

same_timestamp(FileNameA, FileNameB, SameTimestamp, !IO) :-
    compare_file_timestamps(FileNameA, FileNameB, MaybeCompare, !IO),
    ( MaybeCompare = yes(=) ->
        SameTimestamp = yes
    ;
        SameTimestamp = no
    ).

shared_libraries_supported(Globals, Supported) :-
    % XXX This seems to be the standard way to check whether shared libraries
    % are supported but it's not very nice.
    globals.lookup_string_option(Globals, library_extension, LibExt),
    globals.lookup_string_option(Globals, shared_library_extension,
        SharedLibExt),
    Supported = (if LibExt \= SharedLibExt then yes else no).

:- pred get_linker_output_option(globals::in, linked_target_type::in,
    string::out) is det.

get_linker_output_option(Globals, LinkTargetType, OutputOpt) :-
    get_c_compiler_type(Globals, C_CompilerType),
    % XXX we should allow the user to override the compiler's choice of
    % output option here.
    % NOTE: the spacing around the value of OutputOpt here is important.
    % Any changes should be reflected in predicate link_exe_or_shared_lib/9.
    (
        C_CompilerType = cc_cl(_),
        ( if LinkTargetType = executable then
            % NOTE: -Fe _must not_ be separated from its argument by any
            % whitspace; the lack of a trailing space in the following
            % is deliberate.
            OutputOpt = " -Fe"
          else
            % XXX This is almost certainly wrong, but we don't currently
            % support building shared libraries with mmc on Windows
            % anyway.
            OutputOpt = " -o "
        )
    ;
        ( C_CompilerType = cc_gcc(_, _, _)
        ; C_CompilerType = cc_clang(_)
        ; C_CompilerType = cc_lcc
        ; C_CompilerType = cc_unknown
        ),
        OutputOpt = " -o "
    ).

:- func reserve_stack_size_flags(globals) = string.

reserve_stack_size_flags(Globals) = Flags :-
    globals.lookup_int_option(Globals, cstack_reserve_size, ReserveStackSize),
    ( if ReserveStackSize = -1 then
        Flags = ""
    else 
        get_c_compiler_type(Globals, C_CompilerType),
        (
            ( C_CompilerType = cc_gcc(_, _, _)
            ; C_CompilerType = cc_clang(_)
            ; C_CompilerType = cc_lcc
            ; C_CompilerType = cc_unknown
            ),
            string.format("-Wl,--stack=%d", [i(ReserveStackSize)], Flags)
        ;
            C_CompilerType = cc_cl(_),
            string.format("-stack:%d", [i(ReserveStackSize)], Flags)
        )
    ).

%-----------------------------------------------------------------------------%

:- pred process_link_library(globals::in, list(dir_name)::in, string::in,
    string::out, bool::in, bool::out, io::di, io::uo) is det.

process_link_library(Globals, MercuryLibDirs, LibName, LinkerOpt, !Succeeded,
        !IO) :-
    globals.get_target(Globals, Target),
    (
        ( Target = target_c
        ; Target = target_x86_64
        ),
        globals.lookup_string_option(Globals, mercury_linkage, MercuryLinkage),
        LinkOpt = "-l",
        LibSuffix = ""
    ;
        Target = target_csharp,
        MercuryLinkage = "shared",
        LinkOpt = "-r:",
        LibSuffix = ".dll"
    ;
        Target = target_il,
        unexpected($module, $pred, "target_java")
    ;
        Target = target_java,
        unexpected($module, $pred, "target_java")
    ;
        Target = target_erlang,
        unexpected($module, $pred, "target_erlang")
    ),

    globals.lookup_accumulating_option(Globals, mercury_libraries,
        MercuryLibs),
    (
        MercuryLinkage = "static",
        list.member(LibName, MercuryLibs)
    ->
        % If we are linking statically with Mercury libraries, pass the
        % absolute pathname of the `.a' file for the library.
        file_name_to_module_name(LibName, LibModuleName),
        globals.lookup_string_option(Globals, library_extension, LibExt),

        globals.set_option(use_grade_subdirs, bool(no),
            Globals, NoSubDirGlobals),
        module_name_to_lib_file_name(NoSubDirGlobals, "lib", LibModuleName,
            LibExt, do_not_create_dirs, LibFileName, !IO),

        search_for_file_returning_dir(do_not_open_file, MercuryLibDirs,
            LibFileName, SearchResult, !IO),
        (
            SearchResult = ok(DirName),
            LinkerOpt = DirName/LibFileName
        ;
            SearchResult = error(Error),
            LinkerOpt = "",
            write_error_pieces_maybe_with_context(Globals, no, 0,
                [words(Error)], !IO),
            !:Succeeded = no
        )
    ;
        LinkerOpt = LinkOpt ++ LibName ++ LibSuffix
    ).

:- pred create_archive(globals::in, io.output_stream::in, file_name::in,
    bool::in, list(file_name)::in, bool::out, io::di, io::uo) is det.

create_archive(Globals, ErrorStream, LibFileName, Quote, ObjectList,
        Succeeded, !IO) :-
    globals.lookup_string_option(Globals, create_archive_command, ArCmd),
    globals.lookup_accumulating_option(Globals, create_archive_command_flags,
        ArFlagsList),
    join_string_list(ArFlagsList, "", "", " ", ArFlags),
    globals.lookup_string_option(Globals, create_archive_command_output_flag,
        ArOutputFlag),
    globals.lookup_string_option(Globals, ranlib_command, RanLib),
    (
        Quote = yes,
        join_quoted_string_list(ObjectList, "", "", " ", Objects)
    ;
        Quote = no,
        % Elements of ObjectList may contain shell wildcards, which
        % are intended to cause the element to expand to several words.
        % Quoting would prevent that.
        join_string_list(ObjectList, "", "", " ", Objects)
    ),

    % NOTE: when using the Windows Library Manager Tool (lib) there must
    % _not_ be a space between the -OUT: option and its argument.
    % XXX we actually check the C compiler type here since that is more
    % robust than using the values of the configuration options used for
    % archive creation.
    get_c_compiler_type(Globals, C_CompilerType),
    (
        % If we are using Visual C then we must be using the Microsoft
        % lib tool.
        C_CompilerType = cc_cl(_),
        ArOutputSpace = ""
    ;
        ( C_CompilerType = cc_gcc(_, _, _)
        ; C_CompilerType = cc_clang(_)
        ; C_CompilerType = cc_lcc
        ; C_CompilerType = cc_unknown
        ),
        ArOutputSpace = " "
    ),

    MakeLibCmdArgs = string.append_list([
        ArFlags, " ",
        ArOutputFlag, ArOutputSpace, LibFileName, " ",
        Objects]
    ),

    invoke_long_system_command(Globals, ErrorStream, cmd_verbose_commands,
        ArCmd, MakeLibCmdArgs, MakeLibCmdSucceeded, !IO),

    (
        ( RanLib = ""
        ; MakeLibCmdSucceeded = no
        )
    ->
        Succeeded = MakeLibCmdSucceeded
    ;
        RanLibCmd = string.append_list([RanLib, " ", LibFileName]),
        invoke_system_command(Globals, ErrorStream, cmd_verbose_commands,
            RanLibCmd, Succeeded, !IO)
    ).

:- pred create_csharp_exe_or_lib(globals::in, io.output_stream::in,
    linked_target_type::in, module_name::in, file_name::in,
    list(file_name)::in, bool::out, io::di, io::uo) is det.

create_csharp_exe_or_lib(Globals, ErrorStream, LinkTargetType, MainModuleName,
        OutputFileName0, SourceList0, Succeeded, !IO) :-
    get_host_env_type(Globals, EnvType),
    get_csharp_compiler_type(Globals, CSharpCompilerType),

    OutputFileName = csharp_file_name(EnvType, CSharpCompilerType,
        OutputFileName0),
    SourceList = list.map(csharp_file_name(EnvType, CSharpCompilerType),
        SourceList0),

    % Suppress the MS C# compiler's banner message.
    (
        CSharpCompilerType = csharp_microsoft,
        NoLogoOpt = "-nologo "
    ;
        ( CSharpCompilerType = csharp_mono
        ; CSharpCompilerType = csharp_unknown
        ),
        NoLogoOpt = ""
    ),

    globals.lookup_bool_option(Globals, line_numbers, LineNumbers),
    (
        % If we output line numbers the mono C# compiler outputs lots of
        % spurious warnings about unused variables and unreachable code,
        % so disable these warnings. It also confuses #pragma warning
        % which is why we make the options global.
        LineNumbers = yes,
        NoWarnLineNumberOpt = "-nowarn:162,219 "
    ;
        LineNumbers = no,
        NoWarnLineNumberOpt = ""
    ),

    % NOTE: we use the -option style options in preference to the /option
    % style in order to avoid problems with POSIX style shells.
    globals.lookup_string_option(Globals, csharp_compiler, CSharpCompiler),
    globals.lookup_bool_option(Globals, highlevel_data, HighLevelData),
    (
        HighLevelData = yes,
        HighLevelDataOpt = "-define:MR_HIGHLEVEL_DATA"
    ;
        HighLevelData = no,
        HighLevelDataOpt = ""
    ),
    globals.lookup_bool_option(Globals, target_debug, Debug),
    (
        Debug = yes,
        DebugOpt = "-debug "
    ;
        Debug = no,
        DebugOpt = ""
    ),
    globals.lookup_accumulating_option(Globals, csharp_flags, CSCFlagsList),
    (
        LinkTargetType = csharp_executable,
        TargetOption = "-target:exe",
        SignAssemblyOpt = ""
    ;
        LinkTargetType = csharp_library,
        TargetOption = "-target:library",
        globals.lookup_string_option(Globals, sign_assembly, KeyFile),
        ( if KeyFile = ""
        then SignAssemblyOpt = ""
        else SignAssemblyOpt = "-keyfile:" ++ KeyFile ++ " "
        )
    ;
        ( LinkTargetType = executable
        ; LinkTargetType = static_library
        ; LinkTargetType = shared_library
        ; LinkTargetType = java_launcher
        ; LinkTargetType = java_archive
        ; LinkTargetType = erlang_launcher
        ; LinkTargetType = erlang_archive
        ),
        unexpected($module, $pred, "wrong target type")
    ),

    globals.lookup_accumulating_option(Globals, link_library_directories,
        LinkLibraryDirectoriesList0),
    LinkLibraryDirectoriesList =
        list.map(csharp_file_name(EnvType, CSharpCompilerType),
        LinkLibraryDirectoriesList0),
    LinkerPathFlag = "-lib:",
    join_quoted_string_list(LinkLibraryDirectoriesList, LinkerPathFlag, "",
        " ", LinkLibraryDirectories),

    get_link_libraries(Globals, MaybeLinkLibraries, !IO),
    (
        MaybeLinkLibraries = yes(LinkLibrariesList0),
        LinkLibrariesList =
            list.map(csharp_file_name(EnvType, CSharpCompilerType),
            LinkLibrariesList0),
        join_quoted_string_list(LinkLibrariesList, "", "", " ",
            LinkLibraries)
    ;
        MaybeLinkLibraries = no,
        LinkLibraries = ""
    ),

    get_mercury_std_libs(Globals, LinkTargetType, MercuryStdLibs),

    Cmd = CSharpCompiler,
    CmdArgs = string.join_list(" ", [
        NoLogoOpt,
        NoWarnLineNumberOpt,
        HighLevelDataOpt,
        DebugOpt,
        TargetOption,
        "-out:" ++ OutputFileName,
        SignAssemblyOpt,
        LinkLibraryDirectories,
        LinkLibraries,
        MercuryStdLibs] ++
        CSCFlagsList ++
        SourceList),
    invoke_long_system_command(Globals, ErrorStream, cmd_verbose_commands,
        Cmd, CmdArgs, Succeeded0, !IO),

    % Also create a shell script to launch it if necessary.
    globals.get_target_env_type(Globals, TargetEnvType),
    globals.lookup_string_option(Globals, cli_interpreter, CLI),
    (
        Succeeded0 = yes,
        LinkTargetType = csharp_executable,
        CLI \= "",
        TargetEnvType = env_type_posix
    ->
        create_launcher_shell_script(Globals, MainModuleName,
            write_cli_shell_script(Globals, OutputFileName),
            Succeeded, !IO)
    ;
        Succeeded = Succeeded0
    ).

    % Converts the given filename into a format acceptable to the C# compiler.
    %
    % This is because the MS C# compiler only allows \ as the path separator,
    % so we convert all / into \ when using the MC C# compiler.
    %
:- func csharp_file_name(env_type, csharp_compiler_type, file_name)
    = file_name.

csharp_file_name(env_type_posix, csharp_microsoft, _FileName) =
    unexpected($module, $pred, "microsoft c# compiler in posix env").
csharp_file_name(env_type_posix, csharp_mono, Filename) = Filename.
csharp_file_name(env_type_posix, csharp_unknown, Filename) = Filename.

csharp_file_name(env_type_cygwin, csharp_microsoft, Filename) =
    convert_to_windows_path_format(Filename).
csharp_file_name(env_type_cygwin, csharp_mono, Filename) = Filename.
csharp_file_name(env_type_cygwin, csharp_unknown, Filename) = Filename.

csharp_file_name(env_type_msys, csharp_microsoft, Filename) =
    convert_to_windows_path_format(Filename).
csharp_file_name(env_type_msys, csharp_mono, Filename) = Filename.
csharp_file_name(env_type_msys, csharp_unknown, Filename) = Filename.

csharp_file_name(env_type_win_cmd, csharp_microsoft, Filename) =
    convert_to_windows_path_format(Filename).
csharp_file_name(env_type_win_cmd, csharp_mono, Filename) = Filename.
csharp_file_name(env_type_win_cmd, csharp_unknown, Filename) =
    convert_to_windows_path_format(Filename).

csharp_file_name(env_type_powershell, csharp_microsoft, Filename) =
    convert_to_windows_path_format(Filename).
csharp_file_name(env_type_powershell, csharp_mono, Filename) = Filename.
csharp_file_name(env_type_powershell, csharp_unknown, Filename) =
    convert_to_windows_path_format(Filename).

:- func convert_to_windows_path_format(file_name) = file_name.

convert_to_windows_path_format(FileName) =
    string.replace_all(FileName, "/", "\\\\").

:- pred write_cli_shell_script(globals::in, string::in, io.output_stream::in,
    io::di, io::uo) is det.

write_cli_shell_script(Globals, ExeFileName, Stream, !IO) :-
    globals.lookup_string_option(Globals, cli_interpreter, CLI),
    globals.lookup_accumulating_option(Globals, link_library_directories,
        LinkLibraryDirectoriesList),
    join_quoted_string_list(LinkLibraryDirectoriesList, "", "",
        ":", LinkLibraryDirectories),
    list.foldl(io.write_string(Stream), [
        "#!/bin/sh\n",
        "MONO_PATH=$MONO_PATH:", LinkLibraryDirectories, "\n",
        "export MONO_PATH\n",
        "CLI_INTERPRETER=${CLI_INTERPRETER:-", CLI, "}\n",
        "exec $CLI_INTERPRETER ", ExeFileName, " \"$@\"\n"
    ], !IO).

:- pred create_java_archive(globals::in, io.output_stream::in, file_name::in,
    list(file_name)::in, bool::out, io::di, io::uo) is det.

create_java_archive(Globals, ErrorStream, JarFileName, ObjectList, Succeeded,
        !IO) :-
    globals.lookup_string_option(Globals, java_archive_command, Jar),

    list_class_files_for_jar(Globals, ObjectList, ClassSubDir, ListClassFiles,
        !IO),
    (
        ListClassFiles = [],
        unexpected($module, $pred, "empty list of .class files")
    ;
        ListClassFiles = [_ | _]
    ),

    % Write the list of class files to a temporary file and pass the name of
    % the temporary file to jar using @syntax. The list of class files can be
    % extremely long. We create the temporary file in the current directory to
    % avoid problems under Cygwin, where absolute paths will be interpreted
    % incorrectly when passed to a non-Cygwin jar program.
    io.make_temp(".", "mtmp", TempFileName, !IO),
    io.open_output(TempFileName, OpenResult, !IO),
    (
        OpenResult = ok(Stream),
        list.foldl(write_jar_class_argument(Stream, ClassSubDir),
            ListClassFiles, !IO),
        io.close_output(Stream, !IO),

        Cmd = string.append_list(
            [Jar, " cf ", JarFileName, " @", TempFileName]),
        invoke_system_command(Globals, ErrorStream, cmd_verbose_commands, Cmd,
            Succeeded, !IO),
        io.remove_file(TempFileName, _, !IO),

        (
            Succeeded = yes,
            % Add an index, which is supposed to speed up class loading.
            IndexCmd = string.append_list([Jar, " i ", JarFileName]),
            invoke_system_command(Globals, ErrorStream, cmd_verbose_commands,
                IndexCmd, _, !IO)
        ;
            Succeeded = no,
            io.remove_file(JarFileName, _, !IO)
        )
    ;
        OpenResult = error(Error),
        io.write_string(ErrorStream, "Error creating `", !IO),
        io.write_string(ErrorStream, TempFileName, !IO),
        io.write_string(ErrorStream, "': ", !IO),
        io.write_string(ErrorStream, io.error_message(Error), !IO),
        io.nl(ErrorStream, !IO),
        Succeeded = no
    ).

:- pred write_jar_class_argument(io.output_stream::in, string::in, string::in,
    io::di, io::uo) is det.

write_jar_class_argument(Stream, ClassSubDir, ClassFileName, !IO) :-
    ( dir.path_name_is_absolute(ClassFileName) ->
        true
    ;
        io.write_string(Stream, "-C ", !IO),
        io.write_string(Stream, ClassSubDir, !IO),
        io.write_string(Stream, " ", !IO)
    ),
    io.write_string(Stream, ClassFileName, !IO),
    io.nl(Stream, !IO).

%-----------------------------------------------------------------------------%

    % Create an "Erlang archive", which is simply a directory containing
    % `.beam' files.
    %
:- pred create_erlang_archive(globals::in, io.output_stream::in,
    module_name::in, file_name::in, list(file_name)::in, bool::out,
    io::di, io::uo) is det.

create_erlang_archive(Globals, ErrorStream, _ModuleName, ErlangArchiveFileName,
        ObjectList, Succeeded, !IO) :-
    % Delete anything in the way first.
    io.remove_file_recursively(ErlangArchiveFileName, _, !IO),
    dir.make_directory(ErlangArchiveFileName, Res, !IO),
    (
        Res = ok,
        copy_erlang_archive_files(Globals, ErrorStream, ErlangArchiveFileName,
            ObjectList, Succeeded, !IO)
    ;
        Res = error(Error),
        io.write_string(ErrorStream, "Error creating `", !IO),
        io.write_string(ErrorStream, ErlangArchiveFileName, !IO),
        io.write_string(ErrorStream, "': ", !IO),
        io.write_string(ErrorStream, io.error_message(Error), !IO),
        io.nl(ErrorStream, !IO),
        Succeeded = no
    ).

:- pred copy_erlang_archive_files(globals::in, io.output_stream::in,
    file_name::in, list(file_name)::in, bool::out, io::di, io::uo) is det.

copy_erlang_archive_files(_Globals, _ErrorStream, _ErlangArchiveFileName,
        [], yes, !IO).
copy_erlang_archive_files(Globals, ErrorStream, ErlangArchiveFileName,
        [Obj | Objs], Succeeded, !IO) :-
    copy_file(Globals, Obj, ErlangArchiveFileName, Res, !IO),
    (
        Res = ok,
        copy_erlang_archive_files(Globals, ErrorStream, ErlangArchiveFileName,
            Objs, Succeeded, !IO)
    ;
        Res = error(Error),
        io.write_string(ErrorStream, "Error copying `", !IO),
        io.write_string(ErrorStream, Obj, !IO),
        io.write_string(ErrorStream, "': ", !IO),
        io.write_string(ErrorStream, io.error_message(Error), !IO),
        io.nl(ErrorStream, !IO),
        Succeeded = no
    ).

%-----------------------------------------------------------------------------%

get_object_code_type(Globals, FileType, ObjectCodeType) :-
    globals.lookup_string_option(Globals, pic_object_file_extension,
        PicObjExt),
    globals.lookup_string_option(Globals, link_with_pic_object_file_extension,
        LinkWithPicObjExt),
    globals.lookup_string_option(Globals, object_file_extension, ObjExt),
    globals.lookup_string_option(Globals, mercury_linkage, MercuryLinkage),
    globals.lookup_bool_option(Globals, gcc_global_registers, GCCGlobals),
    globals.lookup_bool_option(Globals, highlevel_code, HighLevelCode),
    globals.get_target(Globals, Target),
    (
        ( FileType = static_library
        ; FileType = csharp_executable
        ; FileType = csharp_library
        ; FileType = java_launcher
        ; FileType = java_archive
        ; FileType = erlang_launcher
        ; FileType = erlang_archive
        ),
        ObjectCodeType = non_pic
    ;
        FileType = shared_library,
        ObjectCodeType = ( if PicObjExt = ObjExt then non_pic else pic )
    ;
        FileType = executable,
        ( MercuryLinkage = "shared" ->
            (
                % We only need to create `.lpic' files if `-DMR_PIC_REG'
                % has an effect, which is currently nowhere.
                ( LinkWithPicObjExt = ObjExt
                ; HighLevelCode = yes
                ; GCCGlobals = no
                ; Target \= target_c
                )
            ->
                ObjectCodeType = non_pic
            ;
                LinkWithPicObjExt = PicObjExt
            ->
                ObjectCodeType = pic
            ;
                ObjectCodeType = link_with_pic
            )
        ; MercuryLinkage = "static" ->
            ObjectCodeType = non_pic
        ;
            % The linkage string is checked by options.m.
            unexpected($module, $pred,
                "unknown linkage " ++ MercuryLinkage)
        )
    ).

get_linked_target_type(Globals, LinkedTargetType) :-
    globals.lookup_bool_option(Globals, compile_to_shared_lib, MakeSharedLib),
    (
        MakeSharedLib = yes,
        LinkedTargetType = shared_library
    ;
        MakeSharedLib = no,
        LinkedTargetType = executable
    ).

%-----------------------------------------------------------------------------%

    % join_string_list(Strings, Prefix, Suffix, Separator, Result):
    %
    % Appends the strings in the list `Strings' together into the string
    % Result. Each string is prefixed by Prefix, suffixed by Suffix and
    % separated by Separator.
    %
:- pred join_string_list(list(string)::in, string::in, string::in, string::in,
    string::out) is det.

join_string_list([], _Prefix, _Suffix, _Separator, "").
join_string_list([String | Strings], Prefix, Suffix, Separator, Result) :-
    (
        Strings = [],
        string.append_list([Prefix, String, Suffix], Result)
    ;
        Strings = [_ | _],
        join_string_list(Strings, Prefix, Suffix, Separator, Result0),
        string.append_list([Prefix, String, Suffix, Separator, Result0],
            Result)
    ).

    % As above, but quote the strings first. Note that the strings in values
    % of the *flags options are already quoted.
    %
:- pred join_quoted_string_list(list(string)::in, string::in, string::in,
    string::in, string::out) is det.

join_quoted_string_list(Strings, Prefix, Suffix, Separator, Result) :-
    join_string_list(map(quote_arg, Strings), Prefix, Suffix, Separator,
        Result).

    % join_module_list(Globals, ModuleNames, Extension, Result, !IO):
    %
    % The list of strings `Result' is computed from the list of strings
    % `ModuleNames', by removing any directory paths, and converting the
    % strings to file names and then back, adding the specified Extension.
    % (This conversion ensures that we follow the usual file naming
    % conventions.)
    %
:- pred join_module_list(globals::in, list(string)::in, string::in,
    list(string)::out, io::di, io::uo) is det.

join_module_list(_Globals, [], _Extension, [], !IO).
join_module_list(Globals, [Module | Modules], Extension,
        [FileName | FileNames], !IO) :-
    file_name_to_module_name(dir.det_basename(Module), ModuleName),
    module_name_to_file_name(Globals, ModuleName, Extension,
        do_not_create_dirs, FileName, !IO),
    join_module_list(Globals, Modules, Extension, FileNames, !IO).

%-----------------------------------------------------------------------------%

make_all_module_command(Globals, Command0, MainModule, AllModules, Command,
        !IO) :-
    % Pass the main module first.
    list.map_foldl(
        (pred(Module::in, FileName::out, IO0::di, IO::uo) is det :-
            module_name_to_file_name(Globals, Module, ".m",
                do_not_create_dirs, FileName, IO0, IO)
        ),
        [MainModule | list.delete_all(AllModules, MainModule)],
        ModuleNameStrings, !IO),
    Command = string.join_list(" ",
        list.map(quote_arg, [Command0 | ModuleNameStrings])).

%-----------------------------------------------------------------------------%

:- pragma promise_equivalent_clauses(maybe_pic_object_file_extension/3).

maybe_pic_object_file_extension(Globals::in, PIC::in, Ext::out) :-
    (
        PIC = non_pic,
        globals.lookup_string_option(Globals, object_file_extension, Ext)
    ;
        PIC = pic,
        globals.lookup_string_option(Globals, pic_object_file_extension, Ext)
    ;
        PIC = link_with_pic,
        globals.lookup_string_option(Globals,
            link_with_pic_object_file_extension, Ext)
    ).
maybe_pic_object_file_extension(Globals::in, PIC::out, Ext::in) :-
    (
        % This test must come first -- if the architecture doesn't need
        % special treatment for PIC, we should always return `non_pic'.
        % `mmc --make' depends on this.
        globals.lookup_string_option(Globals, object_file_extension, Ext)
    ->
        PIC = non_pic
    ;
        globals.lookup_string_option(Globals, pic_object_file_extension, Ext)
    ->
        PIC = pic
    ;
        globals.lookup_string_option(Globals,
            link_with_pic_object_file_extension, Ext)
    ->
        PIC = link_with_pic
    ;
        fail
    ).

%-----------------------------------------------------------------------------%
%
% Standalone interfaces
%

% NOTE: the following code is similar to that of make_init_obj/7.
% Any changes here may need to be reflected there.

make_standalone_interface(Globals, Basename, !IO) :-
    make_standalone_int_header(Basename, HdrSucceeded, !IO),
    (
        HdrSucceeded = yes,
        make_standalone_int_body(Globals, Basename, !IO)
    ;
        HdrSucceeded = no
    ).

:- pred make_standalone_int_header(string::in, bool::out,
    io::di, io::uo) is det.

make_standalone_int_header(Basename, Succeeded, !IO) :-
    HdrFileName = Basename ++ ".h",
    io.open_output(HdrFileName, OpenResult, !IO),
    (
        OpenResult = ok(HdrFileStream),
        io.write_strings(HdrFileStream, [
            "#ifndef ", to_upper(Basename), "_H\n",
            "#define ", to_upper(Basename), "_H\n",
            "\n",
            "#ifdef __cplusplus\n",
            "extern \"C\" {\n",
            "#endif\n",
            "\n",
            "extern void\n",
            "mercury_init(int argc, char **argv, void *stackbottom);\n",
            "\n",
            "extern int\n",
            "mercury_terminate(void);\n",
            "\n",
            "#ifdef __cplusplus\n",
            "}\n",
            "#endif\n",
            "\n",
            "#endif /* ", to_upper(Basename), "_H */\n"],
            !IO),
        io.close_output(HdrFileStream, !IO),
        Succeeded = yes
    ;
        OpenResult = error(Error),
        unable_to_open_file(HdrFileName, Error, !IO),
        Succeeded = no
    ).

:- pred make_standalone_int_body(globals::in, string::in, io::di, io::uo)
    is det.

make_standalone_int_body(Globals, Basename, !IO) :-
    globals.lookup_accumulating_option(Globals, init_files, InitFiles0),
    % See the similar code in make_init_target_file for an explanation
    % of why we must remove duplicates from this list.
    list.remove_dups(InitFiles0, InitFiles1),
    globals.lookup_accumulating_option(Globals, trace_init_files,
        TraceInitFiles0),
    globals.lookup_maybe_string_option(Globals,
        mercury_standard_library_directory, MaybeStdLibDir),
    grade_directory_component(Globals, GradeDir),
    (
        MaybeStdLibDir = yes(StdLibDir),
        InitFiles2 = [
            StdLibDir / "modules" / GradeDir / "mer_rt.init",
            StdLibDir / "modules" / GradeDir / "mer_std.init" |
            InitFiles1
        ],
        TraceInitFiles = [
            StdLibDir / "modules" / GradeDir / "mer_browser.init",
            StdLibDir / "modules" / GradeDir / "mer_mdbcomp.init" |
            TraceInitFiles0
        ],
        SourceDebugInitFiles = [
            StdLibDir / "modules" / GradeDir / "mer_ssdb.init"
        ]
    ;
        % Supporting `--no-mercury-standard-library-directory' is necessary
        % in order to use `--generate-standalone-interface' with the
        % the lmc script.
        MaybeStdLibDir = no,
        InitFiles2 = InitFiles1,
        TraceInitFiles = TraceInitFiles0,
        SourceDebugInitFiles = []
    ),
    globals.get_trace_level(Globals, TraceLevel),
    ( given_trace_level_is_none(TraceLevel) = no ->
        TraceOpt = "-t",
        InitFiles3 = InitFiles2 ++ TraceInitFiles
    ;
        TraceOpt = "",
        InitFiles3 = InitFiles2
    ),
    globals.lookup_bool_option(Globals, link_ssdb_libs, SourceDebug),
    (
        SourceDebug = yes,
        InitFiles = InitFiles3 ++ SourceDebugInitFiles
    ;
        SourceDebug = no,
        InitFiles = InitFiles3
    ),
    globals.lookup_accumulating_option(Globals, runtime_flags,
        RuntimeFlagsList),
    join_quoted_string_list(RuntimeFlagsList, "-r ", "", " ", RuntimeFlags),
    globals.lookup_accumulating_option(Globals, init_file_directories,
        InitFileDirsList),
    join_quoted_string_list(InitFileDirsList, "-I ", "", " ", InitFileDirs),
    globals.lookup_string_option(Globals, experimental_complexity,
        ExperimentalComplexity),
    ( ExperimentalComplexity = "" ->
        ExperimentalComplexityOpt = ""
    ;
        ExperimentalComplexityOpt = "-X " ++ ExperimentalComplexity
    ),
    compute_grade(Globals, Grade),
    globals.lookup_string_option(Globals, mkinit_command, MkInit),
    CFileName = Basename ++ ".c",
    io.output_stream(ErrorStream, !IO),
    MkInitArgs = string.append_list(
        [   " -g ", Grade,
            " ", TraceOpt,
            " ", ExperimentalComplexityOpt,
            " ", RuntimeFlags,
            " -o ", quote_arg(CFileName),
            " ", InitFileDirs,
            " -s "
        ]),

    invoke_mkinit(Globals, ErrorStream, cmd_verbose_commands,
        MkInit, MkInitArgs, InitFiles, MkInitCmdOk, !IO),
    (
        MkInitCmdOk = yes,
        get_object_code_type(Globals, executable, PIC),
        maybe_pic_object_file_extension(Globals, PIC, ObjExt),
        ObjFileName = Basename ++ ObjExt,
        do_compile_c_file(ErrorStream, PIC, CFileName, ObjFileName,
            Globals, CompileOk, !IO),
        (
            CompileOk = yes
        ;
            CompileOk = no,
            io.set_exit_status(1, !IO),
            io.write_string("mercury_compile: error while compiling ", !IO),
            io.write_string("standalone interface in `", !IO),
            io.write_string(CFileName, !IO),
            io.write_string("'\n", !IO)
        )
    ;
        MkInitCmdOk = no,
        io.set_exit_status(1, !IO),
        io.write_string("mercury_compile: error while creating ", !IO),
        io.write_string("standalone interface in `", !IO),
        io.write_string(CFileName, !IO),
        io.write_string("'\n", !IO)
    ).

%-----------------------------------------------------------------------------%

    % invoke_long_system_command attempts to use the @file style of
    % calling to avoid command line length arguments on various systems.
    % If the underlying tool chain doesn't support this it just calls
    % the normal invoke_system_command and hopes the command isn't too
    % long.
    %
:- pred invoke_long_system_command(globals::in, io.output_stream::in,
    command_verbosity::in, string::in, string::in, bool::out, io::di, io::uo)
    is det.

invoke_long_system_command(Globals, ErrorStream, Verbosity, Cmd, Args,
        Succeeded, !IO) :-
    invoke_long_system_command_maybe_filter_output(Globals, ErrorStream,
        Verbosity, Cmd, Args, no, Succeeded, !IO).

:- pred invoke_long_system_command_maybe_filter_output(globals::in,
    io.output_stream::in, command_verbosity::in, string::in, string::in,
    maybe(string)::in, bool::out, io::di, io::uo) is det.

invoke_long_system_command_maybe_filter_output(Globals, ErrorStream, Verbosity,
        Cmd, Args, MaybeProcessOutput, Succeeded, !IO) :-
    globals.lookup_bool_option(Globals, restricted_command_line,
        RestrictedCommandLine),
    (
        RestrictedCommandLine = yes,

        % Avoid generating very long command lines by using @files.
        io.make_temp(TmpFile, !IO),
        io.open_output(TmpFile, OpenResult, !IO),
        (
            OpenResult = ok(TmpStream),

            % We need to escape any \ before writing them to the file,
            % otherwise we lose them.
            TmpFileArgs = string.replace_all(Args, "\\", "\\\\"),

            io.write_string(TmpStream, TmpFileArgs, !IO),
            io.close_output(TmpStream, !IO),

            globals.lookup_bool_option(Globals, very_verbose, VeryVerbose),
            (
                VeryVerbose = yes,
                io.write_string("% Args placed in ", !IO),
                io.write_string(at_file_name(Globals, TmpFile) ++ ": `", !IO),
                io.write_string(TmpFileArgs, !IO),
                io.write_string("'\n", !IO),
                io.flush_output(!IO)
            ;
                VeryVerbose = no
            ),

            FullCmd = Cmd ++ " " ++ at_file_name(Globals, TmpFile),
            invoke_system_command_maybe_filter_output(Globals, ErrorStream,
                Verbosity, FullCmd, MaybeProcessOutput, Succeeded0, !IO),

            io.remove_file(TmpFile, RemoveResult, !IO),
            (
                RemoveResult = ok,
                Succeeded = Succeeded0
            ;
                RemoveResult = error(_),
                Succeeded = no
            )
        ;
            OpenResult = error(_),
            Succeeded = no
        )

    ;
        RestrictedCommandLine = no,
        FullCmd = Cmd ++ " " ++ Args,
        invoke_system_command_maybe_filter_output(Globals, ErrorStream,
            Verbosity, FullCmd, MaybeProcessOutput, Succeeded, !IO)
    ).

    % Form the name of an @file given a file name.
    % On some systems we need to escape the `@' character.
    %
:- func at_file_name(globals, string) = string.

at_file_name(Globals, FileName) = AtFileName :-
    get_host_env_type(Globals, EnvType),
    (
        EnvType = env_type_powershell,
        AtFileName = "`@" ++ FileName
    ;
        ( EnvType = env_type_posix
        ; EnvType = env_type_cygwin
        ; EnvType = env_type_msys
        ; EnvType = env_type_win_cmd
        ),
        AtFileName = "@" ++ FileName
    ).

%-----------------------------------------------------------------------------%
%
% C compiler flags.
%

output_c_compiler_flags(Globals, Stream, !IO) :-
    get_object_code_type(Globals, executable, PIC),
    gather_c_compiler_flags(Globals, PIC, CFlags),
    io.write_string(Stream, CFlags, !IO).

%-----------------------------------------------------------------------------%
%
% Grade defines flags.
%

output_grade_defines(Globals, Stream, !IO) :-
    get_object_code_type(Globals, executable, PIC),
    gather_grade_defines(Globals, PIC, GradeDefines),
    io.write_string(Stream, GradeDefines, !IO),
    io.nl(Stream, !IO).

%-----------------------------------------------------------------------------%
%
% C include directory flags.
%

output_c_include_directory_flags(Globals, Stream, !IO) :-
    gather_c_include_dir_flags(Globals, InclOpts),
    io.write_string(Stream, InclOpts, !IO),
    io.nl(Stream, !IO).

%-----------------------------------------------------------------------------%
%
% Library link flags.
%

output_library_link_flags(Globals, Stream, !IO) :-
    % We output the library link flags as they are for when we are linking
    % an executable.
    LinkTargetType = executable,
    RpathFlagOpt = linker_rpath_flag,
    RpathSepOpt = linker_rpath_separator,

    globals.lookup_accumulating_option(Globals, link_library_directories,
        LinkLibraryDirectoriesList),
    globals.lookup_string_option(Globals, linker_path_flag, LinkerPathFlag),
    join_quoted_string_list(LinkLibraryDirectoriesList, LinkerPathFlag, "",
        " ", LinkLibraryDirectories),
    get_runtime_library_path_opts(Globals, LinkTargetType,
        RpathFlagOpt, RpathSepOpt, RpathOpts),
    get_link_libraries(Globals, MaybeLinkLibraries, !IO),
    (
        MaybeLinkLibraries = yes(LinkLibrariesList),
        join_quoted_string_list(LinkLibrariesList, "", "", " ",
            LinkLibraries)
    ;
        MaybeLinkLibraries = no,
        LinkLibraries = ""
    ),
    % Find the Mercury standard libraries.
    get_mercury_std_libs(Globals, LinkTargetType, MercuryStdLibs),
    get_system_libs(Globals, LinkTargetType, SystemLibs),
    string.append_list([
        LinkLibraryDirectories, " ",
        RpathOpts, " ",
        LinkLibraries, " ",
        MercuryStdLibs, " ",
        SystemLibs], LinkFlags),
    io.write_string(Stream, LinkFlags, !IO).

%-----------------------------------------------------------------------------%

    % Succeeds if the configuration name for this machine matches
    % *-apple-darwin*, i.e. its an x86 / x86_64 / ppc machine with Mac OS X.
    %
:- pred arch_is_apple_darwin(string::in) is semidet.

arch_is_apple_darwin(FullArch) :-
    ArchComponents = string.split_at_char(('-'), FullArch),
    % See the comments at the head of config.sub for details of how autoconf
    % handles configuration names.
    ArchComponents = [_CPU, Mfr, OS],
    Mfr = "apple",
    string.prefix(OS, "darwin").

%-----------------------------------------------------------------------------%
:- end_module backend_libs.compile_target_code.
%-----------------------------------------------------------------------------%
