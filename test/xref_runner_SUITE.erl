-module(xref_runner_SUITE).
-author('elbrujohalcon@inaka.net').

-export([ all/0
        , init_per_suite/1
        , end_per_suite/1
        , undefined_function_calls/1
        , undefined_functions/1
        , locals_not_used/1
        , exports_not_used/1
        , deprecated_function_calls/1
        , deprecated_functions/1
        , ignore_xref/1
        , check_with_config_file/1
        , check_with_no_config_file/1
        , check_as_script/1
        , not_xref_register_himself/1
        , check_rebar3_build/1
        , check_rebar3_build_fail/1
        ]).

-type config() :: [{atom(), term()}].

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Common test
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

-spec all() -> [atom()].
all() ->
  Exports = ?MODULE:module_info(exports),
  [F || {F, 1} <- Exports, F /= module_info].

-spec init_per_suite(config()) -> config().
init_per_suite(Config) ->
  application:set_env(xref_runner, halt_behaviour, exception),
  Config.

-spec end_per_suite(config()) -> config().
end_per_suite(Config) ->
    Config.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Test Cases
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
-spec not_xref_register_himself(config()) -> {comment, string()}.
not_xref_register_himself(_Config) ->
  Path = filename:dirname(code:which(deprecated_functions)),
  Config = #{ dirs => [Path] },

  ct:comment("It runs"),
  spawn(xref_runner, check, [deprecated_functions, Config]),
  spawn(xref_runner, check, [deprecated_functions, Config]),
  {comment, ""}.

-spec check_rebar3_build(config()) -> {comment, string()}.
check_rebar3_build(_Config) ->
  Path = "../../lib/xref_runner/test_examples/erlang-repo",
  ct:comment("It runs"),
  {ok, OldCwd} = file:get_cwd(),
  ok = file:set_cwd(Path),
  RepoName = "erlang-repo",
  _ = rebar3_clean(RepoName),
  _ = rebar3_compile(RepoName),
  [] = xref_runner:check(),
  ok = file:set_cwd(OldCwd),
  {comment, ""}.

-spec check_rebar3_build_fail(config()) -> {comment, string()}.
check_rebar3_build_fail(_Config) ->
  Path = "../../lib/xref_runner/test_examples/erlang-repo-fail",
  ct:comment("It runs"),
  {ok, OldCwd} = file:get_cwd(),
  ok = file:set_cwd(Path),
  RepoName = "erlang-repo-fail",
  _ = rebar3_clean(RepoName),
  _ = rebar3_compile(RepoName),
  [Warning] = xref_runner:check(),

  #{ line      := 11
   , check     := undefined_function_calls
   , filename  := Filename
   , source    := {erlang_repo_fail_sup, init, 1}
   , target    := {erlang_repo_fail_app, non_exist_function, 0}
   } = Warning,

  case string:str(Filename, "erlang_repo_fail_sup.erl") of
    0 -> ct:fail("Incorrect filename: " ++ Filename);
    _ -> ok
  end,

  ok = file:set_cwd(OldCwd),
  {comment, ""}.

rebar3_clean(RepoName) ->
  os:cmd("rebar3 clean " ++ RepoName).

rebar3_compile(RepoName) ->
  os:cmd("rebar3 compile " ++ RepoName).


-spec undefined_function_calls(config()) -> {comment, string()}.
undefined_function_calls(_Config) ->
  Path = get_path("undefined_function_calls"),
  Config = #{ dirs => [Path] },

  ct:comment("It runs"),
  AllWarnings = xref_runner:check(undefined_function_calls, Config),
  Warnings =
    [W || W = #{filename := F} <- AllWarnings
        , filename:basename(F) == "undefined_function_calls.erl"],

  ct:comment(
    "It contains a warning for undefined_function_calls:undefined_here()"),
  [W1] =
    [ W || #{ line      := 7 % Where the function is defined
            , source    := {undefined_function_calls, bad, 0}
            , target    := {undefined_function_calls, undefined_here, 0}
            } = W <- Warnings],

  ct:comment(
    "It contains a warning for undefined_functions:undefined_there()"),
  [W2] =
    [ W || #{ line      := 11 % Where the function is defined
            , source    := {undefined_function_calls, bad, 1}
            , target    := {undefined_functions, undefined_there, 0}
            } = W <- Warnings],

  ct:comment(
    "It contains a warning for other_module:undefined_somewhere_else(_)"),
  [W3] =
    [ W || #{ line      := 11 % Where the function is defined
            , source    := {undefined_function_calls, bad, 1}
            , target    := {other_module, undefined_somewhere_else, 1}
            } = W <- Warnings],

  ct:comment("It contains no other warnings"),
  [] = Warnings -- [W1, W2, W3],

  {comment, ""}.

