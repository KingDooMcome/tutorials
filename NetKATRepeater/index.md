---
layout: main
title: NetKAT Repeater
---

So far, we've seen how to implement OpenFlow controllers using the Ox
platform. Most of the controllers we built followed a two-step recipe:

* Write a `packet_in` handler that implements the desired
  packet-processing functionality.

* Use `flow_mod` messages to configure the switch flow tables to
  implement the same functionality efficiently.

In the next few chapters, we will explore a completely different
approach: express policies using a high-level, domain-specific
programming language, and let a compiler and run-time system handle
the details related to configuring switch flow tables (as well as
sending requests for statistics, accumulating replies, etc.)

You will place these files in `netkat-tutorial-solutions`.

~~~
$ cd netkat-tutorial-solutions
~~~

### Example 1: A Repeater (Redux)

**[Solution](https://github.com/frenetic-lang/tutorials/blob/master/netkat-tutorial-solutions/Repeater.ml)**

In the [OxRepeater](../OxRepeater) chapter, we wrote an efficient
repeater that installs forwarding rules in the switch flow table.
Recall that a repeater simply outputs packets out all ports, except
the one that the packet came in on. Suppose that the topology consists
of a single switch with four ports, numbered 1 through 4:

![Repeater](../images/repeater.png)

The following program implements a repeater in NetKAT:

~~~ ocaml
open Frenetic_NetKAT
open Core.Std
open Async.Std

(* a simple repeater *)
let%nk repeater =
  {| if port = 1 then port := 2 + port := 3 + port := 4
     else if port = 2 then port := 1 + port := 3 + port := 4
     else if port = 3 then port := 1 + port := 2 + port := 4
     else if port = 4 then port := 1 + port := 2 + port := 3
     else drop
  |}

let _ =
  let module Controller = Frenetic_NetKAT_Controller.Make (Frenetic_OpenFlow0x01_Plugin) in
  Controller.start 6633;
  Deferred.don't_wait_for (Controller.update repeater);
  never_returns (Scheduler.go ());

~~~

The main part of this code uses a ppx extension of OCaml syntax,
<code>let%nk repeater = {| ... |}</code> to switch into NetKAT syntax.
The embedded NetKAT program uses a cascade of nested conditionals
(<code>if ... then ... else ...</code>) to match packets on each port
(<code>port = 1</code>) and forward them out on all other ports
(<code>port := 2 + port := 3 + port := 4</code>) except the one the
packet came in on. The last line starts a controller that configures
the switch with a static NetKAT policy.

#### Run the Example

To run the repeater, type the code above into a file
<code>Repeater1.ml</code> within the
<code>netkat-tutorial-solutions</code> directory. Then compile and
start the repeater controller using the following commands.

~~~
$ ./netkat-build Repeater.d.byte
$ ./Repeater.d.byte
~~~

Next, in a separate terminal, start up mininet.

~~~
$ sudo mn --controller=remote --topo=single,4 --mac --arp
~~~

#### Test the Example

At the mininet prompt, test your repeater program by pinging <code>h2</code> 
from <code>h1</code>:

~~~
mininet> h1 ping -c 1 h2
~~~

You should see output similar to the following:

~~~
PING 10.0.0.2 (10.0.0.2) 56(84) bytes of data.
64 bytes from 10.0.0.2: icmp_req=1 ttl=64 time=0.216 ms

--- 10.0.0.2 ping statistics ---
1 packets transmitted, 1 received, 0% packet loss, time 0ms
rtt min/avg/max/mdev = 0.216/0.216/0.216/0.000 ms
~~~

Try pinging <code>h1</code> from <code>h2</code> as well.

### Example 2: Referring to OCaml variables

**[Solution](https://github.com/frenetic-lang/tutorials/blob/master/netkat-tutorial-solutions/Repeater2.ml)**

In many programs it is useful to refer to an OCaml variable. We can do
this by writing `$x`, where `x` is the name of an OCaml variable. As
an example, here is an equivalent, but more concise version of the
repeater that uses list-processing functions to build up the NetKAT
policy. This program would be easier to maintain, for example, if we
wanted to implement repeaters on switches with different numbers of
ports.

~~~ ocaml
open Frenetic_NetKAT
open Core.Std
open Async.Std

(* a simple repeater *)
let all_ports : int32 list = [1l; 2l; 3l; 4l]
let%nk drop = {| drop |}

let flood (n : int32) : policy =
  List.fold_left
    all_ports
    ~f: (fun pol m ->
      let%nk flood = {| $pol + port:= $m |} in
      if n = m then pol else flood)
    ~init: drop

let repeater : policy =
  List.fold_right
    all_ports 
    ~f: (fun m pol ->
      let p = flood m in
      let%nk repeat = {| if port = $m then $p else $pol |} in
      repeat)
    ~init: drop

let _ =
  let module Controller = Frenetic_NetKAT_Controller.Make (Frenetic_OpenFlow0x01_Plugin) in
  Controller.start 6633;
  Deferred.don't_wait_for (Controller.update repeater);
  never_returns (Scheduler.go ());

~~~

### NetKAT Reference Manual

The complete NetKAT language is described [here](../NetKATManual).
