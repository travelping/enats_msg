# enats_msg

Forked from https://github.com/yuce/nats_msg and renamed to enats_msg.

**enats_msg** is a pure Erlang NATS message encoder/decoder library for
[NATS](http://nats.io/) high performance messaging platform.
For details about NATS protocol, see:
[NATS Protocol](http://nats.io/documentation/internals/nats-protocol). It doesn't
have any dependency other than Erlang/OTP (27+ *should* be OK) and optionally
[rebar3](http://www.rebar3.org/).

## Install

**enats_msg** uses [rebar3](http://www.rebar3.org/) to build and tests and
it is available on [hex.pm](https://hex.pm/). Just include the following
in your `rebar.config`:

```erlang
{deps, [enats_msg]}.
```

## Tests

Run the tests using:

    $ rebar3 eunit

## Build

    $ rebar3 compile

## Usage

> ### IMPORTANT! {: .info}
>
> Before running any decoding functions, `nats_msg:init/0` must be called once.

Binaries and iodata are used exclusively throughout the library.

Currently, no error handling is performed during encoding/decoding. You can protect
against crashes by wrapping library functions between `try...catch`.

`INFO` and `CONNECT` messages have a JSON object as their parameter; but in order to
not introduce a dependency, **enats_msg** does not encode/decode JSON objects. These parameters
are kept or returned as binaries. You can use [jsx](https://github.com/talentdeficit/jsx),
[jiffy](https://github.com/davisp/jiffy) or Erlang/OTP 23+ [json](https://www.erlang.org/doc/apps/stdlib/json.html)
to deal with JSON. See the **INFO** and **CONNECT** sections in this document for examples.

### Encoding

Encoding a message produces an IO list. `nats_msg:encode/1` takes an atom as the name of the
message or a tuple which contains the name, parameters and payload of the message.

The general form of `nats_msg:encode/1` parameters is:

* `Name :: atom()`: For messages taking no parameters,
* `{Name :: atom(), Parameters :: {iodata() | int(), ...}}` for messages taking parameters but
not a payload,
* `{Name :: atom(), Parameters :: {iodata() | int(), ...}, Payload :: iodata()}` for messages
taking parameters and a payload.

Messages of the same type always have the same structure, even if some of the values are
`undefined`. Some examples:

* `nats_msg:encode(ping)` produces a `PING` message,
* `nats_msg:encode({sub, {<<"INBOX">>, undefined, <<"2">>}}` produces a `SUB` message with
subject `<<"INBOX">>` and SID `<<"2">>`. This particular message has no *queue group*, so
that field is set to `undefined`.
* `nats_msg:encode({pub, {<<"FOO">>, undefined, 11}, <<"Hello NATS!">>}` produces a `PUB` message
with subject `<<"FOO">>` and payload `<<"Hello NATS!">>` of size `11` and no *reply to* subject.

The library has convenience functions for all messages, like `nats_msg:ping/0`, which are
discussed later in this document.

### Decoding

Decoding a binary/iodata produces a `{Message, RemainingBinary}` tuple.
`Message` is either `[]` if the data is not sufficient to decode the message, or the a term for the message,
and `RemainingBinary` is the part of the input which
wasn't decoded and returned. The latter is very useful when dealing with streams, where
the input is chunked and appending chunks is required to be able to decode messages.
In those situations, just prepend `RemainingBinary` to the next binary chunk before attempting
to decode it.

The `Message`  be used as an input to `nats_msg:encode`, like:

<!-- tabs-open -->

### Erlang

```erlang
SomeBinary = ...
{Msg, Remaining} = nats_msg:decode(SomeBinary),
ReEncodedBinary = nats_msg:encode(Msg),
```

### Elixir

```elixir
some_binary = ...
{msg, remaining} = :nats_msg.decode(some_binary)
re_encoded_binary = :nats_msg.encode(msg)
```

<!-- tabs-close -->

### INFO Message

[NATS Spec](http://nats.io/documentation/internals/nats-protocol/#INFO)

#### Encode

<!-- tabs-open -->

### Erlang

```erlang
ServerInfo = #{<<"auth_required">> => true, <<"server_id">> => <<"0001-SERVER">>},
BinaryInfo = json:encode(ServerInfo),
BinaryMsg = nats_msg:info(BinaryInfo).
```

### Elixir

```elixir
server_info = %{"auth_required" => true, "server_id" => "0001-SERVER"}
binary_info = Jason.encode!(server_info)
binary_msg = :nats_msg.info(binary_info)
```

<!-- tabs-close -->

#### Decode

<!-- tabs-open -->

### Erlang

```erlang
Chunk = <<"INFO {\"auth_required\":true,\"server_id\":\"0001-SERVER\"}\r\n">>,
{Msg, _} = nats_msg:decode(Chunk),
{info, BinaryInfo} = Msg,
ServerInfo = jsx:decode(BinaryInfo, [return_maps]).
```

### Elixir

```elixir
chunk = "INFO {\"auth_required\":true,\"server_id\":\"0001-SERVER\"}\r\n"
{msg, _} = :nats_msg.decode(chunk)
{:info, binary_info} = msg
server_info = Jason.decode!(binary_info, keys: :atoms)
```

<!-- tabs-close -->

### CONNECT Message

[NATS Spec](http://nats.io/documentation/internals/nats-protocol/#CONNECT)

#### Encode

<!-- tabs-open -->

### Erlang

```erlang
ConnectInfo = #{<<"auth_required">> => true, <<"server_id">> => <<"0001-SERVER">>},
BinaryInfo = jsx:encode(ConnectInfo),
BinaryMsg = nats_msg:connect(BinaryInfo).
```

### Elixir

```elixir
connect_info = %{"auth_required" => true, "server_id" => "0001-SERVER"}
binary_info = Jason.encode!(connect_info)
binary_msg = :nats_msg.connect(binary_info)
```

<!-- tabs-close -->

#### Decode

<!-- tabs-open -->

### Erlang

```erlang
Chunk = <<"CONNECT {\"verbose\":true,\"name\":\"the_client\"}\r\n">>,
{Msg, _} = nats_msg:decode(Chunk),
{connect, BinaryInfo} = Msg,
ClientInfo = jsx:decode(BinaryInfo, [return_maps]).
```

### Elixir

```elixir
chunk = "CONNECT {\"verbose\":true,\"name\":\"the_client\"}\r\n"
{:connect, binary_info} = :nats_msg.decode(chunk)
client_info = Jason.decode!(binary_info)
```

<!-- tabs-close -->

### PUB Message

[NATS Spec](http://nats.io/documentation/internals/nats-protocol/#PUB)

#### Encode

Notify subscribers of a subject:

<!-- tabs-open -->

### Erlang

```erlang
BinaryMsg = nats_msg:pub(<<"NOTIFY.INBOX">>).
```

### Elixir

```elixir
binary_msg = :nats_msg.pub("NOTIFY.INBOX")
```

<!-- tabs-close -->

Send some data (*payload*) to subscribers, providing a *reply* subject:

<!-- tabs-open -->

### Erlang

```erlang
BinaryMsg = nats_msg:pub(<<"FOOBAR">>, <<"REPRAP">>, <<"Hello, World!">>).
```

### Elixir

```elixir
binary_msg = :nats_msg.pub("FOOBAR", "REPRAP", "Hello, World!")
```

<!-- tabs-close -->

Send some data (*payload*) to subscribers (*without a reply subject*):

<!-- tabs-open -->

### Erlang

```erlang
BinaryMsg = nats_msg:pub(<<"FOOBAR">>, undefined, <<"Hello, World!">>).
```

### Elixir

```elixir
binary_msg = :nats_msg.pub("FOOBAR", :undefined, "Hello, World!")
```

<!-- tabs-close -->

### Decode

Publish notification:

<!-- tabs-open -->

### Erlang

```erlang
Chunk = <<"PUB NOTIFY 0\r\n\r\n">>,
{Msg, _} = nats_msg:decode(Chunk),
{pub, {Subject, ReplyTo, Payload}} = Msg,
% Subject = <<"NOTIFY">>,
% ReplyTo = undefined,
% Payload = <<>>.
```

### Elixir

```elixir
chunk = "PUB NOTIFY 0\r\n\r\n"
{msg, _} = :nats_msg.decode(chunk)
{:pub, {subject, reply_to, payload}} = msg
# ^subject = "NOTIFY"
# ^reply_to = :undefined
# ^payload = ""
```

<!-- tabs-close -->

Publish message with subject, replier and payload:

<!-- tabs-open -->

### Erlang

```erlang
Chunk = <<"PUB FRONT.DOOR INBOX.22 11\r\nKnock Knock\r\n">>,
{Msg, _} = nats_msg:decode(Chunk),
{pub, {Subject, ReplyTo, Payload}} = Msg,
% Subject = <<"FRONT.DOOR">>,
% ReplyTo = <<"INBOX.22">>,
% Payload = <<"Knock Knock">>.
```

### Elixir

```elixir
chunk = "PUB FRONT.DOOR INBOX.22 11\r\nKnock Knock\r\n"
{msg, _} = :nats_msg.decode(chunk)
{:pub, {subject, reply_to, payload}} = msg
# ^subject = "FRONT.DOOR"
# ^reply_to = "INBOX.22"
# ^payload = "Knock Knock"
```

<!-- tabs-close -->

### HPUB Message

[NATS Spec](http://nats.io/documentation/internals/nats-protocol/#HPUB)

#### Encode

Notify subscribers of a subject:

<!-- tabs-open -->

### Erlang

```erlang
BinaryMsg = nats_msg:hpub(<<"NOTIFY.INBOX">>).
```

### Elixir

```elixir
binary_msg = :nats_msg.hpub("NOTIFY.INBOX")
```

<!-- tabs-close -->

Send some data (*payload*) with empty headers to subscribers, providing a *reply* subject:

<!-- tabs-open -->

### Erlang

```erlang
BinaryMsg = nats_msg:hpub(<<"FOOBAR">>, <<"REPRAP">>, <<>>, <<"Hello, World!">>).
```

### Elixir

```elixir
binary_msg = :nats_msg.hpub("FOOBAR", "REPRAP", "", "Hello, World!")
```

<!-- tabs-close -->

Send some data (*payload*) to subscribers (*without a reply subject*):

<!-- tabs-open -->

### Erlang

```erlang
BinaryMsg = nats_msg:hpub(<<"FOOBAR">>, undefined, <<>>, <<"Hello, World!">>).
```

### Elixir

```elixir
binary_msg = :nats_msg.hpub("FOOBAR", :undefined, "", "Hello, World!")
```

<!-- tabs-close -->

### Decode

Hpublish notification:

<!-- tabs-open -->

### Erlang

```erlang

Chunk = <<"HPUB NOTIFY 2 2\r\n\r\n\r\n">>,
{Msg, _} = nats_msg:decode(Chunk),
{hpub, {Subject, ReplyTo, Header, Payload}} = Msg,
% Subject = <<"NOTIFY">>,
% ReplyTo = undefined,
% Header = <<>>,
% Payload = <<>>.
```

### Elixir

```elixir
chunk = "HPUB NOTIFY 2 2\r\n\r\n\r\n"
{msg, _} = :nats_msg.decode(chunk)
{:hpub, {subject, reply_to, header, payload}} = msg
# ^subject = "NOTIFY"
# ^reply_to = :undefined
# ^header = ""
# ^payload = ""
```

<!-- tabs-close -->

Publish message with subject, replier, header and payload:

<!-- tabs-open -->

### Erlang

```erlang
Chunk = <<"HPUB FRONT.DOOR INBOX.22 22 33\r\nNATS/1.0\r\nFoo: Bar\r\n\r\nKnock Knock\r\n">>,
{Msg, _} = nats_msg:decode(Chunk),
{hpub, {Subject, ReplyTo, Header, Payload}} = Msg,
% Subject = <<"FRONT.DOOR">>,
% ReplyTo = <<"INBOX.22">>,
% Header = <<"NATS/1.0\r\nFoo: Bar~\r\n">>,
% Payload = <<"Knock Knock">>.
```

### Elixir

```elixir
chunk = "HPUB FRONT.DOOR INBOX.22 22 33\r\nNATS/1.0\r\nFoo: Bar\r\n\r\nKnock Knock\r\n"
{msg, _} = :nats_msg.decode(chunk)
{:hpub, {subject, reply_to, header, payload}} = msg
# ^subject = "FRONT.DOOR"
# ^reply_to = "INBOX.22"
# ^header = "NATS/1.0\r\nFoo: Bar~\r\n"
# ^payload = "Knock Knock"
```

<!-- tabs-close -->

### SUB Message

[NATS Spec](http://nats.io/documentation/internals/nats-protocol/#SUB)

#### Encode

Subscribe message with subject and SID:

<!-- tabs-open -->

### Erlang

```erlang
BinaryMsg = nats_msg:sub(<<"FOO">>, <<"1">>).
```

### Elixir

```elixir
binary_msg = :nats_msg.sub("FOO", "1")
```

<!-- tabs-close -->

Subscribe message with subject, group queue and SID:

<!-- tabs-open -->

### Erlang

```erlang
BinaryMsg = nats_msg:sub(<<"BAR">>, <<"G1">>, <<"44">>)
```

### Elixir

```elixir
binary_msg = :nats_msg.sub("BAR", "G1", "44")
```

<!-- tabs-close -->

#### Decode

<!-- tabs-open -->

### Erlang

```erlang
Chunk = <<"SUB FOO 1\r\n">>,
{Msg, _} = nats_msg:decode(Chunk),
{sub, {Subject, GroupQueue, Sid}} = Msg,
% Subject = <<"FOO">>,
% GroupQueue = undefined,
% Sid = <<"1">>.
```

### Elixir

```elixir
chunk = "SUB FOO 1\r\n"
{msg, _} = :nats_msg.decode(chunk)
{:sub, {subject, group_queue, sid}} = msg
# ^subject = <<"FOO">>
# ^group_queue = :undefined
# ^sid = "1"
```

<!-- tabs-close -->

### UNSUB Message

[NATS Spec](http://nats.io/documentation/internals/nats-protocol/#UNSUB)

#### Encode

Unsubscribe message with SID:

<!-- tabs-open -->

### Erlang

```erlang
BinaryMsg = nats_msg:unsub(<<"1">>).
```

### Elixir

```elixir
binary_msg = :nats_msg.unsub("1")
```

<!-- tabs-close -->

Unsubscribe message with SID and *max messages*:

<!-- tabs-open -->

### Erlang

```erlang
BinaryMsg = nats_msg:unsub(<<"1">>, 10).
```

### Elixir

```elixir
binary_msg = :nats_msg.unsub("1", 10)
```

<!-- tabs-close -->

#### Decode

<!-- tabs-open -->

### Erlang

```erlang
Chunk = <<"UNSUB 1 10\r\n">>,
{Msg, _} = nats_msg:decode(Chunk),
{unsub, {Sid, MaxMessages}} = Msg,
% Sid = <<"1">>,
% MaxMessages = 10
```

### Elixir

```elixir
chunk = "UNSUB 1 10\r\n"
{msg, _} = :nats_msg.decode(chunk)
{:unsub, {sid, max_messages}} = msg
# ^sid = "1"
# ^max_messages = 10
```

<!-- tabs-close -->

### MSG Message

[NATS Spec](http://nats.io/documentation/internals/nats-protocol/#MSG)

#### Encode

Message with subject and SID:

<!-- tabs-open -->

### Erlang

```erlang
BinaryMsg = nats_msg:msg(<<"FOO">>, <<"5">>).
```

### Elixir

```elixir
binary_msg = :nats_msg.msg("FOO", "5")
```

<!-- tabs-close -->

Message with subject, sid, *reply to subject* and payload:

<!-- tabs-open -->

### Erlang

```erlang
BinaryMsg = nats_msg:msg(<<"FOO">>, <<"5">>, <<"INBOX">>, <<"Hello!">>).
```

### Elixir

```elixir
binary_msg = :nats_msg.msg("FOO", "5", "INBOX", "Hello!")
```

<!-- tabs-close -->

Message with subject, sid and payload:

<!-- tabs-open -->

### Erlang

```erlang
BinaryMsg = nats_msg:msg(<<"FOO">>, <<"5">>, undefined, <<"Hello!">>).
```

### Elixir

```elixir
binary_msg = :nats_msg.msg("FOO", "5", :undefined, "Hello!")
```

<!-- tabs-close -->

#### Decode

Message with subject, sid and payload:

<!-- tabs-open -->

### Erlang

```erlang
Chunk = <<"MSG FOO.BAR 9 13\r\nHello, World!\r\n">>,
{Msg, _} = nats_msg:decode(Chunk),
{msg, {Subject, Sid, ReplyTo, Payload}} = Msg,
% Subject = <<"FOO.BAR">>,
% Sid = <<"9">>,
% ReplyTo = undefined,
% Payload = <<"Hello, World!">>.
```

### Elixir

```elixir
chunk = "MSG FOO.BAR 9 13\r\nHello, World!\r\n"
{msg, _} = :nats_msg.decode(chunk)
{:msg, {subject, sid, reply_to, payload}} = msg
% subject = "FOO.BAR"
% sid = "9"
% reply_to = :undefined
% payload = "Hello, World!"
```

<!-- tabs-close -->

### HMSG Message

[NATS Spec](http://nats.io/documentation/internals/nats-protocol/#HMSG)

#### Encode

Message with subject, empty header and SID:

<!-- tabs-open -->

### Erlang

```erlang
BinaryHmsg = nats_hmsg:hmsg(<<"FOO">>, <<"5">>).
```

### Elixir

```elixir
binary_hmsg = :nats_hmsg.hmsg("FOO", "5")
```

<!-- tabs-close -->

Message with subject, sid, *reply to subject*, minimal header and payload:

<!-- tabs-open -->

### Erlang

```erlang
BinaryHmsg = nats_hmsg:hmsg(<<"FOO">>, <<"5">>, <<"INBOX">>, <<"NATS/1.0\r\n">>, <<"Hello!">>).
```

### Elixir

```elixir
binary_hmsg = :nats_hmsg.hmsg("FOO", "5", "INBOX", "NATS/1.0\r\n", "Hello!")
```

<!-- tabs-close -->

Message with subject, sid, empty header and payload:

<!-- tabs-open -->

### Erlang

```erlang
BinaryHmsg = nats_hmsg:hmsg(<<"FOO">>, <<"5">>, undefined, <<>>, <<"Hello!">>).
```

### Elixir

```elixir
binary_hmsg = :nats_hmsg.hmsg("FOO", "5", :undefined, "", "Hello!")
```

<!-- tabs-close -->

#### Decode

Message with subject, sid and payload:

<!-- tabs-open -->

### Erlang

```erlang
Chunk = <<"HMSG FOO.BAR 9 2 15\r\n\r\nHello, World!\r\n">>,
{Msg, _} = nats_hmsg:decode(Chunk),
{hmsg, {Subject, Sid, ReplyTo, Header, Payload}} = Msg,
% Subject = <<"FOO.BAR">>,
% Sid = <<"9">>,
% ReplyTo = undefined,
% Header = <<>>,
% Payload = <<"Hello, World!">>.
```

### Elixir

```elixir
chunk = "HMSG FOO.BAR 9 2 15\r\n\r\nHello, World!\r\n"
{msg, _} = :nats_hmsg.decode(chunk)
{:hmsg, {subject, sid, reply:to, header, payload}} = msg
# ^subject = "FOO.BAR"
# ^sid = "9"
# ^reply_to = :undefined
# ^header = ""
# ^payload = "Hello, World!"
```

<!-- tabs-close -->

### PING Message

[NATS Spec](http://nats.io/documentation/internals/nats-protocol/#PING)

#### Encode

<!-- tabs-open -->

### Erlang

```erlang
BinaryMsg = nats_msg:ping().
```

### Elixir

```elixir
binary_msg = :nats_msg.ping()
```

<!-- tabs-close -->

#### Decode

<!-- tabs-open -->

### Erlang

```erlang
{Msg, _} = nats_msg:decode(<<"PING\r\n">>),
% Msg = ping
```

### Elixir

```elixir
{msg, _} = :nats_msg.decode("PING\r\n")
# ^msg = :ping
```

<!-- tabs-close -->

### PONG Message

[NATS Spec](http://nats.io/documentation/internals/nats-protocol/#PONG)

#### Encode

<!-- tabs-open -->

### Erlang

```erlang
BinaryMsg = nats_msg:pong().
```

### Elixir

```elixir
binary_msg = :nats_msg.pong()
```

<!-- tabs-close -->

#### Decode

<!-- tabs-open -->

### Erlang

```erlang
{Msg, _} = nats_msg:decode(<<"PONG\r\n">>),
% Msg = pong
```

### Elixir

```elixir
{msg, _} = :nats_msg.decode("PONG\r\n")
# ^msg = :pong
```

<!-- tabs-close -->

### +OK Message

[NATS Spec](http://nats.io/documentation/internals/nats-protocol/#OKERR)

#### Encode

<!-- tabs-open -->

### Erlang

```erlang
BinaryMsg = nats_msg:ok().
```

### Elixir

```elixir
binary_msg = :nats_msg.ok()
```

<!-- tabs-close -->

#### Decode

<!-- tabs-open -->

### Erlang

```erlang
{Msg, _} = nats_msg:decode(<<"+OK\r\n">>),
% Msg = ok
```

### Elixir

```elixir
{msg, _} = :nats_msg.decode("+OK\r\n")
# ^msg = :ok
```

<!-- tabs-close -->

### -ERR Message

[NATS Spec](http://nats.io/documentation/internals/nats-protocol/#OKERR)

The spec defines a predefined set of error messages, so **enats_msg** encodes/decodes these
to/from atoms as:

* `'Unknown Protocol Operation'` => `unknown_operation`
* `'Authorization Violation'` => `auth_violation`
* `'Authorization Timeout'` => `auth_timeout`
* `'Parser Error'` => `parser_error`
* `'Stale Connection'` => `stale_connection`
* `'Slow Consumer'` => `slow_consumer`
* `'Maximum Payload Exceeded'` => `max_payload`
* `'Invalid Subject'` => `invalid_subject`
* Other errors are converted to `unknown_error` during decoding and kept as is during encoding.

#### Encode

<!-- tabs-open -->

### Erlang

```erlang
BinaryMsg = nats_msg:err(auth_violation).
```

### Elixir

```elixir
binary_msg = :nats_msg.err(:auth_violation)
```

<!-- tabs-close -->

#### Decode

<!-- tabs-open -->

### Erlang

```erlang
Chunk = <<"-ERR 'Authorization Timeout'\r\n">>,
{Msg, _} = nats_msg:decode(Chunk),
{ok, Error} = Msg,
% Error = auth_timeout
```

### Elixir

```elixir
chunk = "-ERR 'Authorization Timeout'\r\n"
{msg, _} = :nats_msg.decode(chunk)
{:ok, error} = msg
# ^error = :auth_timeout
```

<!-- tabs-close -->

## License

```
Copyright (c) 2016, Yuce Tekol <yucetekol@gmail.com>.
Copyright (c) 2024, Travelping GmbH <info@travelping.com>.
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are
met:

* Redistributions of source code must retain the above copyright
  notice, this list of conditions and the following disclaimer.

* Redistributions in binary form must reproduce the above copyright
  notice, this list of conditions and the following disclaimer in the
  documentation and/or other materials provided with the distribution.

* The names of its contributors may not be used to endorse or promote
  products derived from this software without specific prior written
  permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
"AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
```
