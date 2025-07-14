%% Copyright (c) 2016, Yuce Tekol <yucetekol@gmail.com>.
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

-module(nats_msg).
-author("Yuce Tekol").
%% -compile([bin_opt_info]).
-compile({no_auto_import, [get/1]}).

-export([init/0,
         encode/1,
         decode/1,
         decode/2,
         decode_all/1]).

-export([ping/0,
         pong/0,
         ok/0,
         err/1,
         info/1,
         connect/1,
         pub/1,
         pub/3,
         hpub/1,
         hpub/3,
         hpub/4,
         sub/2,
         sub/3,
         unsub/1,
         unsub/2,
         msg/2,
         msg/4,
         hmsg/2,
         hmsg/4,
         hmsg/5]).
-export([js_metadata/1]).

-define(SEP, <<" ">>).
-define(NL, <<"\r\n">>).
-define(SEPLIST, [<<" ">>, <<"\t">>]).

-type error_atom() :: unknown_operation |
                      auth_violation |
                      auth_timeout |
                      parser_error |
                      stale_connection |
                      slow_consumer |
                      max_payload |
                      invalid_subject.

-type error_param() :: {error, error_atom()}.

-type pub_param() :: {pub, {Subject :: iodata(),
                            ReplyTo :: iodata() | undefined,
                            Payload :: iodata()}}.

-type hpub_param() :: {hpub, {Subject :: iodata(),
                              ReplyTo :: iodata() | undefined,
                              Header :: iodata(),
                              Payload :: iodata()}}.

-type sub_param() :: {sub, {Subject :: iodata(),
                            QueueGrp :: iodata() | undefined,
                            Sid :: iodata()}}.

-type unsub_param() :: {unsub, {Sid :: iodata(),
                                MaxMsg :: integer() | undefined}}.

-type msg_param() :: {msg, {Subject :: iodata(),
                            Sid :: iodata(),
                            ReplyTo :: iodata() | undefined,
                            Payload :: iodata()}}.

-type hmsg_param() :: {hmsg, {Subject :: iodata(),
                              Sid :: iodata(),
                              ReplyTo :: iodata() | undefined,
                              Header :: iodata(),
                              Payload :: iodata()}}.

-type encode_param() :: ping | pong | ok | error |
                        {info, iodata()} | {connect, iodata()} |
                        error_param() |
                        pub_param() | hpub_param() |
                        sub_param() | unsub_param() |
                        msg_param() | hmsg_param().

%% == API

-spec init() -> ok.
-doc """
Initializes the nats_msg module.
""".
init() ->
    lists:foreach(fun get/1, [nats_msg@nl, nats_msg@sep, nats_msg@topic]),
    ok.

init(nats_msg@nl) -> binary:compile_pattern(<<"\r\n">>);
init(nats_msg@sep) -> binary:compile_pattern(<<" ">>);
init(nats_msg@topic) -> binary:compile_pattern(<<".">>).

get(Key) ->
    try persistent_term:get({?MODULE, Key})
    catch
        error:badarg ->
            Value = init(Key),
            persistent_term:put({?MODULE, Key}, Value),
            Value
    end.

%% == Encode API

-spec ping() -> iolist().
-doc """
Encodes a PING keep-alive message.
""".
ping() -> encode(ping).

-spec pong() -> iolist().
-doc """
Encodes a PONG keep-alive response.
""".
pong() -> encode(pong).

-spec ok() -> iolist().
-doc """
Encodes a +OK acknowledgement message.
""".
ok() -> encode(ok).

-spec err(Msg :: error_atom()) -> iolist().
-doc """
Encodes an -ERR message indicating a protocol error.
""".
err(Msg) -> encode({error, Msg}).

-spec info(Info :: iodata()) -> iolist().
-doc """
Encodes an INFO message sent by the server to provide connection information.
The argument is the JSON info payload.
""".
info(Info) -> encode({info, Info}).

-spec connect(Info :: iodata()) -> iolist().
-doc """
Encodes a CONNECT message sent by the client to provide connection details and security information.
The argument is the JSON connect options payload.
""".
connect(Info) -> encode({connect, Info}).

-spec pub(Subject :: iodata()) -> iolist().
-doc """
Encodes a PUB message to publish data to a subject with an empty payload.
""".
pub(Subject) ->
    encode({pub, {Subject, undefined, <<>>}}).

-spec pub(Subject :: iodata(), ReplyTo :: iodata() | undefined, Payload :: iodata()) -> iolist().
-doc """
Encodes a PUB message to publish data to a subject, optionally including a reply subject.
""".
pub(Subject, ReplyTo, Payload) ->
    encode({pub, {Subject, ReplyTo, Payload}}).

-spec hpub(Subject :: iodata()) -> iolist().
-doc """
Encodes an HPUB message to publish data with headers to a subject with empty header and payload.
""".
hpub(Subject) ->
    encode({hpub, {Subject, undefined, <<>>, <<>>}}).

-spec hpub(Subject :: iodata(), Header :: iodata(), Payload :: iodata()) -> iolist().
-doc """
Encodes an HPUB message to publish data with headers to a subject.
""".
hpub(Subject, Header, Payload) ->
    encode({hpub, {Subject, undefined, Header, Payload}}).

-spec hpub(Subject :: iodata(), ReplyTo :: iodata() | undefined, Header :: iodata(), Payload :: iodata()) -> iolist().
-doc """
Encodes an HPUB message to publish data with headers to a subject, optionally including a reply subject.
""".
hpub(Subject, ReplyTo, Header, Payload) ->
    encode({hpub, {Subject, ReplyTo, Header, Payload}}).

