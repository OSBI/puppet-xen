/*

== Definition: xen::guest

This definition allows to start/stop xen guests, optionnally bootstrap a guest
installation, or completely remove it from the host.

Parameters:
- *ensure*: define the state in which the guest must be. Default to "present".
  Possible values are:
  - present: will ensure the guest has been created by testing the presence of
    its configuration file in /etc/xen/. Will attempt an installation if the
    guest doesn't exist.
  - running: same as "present", but will start it if it is stopped and ensure
    it gets started at boot time.
  - stopped: same as "present", but will stop it if it is running and ensure it
    won't get started at boot time.
  - absent: will stop the guest and remove all files related to it. *WARNING* -
    data loss is guaranteed !
- *paravirt*: define if the guest must be created using para-virtualisation or
  full virtualisation. Possible values are: true/false. Default to "true"
  (para-virtualisation)
- *lvm*: whether to create an LVM disk or an image file. Defaults to "true"
  (LVM).
- *vg*: name of the volume group, if using LVM. Defaults to "vg0".
- *dir*: name if the directory in which the image file must get created, if not
  using LVM. Defaults to "/srv/xen".
- *disksize*: size of the disk image to create, in bytes. K/M/G/T suffixes
  accepted. Defaults to "2G".
- *ram*: memory size allocated to the guest, in MB. Defaults to "256".
- *vcpus*: how many virtual CPUs to allocate to the guest. Defaults to "1".
- *console*: whether to configure a graphical console or not. Defaults to
  "true" (use the console).
- *net*: define whether guest will have network access, and if it will have a
  bridged or NATed access. Possible values are: "none", "nat", "bridge".
  Defaults to "bridge". Any other option will be passed directly to
  virt-install's --network parameter.
- *installopts*: additonal parameters you would like to pass to the
  virt-install command when installing the guest. You would typically add one
  of: --cdrom, --location, --pxe or --import.

See also:  virt-install(1), virsh(1), virt-viewer(1)

Notes:
- expect "ensure", the parameters (currently) don't change anything once the
  virtual guest is installed.
- if the installation is not able to complete automatically, you'll need to use
  "virt-viewer" to answer the questions the installer is waiting for.

Requires: Class["xen::host"]

Example usage:

This will create a 20GB LVM volume named /dev/vg0/myserver, and run virt-install
on it, with the options needed to install fedora 10 from a kickstart file.

  include xen::host

  xen::guest { "myserver":
    ensure => "running",
    disksize => '20G',
    ram => '2048',
    vcpus => 2,
    installopts => '--location http://de.archive.ubuntu.com/ubuntu --extra-args ks=http://www.example.com/kickstart/myserver.cfg',
  }

*/
define xen::guest (
  $ensure='present',
  $dir='/srv/xen',
  $disksize='2G',
  $ram='256M',
  $vcpus='1',
  $ipaddr='') {

  if $virtual != "xen0" {
    fail ('please reboot on the xen hypervisor before continuing.')
  }

  case $ensure {

    'present', 'running', 'stopped': {

      $virt_install_args = "--force --hostname=$name --size=$disksize --memory=$ram --vcpus=$vcpus --ip=$ipaddr"

      # launch virt-install only if guest config file doesn't exist
      exec { "install guest $name":
        command => "xen-create-image $virt_install_args",
        creates => "/etc/xen/${name}.cfg",
        require => Class["xen::host"],
        timeout => "0",
      }


      if $ensure == 'running' {

        # start guest if stopped
        exec { "start guest $name":
          command => "xm create /etc/xen/${name}.cfg",
          ##onlyif  => "virsh dominfo $name | egrep -q '^State:[ \t]+(shut|crash)'",
          require => Exec["install guest $name"],
        }

		file { "/etc/xen/auto":
    		ensure => "directory",
		}
        # set autostart file
        file { "/etc/xen/auto/${name}.cfg":
          ensure => link,
          target => "/etc/xen/${name}.cfg",
          require => File["/etc/xen/auto"],
        }
      }		

      if $ensure == 'stopped' {

        # stop guest if running
        exec { "shutdown guest $name":
          command => "virsh shutdown $name",
          unless  => "virsh dominfo $name | egrep -q '^State:[ \t]+(shut|crash)'",
          require => Exec["install guest $name"],
        }

        # unset autostart file
        file { "/etc/xen/auto/$name":
          ensure => absent,
        }
      }

    }

    'absent': {

      # stop guest if running
      exec { "destroy guest $name":
        command => "virsh destroy $name",
        onlyif  => "virsh list | grep -q $name",
      }

      # remove guest if stopped
      exec { "undefine guest $name":
        command => "virsh undefine $name",
        onlyif  => "virsh list --inactive | grep -q $name",
        require => Exec["destroy guest $name"],
      }

      # remove disk file once guest is removed
      if $lvm == true {

        exec { "remove disk for $name":
          command => "lvremove -f /dev/${vg}/${name}",
          onlyif  => "test -e /dev/${vg}/${name}",
          require => Exec["undefine guest $name"],
        }
      } else {

        file { "remove disk for $name":
          path    => "${dir}/${name}.img",
          ensure  => absent,
          require => Exec["undefine guest $name"],
        }
      }

      # remove autostart file
      file { "/etc/xen/auto/${name}.cfg": ensure => absent }

    }
  }

}
