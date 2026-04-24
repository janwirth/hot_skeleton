-module(hot_skeleton_test_ffi).

-export([tcp_connect/1]).

tcp_connect(Port) ->
    case gen_tcp:connect("localhost", Port, [binary, {active, false}], 300) of
        {ok, Socket} ->
            gen_tcp:close(Socket),
            true;
        _ ->
            false
    end.