-spec undefined_functions(config()) -> {comment, string()}.
undefined_functions(_Config) ->
  Path = get_path("undefined_functions"),
  Config = #{ dirs => [Path]
            , xref_defaults => []
            },

  ct:comment("It runs"),
  AllWarnings = xref_runner:check(undefined_functions, Config),
  Warnings =
    [W || W = #{filename := F} <- AllWarnings
        , filename:basename(F) == "undefined_functions.erl"],

  ct:comment(
    "It contains a warning for undefined_functions:undefined_here()"),
  [W1] =
    [ W || #{ line      := 0 % It's a module level bug
            , source    := {undefined_functions, undefined_here, 0}
            } = W <- Warnings],

  ct:comment(
    "It contains a warning for undefined_functionse:undefined_there()"),
  [W2] =
    [ W || #{ line      := 0 % It's a module level bug
            , source    := {undefined_functions, undefined_there, 0}
            } = W <- Warnings],

  ct:comment("It contains no other warnings"),
  [] = Warnings -- [W1, W2],

  {comment, ""}.

-spec locals_not_used(config()) -> {comment, string()}.
locals_not_used(_Config) ->
  Path = get_path("locals_not_used"),
  Config = #{ dirs => [Path] },

  ct:comment("It runs"),
  AllWarnings = xref_runner:check(locals_not_used, Config),
  Warnings =
    [W || W = #{filename := F} <- AllWarnings
        , filename:basename(F) == "locals_not_used.erl"],

  ct:comment(
    "It contains a warning for locals_not_used:local_not()"),
  [W1] =
    [ W || #{ line      := 11
            , source    := {locals_not_used, local_not, 1}
            } = W <- Warnings],

  ct:comment("It contains no other warnings"),
  [] = Warnings -- [W1],

  {comment, ""}.

-spec exports_not_used(config()) -> {comment, string()}.
exports_not_used(_Config) ->
  Path = get_path("exports_not_used"),
  Config = #{ dirs => [Path] },

  ct:comment("It runs"),
  AllWarnings = xref_runner:check(exports_not_used, Config),
  Warnings =
    [W || W = #{filename := F} <- AllWarnings
        , filename:basename(F) == "exports_not_used.erl"],

  ct:comment(
    "It contains a warning for exports_not_used:export_not()"),
  [W1] =
    [ W || #{ line      := 9
            , source    := {exports_not_used, export_not, 1}
            } = W <- Warnings],

  ct:comment("It contains no other warnings"),
  [] = Warnings -- [W1],

  {comment, ""}.

-spec deprecated_function_calls(config()) -> {comment, string()}.
deprecated_function_calls(_Config) ->
  Path = get_path("deprecated_function_calls"),
  Config = #{ dirs => [Path] },

  ct:comment("It runs"),
  AllWarnings = xref_runner:check(deprecated_function_calls, Config),
  Warnings =
    [W || W = #{filename := F} <- AllWarnings
        , filename:basename(F) == "deprecated_function_calls.erl"],

  ct:comment(
    "It contains a warning for deprecated_function_calls:internal()"),
  [W1] =
    [ W || #{ line      := 10 % Where the function is defined
            , source    := {deprecated_function_calls, bad, 1}
            , target    := {deprecated_function_calls, internal, 0}
            } = W <- Warnings],

  ct:comment(
    "It contains a warning for deprecated_functions:deprecated()"),
  [W2] =
    [ W || #{ line      := 7 % Where the function is defined
            , source    := {deprecated_function_calls, bad, 0}
            , target    := {deprecated_functions, deprecated, 0}
            } = W <- Warnings],

  ct:comment(
    "It contains a warning for deprecated_functions:deprecated(_)"),
  [W3] =
    [ W || #{ line      := 10 % Where the function is defined
            , source    := {deprecated_function_calls, bad, 1}
            , target    := {deprecated_functions, deprecated, 1}
            } = W <- Warnings],

  ct:comment("It contains no other warnings"),
  [] = Warnings -- [W1, W2, W3],

  {comment, ""}.

