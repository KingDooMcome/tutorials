open Frenetic_NetKAT
open Core.Std
open Async.Std
open Forwarding

let firewall : policy =
  <:netkat<
    if ((ipProto=0x6 and (tcpSrcPort = 80 or tcpDstPort = 80)) and
       (ip4Src = 10.0.0.1 and ip4Dst = 10.0.0.2 or 
        ip4Src = 10.0.0.2 and ip4Dst = 10.0.0.1)) or 
       (ipProto = 0x01 and
       (ip4Src = 10.0.0.3 and ip4Dst = 10.0.0.4 or
        ip4Src = 10.0.0.4 and ip4Dst = 10.0.0.3)) then
        (filter ethTyp = 0x800; $forwarding)
    else
      drop
  >>

let _ =
  let module Controller = Frenetic_NetKAT_Controller.Make in
  Controller.start 6633;
  Controller.update_policy firewall;
  never_returns (Scheduler.go ());