%% Client-side access to a remote engine. A connection is a small map; every
%% request is a synchronous call to the engine worker that owns the user.
%%
%% Request tuples (all user names, sub names and texts are binaries):
%%   {register, U}                    {connect, U, Pid}   {disconnect, U}
%%   {create_sub, U, Sub}             {join_sub, U, Sub}  {leave_sub, U, Sub}
%%   {post, U, Sub, Title, Body}      {repost, U, Sub, PostId}
%%   {comment, U, ParentItemId, Body} {vote, U, ItemId, up | down | none}
%%   {get_feed, U, Limit, hot | new | top}   {get_post, U, PostId}
%%   {send_dm, U, To, Body}  {reply_dm, U, DmId, Body}  {get_dms, U, Limit}
%%   {get_karma, U}
-module(reddit_client).
-export([connect/1, conn/2, call/3]).

-define(TIMEOUT, 30000).

%% Connect to an engine node and discover its worker pool.
connect(EngineNode) ->
    pong = net_adm:ping(EngineNode),
    conn(EngineNode, erpc:call(EngineNode, reddit_engine, num_workers, [])).

conn(EngineNode, NumWorkers) ->
    Names = [reddit_engine:worker_name(I) || I <- lists:seq(1, NumWorkers)],
    #{node => EngineNode, n => NumWorkers, workers => list_to_tuple(Names)}.

call(#{node := Node, n := N, workers := Ws}, User, Req) ->
    Name = element(erlang:phash2(User, N) + 1, Ws),
    gen_server:call({Name, Node}, Req, ?TIMEOUT).