-spec deprecated_functions(config()) -> {comment, string()}.
deprecated_functions(_Config) ->
  Path = get_path("deprecated_functions"),
  Config = #{ dirs => [Path] },

  ct:comment("It runs"),
  AllWarnings = xref_runner:check(deprecated_functions, Config),
  Warnings =
    [W || W = #{filename := F} <- AllWarnings
        , filename:basename(F) == "deprecated_functions.erl"],

  ct:comment(
    "It contains a warning for deprecated_functions:deprecated()"),
  [W1] =
    [ W || #{ line      := 8 % Where the function is defined
            , source    := {deprecated_functions, deprecated, 0}
            } = W <- Warnings],

  ct:comment(
    "It contains a warning for deprecated_functionse:deprecated_there()"),
  [W2] =
    [ W || #{ line      := 10 % Where the function is defined
            , source    := {deprecated_functions, deprecated, 1}
            } = W <- Warnings],

  ct:comment("It contains no other warnings"),
  [] = Warnings -- [W1, W2],

  {comment, ""}.

-spec ignore_xref(config()) -> {comment, string()}.
ignore_xref(_Config) ->
  Path = get_path("ignore_xref"),
  Config = #{ dirs => [Path] },

  ct:comment("It runs"),
  AllWarnings = xref_runner:check(deprecated_function_calls, Config),
  Warnings =
    [W || W = #{filename := F} <- AllWarnings
        , filename:basename(F) == "ignore_xref.erl"],

  ct:comment(
    "It contains a warning for ignore_xref:internal()"),
  [W1] =
    [ W || #{ line      := 12 % Where the function is defined
            , source    := {ignore_xref, bad, 1}
            , target    := {ignore_xref, internal, 0}
            } = W <- Warnings],

  ct:comment(
    "It contains a warning for deprecated_functions:deprecated()"),
  [W2] =
    [ W || #{ line      := 9 % Where the function is defined
            , source    := {ignore_xref, bad, 0}
            , target    := {deprecated_functions, deprecated, 0}
            } = W <- Warnings],

  ct:comment("It contains no other warnings"),
  [] = Warnings -- [W1, W2],

  {comment, ""}.

