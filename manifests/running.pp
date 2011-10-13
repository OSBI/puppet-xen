class running {

notify { "needs automatic start code": }
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