-spec sub(Subject :: iodata(), Sid :: iodata()) -> iolist().
-doc """
Encodes a SUB message to subscribe to a subject.
""".
sub(Subject, Sid) ->
    encode({sub, {Subject, undefined, Sid}}).

-spec sub(Subject :: iodata(), QueueGrp :: iodata() | undefined, Sid :: iodata()) -> iolist().
-doc """
Encodes a SUB message to subscribe to a subject, optionally joining a queue group.
""".
sub(Subject, QueueGrp, Sid) ->
    encode({sub, {Subject, QueueGrp, Sid}}).

-spec unsub(Sid :: iodata()) -> iolist().
-doc """
Encodes an UNSUB message to unsubscribe from a subject.
""".
unsub(Sid) ->
    encode({unsub, {Sid, undefined}}).

-spec unsub(Sid :: iodata(), MaxMsg :: integer() | undefined) -> iolist().
-doc """
Encodes an UNSUB message to unsubscribe from a subject after a certain number of messages.
""".
unsub(Sid, MaxMsg) ->
    encode({unsub, {Sid, MaxMsg}}).

-spec msg(Subject :: iodata(), Sid :: iodata()) -> iolist().
-doc """
Encodes a MSG message with no reply-to and empty payload.
""".
msg(Subject, Sid) ->
    encode({msg, {Subject, Sid, undefined, <<>>}}).

-spec msg(Subject :: iodata(), Sid :: iodata(), ReplyTo :: iodata() | undefined, Payload :: iodata()) -> iolist().
-doc """
Encodes a MSG message.
""".
msg(Subject, Sid, ReplyTo, Payload) ->
    encode({msg, {Subject, Sid, ReplyTo, Payload}}).

-spec hmsg(Subject :: iodata(), Sid :: iodata()) -> iolist().
-doc """
Encodes an HMSG message with no reply-to, empty header, and empty payload.
""".
hmsg(Subject, Sid) ->
    encode({hmsg, {Subject, Sid, undefined, <<>>, <<>>}}).

-spec hmsg(Subject :: iodata(), Sid :: iodata(), Header :: iodata(), Payload :: iodata()) -> iolist().
-doc """
Encodes an HMSG message with no reply-to.
""".
hmsg(Subject, Sid, Header, Payload) ->
    encode({hmsg, {Subject, Sid, undefined, Header, Payload}}).

-spec hmsg(Subject :: iodata(), Sid :: iodata(), ReplyTo :: iodata() | undefined, Header :: iodata(), Payload :: iodata()) -> iolist().
-doc """
Encodes an HMSG message.
""".
hmsg(Subject, Sid, ReplyTo, Header, Payload) ->
    encode({hmsg, {Subject, Sid, ReplyTo, Header, Payload}}).

-spec encode(Param :: encode_param()) -> iolist().
-doc """
Encodes an Erlang term representing a NATS protocol message into an iolist suitable for sending over the wire.
""".

encode(ping) -> <<"PING\r\n">>;
encode(pong) -> <<"PONG\r\n">>;
encode(ok) -> <<"+OK\r\n">>;
encode({error, unknown_operation}) -> <<"-ERR 'Unknown Protocol Operation'\r\n">>;
encode({error, auth_violation}) -> <<"-ERR 'Authorization Violation'\r\n">>;
encode({error, auth_timeout}) -> <<"-ERR 'Authorization Timeout'\r\n">>;
encode({error, parser_error}) -> <<"-ERR 'Parser Error'\r\n">>;
encode({error, stale_connection}) -> <<"-ERR 'Stale Connection'\r\n">>;
encode({error, slow_consumer}) -> <<"-ERR 'Slow Consumer'\r\n">>;
encode({error, max_payload}) -> <<"-ERR 'Maximum Payload Exceeded'\r\n">>;
encode({error, invalid_subject}) -> <<"-ERR 'Invalid Subject'\r\n">>;
encode({info, BinInfo}) -> [<<"INFO ">>, BinInfo, <<"\r\n">>];
encode({connect, BinConnect}) -> [<<"CONNECT ">>, BinConnect, <<"\r\n">>];

encode({pub, {Subject, undefined, Payload}}) ->
    BinPS = integer_to_binary(iodata_size(Payload)),
    [<<"PUB ">>, Subject, <<" ">>, BinPS, <<"\r\n">>,
     Payload, <<"\r\n">>];

encode({pub, {Subject, ReplyTo, Payload}}) ->
    BinPS = integer_to_binary(iodata_size(Payload)),
    [<<"PUB ">>, Subject, <<" ">>, ReplyTo, <<" ">>, BinPS, <<"\r\n">>,
     Payload, <<"\r\n">>];

encode({hpub, {Subject, undefined, Header, Payload}}) ->
    BinHdrS = integer_to_binary(iodata_size(Header) + 2),
    BinPS = integer_to_binary(iodata_size(Header) + 2 + iodata_size(Payload)),
    [<<"HPUB ">>, Subject, <<" ">>, BinHdrS, <<" ">>, BinPS, <<"\r\n">>,
     Header, <<"\r\n">>, Payload, <<"\r\n">>];

encode({hpub, {Subject, ReplyTo, Header, Payload}}) ->
    BinHdrS = integer_to_binary(iodata_size(Header) + 2),
    BinPS = integer_to_binary(iodata_size(Header) + 2 + iodata_size(Payload)),
    [<<"HPUB ">>, Subject, <<" ">>, ReplyTo, <<" ">>, BinHdrS, <<" ">>, BinPS, <<"\r\n">>,
     Header, <<"\r\n">>, Payload, <<"\r\n">>];