-spec check_with_no_config_file(config()) -> {comment, string()}.
check_with_no_config_file(_Config) ->

  ct:comment("Make sure there is no config"),
  false = filelib:is_regular("xref.config"),

  ct:comment("Run the checks in the wrong folder"),
  [] = xref_runner:check(),

  ct:comment("cd to the right folder"),
  {ok, OldCwd} = file:get_cwd(),
  try
    Path = get_path("ignore_xref"),
    ok = file:set_cwd(Path),

    ct:comment("Run the checks with an empty ebin folder"),
    ok =
      case filelib:is_dir("ebin") of
        true -> file:del_dir("ebin");
        false -> ok
      end,
    ok = file:make_dir("ebin"),
    [] = xref_runner:check(),

    ct:comment("Run the checks in the right folder, without ebin"),
    ok = file:del_dir("ebin"),
    Results = xref_runner:check(), %% All the warnings from the default tests
    [_|_] = [1 || #{check := undefined_function_calls} <- Results],
    [] = [1 || #{check := undefined_functions} <- Results],
    [_|_] = [1 || #{check := locals_not_used} <- Results],
    [] = [1 || #{check := exports_not_used} <- Results],
    [_|_] = [1 || #{check := deprecated_function_calls} <- Results],
    [] = [1 || #{check := deprecated_functions} <- Results],

    {comment, ""}
  after
    file:set_cwd(OldCwd)
  end.


-spec check_with_config_file(config()) -> {comment, string()}.
check_with_config_file(_Config) ->

  ct:comment("Make sure there is no config"),
  false = filelib:is_regular("xref.config"),
  false = filelib:is_regular("test-xref.config"),

  WriteConfig =
    fun(Config) ->
      file:write_file("xref.config", io_lib:format("~p.", [Config]))
    end,

  WriteTestConfig =
    fun(Config) ->
      file:write_file("test-xref.config", io_lib:format("~p.", [Config]))
    end,

  {ok, OldCwd} = file:get_cwd(),

  try
    ct:comment("Empty config works as if there is no config"),
    ok = WriteConfig([]),
    [] = xref_runner:check(),

    ct:comment("Empty list of options works as if there is no config"),
    ok = WriteConfig([{xref, []}]),
    [] = xref_runner:check(),

    ct:comment("With the proper dir, but no checks, runs default checks"),
    Path = get_path("ignore_xref"),
    ok = WriteConfig([{xref, [{config, #{dirs => [Path]}}]}]),
    AllResults = xref_runner:check(),
    [_|_] = [1 || #{check := undefined_function_calls} <- AllResults],
    [] = [1 || #{check := undefined_functions} <- AllResults],
    [_|_] = [1 || #{check := locals_not_used} <- AllResults],
    [] = [1 || #{check := exports_not_used} <- AllResults],
    [_|_] = [1 || #{check := deprecated_function_calls} <- AllResults],
    [] = [1 || #{check := deprecated_functions} <- AllResults],

    ct:comment("With the proper dir, with checks, runs only those checks"),
    ok =
      WriteConfig(
        [ { xref
          , [ {config, #{dirs => [Path]}}
            , {checks, [locals_not_used, exports_not_used]}
            ]
          }
        ] ),
    SomeResults1 = xref_runner:check(),
    [] = [1 || #{check := undefined_function_calls} <- SomeResults1],
    [] = [1 || #{check := undefined_functions} <- SomeResults1],
    [_|_] = [1 || #{check := locals_not_used} <- SomeResults1],
    [_|_] = [1 || #{check := exports_not_used} <- SomeResults1],
    [] = [1 || #{check := deprecated_function_calls} <- SomeResults1],
    [] = [1 || #{check := deprecated_functions} <- SomeResults1],

    ct:comment("With the proper dir, with checks == [], runs no check"),
    ok =
      WriteConfig(
        [ { xref
          , [ {config, #{dirs => [Path]}}
            , {checks, []}
            ]
          }
        ] ),
    [] = xref_runner:check(),

    ct:comment("With the proper dir, with checks, specifying xref.config path"),
    ok =
      WriteTestConfig(
        [ { xref
          , [ {config, #{dirs => [Path]}}
            , {checks, [locals_not_used, exports_not_used]}
            ]
          }
        ] ),
    SomeResults2 = xref_runner:check("test-xref.config"),
    [] = [1 || #{check := undefined_function_calls} <- SomeResults2],
    [] = [1 || #{check := undefined_functions} <- SomeResults2],
    [_|_] = [1 || #{check := locals_not_used} <- SomeResults2],
    [_|_] = [1 || #{check := exports_not_used} <- SomeResults2],
    [] = [1 || #{check := deprecated_function_calls} <- SomeResults2],
    [] = [1 || #{check := deprecated_functions} <- SomeResults2],

    {comment, ""}
  after
    _ = file:delete("xref.config"),
    _ = file:delete("test-xref.config"),
    file:set_cwd(OldCwd)
  end.

-spec check_as_script(config()) -> {comment, string()}.
check_as_script(_Config) ->

  ct:comment("Make sure there is no config"),
  false = filelib:is_regular("xref.config"),
  false = filelib:is_regular("test-xref.config"),

  WriteConfig =
    fun(Config) ->
      file:write_file("xref.config", io_lib:format("~p.", [Config]))
    end,

  WriteTestConfig =
    fun(Config) ->
      file:write_file("test-xref.config", io_lib:format("~p.", [Config]))
    end,

  {ok, OldCwd} = file:get_cwd(),

  try
    ct:comment("Invalid argument"),
    try xrefr:main("-g") of
      R -> ct:fail("Unexpected result ~p", [R])
    catch
      _:{halt, 64} -> ok
    end,

    ct:comment("Argument -h"),
    ok = xrefr:main("-h"),

    ct:comment("Specifying an unexistent config file with -config"),
    ok = xrefr:main("--config invalid_xref_config"),

    ct:comment("Specifying an invalid argument"),
    ok = xrefr:main("invalid-argument"),

    ct:comment("Empty config works as if there is no config"),
    ok = WriteConfig([]),
    ok = xrefr:main([]),

    ct:comment("Empty list of options works as if there is no config"),
    ok = WriteConfig([{xref, []}]),
    ok = xrefr:main([]),

    ct:comment("With the proper dir, but no checks, runs default checks"),
    Path = get_path("ignore_xref"),
    ok = WriteConfig([{xref, [{config, #{dirs => [Path]}}]}]),
    try xrefr:main([]) of
      Ret1 -> ct:fail("Unexpected result ~p", [Ret1])
    catch
      _:{halt, AllResults} ->
        [_|_] = [1 || #{check := undefined_function_calls} <- AllResults],
        [] = [1 || #{check := undefined_functions} <- AllResults],
        [_|_] = [1 || #{check := locals_not_used} <- AllResults],
        [] = [1 || #{check := exports_not_used} <- AllResults],
        [_|_] = [1 || #{check := deprecated_function_calls} <- AllResults],
        [] = [1 || #{check := deprecated_functions} <- AllResults]
    end,

    ct:comment("With the proper dir, with checks, runs only those checks"),
    ok =
      WriteConfig(
        [ { xref
          , [ {config, #{dirs => [Path]}}
            , {checks, [ undefined_functions
                       , exports_not_used
                       , deprecated_functions
                       ]}
            ]
          }
        ] ),
    try xrefr:main([]) of
      Ret2 -> ct:fail("Unexpected result ~p", [Ret2])
    catch
      _:{halt, SomeResults1} ->
        [] = [1 || #{check := undefined_function_calls} <- SomeResults1],
        [_|_] = [1 || #{check := undefined_functions} <- SomeResults1],
        [] = [1 || #{check := locals_not_used} <- SomeResults1],
        [_|_] = [1 || #{check := exports_not_used} <- SomeResults1],
        [] = [1 || #{check := deprecated_function_calls} <- SomeResults1],
        [_|_] = [1 || #{check := deprecated_functions} <- SomeResults1]
    end,

    ct:comment("With the proper dir, with checks == [], runs no check"),
    ok =
      WriteConfig(
        [ { xref
          , [ {config, #{dirs => [Path]}}
            , {checks, []}
            ]
          }
        ] ),
    ok = xrefr:main([]),

    ct:comment("With the proper dir, with checks, specifying xref.config path"),
    ok =
      WriteTestConfig(
        [ { xref
          , [ {config, #{dirs => [Path]}}
            , {checks, [locals_not_used, exports_not_used]}
            ]
          }
        ] ),
    try xrefr:main("-c test-xref.config") of
      Ret3 -> ct:fail("Unexpected result ~p", [Ret3])
    catch
      _:{halt, SomeResults2} ->
        [] = [1 || #{check := undefined_function_calls} <- SomeResults2],
        [] = [1 || #{check := undefined_functions} <- SomeResults2],
        [_|_] = [1 || #{check := locals_not_used} <- SomeResults2],
        [_|_] = [1 || #{check := exports_not_used} <- SomeResults2],
        [] = [1 || #{check := deprecated_function_calls} <- SomeResults2],
        [] = [1 || #{check := deprecated_functions} <- SomeResults2]
    end,

    {comment, ""}
  after
    _ = file:delete("xref.config"),
    _ = file:delete("test-xref.config"),
    file:set_cwd(OldCwd)
  end.

get_path(Module) ->
  [BeamPath] = filelib:wildcard("../../**/" ++ Module ++ ".beam"),
  filename:dirname(BeamPath).
