Chapter 4: Traffic Monitoring
=============================

In this exercise, you will write a controller that measures the volume
of Web traffic on a network. To implement monitoring efficiently, you
will learn how to read the traffic [statistics] that OpenFlow switches
maintain. You will compose your new traffic monitor with the
[repeater][Ch2] and [firewall][Ch3] you wrote in earlier exercises.

As usual, you will proceed in two steps: you will first write and test
a traffic monitoring function and then implement it efficiently using
flow tables and OpenFlow statistics.

### The Monitoring Function

Your monitor must count the total number of packets sent to *and*
received from port 80. Since the `packet_in` function receives all
packets, all you need to do is increment a global counter each time
`packet_in` receives a new packet:

```ocaml
let num_http_packets = ref 0

let packet_in (sw : switchId) (xid : xid) (pktIn : packetIn) : unit =
  if is_http_packet (parse_payload pktIn.payload) then
    begin
      num_http_packets := !num_http_packets + 1;
      Printf.printf "Saw %d HTTP packets.\n%!" !num_http_packets
    end
```

#### Programming Task

Use [Monitor.ml](ox-tutorial-code/Monitor.ml) as a template for this exercise.

- Write the `is_http_packet` predicate, using the [header accessor
  functions] you used to build the firewall.

- You're not just monitoring Web traffic. You need to firewall ICMP
  traffic and apply the repeater to non-ICMP traffic, as you did
  before. In fact, you should use the `packet_in` function from
  `Firewall.ml` _verbatim_.

#### Building and Testing Your Monitor

You should first test that your monitor preserves the features of the
firewall and repeater. To do so, you'll run the same tests you in the previous
chapter. You should next test  the monitor by checking that traffic to and from
port 80 increments the counter (and that other traffic does not).

- Build and launch the controller:

  ```shell
  $ make Monitor.d.byte
  $ ./Monitor.d.byte
  ```

- In a separate terminal window, start Mininet:

  ```
  $ sudo mn --controller=remote --topo=single,3 --mac
  ```

- Test that the firewall correctly drops pings, reporting "100% packet loss":

  ```
  mininet> h1 ping h2
  mininet> h2 ping h1
  ```

- Test that Web traffic is unaffected, but logged. To do so, run a fortune
   server on one host and a client on another:

  * In Mininet, start new terminals for `h1` and `h2`:

    ```
    mininet> xterm h1 h2
    ```

  * In the terminal for `h1` start a local fortune server:

    ```
    # while true; do fortune | nc -l 80; done
    ```

  * In the terminal for `h2` fetch a fortune from `h1`:

    ```
    # curl 10.0.0.1:80
    ```

    This command should succeed and you should find HTTP traffic
    logged in the controller's terminal:

    ```
    Saw 1 HTTP packets.
    Saw 2 HTTP packets.
    Saw 3 HTTP packets.
    Saw 4 HTTP packets.
    Saw 5 HTTP packets.
    ...
    ```   
> If you are seeing <code>packetIn</code> messages in between the HTTP traffic logs,
> you could comment out the appropriate printf commands.


- Finally, you should test that other traffic is neither blocked by
  the firewall nor counted by your monitor. To do so, kill the fortune 
  server running on `h1` and start a new fortune server on a non-standard
  port (e.g., 8080):

  * On the terminal for `h1`:

    ```
    ^C
    $ while true; do fortune | nc -l 8080; done
    ```

  * On the terminal for `h2`, fetch a fortune:

    ```
    $ curl 10.0.0.1:8080
    ```

  The client should successfully download the fortune. However, none of
  these packets should get logged by the controller.

### Efficiently Monitoring Web Traffic

Switches themselves keeps track of the number of packets (and bytes)
they receive.  To implement an efficient monitor, you will use
OpenFlow's [statistics] API to query these counters.

Recall from [Chapter 2][Ch2] that each rule in a flow table is
associated with a packet-counter that counts the number of packets to
which the rule is applied. For example, consider the following flow
table:

<table>
<tr>
  <th>Priority</th> <th>Pattern</th> <th>Action</th> <th>Counter (bytes)</th>
</tr>
<tr>
  <td>60</td><td>ICMP</td><td>drop</td><td>10</td>
