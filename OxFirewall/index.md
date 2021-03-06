---
layout: main
title: Firewall with Ox
---

In this chapter, we will compose our repeater with a simple firewall
that blocks ICMP traffic. As a result, the `ping` command will no
longer work on hosts. But, the network will still carry other traffic,
such as Web traffic. As before, we will first write the `packet_in`
function for the firewall. Then, after we've tested it successfully,
we'll configure the flow table to implement the same functionality
more efficiently.

## Exercise 1: The Firewall Function

**[Solution](https://github.com/frenetic-lang/tutorials/blob/master/ox-tutorial-solutions/Firewall1.ml)**

Unlike the repeater, which blindly forwards packets, the `packet_in`
function for the firewall needs to inspect packets' headers to
determine whether they should be dropped. To do this, it needs to
parse the packet received. Ox includes a packet parsing library that
supports some common packet formats, including ICMP.  You can use it
to parse packets as follows:

~~~ ocaml
let packet_in (sw : switchId) (xid : xid) (pktIn : packetIn) : unit =
  let pk = parse_payload pktIn.input_payload in
  ...
~~~

Applying `parse_payload` parses the packet into a series of nested
frames. The easiest way to examine packet headers is to then use the
[header accessor functions] in the packet library. The frame type for
IP packets is 0x800 (`Frenetic_Packet.dlTyp pk = 0x800`) and the protocol
number for ICMP is 1 (`Frenetic_Packet.nwProto pk = 1`).

### Firewall Template

Fill in the `is_icmp_packet` function in the following template:

~~~ ocaml
open Frenetic_Ox
open Frenetic_OpenFlow0x01

module MyApplication = struct
  include DefaultHandlers
  open Platform

  let is_icmp_packet (pk : Frenetic_Packet.packet) = ... (* [FILL] *)

  let packet_in (sw : switchId) (xid : xid) (pktIn : packetIn) : unit =
    let pk = parse_payload pktIn.input_payload in
    Printf.printf "%s\n%!" (packetIn_to_string pktIn);
    send_packet_out sw 0l {
      output_payload = pktIn.input_payload;
      port_id = None;
      apply_actions = if is_icmp_packet pk then [] else [Output AllPorts]
    }

end

let _ =
  let module C = Make (MyApplication) in
  C.start ();
~~~

### Building and Testing Your Firewall

- Build and launch the controller:

      $ ./ox-build Firewall1.d.byte
      $ ./Firewall1.d.byte

- In a separate terminal window, start Mininet using the same
  parameters you've used before:

      $ sudo mn --controller=remote --topo=single,4 --mac --arp


- Test to ensure that pings fail within Mininet:


      mininet> h1 ping -c 1 h2
      mininet> h2 ping -c 1 h1

  These command should fail, printing `100.0% packet loss`.

- On the controller terminal, you should see the controller receiving
  several ICMP echo requests, but no ICMP echo replies:

~~~
Switch 1 connected.
packetIn{
  total_len=98 port=1 reason=NoMatch
  payload=dlSrc=00:00:00:00:00:01,dlDst=00:00:00:00:00:02,nwSrc=10.0.0.1,nwDst=10.0.0.2,<b>ICMP echo request</b> (buffered at 277)
}
~~~

- This indicates that the controller sees the ping request and drops it,
  thus no host ever sends a reply.

- Although ICMP is blocked, other traffic, such as Web traffic should
  be unaffected. To ensure that this is the case, try to run a Web server
  on one host and a client on another.  In Mininet, run a simple web server on h1:

~~~
mininet> h1 python -m SimpleHTTPServer 80 &
~~~

  * And run a HTTP request to h1 from h2 (assuming h1 has ip address 10.0.0.1,
    mininet does not resolve hostnames of hosts)

~~~
mininet> h2 curl 10.0.0.1:80
~~~

  * This command should succeed and you should see a directory listing for the tutorial directory. 
    Finally, run this command to shut down the web server on h1

~~~
mininet> h1 kill %python
~~~

## Exercise 2: An Efficient Firewall

**[Solution](https://github.com/frenetic-lang/tutorials/blob/master/ox-tutorial-solutions/Firewall2.ml)**

Next, let us extend our implementation of the firewall function to use
flow tables. To do this, we will add a `switch_connected` handler. We
will need to install two entries into the flow table: one for ICMP
traffic and the other for all other traffic. Use the following
template:

~~~ ocaml
let switch_connected (sw : switchId) feats : unit =
  Printf.printf "Switch %Ld connected.\n%!" sw;
  send_flow_mod sw 0l (add_flow priority1 pattern1 actions1);
  send_flow_mod sw 0l (add_flow priority2 pattern2 actions2)
~~~

To determine the priorities, patterns, and actions in the handler
above, it may be useful to revisit the description of flow tables in
the last chapter.

#### Building and Testing

Build and test the efficient firewall in exactly the same way you
tested the firewall function. In addition, you shouldn't observe
packets at the controller.

{% include api.md %}
