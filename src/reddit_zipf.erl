%% Zipf distribution over ranks 1..N: P(k) = (1/k^s) / H(N, s).
-module(reddit_zipf).
-export([new/2, sample/1, weight/2, prob/2, sample_distinct/2]).

new(N, S) when N > 0 ->
    Ws = [1 / math:pow(K, S) || K <- lists:seq(1, N)],
    H = lists:sum(Ws),
    {Cum, _} = lists:mapfoldl(fun(W, Acc) -> A = Acc + W / H, {A, A} end, 0.0, Ws),
    #{n => N, s => S, h => H, cum => list_to_tuple(Cum)}.

%% A rank in 1..N.
sample(#{n := N, cum := Cum}) ->
    bsearch(Cum, rand:uniform(), 1, N).

%% Smallest index I with Cum[I] >= R.
bsearch(_Cum, _R, Lo, Hi) when Lo >= Hi -> Lo;
bsearch(Cum, R, Lo, Hi) ->
    Mid = (Lo + Hi) div 2,
    case element(Mid, Cum) >= R of
        true -> bsearch(Cum, R, Lo, Mid);
        false -> bsearch(Cum, R, Mid + 1, Hi)
    end.

weight(#{s := S}, K) -> 1 / math:pow(K, S).

prob(#{h := H} = Z, K) -> weight(Z, K) / H.

%% Up to J distinct ranks.
sample_distinct(J, #{n := N} = Z) ->
    sample_distinct(min(J, N), Z, [], 20 * J + 20).

sample_distinct(J, _Z, Acc, Tries) when length(Acc) >= J; Tries =< 0 ->
    Acc;
sample_distinct(J, Z, Acc, Tries) ->
    K = sample(Z),
    case lists:member(K, Acc) of
        true -> sample_distinct(J, Z, Acc, Tries - 1);
        false -> sample_distinct(J, Z, [K | Acc], Tries - 1)
    end.