encode({sub, {Subject, undefined, Sid}}) ->
    [<<"SUB ">>, Subject, <<" ">>, Sid, <<"\r\n">>];

encode({sub, {Subject, QueueGrp, Sid}}) ->
    [<<"SUB ">>, Subject, <<" ">>, QueueGrp, <<" ">>, Sid, <<"\r\n">>];

encode({unsub, {Subject, undefined}}) ->
    [<<"UNSUB ">>, Subject, <<"\r\n">>];

encode({unsub, {Subject, MaxMsg}}) ->
    BinMaxMsg = integer_to_binary(MaxMsg),
    [<<"UNSUB ">>, Subject, <<" ">>, BinMaxMsg, <<"\r\n">>];

encode({msg, {Subject, Sid, undefined, Payload}}) ->
    BinPS = integer_to_binary(iodata_size(Payload)),
    [<<"MSG ">>, Subject, <<" ">>, Sid, <<" ">>, BinPS, <<"\r\n">>,
     Payload, <<"\r\n">>];

encode({msg, {Subject, Sid, ReplyTo, Payload}}) ->
    BinPS = integer_to_binary(iodata_size(Payload)),
    [<<"MSG ">>, Subject, <<" ">>, Sid, <<" ">>, ReplyTo, <<" ">>, BinPS, <<"\r\n">>,
     Payload, <<"\r\n">>];

encode({hmsg, {Subject, Sid, undefined, Header, Payload}}) ->
    BinHdrS = integer_to_binary(iodata_size(Header) + 2),
    BinPS = integer_to_binary(iodata_size(Header) + 2 + iodata_size(Payload)),
    [<<"HMSG ">>, Subject, <<" ">>, Sid, <<" ">>, BinHdrS, <<" ">>, BinPS, <<"\r\n">>,
     Header, <<"\r\n">>, Payload, <<"\r\n">>];

encode({hmsg, {Subject, Sid, ReplyTo, Header, Payload}}) ->
    BinHdrS = integer_to_binary(iodata_size(Header) + 2),
    BinPS = integer_to_binary(iodata_size(Header) + 2 + iodata_size(Payload)),
    [<<"HMSG ">>, Subject, <<" ">>, Sid, <<" ">>, ReplyTo, <<" ">>, BinHdrS, <<" ">>, BinPS, <<"\r\n">>,
     Header, <<"\r\n">>, Payload, <<"\r\n">>].

%% == Decode API

-spec decode_all(Bin :: iodata()) -> {list(), binary()}.
-doc """
Decodes all complete NATS protocol messages found in the input binary.
Returns a list of decoded messages and any remaining binary data.
""".
decode_all(Bin) ->
    decode(Bin, {fun decode_all_msg_fun/2, []}).

-spec decode(Param :: iodata()) ->
          {term(), binary()}.
-doc """
Decodes a binary or iolist containing NATS protocol messages.
Stops after the first complete message is decoded.
Returns the decoded message term and any remaining binary data.
""".
decode(L) when is_list(L) ->
    decode(iolist_to_binary(L));
decode(Bin) when is_binary(Bin) ->
    decode(Bin, {fun decode_single_msg_fun/2, []}).

decode_single_msg_fun(stop, State) ->
    {stop, State};
decode_single_msg_fun(Ev, _) ->
    {stop, Ev}.

decode_all_msg_fun(stop, Acc) ->
    {stop, lists:reverse(Acc)};
decode_all_msg_fun(Ev, Acc) ->
    {continue, [Ev|Acc]}.

return(<<Rest/binary>>, State) ->
    {State, Rest}.

decode_cont(<<Rest/binary>>, {CbFun, CbState}, Ev) ->
    case CbFun(Ev, CbState) of
        {stop, NextState} ->
            return(Rest, NextState);
        {continue, NextState} ->
            decode(Rest, {CbFun, NextState})
    end.

-spec decode(Bin :: iodata(), CbFunState :: {function(), term()}) -> {term(), binary()}.
-doc """
Decodes a binary or iolist containing NATS protocol messages using a callback function to handle decoded events.
The callback function is called with `(Event, State)` and should return `{continue, NewState}` or `{stop, FinalState}`.
Returns the final state returned by the callback and any remaining binary data.
""".
decode(<<_:0/binary>>, CbFunState) ->
    decode_cont(<<>>, CbFunState, stop);
decode(<<"+OK\r\n", Rest/binary>>, CbFunState) ->
    decode_cont(Rest, CbFunState, ok);
decode(<<"PING\r\n", Rest/binary>>, CbFunState) ->
    decode_cont(Rest, CbFunState, ping);
decode(<<"PONG\r\n", Rest/binary>>, CbFunState) ->
    decode_cont(Rest, CbFunState, pong);

decode(<<"-ERR 'Unknown Protocol Operation'\r\n", Rest/binary>>, CbFunState) ->
    decode_cont(Rest, CbFunState, {error, unknown_operation});
decode(<<"-ERR 'Authorization Violation'\r\n", Rest/binary>>, CbFunState) ->
    decode_cont(Rest, CbFunState, {error, auth_violation});
decode(<<"-ERR 'Authorization Timeout'\r\n", Rest/binary>>, CbFunState) ->
    decode_cont(Rest, CbFunState, {error, auth_timeout});
decode(<<"-ERR 'Parser Error'\r\n", Rest/binary>>, CbFunState) ->
    decode_cont(Rest, CbFunState, {error, parser_error});
