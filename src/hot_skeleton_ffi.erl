-module(hot_skeleton_ffi).

-export([first_free_tcp_port/2]).

%% Walk [First, Last] inclusive: bind 0.0.0.0:Port, close, return {ok, Port} on
%% first success, or {error, nil} if none. Only eaddrinuse tries the next port.
-spec first_free_tcp_port(integer(), integer()) -> {ok, integer()} | {error, nil}.
first_free_tcp_port(First, Last) when is_integer(First), is_integer(Last), First =< Last ->
    case try_range(First, Last) of
        {ok, _} = Ok -> Ok;
        {error, _} -> {error, nil}
    end;
first_free_tcp_port(_First, _Last) ->
    {error, nil}.

try_range(P, Last) when P =< Last ->
    case try_listen_one(P) of
        ok -> {ok, P};
        eaddrinuse -> try_range(P + 1, Last);
        {error, _} = E -> E
    end;
try_range(_P, _Last) ->
    {error, eunavailable}.

try_listen_one(Port) ->
    Opts = [
        binary,
        {packet, raw},
        {active, false},
        {reuseaddr, true},
        {ip, {0, 0, 0, 0}}
    ],
    case gen_tcp:listen(Port, Opts) of
        {ok, S} ->
            Result =
                case inet:port(S) of
                    {ok, P} when P =:= Port -> ok;
                    _ -> {error, port_mismatch}
                end,
            gen_tcp:close(S),
            Result;
        {error, eaddrinuse} -> eaddrinuse;
        {error, eacces} -> {error, eacces};
        {error, enfile} -> {error, enfile};
        {error, emfile} -> {error, emfile};
        {error, Other} -> {error, Other}
    end.
