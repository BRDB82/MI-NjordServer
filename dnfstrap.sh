#!/bin/bash

#
# Assumptions:
#  1) User has partioned, formatted, and mounted partitions on /mnt
#  2) Network is functional
#  3) Arguments passed to the script are valid dnf targets
#  4) A valid repo appears in /etc/yum.repos.d

shopt -s extglob

hostcache=0
dnf_args=()
dnfmode="install"
unshare=0
copyconf=0
dnf_config="/etc/dnf/dnf.conf"

m4_include(common)

usage() {
  cat <<EOF
usage: ${0##*/} [options] root [packages...]

  Options:
    -C <config>    Use an alternate config file for dnf
    -c             Use the package cache on the host, rather than the target
    -i             Prompt for package confirmation when needed (run interactively)
    -M             Avoid copying the host's repo files to the target
    -N             Run in unshare mode as a regular user
    -P             Copy the host's dnf config to the target
    -U             Use dnf install from local RPMs

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

# creat obligatory directories
msg 'Creating install at %s' "$newroot"
# shellcheck disable=SC2174 # permissions are perfectly fine here
mkdir -m 0755 -p "$newroot"/var/{cache/dnf,lib,log} "$newroot"/{dev,run,etc/yum.repos.d}
# shellcheck disable=SC2174 # permissions are perfectly fine here
mkdir -m 1777 -p "$newroot"/tmp
# shellcheck disable=SC2174 # permissions are perfectly fine here
mkdir -m 0555 -p "$newroot"/{sys,proc}
