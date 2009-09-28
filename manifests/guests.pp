#
# == Class: xen::guest::paravirt
#
# Class to include on para-virtualized guests
#
class xen::guest::paravirt {
  package { "kernel-xen": ensure => present }
}

# 
# == Class: xen::guest::hvm
#
# Class to include on full-virtualized guests
#
class xen::guest::hvm {
}
