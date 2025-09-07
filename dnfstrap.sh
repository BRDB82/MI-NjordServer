#!/bin/bash

#
# Assumptions:
#  1) User has partioned, formatted, and mounted partitions on /mnt
#  2) Network is functional
#  3) Arguments passed to the script are valid dnf targets
#  4) A valid repo appears in /etc/yum.repos.d

shopt -s extglob

hostcache=0
copykeyring=1
copymirrorlist=1

usage() {
  cat <<EOF
usage: ${0##*/} [options] root [packages...]

  Options:
    -C config      Use an alternate config file for pacman
    -c             Use the package cache on the host, rather than the target
    -G             Avoid copying the host's dnf keyring to the target
    -i             Prompt for package confirmation when needed (run interactively)
    -M             Avoid copying the host's repo ist to the target

    -h             Print this help message

dnfstrap installs packages to the specified new root directory. If no packages
are given, dnfstrap defaults to the "base" group.

EOF
}

if [[ -z $1 || $1 = @(-h|--help) ]]; then
  usage
  exit $(( $# ? 0 : 1 ))
fi

(( EUID == 0 )) || die 'This script must be run with root privileges'
