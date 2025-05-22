%% Copyright (c) 2024, Travelping GmbH <info@travelping.com>.
%% All rights reserved.
%%
%% Redistribution and use in source and binary forms, with or without
%% modification, are permitted provided that the following conditions are
%% met:
%%
%% * Redistributions of source code must retain the above copyright
%%   notice, this list of conditions and the following disclaimer.
%%
%% * Redistributions in binary form must reproduce the above copyright
%%   notice, this list of conditions and the following disclaimer in the
%%   documentation and/or other materials provided with the distribution.
%%
%% * The names of its contributors may not be used to endorse or promote
%%   products derived from this software without specific prior written
%%   permission.
%%
%% THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
%% "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
%% LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
%% A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
%% OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
%% SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
%% LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
%% DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
%% THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
%% (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
%% OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

-module(nats_hd).
%% -compile([bin_opt_info]).

-export([header/2, header/1, headers/1]).
-export([parse_headers/1]).

-type status() :: 100..999.
-export_type([status/0]).

-type headers() :: [{binary(), iodata()}].
-export_type([headers/0]).

-define(NL, ~"\r\n").

-spec header(status() | binary(), headers()) -> iolist().
header(Status, Headers) ->
    [version(), ~" ", status(Status), ?NL, headers(Headers)].

-spec header(headers()) -> iolist().
header(Headers) ->
    [version(), ?NL, headers(Headers)].

-spec headers(headers()) -> iolist().
headers(Headers) ->
    [[N, ~": ", V, ?NL] || {N, V} <- Headers].

version() ->
    ~"NATS/1.0".

status(X) when is_integer(X) ->
    integer_to_binary(X);
status(X) when is_binary(X) ->
    X.

%% @doc Parse the list of headers.
%% copied from cowlib

-spec parse_headers(binary()) -> [{binary(), binary()}].
parse_headers(Data) ->
    parse_header(Data, []).

parse_header(<<>>, Acc) ->
    lists:reverse(Acc);
parse_header(<<Data/binary>>, Acc) ->
    parse_hd_name(Data, Acc, <<>>).

parse_hd_name(<<>>, Acc, << $\r, $\n>>) ->
    parse_header(<<>>, Acc);
parse_hd_name(<< C, Rest/binary >>, Acc, SoFar) ->
    case C of
        $: -> parse_hd_before_value(Rest, Acc, SoFar);
        $\s -> parse_hd_name_ws(Rest, Acc, SoFar);
        $\t -> parse_hd_name_ws(Rest, Acc, SoFar);
        _ -> parse_hd_name(Rest, Acc, <<SoFar/binary, C>>)
    end.

parse_hd_name_ws(<< C, Rest/binary >>, Acc, Name) ->
    case C of
        $: -> parse_hd_before_value(Rest, Acc, Name);
        $\s -> parse_hd_name_ws(Rest, Acc, Name);
        $\t -> parse_hd_name_ws(Rest, Acc, Name)
    end.

parse_hd_before_value(<< $\s, Rest/binary >>, Acc, Name) ->
    parse_hd_before_value(Rest, Acc, Name);
parse_hd_before_value(<< $\t, Rest/binary >>, Acc, Name) ->
    parse_hd_before_value(Rest, Acc, Name);
parse_hd_before_value(Data, Acc, Name) ->
    parse_hd_value(Data, Acc, Name, <<>>).

parse_hd_value(<< $\r, $\n, Rest/binary >>, Acc, Name, SoFar) ->
    Value = clean_value_ws_end(SoFar, byte_size(SoFar) - 1),
    parse_header(Rest, [{Name, Value}|Acc]);
parse_hd_value(<< C, Rest/binary >>, Acc, Name, SoFar) ->
    parse_hd_value(Rest, Acc, Name, << SoFar/binary, C >>).

%% This function has been copied from cowboy_http.
clean_value_ws_end(_, -1) ->
    <<>>;
clean_value_ws_end(Value, N) ->
    case binary:at(Value, N) of
        $\s -> clean_value_ws_end(Value, N - 1);
        $\t -> clean_value_ws_end(Value, N - 1);
        _ ->
            S = N + 1,
            << Value2:S/binary, _/binary >> = Value,
            Value2
    end.
