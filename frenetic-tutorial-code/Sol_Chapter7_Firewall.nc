(* Copied from Sol_Chapter7_Forwarding.nc. *)
let forwarding =
  if dlDst=00:00:00:00:00:01 then
     fwd(1)
  else if dlDst=00:00:00:00:00:02 then
    fwd(2)
  else if dlDst=00:00:00:00:00:03 then
    fwd(3)
  else if dlDst=00:00:00:00:00:04 then
    fwd(4)
  else
    drop

(* This is a very naive way to write this firewall. *)
let firewall_or_forward =
  if (tcpDstPort = 80 || tcpSrcPort = 80) &&
      ((dlSrc = 00:00:00:00:00:01 && dlDst = 00:00:00:00:00:02) ||
       (dlSrc = 00:00:00:00:00:02 && dlDst = 00:00:00:00:00:01))
  then
    forwarding
  else if nwProto = 1 && 
      ((dlSrc = 00:00:00:00:00:03 && dlDst = 00:00:00:00:00:04) ||
       (dlSrc = 00:00:00:00:00:04 && dlDst = 00:00:00:00:00:03))
       then
	 forwarding
       else
         drop

monitorTable(1, firewall_or_forward)
