-module(hot_skeleton_hot_reload_ffi).

-include_lib("kernel/include/file.hrl").

-export([cwd/0, css_path_string/0, css_cache_bust/0, spawn_tailwind_watcher/2, os_is_unix/0]).

-define(CSS_NAME, "tailwind.css").
-define(OUT_DIR, ".hot_skeleton").

-spec cwd() -> binary().
cwd() ->
    {ok, C} = file:get_cwd(),
    unicode:characters_to_binary(C).

-spec css_path_string() -> binary().
css_path_string() ->
    {ok, C} = file:get_cwd(),
    P = filename:join(unicode:characters_to_list(C), filename:join(?OUT_DIR, ?CSS_NAME)),
    iolist_to_binary(P).

-spec css_cache_bust() -> binary().
css_cache_bust() ->
    Path = binary_to_list(css_path_string()),
    Mtime = file_mtime_posix(Path),
    list_to_binary(integer_to_list(Mtime)).

file_mtime_posix(Path) ->
    case file:read_file_info(Path, [{time, posix}]) of
        {ok, #file_info{mtime = Mtime}} when is_integer(Mtime) ->
            Mtime;
        {ok, #file_info{}} ->
            erlang:system_time(second);
        {error, _} ->
            erlang:system_time(second)
    end.

%% Unix: run Tailwind watch with stdin from /dev/null so the process never reads
%% the same TTY as the dev shell. Otherwise (after ctrl+c) keyboard input can
%% be split between the shell and a leftover watch child (fewer and fewer
%% characters echoing in the shell).
-spec os_is_unix() -> boolean().
os_is_unix() ->
    case os:type() of
        {win32, _} -> false;
        _ -> true
    end.

%% @param Exe  UTF-8 path to the tailwind binary (relative to cwd is fine).
%% @param Argv  UTF-8 argument list, same as `tailwind:run/1` would use.
-spec spawn_tailwind_watcher(Exe :: binary(), Argv :: [binary()]) -> nil.
spawn_tailwind_watcher(Exe, Argv) when is_binary(Exe), is_list(Argv) ->
    {ok, Cwd0} = file:get_cwd(),
    CwdL = binary_to_list(unicode:characters_to_binary(Cwd0)),
    ExeL = binary_to_list(unicode:characters_to_binary(Exe)),
    ArgL = [binary_to_list(unicode:characters_to_binary(B)) || B <- Argv],
    Null = null_device(),
    ArgPart = string:join(ArgL, " "),
    %% Port `cd` sets cwd; sh runs: exec with stdin from null and stderr merged.
    Inner = lists:concat([
        "exec ", squote(ExeL), " ", ArgPart, " <", Null, " 2>&1"
    ]),
    _ = erlang:spawn(fun() ->
        Port = open_port(
            {spawn_executable, "/bin/sh"},
            [stream, stderr_to_stdout, exit_status, hide, in, {args, ["-c", Inner]}, {cd, CwdL}]
        ),
        _ = tailwind_port_drain(Port, []),
        ok
    end),
    nil.

null_device() ->
    case os:type() of
        {win32, _} -> "NUL";
        _ -> "/dev/null"
    end.

squote(S) when is_list(S) ->
    "'" ++ squote_h(S) ++ "'".

squote_h([]) ->
    [];
squote_h([$' | T]) ->
    "'\\''" ++ squote_h(T);
squote_h([C | T]) ->
    [C] ++ squote_h(T).

%% Like shellout non-LetBeStdout stream collect, but do not `io:format` to the
%% group leader (avoids TTY line noise; matches prior `tailwind.run` in spawn).
tailwind_port_drain(Port, SoFar) ->
    receive
        {Port, {data, {Flag, Bytes}}} when Flag =:= eol; Flag =:= noeol ->
            tailwind_port_drain(Port, [SoFar | Bytes]);
        {Port, {data, Bytes}} when is_binary(Bytes) ->
            tailwind_port_drain(Port, [SoFar, Bytes]);
        {Port, {data, Bytes}} when is_list(Bytes) ->
            tailwind_port_drain(Port, [SoFar | Bytes]);
        {Port, eof} ->
            Port ! {self(), close},
            receive
                {Port, closed} ->
                    true
            end,
            receive
                {'EXIT', Port, _} ->
                    ok
            after
                1 -> ok
            end,
            receive
                {Port, {exit_status, _Code}} ->
                    ok
            end,
            _ = iolist_to_binary(lists:flatten(SoFar)),
            ok
    end.