decode(<<"-ERR 'Stale Connection'\r\n", Rest/binary>>, CbFunState) ->
    decode_cont(Rest, CbFunState, {error, stale_connection});
decode(<<"-ERR 'Slow Consumer'\r\n", Rest/binary>>, CbFunState) ->
    decode_cont(Rest, CbFunState, {error, slow_consumer});
decode(<<"-ERR 'Maximum Payload Exceeded'\r\n", Rest/binary>>, CbFunState) ->
    decode_cont(Rest, CbFunState, {error, max_payload});
decode(<<"-ERR 'Invalid Subject'\r\n", Rest/binary>>, CbFunState) ->
    decode_cont(Rest, CbFunState, {error, invalid_subject});

decode(<<"MSG ", Rest/binary>> = OrigMsg, CbFunState) ->
    case parts(Rest) of
        [L4, L3, L2, L1] ->
            <<Subject:L1/bytes, " ", Sid:L2/bytes, " ", ReplyTo:L3/bytes, " ", BinPS:L4/bytes, "\r\n", More/binary>> = Rest,
            PS = binary_to_integer(BinPS),
            case More of
                <<Payload:PS/binary, "\r\n", Next/binary>> ->
                    decode_cont(Next, CbFunState, {msg, {Subject, Sid, ReplyTo, Payload}});
                _ ->
                    decode_cont(OrigMsg, CbFunState, stop)
            end;
        [L3, L2, L1] ->
            <<Subject:L1/bytes, " ", Sid:L2/bytes, " ", BinPS:L3/bytes, "\r\n", More/binary>> = Rest,
            PS = binary_to_integer(BinPS),
            case More of
                <<Payload:PS/binary, "\r\n", Next/binary>> ->
                    decode_cont(Next, CbFunState, {msg, {Subject, Sid, undefined, Payload}});
                _ ->
                    decode_cont(OrigMsg, CbFunState, stop)
            end;
        eof ->
            decode_cont(OrigMsg, CbFunState, stop);
        _ ->
            throw(parse_error)
    end;

decode(<<"HMSG ", Rest/binary>> = OrigMsg, CbFunState) ->
    case parts(Rest) of
        [L5, L4, L3, L2, L1] ->
            <<Subject:L1/bytes, " ", Sid:L2/bytes, " ", ReplyTo:L3/bytes, " ",
              BinHdrS:L4/bytes, " ", BinTotS:L5/bytes, "\r\n", More/binary>> = Rest,
            HdrS = binary_to_integer(BinHdrS) - 2,
            PS = binary_to_integer(BinTotS) - HdrS - 2,
            case More of
                <<Header:HdrS/bytes, "\r\n", Payload:PS/binary, "\r\n", Next/binary>> ->
                    decode_cont(Next, CbFunState, {hmsg, {Subject, Sid, ReplyTo, Header, Payload}});
                _ ->
                    decode_cont(OrigMsg, CbFunState, stop)
            end;
        [L4, L3, L2, L1] ->
            <<Subject:L1/bytes, " ", Sid:L2/bytes, " ",
              BinHdrS:L3/bytes, " ", BinTotS:L4/bytes, "\r\n", More/binary>> = Rest,
            HdrS = binary_to_integer(BinHdrS) - 2,
            PS = binary_to_integer(BinTotS) - HdrS - 2,
            case More of
                <<Header:HdrS/bytes, "\r\n", Payload:PS/binary, "\r\n", Next/binary>> ->
                    decode_cont(Next, CbFunState, {hmsg, {Subject, Sid, undefined, Header, Payload}});
                _ ->
                    decode_cont(OrigMsg, CbFunState, stop)
            end;
        eof ->
            decode_cont(OrigMsg, CbFunState, stop);
        _ ->
            throw(parse_error)
    end;
decode(<<"PUB ", Rest/binary>> = OrigMsg, CbFunState) ->
    case parts(Rest) of
        [L3, L2, L1] ->
            <<Subject:L1/bytes, " ", ReplyTo:L2/bytes, " ", BinPS:L3/bytes, "\r\n", More/binary>> = Rest,
            PS = binary_to_integer(BinPS),
            case More of
                <<Payload:PS/binary, "\r\n", Next/binary>> ->
                    decode_cont(Next, CbFunState, {pub, {Subject, ReplyTo, Payload}});
                _ ->
                    decode_cont(OrigMsg, CbFunState, stop)
            end;
        [L2, L1] ->
            <<Subject:L1/bytes, " ", BinPS:L2/bytes, "\r\n", More/binary>> = Rest,
            PS = binary_to_integer(BinPS),
            case More of
                <<Payload:PS/binary, "\r\n", Next/binary>> ->
                    decode_cont(Next, CbFunState, {pub, {Subject, undefined, Payload}});
                _ ->
                    decode_cont(OrigMsg, CbFunState, stop)
            end;
        eof ->
            decode_cont(OrigMsg, CbFunState, stop);
        _ ->
            throw(parse_error)
    end;

