-module(hot_skeleton_hot_reload_ffi).

-export([cwd/0]).

cwd() ->
    {ok, Cwd} = file:get_cwd(),
    unicode:characters_to_binary(Cwd).
