-module(hot_skeleton_hot_reload_ffi).

-include_lib("kernel/include/file.hrl").

-export([
    cwd/0,
    css_path_string/0,
    css_cache_bust/0,
    css_path_mtime_size/0,
    wait_for_css_write_complete/2,
    monotonic_ms/0,
    start_tailwind_watch/3
]).

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

%% Before/after a Tailwind run: mtime+size in one tuple for the Gleam side.
-spec css_path_mtime_size() -> {integer(), integer()}.
css_path_mtime_size() ->
    Path = binary_to_list(css_path_string()),
    case file:read_file_info(Path, [{time, posix}]) of
        {ok, #file_info{mtime = M, size = Sz}} when is_integer(M), is_integer(Sz) ->
            {M, Sz};
        {ok, F} ->
            M = file_mtime_posix(Path),
            {M, F#file_info.size};
        {error, _} ->
            {0, 0}
    end.

%% After `tailwind` exits, poll until mtime+size differ, then two matching stats.
%% Returns `{WaitChangedMs, WaitSettledMs}` for dev timing logs.
-spec wait_for_css_write_complete(PreMtime :: integer(), PreSize :: integer()) ->
    {integer(), integer()}.
wait_for_css_write_complete(PreM, PreS) when is_integer(PreM), is_integer(PreS) ->
    Path = binary_to_list(css_path_string()),
    T0 = erlang:monotonic_time(millisecond),
    ok = wait_changed(Path, PreM, PreS, 0, 200),
    T1 = erlang:monotonic_time(millisecond),
    ok = wait_settled(Path, 0, 100),
    T2 = erlang:monotonic_time(millisecond),
    {T1 - T0, T2 - T1}.

-spec monotonic_ms() -> integer().
monotonic_ms() ->
    erlang:monotonic_time(millisecond).

wait_changed(_Path, _PreM, _PreS, I, Max) when I >= Max ->
    ok;
wait_changed(Path, PreM, PreS, I, Max) when I < Max ->
    case read_mtime_size(Path) of
        {M, S} when M =/= PreM orelse S =/= PreS ->
            ok;
        _ ->
            timer:sleep(2),
            wait_changed(Path, PreM, PreS, I + 1, Max)
    end.

wait_settled(_Path, I, Max) when I >= Max ->
    ok;
wait_settled(Path, I, Max) when I < Max ->
    S1 = read_mtime_size(Path),
    timer:sleep(2),
    S2 = read_mtime_size(Path),
    case S1 =:= S2 of
        true ->
            ok;
        false ->
            wait_settled(Path, I + 1, Max)
    end.

read_mtime_size(Path) ->
    case file:read_file_info(Path, [{time, posix}]) of
        {ok, #file_info{mtime = M, size = S}} when is_integer(M), is_integer(S) ->
            {M, S};
        {ok, F} ->
            {file_mtime_posix(Path), F#file_info.size};
        {error, _} ->
            {0, 0}
    end.

%% `tailwindcss` prints lines like "Done in 26ms" (stdout merged from port).
%% Relabel to <<"Tailwind: ">>/<<"Tailwind:">> so timing, checkmarks, and ANSI
%% on the line stay in place. `os:putenv("FORCE_COLOR", "1")` in init so the
%% CLI still emits color when not a TTY.
-spec format_tailwind_log_line(binary()) -> binary().
format_tailwind_log_line(Line) ->
    L1 = binary:replace(Line, <<"Done in ">>, <<"Tailwind: ">>, [global]),
    case L1 =:= Line of
        true -> binary:replace(Line, <<"Done in">>, <<"Tailwind:">>, [global]);
        false -> L1
    end.

%% Spawn `tailwindcss` with `-w=always` and a port; on each line containing
%% <<"Done in">>, notify Gleam: `{hot_skeleton_tailwind_rebuilt, Line}` and
%% print the line with "Done in" relabeled to "Tailwind:" (same bytes elsewhere).
%% Args are the same paths as the one-shot CLI (`-i=`, `-o=`) from Gleam.
-spec start_tailwind_watch(Exe :: binary(), Args :: [binary()], NotifyPid :: pid()) -> ok.
start_tailwind_watch(ExeBin, ArgBins, NotifyPid) when is_binary(ExeBin), is_list(ArgBins), is_pid(NotifyPid) ->
    Args = [binary_to_list(B) || B <- ArgBins],
    Exe = binary_to_list(ExeBin),
    {ok, Cwd} = file:get_cwd(),
    AbsExe = filename:absname(filename:join(Cwd, Exe)),
    _ = erlang:spawn(fun() -> tailwind_watch_init(AbsExe, Args, NotifyPid) end),
    ok.

tailwind_watch_init(Exe, Args, Pid) ->
    %% Merging {env, [...]} into open_port replaced the *entire* child env; use
    %% putenv so PATH and the rest of the parent environment still apply.
    _ = os:putenv("FORCE_COLOR", "1"),
    case file:read_file_info(Exe) of
        {ok, #file_info{type = regular}} ->
            case open_tailwind_port(Exe, Args) of
                {ok, Port} -> tailwind_port_loop(Port, Pid);
                {error, Reason} -> io:format(<<"hot_skeleton: tailwind watch: ~p~n">>, [Reason])
            end;
        {ok, _} ->
            io:format(<<"hot_skeleton: not a file: ~ts~n">>, [Exe]);
        {error, _} ->
            io:format(<<"hot_skeleton: tailwind not found: ~ts~n">>, [Exe])
    end.

open_tailwind_port(Exe, Args) ->
    try
        Port = erlang:open_port(
            {spawn_executable, Exe},
            [
                {args, Args},
                stream,
                {line, 65535},
                binary,
                exit_status,
                stderr_to_stdout,
                hide,
                eof
            ]
        ),
        {ok, Port}
    catch
        _:Reason ->
            {error, Reason}
    end.

tailwind_port_loop(Port, Pid) ->
    receive
        {Port, {data, {eol, Line}}} ->
            case binary:match(Line, <<"Done in">>) of
                nomatch ->
                    ok;
                _ ->
                    Pid ! {hot_skeleton_tailwind_rebuilt, Line},
                    _ = io:put_chars([format_tailwind_log_line(Line), <<"\n">>])
            end,
            tailwind_port_loop(Port, Pid);
        {Port, {data, {noeol, _Chunk}}} ->
            tailwind_port_loop(Port, Pid);
        {Port, eof} ->
            ok;
        {Port, {exit_status, Status}} ->
            io:format(<<"hot_skeleton: tailwind watch exit_status ~p~n">>, [Status]);
        _Other ->
            tailwind_port_loop(Port, Pid)
    end.
