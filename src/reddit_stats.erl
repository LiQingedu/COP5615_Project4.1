%% Mergeable latency statistics.
%%
%% Per operation we keep {Count, SumMicros, MaxMicros, Histogram}. The
%% histogram has power-of-two buckets: bucket 1 holds 0 us, bucket B >= 2
%% holds [2^(B-2), 2^(B-1)) us. Each simulated user records locally (no
%% shared state on the hot path) and the maps are merged at the end.
-module(reddit_stats).
-export([record/3, merge/2, combine/1, percentile/2, avg/1, bump/2, bump/3, merge_counts/2]).

-define(NB, 40).

record(Op, Us, Stats) ->
    {C, S, M, H} = case Stats of
                       #{Op := V} -> V;
                       _ -> {0, 0, 0, erlang:make_tuple(?NB, 0)}
                   end,
    B = bucket(Us),
    Stats#{Op => {C + 1, S + Us, max(M, Us), setelement(B, H, element(B, H) + 1)}}.

bucket(Us) when Us =< 0 -> 1;
bucket(Us) -> min(?NB, bits(Us, 0) + 1).

bits(0, N) -> N;
bits(X, N) -> bits(X bsr 1, N + 1).

merge(A, B) ->
    maps:fold(fun(Op, V, Acc) ->
                      case Acc of
                          #{Op := W} -> Acc#{Op => add(V, W)};
                          _ -> Acc#{Op => V}
                      end
              end, A, B).

combine([V | Vs]) -> lists:foldl(fun add/2, V, Vs).

add({C1, S1, M1, H1}, {C2, S2, M2, H2}) ->
    H = lists:zipwith(fun erlang:'+'/2, tuple_to_list(H1), tuple_to_list(H2)),
    {C1 + C2, S1 + S2, max(M1, M2), list_to_tuple(H)}.

avg({0, _, _, _}) -> 0.0;
avg({C, S, _, _}) -> S / C.

%% Approximate P-th percentile (0 < P =< 1), interpolated inside a bucket.
percentile({0, _, _, _}, _P) -> 0;
percentile({C, _, Max, H}, P) ->
    walk(tuple_to_list(H), 1, 0, P * C, Max).

walk([N | Rest], B, Cum, Target, Max) ->
    case N > 0 andalso Cum + N >= Target of
        true ->
            Lo = lo(B),
            Hi = min(hi(B), Max),
            round(min(Max, Lo + (Hi - Lo) * (Target - Cum) / N));
        false ->
            walk(Rest, B + 1, Cum + N, Target, Max)
    end;
walk([], _, _, _, Max) ->
    Max.

lo(1) -> 0;
lo(B) -> 1 bsl (B - 2).

hi(1) -> 0;
hi(B) -> 1 bsl (B - 1).

bump(Key, Map) -> bump(Key, 1, Map).
bump(Key, N, Map) -> maps:update_with(Key, fun(V) -> V + N end, N, Map).

merge_counts(A, B) ->
    maps:fold(fun(K, V, Acc) -> bump(K, V, Acc) end, A, B).
