NetCore Manual
==============

The NetCore Manual is intended as a lightweight reference to the syntax of the
NetCore domain-specific language (NetCoreDSL).  More detailed documentation can
be found in the [NetCore tutorial](01-Introduction.md).


NetCore Syntax
--------------

Types:

```
(* Integers can be either decimal or hexadecimal (with leading 0x *)

<mac-address> ::= xx:xx:xx:xx:xx:xx
<ip-address> ::= xxx.xxx.xxx.xxx
<switch-id> ::= 64-bit integer
<port-id> ::= 16-bit integer
<vlan-id> ::= none | 12-bit integer
<tcp-port> ::= 16-bit integer
<frame-type> ::= arp (* shorthand for 0x806 *)
               | ip  (* shorthand for 0x800 *)
               | 8-bit integer
<ip-protocol> ::= icmp (* shorthand for 0x01 *)
                | tcp  (* shorthand for 0x06 *)
                | udp  (* shorthand for 0x11 *)
                | 8-bit integer

<seconds> ::= [0-9]+ | [0-9]+ . [0-9]+
<string> ::= '"' [^ '"']* '"'
```

Predicates:

```
<apred> ::= ( <pred> )
          | ! <apred> 
          | *
          | <none>
          | switch = <switch-id>
          | inPort = <port-id>
          | dlSrc = <mac-address>
          | dlDst = <mac-address>
          | vlan = <vlan-id>
          | srcIP = <ip-address>
          | dstIP = <ip-address>
          | nwProto = <ip-protocol>
          | tcpSrcPort = <tcp-port>
          | tcpDstPort = <tcp-port>
          | dlTyp = <frame-type>

<orpred> ::= <apred>
           | <apred> || <orpred>

<pred> ::= <orpred>
         | <orpred> && <pred>

```

Policies:

```
<id> ::= [A-Z a-z _] [A-Z a-z _ 0-9]*

<module> ::= learn ( )
           | nat ( publicIP = <ip-addr> )

<apol> ::= ( <pol> )
         | <id>
         | filter <pred>
         | <port-id> (* Forward out port <port-id>. *)
         | pass
         | drop
         | all (* Forward out all ports. *)
         | dlSrc <mac-address> -> <mac-address>
         | dlDst <mac-address> -> <mac-address>
         | vlan <vlan-id> -> <vlan-id>
         | srcIP <ip-address> -> <ip-address>
         | dstIP <ip-address> -> <ip-address>
         | tcpSrcPort <tcp-port> -> <tcp-port>
         | tcpDstPort <tcp-port> -> <tcp-port>
         | monitorPackets ( <string> )
         | monitorPolicy ( <pol> )
         | monitorTable ( <switch-id> , <pol> )
         | monitorLoad (<seconds>, <string>) (* Print the number of packets  *)
                                             (* and bytes processed by this  *)
                                             (* policy in the last <seconds>.*)
                                             (* Label output using <string>. *)

<cpol> ::= <apol>
        | if <pred> then <cpol> else <cpol>

<seq_pol_list> ::= <cpol>
                 | <cpol> ; <seq_pol_list>

<par_pol_list> ::= <cpol>
                 | <cpol> | <par_pol_list>

<pol> ::= <cpol>
        | <cpol> ; <seq_pol_list>
        | <cpol> | <par_pol_list>
        | let <id_1>, ... <id_n> = <module>(<arg_1> ,... , <arg_m>)

<program> ::= <pol>
```
