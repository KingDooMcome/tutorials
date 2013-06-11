Chapter 3: Firewall
===================

In this chapter, you will compose your repeater with a simple firewall
that blocks ICMP traffic. As a result, the `ping` command will no
longer work on hosts. But, you will still be able to run other
programs, such as Web servers.  You will first write the `packet_in`
function for the firewall.  After you've tested it successfully,
you'll configure the flow table to implement the firewall efficiently.

### The Firewall Function

Unlike the repeater, which blindly forwards packets, the firewall's
`packet_in` function needs to inspect packets' headers to determine if
they should be dropped.

To do so, you need to parse the packet received. Ox includes a packet
parsing library that supports some common packet formats, including ICMP.
You can use it to parse the packet as follows:

```ocaml
let packet_in (sw : switchId) (xid : xid) (pktIn : packetIn) : unit =
  let pk = parse_payload pktIn.input_payload in
  ...
```
Applying `parse_payload` parses the packet into a series of nested
frames. The easiest way to examine packet headers is to then use the
[header accessor functions] in the packet library.

#### Programming Task

Starting from [Firewall.ml](ox-tutorial-code/Firewall.ml), fill in the
`is_icmp_packet` function.  The _frame type_ for IP packets
is _0x800_ and the _protocol number_ for ICMP is _1_.

#### Building and Testing Your Firewall

- Build and launch the controller:

  ```shell
  $ make Firewall.d.byte
  $ ./Firewall.d.byte
  ```

- In a separate terminal window, start Mininet using the same
  parameters you've used before:

  ```
  $ sudo mn --controller=remote --topo=single,3 --mac
  ```

- Test to ensure that pings fail within Mininet:

  ```
  mininet> h1 ping -c 1 h2
  mininet> h2 ping -c 1 h1
  ```

  These command should fail, printing `100.0% packet loss`.

- On the controller terminal, you should see the controller receiving
  several ICMP echo requests, but no ICMP echo replies:
  
  ```
Switch 1 connected.
packetIn{
  total_len=98 port=1 reason=NoMatch
  payload=dlSrc=00:00:00:00:00:01,dlDst=00:00:00:00:00:02,nwSrc=10.0.0.1,nwDst=10.0.0.2,ICMP echo request (buffered at 277)
}
packetIn{
  total_len=98 port=1 reason=NoMatch
  payload=dlSrc=00:00:00:00:00:01,dlDst=00:00:00:00:00:02,nwSrc=10.0.0.1,nwDst=10.0.0.2,ICMP echo request (buffered at 278)
}
packetIn{
  total_len=98 port=1 reason=NoMatch
  payload=dlSrc=00:00:00:00:00:01,dlDst=00:00:00:00:00:02,nwSrc=10.0.0.1,nwDst=10.0.0.2,ICMP echo request (buffered at 279)
}
...
```

  This indicates that the controller sees the ping request and drops it,
  thus no host ever sends a reply.

- Although ICMP is blocked, other traffic, such as Web traffic should
  be unaffected. To ensure that this is the case, try to run a Web server
  on one host and a client on another.


  * In Mininet, start new terminals for `h1` and `h2`:

    ```
    mininet> xterm h1 h2
    ```

  * In the terminal for `h1` start a local "fortune server" (a server
    that returns insightful fortunes to those who query it):

    ```
    # while true; do fortune | nc -l 80; done
    ```

  * In the terminal for `h2` fetch a fortune from `h1`:

    ```
    # curl 10.0.0.1:80
    ```

    This command should succeed.

### An Efficient Firewall

In this part, you will extend your implementation of the firewall
function to also implement the firewall using flow tables.

> Use [Sol_Firewall1.ml](ox-tutorial-code/Sol_Firewall1.ml) if necessary.

#### Programming Task

Fill in the `switch_connected` event handler. You need to install two
entries into the flow table: one for ICMP traffic and the other for
all other traffic. Use the following template:

```ocaml
let switch_connected (sw : switchId) : unit =
  Printf.printf "Switch %Ld connected.\n%!" sw;
  send_flow_mod sw 0l (add_flow priority1 pattern1 actions1);
  send_flow_mod sw 0l (add_flow priority2 pattern2 actions2)
```

You have to determine the priorities, patterns, and actions in the
handler above. You might want to revisit the description of flow
tables in [Chapter 2][Ch2]. Here is a quick refresher:

- *Priorities*: higher numbers mean higher priority.

- *Action lists*: To drop traffic, you provide an empty list (`[]` in
  OCaml) of actions.

- *Patterns*: In the previous chapter, you used the builtin pattern
  `match_all`, which you may use again if needed. You will certainly
  need to write a pattern to match ICMP packets. The Ox Manual has
  several [example patterns] to get you started.

#### Building and Testing

Build and test the efficient firewall in exactly the same way you
tested the firewall function. In addition, you shouldn't observe
packets at the controller.

## Next chapter: [Ox Monitor][Ch4]

[Action]: http://frenetic-lang.github.io/frenetic/docs/OpenFlow0x01.Action.html

[PacketIn]: http://frenetic-lang.github.io/frenetic/docs/OpenFlow0x01.PacketIn.html

[PacketOut]: http://frenetic-lang.github.io/frenetic/docs/OpenFlow0x01.PacketOut.html

[Ox Platform]: http://frenetic-lang.github.io/frenetic/docs/Ox_Controller.OxPlatform.html

[Match]: http://frenetic-lang.github.io/frenetic/docs/OpenFlow0x01.Match.html

[Packet]: http://frenetic-lang.github.io/frenetic/docs/Packet.html

[Ch2]: 02-OxRepeater.md
[Ch3]: 03-OxFirewall.md
[Ch4]: 04-OxMonitor.md
[Ch5]: 05-OxLearning.md
[Ch6]: 06-NetCoreIntroduction.md
[Ch7]: 07-NetCoreComposition.md
[Ch8]: 08-DynamicNetCore.md

[OpenFlow_Core]: http://frenetic-lang.github.io/frenetic/docs/OpenFlow0x01_Core.html

[send_flow_mod]: http://frenetic-lang.github.io/frenetic/docs/OxPlatform.html#VALsend_flow_mod

[pattern]: http://frenetic-lang.github.io/frenetic/docs/OpenFlow0x01_Core.html#TYPEpattern

[match_all]: http://frenetic-lang.github.io/frenetic/docs/OpenFlow0x01_Core.html#VALmatch_all

[match_all]: http://frenetic-lang.github.io/frenetic/docs/OpenFlow0x01_Core.html#VALmatch_all

[example patterns]: http://frenetic-lang.github.io/frenetic/docs/OpenFlow0x01_Core.html#patternexamples

[header accessor functions]: http://frenetic-lang.github.io/frenetic/docs/Packet.html#accs
