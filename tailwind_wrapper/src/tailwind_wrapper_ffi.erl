-module(tailwind_wrapper_ffi).

-include_lib("kernel/include/file.hrl").

-export([
    cwd/0,
    absolute_path/1,
    format_tailwind_log_line/1,
    start_tailwind_watch/3,
    file_mtime_size/1,
    wait_for_css_write_complete/3,
    css_cache_bust/1,
    monotonic_ms/0
]).

-spec cwd() -> binary().
cwd() ->
    {ok, C0} = file:get_cwd(),
    case C0 of
        C when is_binary(C) -> C;
        C when is_list(C) -> unicode:characters_to_binary(C, utf8)
    end.

%% `file:get_cwd/0` may return list or binary depending on runtime.
str_to_list(S) when is_binary(S) -> binary_to_list(S);
str_to_list(S) when is_list(S) -> S.

%% Gleam passes output path as UTF-8 `String` (binary on Erlang).
-spec absolute_path(Path :: any()) -> binary().
absolute_path(PathIn) ->
    {ok, Cwd0} = file:get_cwd(),
    CwdL = str_to_list(Cwd0),
    PathB = case PathIn of
        P when is_binary(P) -> P;
        P when is_list(P) -> iolist_to_binary(P);
        _ -> <<>>
    end,
    PathL = binary_to_list(PathB),
    Abs = filename:absname(PathL, CwdL),
    unicode:characters_to_binary(Abs).

%% Relabel "Done in" -> "Tailwind:" on a CLI line (ANSI kept).
-spec format_tailwind_log_line(binary()) -> binary().
format_tailwind_log_line(Line) ->
    L1 = binary:replace(Line, <<"Done in ">>, <<"Tailwind: ">>, [global]),
    case L1 =:= Line of
        true -> binary:replace(Line, <<"Done in">>, <<"Tailwind:">>, [global]);
        false -> L1
    end.

-spec start_tailwind_watch(Exe :: binary(), Args :: [binary()], NotifyPid :: pid()) -> ok.
start_tailwind_watch(ExeBin, ArgBins, NotifyPid) when is_binary(ExeBin), is_list(ArgBins), is_pid(NotifyPid) ->
    Args = [binary_to_list(B) || B <- ArgBins],
    Exe = binary_to_list(ExeBin),
    {ok, Cwd} = file:get_cwd(),
    AbsExe = filename:absname(filename:join(Cwd, Exe)),
    _ = erlang:spawn(fun() -> tailwind_watch_init(AbsExe, Args, NotifyPid) end),
    ok.

tailwind_watch_init(Exe, Args, Pid) ->
    _ = os:putenv("FORCE_COLOR", "1"),
    case file:read_file_info(Exe) of
        {ok, #file_info{type = regular}} ->
            case open_tailwind_port(Exe, Args) of
                {ok, Port} -> tailwind_port_loop(Port, Pid);
                {error, Reason} ->
                    io:format(<<"tailwind_wrapper: open port ~p~n">>, [Reason])
            end;
        {ok, _} ->
            io:format(<<"tailwind_wrapper: not a file: ~ts~n">>, [Exe]);
        {error, _} ->
            io:format(<<"tailwind_wrapper: not found: ~ts~n">>, [Exe])
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
                    F = format_tailwind_log_line(Line),
                    Pid ! {tw_rebuild, F}
            end,
            tailwind_port_loop(Port, Pid);
        {Port, {data, {noeol, _Chunk}}} ->
            tailwind_port_loop(Port, Pid);
        {Port, eof} ->
            ok;
        {Port, {exit_status, Status}} ->
            io:format(<<"tailwind_wrapper: tailwind watch exit_status ~p~n">>, [Status]);
        _Other ->
            tailwind_port_loop(Port, Pid)
    end.

path_bin_to_list(P) when is_binary(P) -> binary_to_list(P);
path_bin_to_list(P) when is_list(P) -> P;
path_bin_to_list(_) -> "".

-spec file_mtime_size(Path :: any()) -> {integer(), integer()}.
file_mtime_size(PathIn) ->
    Path = path_bin_to_list(PathIn),
    case file:read_file_info(Path, [{time, posix}]) of
        {ok, #file_info{mtime = M, size = Sz}} when is_integer(M), is_integer(Sz) ->
            {M, Sz};
        {ok, F} ->
            {file_mtime_posix(Path), F#file_info.size};
        {error, _} ->
            {0, 0}
    end.

file_mtime_posix(Path) ->
    case file:read_file_info(Path, [{time, posix}]) of
        {ok, #file_info{mtime = Mtime}} when is_integer(Mtime) -> Mtime;
        {ok, #file_info{}} -> erlang:system_time(second);
        {error, _} -> erlang:system_time(second)
    end.

-spec css_cache_bust(Path :: any()) -> binary().
css_cache_bust(PathIn) ->
    Path = path_bin_to_list(PathIn),
    Mtime = file_mtime_posix(Path),
    list_to_binary(integer_to_list(Mtime)).

-spec wait_for_css_write_complete(Path :: any(), PreM :: integer(), PreS :: integer()) -> {integer(), integer()}.
wait_for_css_write_complete(PathIn, PreM, PreS) when is_integer(PreM), is_integer(PreS) ->
    Path = path_bin_to_list(PathIn),
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
        true -> ok;
        false -> wait_settled(Path, I + 1, Max)
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
