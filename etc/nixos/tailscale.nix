{ ... }:

{
  # Only used to reach Sunshine remotely over its tailnet IP. Userspace
  # networking avoids tailscaled needing root/CAP_NET_ADMIN or a real TUN
  # device -- it runs a userspace netstack instead of touching the kernel
  # routing table. Inbound connections to local listening ports (Sunshine's)
  # still work fine in this mode; what's lost is subnet routes/exit-node,
  # which aren't needed here.
  services.tailscale = {
    enable = true;
    extraDaemonFlags = [ "--tun=userspace-networking" ];
  };
}