decode(<<"HPUB ", Rest/binary>> = OrigMsg, CbFunState) ->
    case parts(Rest) of
        [L4, L3, L2, L1] ->
            <<Subject:L1/bytes, " ", ReplyTo:L2/bytes, " ", BinHdrS:L3/bytes, " ", BinTotS:L4/bytes, "\r\n", More/binary>> = Rest,
            HdrS = binary_to_integer(BinHdrS) - 2,
            PS = binary_to_integer(BinTotS) - HdrS - 2,
            case More of
                <<Header:HdrS/bytes, "\r\n", Payload:PS/binary, "\r\n", Next/binary>> ->
                    decode_cont(Next, CbFunState, {hpub, {Subject, ReplyTo, Header, Payload}});
                _ ->
                    decode_cont(OrigMsg, CbFunState, stop)
            end;
        [L3, L2, L1] ->
            <<Subject:L1/bytes, " ", BinHdrS:L2/bytes, " ", BinTotS:L3/bytes, "\r\n", More/binary>> = Rest,
            HdrS = binary_to_integer(BinHdrS) - 2,
            PS = binary_to_integer(BinTotS) - HdrS - 2,
            case More of
                <<Header:HdrS/bytes, "\r\n", Payload:PS/binary, "\r\n", Next/binary>> ->
                    decode_cont(Next, CbFunState, {hpub, {Subject, undefined, Header, Payload}});
                _ ->
                    decode_cont(OrigMsg, CbFunState, stop)
            end;
        eof ->
            decode_cont(OrigMsg, CbFunState, stop);
        _ ->
            throw(parse_error)
    end;

decode(<<"SUB ", Rest/binary>> = OrigMsg, CbFunState) ->
    case parts(Rest) of
        [L3, L2, L1] ->
            <<Subject:L1/bytes, " ", QueueGrp:L2/bytes, " ", Sid:L3/bytes, "\r\n", Next/binary>> = Rest,
            decode_cont(Next, CbFunState, {sub, {Subject, QueueGrp, Sid}});
        [L2, L1] ->
            <<Subject:L1/bytes, " ", Sid:L2/bytes, "\r\n", Next/binary>> = Rest,
            decode_cont(Next, CbFunState, {sub, {Subject, undefined, Sid}});
        eof ->
            decode_cont(OrigMsg, CbFunState, stop);
        _ ->
            throw(parse_error)
    end;

decode(<<"UNSUB ", Rest/binary>> = OrigMsg, CbFunState) ->
    case parts(Rest) of
        [L2, L1] ->
            <<Subject:L1/bytes, " ", BinMaxMsg:L2/bytes, "\r\n", Next/binary>> = Rest,
            decode_cont(Next, CbFunState, {unsub, {Subject, binary_to_integer(BinMaxMsg)}});
        [L1] ->
            <<Subject:L1/bytes, "\r\n", Next/binary>> = Rest,
            decode_cont(Next, CbFunState, {unsub, {Subject, undefined}});
        eof ->
            decode_cont(OrigMsg, CbFunState, stop);
        _ ->
            throw(parse_error)
    end;

decode(<<"CONNECT ", Rest/binary>> = OrigMsg, CbFunState) ->
    case binary:split(Rest, get(nats_msg@nl)) of
        [Info, More] ->
            decode_cont(More, CbFunState, {connect, Info});
        _ ->
            decode_cont(OrigMsg, CbFunState, stop)
    end;

decode(<<"INFO ", Rest/binary>> = OrigMsg, CbFunState) ->
    case binary:split(Rest, get(nats_msg@nl)) of
        [Info, More] ->
            decode_cont(More, CbFunState, {info, Info});
        _ ->
            decode_cont(OrigMsg, CbFunState, stop)
    end;

decode(Other, CbFunState) ->
    decode_cont(Other, CbFunState, stop).

%% == Internal - decode

parts(Bin) ->
    parts(Bin, 0, []).

parts(<<>>, _, _) ->
    eof;
parts(<<"\r\n", _Rest/binary>>, Cnt, Acc) ->
    [Cnt | Acc];
parts(<<" ", Rest/binary>>, Cnt, Acc) ->
    parts(Rest, 0, [Cnt | Acc]);
parts(<<_:8, Rest/binary>>, Cnt, Acc) ->
    parts(Rest, Cnt + 1, Acc).

iodata_size(List) when is_list(List) ->
    iolist_size(List);
iodata_size(Bin) when is_binary(Bin) ->
    byte_size(Bin).

%% == reply metadata

js_metadata(<<"$JS.ACK.", Topic/binary>>) ->
    ack_metadata(binary:split(Topic, get(nats_msg@topic), [global]));
js_metadata(_) ->
    {error, invalid_subject_format}.

ack_metadata([Stream, Consumer, Delivered, SSeq, CSeq, TM, Pending]) ->
    %% Subject without domain:
    %% $JS.ACK.<stream>.<consumer>.<delivered>.<sseq>.<cseq>.<tm>.<pending>
    Meta = #{stream_seq => binary_to_integer(SSeq),
             consumer_seq => binary_to_integer(CSeq),
             num_delivered => binary_to_integer(Delivered),
             num_pending => binary_to_integer(Pending),
             timestamp => binary_to_integer(TM),
             stream => Stream,
             consumer => Consumer},
    {ok, Meta};