</tr>
  <td>50</td><td>ALL</td><td>Output AllPorts</td><td>300</td>
</tr>
</table>

The first counter states that 10 ICMP packets have been blocked and
the secord reports that 300 non-ICMP packets have been forwarded.

You can read these counters using the OpenFlow statistics API, but
these are not the counters you are looking for. Do you see the
problem?

> Answer: The problem is that the second counter accounts for HTTP
> packets as well as *all other* non-ICMP traffic. Although this flow table
> implements the desired forwarding policy, it is too coarse grained
> to implement the desired monitoring policy.

#### Programming Task 1

Augment `Monitor.ml` to build a flow table. The forwarding logic only
requires two rules &mdash; one for ICMP and the other for non-ICMP traffic
&mdash; but you'll need additional rules to ensure that you have
fine-grained counters.  Once you have determined the rules you need,
create the rules as you did before using `send_flow_mod` in the
`switch_connected` function.

#### Programming Task 2

*Complete Programming Task 1 before moving on to this task.*

As you realized in the previous programing task, you cannot write a
single OpenFlow pattern that matches both HTTP requests and
replies. You need to match them separately, using two rules, which will
give you two counters. Therefore, you need to read each counter
independently and calculate their sum.


You can read counters by calling [send_stats_request] periodically.
To do so, you can use the following function:

```ocaml
let rec periodic_stats_request sw interval xid pat =
  let callback () =
    Printf.printf "Sending stats request to %Ld\n%!" sw; 
    send_stats_request sw xid
      (Stats.AggregateRequest (pat, 0xff, None));
    periodic_stats_request sw interval xid pat in
  timeout interval callback
```

This function issues a request every `interval` seconds for counters
that match `pat`. Use `periodic_stats_request` in
`switch_connected`. For example, in the template below, the program
periodically reads the counter for HTTP requests and HTTP responses
every five seconds:

```ocaml
let switch_connected (sw : switchId) : unit =
  Printf.printf "Switch %Ld connected.\n%!" sw;
  periodic_stats_request sw 5.0 10l match_http_requests;
  periodic_stats_request sw 5.0 20l match_http_responses;
  ...
```

You need to fill in the patterns `match_http_requests` and
`match_http_responses`, which you have already calculated.

Finally, you need a `stats_reply` function that will handle the stats
responses from the switch and calculate the sum of the two
counters. We've provided one below:

```ocaml
let num_http_request_packets = ref 0L 
let num_http_response_packets = ref 0L

let stats_reply (sw : switchId) (xid : xid) (stats : Stats.reply) : unit =
  match stats with
  | Stats.AggregateFlowRep rep ->
    begin
      if xid = 10l then
        num_http_request_packets := rep.Stats.total_packet_count
      else if xid = 20l then
        num_http_response_packets := rep.Stats.total_packet_count
    end;
    Printf.printf "Saw %Ld HTTP packets.\n%!"
      (Int64.add !num_http_request_packets !num_http_response_packets)
  | _ -> ()

```

#### Building and Testing Your Monitor

You should be able to build and test the extended monitor as before.


#### Extra Credit

Did you spot the bug? What happens if the controller receives HTTP
packets before the switch is fully initialized?

## Next chapter: [Ox Learning Switch][Ch5]

[statistics]: http://frenetic-lang.github.io/frenetic/docs/OpenFlow0x01_Stats.html

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

[send_stats_request]: http://frenetic-lang.github.io/frenetic/docs/OxPlatform.html#VALsend_stats_request

[send_flow_mod]: http://frenetic-lang.github.io/frenetic/docs/OxPlatform.html#VALsend_flow_mod

[pattern]: http://frenetic-lang.github.io/frenetic/docs/OpenFlow0x01_Core.html#TYPEpattern

[match_all]: http://frenetic-lang.github.io/frenetic/docs/OpenFlow0x01_Core.html#VALmatch_all

[match_all]: http://frenetic-lang.github.io/frenetic/docs/OpenFlow0x01_Core.html#VALmatch_all

[example patterns]: http://frenetic-lang.github.io/frenetic/docs/OpenFlow0x01_Core.html#patternexamples

[header accessor functions]: http://frenetic-lang.github.io/frenetic/docs/Packet.html#accs
