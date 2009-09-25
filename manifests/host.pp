/*
== Class: xen::host

This class can be used to setup a working xen host.

It will install various packages, ensure the various xen daemons are running
and define the firewall rules needed by the guests.

See also:
- xen::guest
- xen::guest::paravirt
- xen::guest::hvm

Usage:
  include xen::host

Note: if the host isn't running the xen hypervisor yet, you will get a warning
asking you to reboot on a xen kernel.

*/
class xen::host {

  package { ["xen", "kernel-xen", "libvirt", "libvirt-python", "python-virtinst", "virt-manager", "virt-viewer", "vnc", "xorg-x11-xauth"]: ensure => present }

  # these services must be running
  service { ["xend", "libvirtd", "dnsmasq"]:
    hasstatus => true,
    ensure    => running,
    enable    => true,
    require   => [Package["libvirt"], Package["xen"]],
  }

  # ensure xendomains is enabled at boot, but don't bother ensuring it's
  # running as the initscript exit status depends on the running virtual
  # guests (and this should be managed by xen::guest).
  service { "xendomains":
    enable    => true,
    require   => Package["xen"],
  }

  # enable packet forwarding
  sysctl::set_value { "net.ipv4.ip_forward":
    value => "1",
  }

  if $virtual != "xen0" {
    fail ('please reboot on the xen hypervisor before continuing.')
  } else {

    iptables { "allow dns and dhcp on virbr0":
      iniface => "virbr0",
      proto     => "udp",
      dport     => ["53", "67"],
      jump      => "ACCEPT",
    }

    iptables { "A allow traffic to nat network":
      chain       => "FORWARD",
      outiface    => "virbr0",
      state       => ["RELATED", "ESTABLISHED"],
      destination => "192.168.122.0/24",
      jump        => "ACCEPT",
    }

    iptables { "B allow traffic from nat network":
      chain       => "FORWARD",
      iniface     => "virbr0",
      source      => "192.168.122.0/24",
      jump        => "ACCEPT",
    }

    iptables { "C allow traffic between virbr0":
      chain       => "FORWARD",
      iniface     => "virbr0",
      outiface    => "virbr0",
      jump        => "ACCEPT",
    }

    iptables { "D drop traffic from virbr0":
      chain       => "FORWARD",
      outiface    => "virbr0",
      jump        => "REJECT",
      reject      => "icmp-port-unreachable",
    }

    iptables { "E drop traffic to virbr0":
      chain       => "FORWARD",
      iniface     => "virbr0",
      jump        => "REJECT",
      reject      => "icmp-port-unreachable",
    }

    iptables { "masquerade nat network":
      table  => "nat",
      chain  => "POSTROUTING",
      source => "192.168.122.0/24",
      jump   => "MASQUERADE",
    }
  }
}