ack_metadata([Domain, Hash, Stream, Consumer, Delivered, SSeq, CSeq, TM, Pending | _]) ->
    %% New subject with domain
    %% $JS.ACK.<domain>.<account hash>.<stream>.<consumer>.<delivered>.<sseq>.<cseq>.<tm>.<pending>.<a token with a random value>
    %% the last field, token, might be removed in the future is not used
    Meta =
        #{hash => Hash,
          stream_seq => binary_to_integer(SSeq),
          consumer_seq => binary_to_integer(CSeq),
          num_delivered => binary_to_integer(Delivered),
          num_pending => binary_to_integer(Pending),
          timestamp => binary_to_integer(TM),
          stream => Stream,
          consumer => Consumer},
    case Domain of
        ~"_" ->
            {ok, Meta};
        _ ->
            {ok, Meta#{domain => Domain}}
    end;
ack_metadata(_) ->
    {error, invalid_subject_format}.

%% upper_case(Bin) ->
%%     list_to_binary(string:to_upper(binary_to_list(Bin))).

%% == Tests

-ifdef(TEST).
-include_lib("eunit/include/eunit.hrl").

setup() ->
    io:format("setup called"),
    nats_msg:init().

%% == Encode Tests

ping_test() ->
    R = ping(),
    E = <<"PING\r\n">>,
    ?assertEqual(E, R).

pong_test() ->
    R = pong(),
    E = <<"PONG\r\n">>,
    ?assertEqual(E, R).

ok_test() ->
    R = ok(),
    E = <<"+OK\r\n">>,
    ?assertEqual(E, R).

err_test() ->
    R = err(auth_timeout),
    E = <<"-ERR 'Authorization Timeout'\r\n">>,
    ?assertEqual(E, R).

info_test() ->
    R = iolist_to_binary(info(<<"{\"auth_required\":true,\"server_id\":\"0001-SERVER\"}">>)),
    E = <<"INFO {\"auth_required\":true,\"server_id\":\"0001-SERVER\"}\r\n">>,
    ?assertEqual(E, R).

connect_test() ->
    R = iolist_to_binary(connect(<<"{\"name\":\"sample-client\",\"verbose\":true}">>)),
    E = <<"CONNECT {\"name\":\"sample-client\",\"verbose\":true}\r\n">>,
    ?assertEqual(E, R).

pub_1_test() ->
    R = iolist_to_binary(pub(<<"NOTIFY">>)),
    E = <<"PUB NOTIFY 0\r\n\r\n">>,
    ?assertEqual(E, R).

pub_2_test() ->
    R = iolist_to_binary(pub(<<"FRONT.DOOR">>, <<"INBOX.22">>, <<"Knock Knock">>)),
    E = <<"PUB FRONT.DOOR INBOX.22 11\r\nKnock Knock\r\n">>,
    ?assertEqual(E, R).

hpub_1_test() ->
    R = iolist_to_binary(hpub(<<"FOO">>, <<"NATS/1.0\r\nBar: Baz\r\n">>, <<"Hello NATS!">>)),
    E = <<"HPUB FOO 22 33\r\nNATS/1.0\r\nBar: Baz\r\n\r\nHello NATS!\r\n">>,
    ?assertEqual(E, R).

hpub_2_test() ->
    R = iolist_to_binary(hpub(<<"FRONT.DOOR">>, <<"JOKE.22">>, <<"NATS/1.0\r\nBREAKFAST: donut\r\nLUNCH: burger\r\n">>, <<"Knock Knock">>)),
    E = <<"HPUB FRONT.DOOR JOKE.22 45 56\r\nNATS/1.0\r\nBREAKFAST: donut\r\nLUNCH: burger\r\n\r\nKnock Knock\r\n">>,
    ?assertEqual(E, R).

hpub_3_test() ->
    R = iolist_to_binary(hpub(<<"NOTIFY">>, <<"NATS/1.0\r\nBar: Baz\r\n">>,<<>>)),
    E = <<"HPUB NOTIFY 22 22\r\nNATS/1.0\r\nBar: Baz\r\n\r\n\r\n">>,
    ?assertEqual(E, R).

hpub_4_test() ->
    R = iolist_to_binary(hpub(<<"MORNING.MENU">>, <<"NATS/1.0\r\nBREAKFAST: donut\r\nBREAKFAST: eggs\r\n">>, <<"Yum!">>)),
    E = <<"HPUB MORNING.MENU 47 51\r\nNATS/1.0\r\nBREAKFAST: donut\r\nBREAKFAST: eggs\r\n\r\nYum!\r\n">>,
    ?assertEqual(E, R).

sub_1_test() ->
    R = iolist_to_binary(sub(<<"FOO">>, <<"1">>)),
    E = <<"SUB FOO 1\r\n">>,
    ?assertEqual(E, R).

sub_2_test() ->
    R = iolist_to_binary(sub(<<"BAR">>, <<"G1">>, <<"44">>)),
    E = <<"SUB BAR G1 44\r\n">>,
    ?assertEqual(E, R).

unsub_1_test() ->
    R = iolist_to_binary(unsub(<<"1">>)),
    E = <<"UNSUB 1\r\n">>,
    ?assertEqual(E, R).

unsub_2_test() ->
    R = iolist_to_binary(unsub(<<"1">>, 10)),
    E = <<"UNSUB 1 10\r\n">>,
    ?assertEqual(E, R).

msg_4_test() ->
    R = iolist_to_binary(msg(<<"FOO.BAR">>, <<"9">>, <<"INBOX.34">>, <<"Hello, World!">>)),
    E = <<"MSG FOO.BAR 9 INBOX.34 13\r\nHello, World!\r\n">>,
    ?assertEqual(E, R).

hmsg_1_test() ->
    R = iolist_to_binary(hmsg(<<"FOO.BAR">>, <<"9">>, undefined,
                              <<"NATS/1.0\r\nFoodGroup: vegetable\r\n">>,
                              <<"Hello World">>)),
    E = <<"HMSG FOO.BAR 9 34 45\r\nNATS/1.0\r\nFoodGroup: vegetable\r\n\r\nHello World\r\n">>,
    ?assertEqual(E, R).

hmsg_2_test() ->
    R = iolist_to_binary(hmsg(<<"FOO.BAR">>,<<"9">>,<<"BAZ.69">>,
                              <<"NATS/1.0\r\nFoodGroup: vegetable\r\n">>,
                              <<"Hello World">>)),
    E = <<"HMSG FOO.BAR 9 BAZ.69 34 45\r\nNATS/1.0\r\nFoodGroup: vegetable\r\n\r\nHello World\r\n">>,
    ?assertEqual(E, R).

%% == Decode Tests

dec_ping_test() ->
    {ping, <<>>} = decode(<<"PING\r\n">>).

dec_pong_test() ->
    {pong, <<>>} = decode(<<"PONG\r\n">>).

dec_ok_test() ->
    {ok, <<>>} = decode(<<"+OK\r\n">>).

dec_err_test() ->
    R = decode(<<"-ERR 'Authorization Timeout'\r\n">>),
    E = {{error, auth_timeout}, <<>>},
    ?assertEqual(E, R).

dec_info_test() ->
    setup(),
    {{info, Info}, <<>>} = decode(<<"INFO {\"auth_required\":true,\"server_id\":\"0001-SERVER\"}\r\n">>),
    Info = <<"{\"auth_required\":true,\"server_id\":\"0001-SERVER\"}">>.

dec_connect_test() ->
    setup(),
    R = decode(<<"CONNECT {\"name\":\"sample-client\",\"verbose\":true}\r\n">>),
    E = {{connect, <<"{\"name\":\"sample-client\",\"verbose\":true}">>}, <<>>},
    ?assertEqual(E, R).

dec_pub_1_test() ->
    R = decode(<<"PUB NOTIFY 0\r\n\r\n">>),
    E = {{pub, {<<"NOTIFY">>, undefined, <<>>}}, <<>>},
    ?assertEqual(E, R).

dec_pub_2_test() ->
    R = decode(<<"PUB FOO 11\r\nHello NATS!\r\n">>),
    E = {{pub, {<<"FOO">>, undefined, <<"Hello NATS!">>}}, <<>>},
    ?assertEqual(E, R).

dec_pub_3_test() ->
    R = decode(<<"PUB FRONT.DOOR INBOX.22 11\r\nKnock Knock\r\n">>),
    E = {{pub, {<<"FRONT.DOOR">>, <<"INBOX.22">>, <<"Knock Knock">>}}, <<>>},
    ?assertEqual(E, R).

dec_hpub_1_test() ->
    R = decode(<<"HPUB FOO 22 33\r\nNATS/1.0\r\nBar: Baz\r\n\r\nHello NATS!\r\n">>),
    E = {{hpub, {<<"FOO">>, undefined,
                 <<"NATS/1.0\r\nBar: Baz\r\n">>, <<"Hello NATS!">>}}, <<>>},
    ?assertEqual(E, R).

dec_hpub_2_test() ->
    R = decode(<<"HPUB FRONT.DOOR JOKE.22 45 56\r\nNATS/1.0\r\nBREAKFAST: donut\r\nLUNCH: burger\r\n\r\nKnock Knock\r\n">>),
    E = {{hpub, {<<"FRONT.DOOR">>, <<"JOKE.22">>,
                 <<"NATS/1.0\r\nBREAKFAST: donut\r\nLUNCH: burger\r\n">>,
                 <<"Knock Knock">>}}, <<>>},
    ?assertEqual(E, R).

dec_hpub_3_test() ->
    R = decode(<<"HPUB NOTIFY 22 22\r\nNATS/1.0\r\nBar: Baz\r\n\r\n\r\n">>),
    E = {{hpub, {<<"NOTIFY">>, undefined,
                 <<"NATS/1.0\r\nBar: Baz\r\n">>,<<>>}}, <<>>},
    ?assertEqual(E, R).

dec_hpub_4_test() ->
    R = decode(<<"HPUB MORNING.MENU 47 51\r\nNATS/1.0\r\nBREAKFAST: donut\r\nBREAKFAST: eggs\r\n\r\nYum!\r\n">>),
    E = {{hpub, {<<"MORNING.MENU">>, undefined,
                 <<"NATS/1.0\r\nBREAKFAST: donut\r\nBREAKFAST: eggs\r\n">>, <<"Yum!">>}}, <<>>},
    ?assertEqual(E, R).

dec_sub_1_test() ->
    R = decode(<<"SUB FOO 1\r\n">>),
    E = {{sub, {<<"FOO">>, undefined, <<"1">>}}, <<>>},
    ?assertEqual(E, R).

dec_sub_2_test() ->
    R = decode(<<"SUB BAR G1 44\r\n">>),
    E = {{sub,{<<"BAR">>,<<"G1">>,<<"44">>}}, <<>>},
    ?assertEqual(E, R).

dec_unsub_1_test() ->
    R = decode(<<"UNSUB 1\r\n">>),
    E = {{unsub, {<<"1">>, undefined}}, <<>>},
    ?assertEqual(E, R).

dec_unsub_2_test() ->
    R = decode(<<"UNSUB 1 10\r\n">>),
    E = {{unsub, {<<"1">>, 10}}, <<>>},
    ?assertEqual(E, R).

dec_msg_1_test() ->
    R = decode(<<"MSG FOO.BAR 9 13\r\nHello, World!\r\n">>),
    E = {{msg, {<<"FOO.BAR">>, <<"9">>, undefined, <<"Hello, World!">>}}, <<>>},
    ?assertEqual(E, R).

dec_msg_2_test() ->
    R = decode(<<"MSG FOO.BAR 9 INBOX.34 13\r\nHello, World!\r\n">>),
    E = {{msg, {<<"FOO.BAR">>, <<"9">>, <<"INBOX.34">>, <<"Hello, World!">>}}, <<>>},
    ?assertEqual(E, R).

dec_hmsg_1_test() ->
    R = decode(<<"HMSG FOO.BAR 9 34 45\r\nNATS/1.0\r\nFoodGroup: vegetable\r\n\r\nHello World\r\n">>),
    E = {{hmsg, {<<"FOO.BAR">>, <<"9">>, undefined,
                 <<"NATS/1.0\r\nFoodGroup: vegetable\r\n">>,
                 <<"Hello World">>}}, <<>>},
    ?assertEqual(E, R).

dec_hmsg_2_test() ->
    R = decode(<<"HMSG FOO.BAR 9 BAZ.69 34 45\r\nNATS/1.0\r\nFoodGroup: vegetable\r\n\r\nHello World\r\n">>),
    E = {{hmsg, {<<"FOO.BAR">>,<<"9">>,<<"BAZ.69">>,
                 <<"NATS/1.0\r\nFoodGroup: vegetable\r\n">>,
                 <<"Hello World">>}}, <<>>},
    ?assertEqual(E, R).

dec_many_lines_test() ->
    R = decode(<<"PING\r\nMSG FOO.BAR 9 INBOX.34 13\r\nHello, World!\r\n">>),
    E = {ping, <<"MSG FOO.BAR 9 INBOX.34 13\r\nHello, World!\r\n">>},
    ?assertEqual(E, R).

dec_nl_in_payload_test() ->
    R = decode(<<"PUB FOO 12\r\nHello\r\nNATS!\r\n">>),
    E = {{pub, {<<"FOO">>, undefined, <<"Hello\r\nNATS!">>}}, <<>>},
    ?assertEqual(E, R).

dec_incomplete_payload_test() ->
    R = decode(<<"PUB FOO 12\r\nHello\r\nNATS!">>),
    E = {[], <<"PUB FOO 12\r\nHello\r\nNATS!">>},
    ?assertEqual(E, R).

dec_all_messages_1_test() ->
    R = decode_all(<<"+OK\r\nPING\r\nM">>),
    E = {[ok, ping], <<"M">>},
    ?assertEqual(E, R).

dec_all_messages_2_test() ->
    R = decode_all(<<"INFO {\"server_id\":\"b379e32c3cd3dd8515c919a42d813eaf\",\"version\":\"0.7.2\",\"go\":\"go1.5.2\",\"host\":\"127.0.0.1\",\"port\":4222,\"auth_required\":false,\"ssl_required\":false,\"tls_required\":false,\"tls_verify\":false,\"max_payload\":1048576} \r\n">>),
    E = {[{info, <<"{\"server_id\":\"b379e32c3cd3dd8515c919a42d813eaf\",\"version\":\"0.7.2\",\"go\":\"go1.5.2\",\"host\":\"127.0.0.1\",\"port\":4222,\"auth_required\":false,\"ssl_required\":false,\"tls_required\":false,\"tls_verify\":false,\"max_payload\":1048576} ">>}], <<>>},
    ?assertEqual(E, R).

%% == Other Tests

decode_encode_1_test() ->
    E = <<"MSG FOO.BAR 9 INBOX.34 13\r\nHello, World!\r\n">>,
    {R1, _} = decode(E),
    io:format("R1: ~p~n", [R1]),
    R2 = iolist_to_binary(encode(R1)),
    ?assertEqual(E, R2).

%% == JS metadata

decode_v1_metadata_test() ->
    Want = #{stream => <<"KV_ERGW_SESSIONS">>,
             timestamp => 1747382905538829661,
             stream_seq => 33312,
             consumer_seq => 2,
             num_delivered => 1,
             num_pending => 1,
             consumer => <<"80KyLl05">>},
    {ok, V1} = nats_msg:js_metadata(~"$JS.ACK.KV_ERGW_SESSIONS.80KyLl05.1.33312.2.1747382905538829661.1"),
    ?assertEqual(Want, V1).

