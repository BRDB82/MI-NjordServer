#!/bin/bash

#
# Assumptions:
#  1) User has partioned, formatted, and mounted partitions on /mnt
#  2) Network is functional
#  3) Arguments passed to the script are valid dnf targets
#  4) A valid repo appears in /etc/yum.repos.d

shopt -s extglob
source "/usr/bin/dnfcommon"

hostcache=0
copyrepolist=1
dnf_args=()
dng_group_args=()
dnfmode="install"
copyconf=0
dnf_config="/etc/dnf/dnf.conf"

usage() {
  cat <<EOF
usage: ${0##*/} [options] root [packages...]

  Options:
    -C <config>    Use an alternate config file for dnf
    -c             Use the package cache on the host, rather than the target
    -D             Skip dnf dependency checks
    -i             Prompt for package confirmation when needed (run interactively)
    -M             Avoid copying the host's repolist to the target
    -P             Copy the host's dnf config to the target

    -h             Print this help message

pacstrap installs packages to the specified new root directory. If no packages
are given, pacstrap defaults to the "base" group.

EOF
}

dnfstrap() {
  (( EUID == 0 )) || die 'This script must be run with root privileges'

  # create obligatory directories
  msg 'Creating install root at %s' "$newroot"
  # shellcheck disable=SC2174 # permissions are perfectly fine here
  mkdir -m 0755 -p "$newroot"/var/{cache/dnf,lib/rpm,log} "$newroot"/{dev,run,etc/yum.repos.d}
  # shellcheck disable=SC2174 # permissions are perfectly fine here
  mkdir -m 1777 -p "$newroot"/tmp
  # shellcheck disable=SC2174 # permissions are perfectly fine here
  mkdir -m 0555 -p "$newroot"/{sys,proc}

  # mount API filesystems
  $setup "$newroot" || die "failed to setup chroot %s" "$newroot"

  msg 'Installing packages to %s' "$newroot"

  # If no arguments are passed after root, default to @core
  (( $# == 0 )) && set -- @core
  
  # Filter group targets and regular packages
  while [[ $# -gt 0 ]]; do
    case $1 in
      @*)
        dnf_group_args+=("$1")  # preserve @ prefix
        ;;
      *)
        dnf_args+=("$1")
        ;;
    esac
    shift
  done
  
  # First install groups inside chroot
  for group in "${dnf_group_args[@]}"; do
    msg 'Installing group "%s" inside installroot' "$group"
    if ! dnf group install "$group" \
          --installroot="$newroot" \
          --setopt=group_package_types=mandatory,default \
          --assumeyes; then
      die 'Failed to install group "%s"' "$group"
    fi
  done
  
  # Then install regular packages into installroot
  if (( ${#dnf_args[@]} )); then
    if ! dnf --installroot="$newroot" "${dnf_args[@]}"; then
      die 'Failed to install packages to new root'
    fi
  fi


  if (( copyrepolist )); then
    # install the host's repo definitions onto the new root
    cp -a /etc/yum.repos.d "$newroot/etc/"
  fi

  if (( copyconf )); then
    cp -a "$dnf_config" "$newroot/etc/dnf/dnf.conf"
  fi
}

if [[ -z $1 || $1 = @(-h|--help) ]]; then
  usage
  exit $(( $# ? 0 : 1 ))
fi

while getopts ':C:cDiMPh' flag; do
  case $flag in
    C)
      dnf_config=$OPTARG
      ;;
    D)
      dnf_args+=(--setopt=skip_if_unavailable=True)
      ;;
    c)
      hostcache=1
      ;;
    i)
      dnf_args+=("--assumeyes")
      ;;
    M)
      copyrepolist=0
      ;;
    P)
      copyconf=1
      ;;
    h)
      usage
      exit 0
      ;;
    :)
      die '%s: option requires an argument -- '\''%s'\''' "${0##*/}" "$OPTARG"
      ;;
    ?)
      die "%s: invalid option -- '\''%s'\'" "${0##*/}" "$OPTARG"
      ;;
  esac
done

shift $(( OPTIND - 1 ))

(( $# )) || die "No root directory specified"
newroot=$1
shift

[[ -d $newroot ]] || die "%s is not a directory" "$newroot"

dnf_args+=("${@:-@core}" --config="$dnf_config" --installroot="$newroot")

if (( ! hostcache )); then
  dnf_args+=(--setopt=keepcache=False)
fi

if (( ! interactive )); then
  dnf_args+=(--assumeyes)
fi

setup=chroot_setup
dnfstrap
