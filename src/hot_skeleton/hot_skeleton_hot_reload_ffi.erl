-module(hot_skeleton_hot_reload_ffi).

-include_lib("kernel/include/file.hrl").

-export([cwd/0, css_path_string/0, css_cache_bust/0]).

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