decode_v2_metadata_test() ->
    Want1 = #{stream => <<"KV_ERGW_SESSIONS">>,
              timestamp => 1747382905538829661,
              stream_seq => 33312,
              consumer_seq => 2,
              num_delivered => 1,
              num_pending => 1,
              consumer => <<"80KyLl05">>,
              domain => <<"DOMAIN">>,
              hash => <<"HASH">>},
    {ok, V2_1} = nats_msg:js_metadata(~"$JS.ACK.DOMAIN.HASH.KV_ERGW_SESSIONS.80KyLl05.1.33312.2.1747382905538829661.1"),
    ?assertEqual(Want1, V2_1),
    {ok, V2_2} = nats_msg:js_metadata(~"$JS.ACK.DOMAIN.HASH.KV_ERGW_SESSIONS.80KyLl05.1.33312.2.1747382905538829661.1.TOKEN"),
    ?assertEqual(Want1, V2_2),

    Want2 = #{stream => <<"KV_ERGW_SESSIONS">>,
              timestamp => 1747382905538829661,
              stream_seq => 33312,
              consumer_seq => 2,
              num_delivered => 1,
              num_pending => 1,
              consumer => <<"80KyLl05">>,
              hash => <<"HASH">>},
    {ok, V2_3} = nats_msg:js_metadata(~"$JS.ACK._.HASH.KV_ERGW_SESSIONS.80KyLl05.1.33312.2.1747382905538829661.1"),
    ?assertEqual(Want2, V2_3),
    {ok, V2_4} = nats_msg:js_metadata(~"$JS.ACK._.HASH.KV_ERGW_SESSIONS.80KyLl05.1.33312.2.1747382905538829661.1.TOKEN"),
    ?assertEqual(Want2, V2_4).

-endif.
