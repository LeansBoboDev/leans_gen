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

  # Userspace networking means tailscaled never needs CAP_NET_ADMIN or raw
  # kernel network access -- it only opens regular UDP/TCP sockets. These
  # merge on top of the serviceConfig the tailscale module already sets
  # (StateDirectory/RuntimeDirectory etc.), so state/socket paths stay
  # writable; this just drops everything else it doesn't need. Test with
  # `nixos-rebuild test` before `switch` -- if tailscaled fails to start,
  # the empty CapabilityBoundingSet is the first thing to loosen.
  systemd.services.tailscaled.serviceConfig = {
    CapabilityBoundingSet = [ ];
    NoNewPrivileges = true;
    ProtectHome = true;
    ProtectKernelModules = true;
    ProtectKernelTunables = true;
    ProtectKernelLogs = true;
    ProtectClock = true;
    ProtectHostname = true;
    ProtectControlGroups = true;
    RestrictNamespaces = true;
    RestrictRealtime = true;
    RestrictSUIDSGID = true;
    LockPersonality = true;
    MemoryDenyWriteExecute = true;
  };
}
