#!/bin/bash

#!/bin/bash

# Redirect stout and stderr to njord.txt and still output to console
exec > >(tee -i njord.txt)
exec 2>&1

echo -ne "
████╗  ███╗██╗              ███╗   ██╗     ██╗ ██████╗ ██████╗ ██████╗ 
████╗ ████║██║              ████╗  ██║     ██║██╔═══██╗██╔══██╗██╔══██╗
██╔████╔██║██║    █████╗    ██╔██╗ ██║     ██║██║   ██║██████╔╝██║  ██║
██║╚██╔╝██║██║    ╚════╝    ██║╚██╗██║██   ██║██║   ██║██╔══██╗██║  ██║
██║ ╚═╝ ██║██║              ██║ ╚████║╚█████╔╝╚██████╔╝██║  ██║██████╔╝
╚═╝     ╚═╝╚═╝              ╚═╝  ╚═══╝ ╚════╝  ╚═════╝ ╚═╝  ╚═╝╚═════╝ 
                                                                       
           ███████╗███████╗██████╗ ██╗   ██╗███████╗██████╗                       
           ██╔════╝██╔════╝██╔══██╗██║   ██║██╔════╝██╔══██╗                      
           ███████╗█████╗  ██████╔╝██║   ██║█████╗  ██████╔╝                     
           ╚════██║██╔══╝  ██╔══██╗╚██╗ ██╔╝██╔══╝  ██╔══██╗                      
           ███████║███████╗██║  ██║ ╚████╔╝ ███████╗██║  ██║                      
           ╚══════╝╚══════╝╚═╝  ╚═╝  ╚═══╝  ╚══════╝╚═╝  ╚═╝
-----------------------------------------------------------------------
                  Automated Rocky Linux Installer
-----------------------------------------------------------------------

Verifying Rocky Linux ISO is Booted

"

if ! ps aux | grep "[a]naconda" > /dev/null; then
 echo "This script must be run from a Rocky Linux ISO environment."
 exit 1
fi

root_check() {
    if [[ "$(id -u)" != "0" ]]; then
        echo -ne "ERROR! This script must be run under the 'root' user!\n"
        exit 0
    fi
}

docker_check() {
    if awk -F/ '$2 == "docker"' /proc/self/cgroup | read -r; then
        echo -ne "ERROR! Docker container is not supported (at the moment)\n"
        exit 0
    elif [[ -f /.dockerenv ]]; then
        echo -ne "ERROR! Docker container is not supported (at the moment)\n"
        exit 0
    fi
}

rhel_check() {
    if [[ ! -e /etc/redhat-release ]]; then
        echo -ne "ERROR! This script must be run on RedHat-based Linux!\n"
        exit 0
    fi
}

dnf_check() {
    if [[ -f /var/lib/dnf/lock ]] || ps -e | grep -w -E 'dnf|yum' >/dev/null; then
        echo "ERROR! DNF is blocked."
        echo -ne "If not running remove /var/lib/dnf/lock or kill the running process.\n"
        exit 0
    fi
}

background_checks() {
    root_check
    rhel_check
    dnf_check
    docker_check
}

select_option() {
    local options=("$@")
    local num_options=${#options[@]}
    local selected=0
    local last_selected=-1

    while true; do
        # Move cursor up to the start of the menu
        if [ $last_selected -ne -1 ]; then
            echo -ne "\033[${num_options}A"
        fi

        if [ $last_selected -eq -1 ]; then
            echo "Please select an option using the arrow keys and Enter:"
        fi
        for i in "${!options[@]}"; do
            if [ "$i" -eq $selected ]; then
                echo "> ${options[$i]}"
            else
                echo "  ${options[$i]}"
            fi
        done

        last_selected=$selected

        # Read user input
        read -rsn1 key
        case $key in
            $'\x1b') # ESC sequence
                read -rsn2 -t 0.1 key
                case $key in
                    '[A') # Up arrow
                        ((selected--))
                        if [ $selected -lt 0 ]; then
                            selected=$((num_options - 1))
                        fi
                        ;;
                    '[B') # Down arrow
                        ((selected++))
                        if [ $selected -ge $num_options ]; then
                            selected=0
                        fi
                        ;;
                esac
                ;;
            '') # Enter key
                break
                ;;
        esac
    done

    return $selected
}

# @description Displays MI - Njord Server logo
# @noargs
logo() {
# This will be shown on every set as user is progressing
echo -ne "
████╗  ███╗██╗              ███╗   ██╗     ██╗ ██████╗ ██████╗ ██████╗ 
████╗ ████║██║              ████╗  ██║     ██║██╔═══██╗██╔══██╗██╔══██╗
██╔████╔██║██║    █████╗    ██╔██╗ ██║     ██║██║   ██║██████╔╝██║  ██║
██║╚██╔╝██║██║    ╚════╝    ██║╚██╗██║██   ██║██║   ██║██╔══██╗██║  ██║
██║ ╚═╝ ██║██║              ██║ ╚████║╚█████╔╝╚██████╔╝██║  ██║██████╔╝
╚═╝     ╚═╝╚═╝              ╚═╝  ╚═══╝ ╚════╝  ╚═════╝ ╚═╝  ╚═╝╚═════╝ 
                                                                       
           ███████╗███████╗██████╗ ██╗   ██╗███████╗██████╗                       
           ██╔════╝██╔════╝██╔══██╗██║   ██║██╔════╝██╔══██╗                      
           ███████╗█████╗  ██████╔╝██║   ██║█████╗  ██████╔╝                     
           ╚════██║██╔══╝  ██╔══██╗╚██╗ ██╔╝██╔══╝  ██╔══██╗                      
           ███████║███████╗██║  ██║ ╚████╔╝ ███████╗██║  ██║                      
           ╚══════╝╚══════╝╚═╝  ╚═╝  ╚═══╝  ╚══════╝╚═╝  ╚═╝
-----------------------------------------------------------------------
            Please select presetup settings for your system
-----------------------------------------------------------------------
"
}
# @description This function will handle file systems. At this moment we are handling only
# ext2, ext3, ext4, and xfs. Others will be added in future.
filesystem () {
    echo -ne "
    Please Select your file system for both boot and root
    "
    options=("btrfs" "xfs" "ext4" "exit")
    select_option "${options[@]}"

    case $? in
    0) export FS=btrfs;;
    1) export FS=xfs;;
    2) export FS=ext4;;
    3) exit ;;
    *) echo "Wrong option please select again"; filesystem;;
    esac
}
# @description Detects and sets timezone for Rocky Linux.
timezone () {
    # Attempt to detect timezone using external service
    time_zone="$(curl --fail -s https://ipapi.co/timezone)"
    echo -ne "
System detected your timezone to be '$time_zone' \n"
    echo -ne "Is this correct?
    "
    options=("Yes" "No")
    select_option "${options[@]}"

    case $? in
        0)
            echo "${time_zone} set as timezone"
            export TIMEZONE=$time_zone
            timedatectl set-timezone "$time_zone"
            ;;
        1)
            echo "Please enter your desired timezone e.g. Europe/Brussels :"
            read -r new_timezone
            echo "${new_timezone} set as timezone"
            export TIMEZONE=$new_timezone
            timedatectl set-timezone "$new_timezone"
            ;;
        *)
            echo "Wrong option. Try again"
            timezone
            ;;
    esac
}
# @description Set user's keyboard mapping for Rocky Linux.
keymap () {
    echo -ne "
Please select keyboard layout from this list
"
    # These are default key maps commonly supported on Rocky Linux
    options=(us by ca cf cz de dk es et fa fi fr gr hu il it lt lv mk nl no pl ro ru se sg ua uk)

    select_option "${options[@]}"
    keymap=${options[$?]}

    echo -ne "Your keyboard layout: ${keymap} \n"
    export KEYMAP=$keymap

    # Apply the selected keymap using localectl
    localectl set-keymap "$keymap"
}
# @description Choose whether drive is SSD or not for Rocky Linux (non-Btrfs).
drivessd () {
    echo -ne "
Is this an SSD? yes/no:
"
    options=("Yes" "No")
    select_option "${options[@]}"

    case $? in
        0)
            export MOUNT_OPTIONS="noatime,commit=120"
            ;;
        1)
            export MOUNT_OPTIONS="noatime,commit=120"
            ;;
        *)
            echo "Wrong option. Try again"
            drivessd
            ;;
    esac
}

# @description Disk selection for drive to be used with installation.
diskpart () {
echo -ne "
------------------------------------------------------------------------
    THIS WILL FORMAT AND DELETE ALL DATA ON THE DISK
    Please make sure you know what you are doing because
    after formatting your disk there is no way to get data back
    *****BACKUP YOUR DATA BEFORE CONTINUING*****
    ***I AM NOT RESPONSIBLE FOR ANY DATA LOSS***
------------------------------------------------------------------------

"

    PS3='
    Select the disk to install on: '
    options=($(lsblk -n --output TYPE,KNAME,SIZE | awk '$1=="disk"{print "/dev/"$2"|"$3}'))

    select_option "${options[@]}"
    disk=${options[$?]%|*}

    echo -e "\n${disk%|*} selected \n"
        export DISK=${disk%|*}

    drivessd
}

# @description Gather username and password to be used for installation.
userinfo () {
    # Loop through user input until the user gives a valid username
    while true
    do
            read -r -p "Please enter username: " username
            if [[ "${username,,}" =~ ^[a-z_]([a-z0-9_-]{0,31}|[a-z0-9_-]{0,30}\$)$ ]]
            then
                    break
            fi
            echo "Incorrect username."
    done
    export USERNAME=$username

    while true
    do
        read -rs -p "Please enter password: " PASSWORD1
        echo -ne "\n"
        read -rs -p "Please re-enter password: " PASSWORD2
        echo -ne "\n"
        if [[ "$PASSWORD1" == "$PASSWORD2" ]]; then
            break
        else
            echo -ne "ERROR! Passwords do not match. \n"
        fi
    done
    export PASSWORD=$PASSWORD1

     # Loop through user input until the user gives a valid hostname, but allow the user to force save
    while true
    do
            read -r -p "Please name your machine: " name_of_machine
            # hostname regex (!!couldn't find spec for computer name!!)
            if [[ "${name_of_machine,,}" =~ ^[a-z][a-z0-9_.-]{0,62}[a-z0-9]$ ]]
            then
                    break
            fi
            # if validation fails allow the user to force saving of the hostname
            read -r -p "Hostname doesn't seem correct. Do you still want to save it? (y/n)" force
            if [[ "${force,,}" = "y" ]]
            then
                    break
            fi
    done
    export NAME_OF_MACHINE=$name_of_machine
}

clear() {
  printf "\033[H\033[J" #clear
}

# Starting functions
background_checks
clear
logo
userinfo
clear
logo
diskpart
clear
logo
filesystem
clear
logo
timezone
clear
logo
keymap

echo "Setting up mirrors for optimal download"
is=$(curl -4 -s ifconfig.io/coutnry_code)
timedatectl set-ntp true
#determine RHEL derivative, currently only Rocky is supported
if ! grep -qi '^ID=rocky' /etc/os-release 2>/dev/null; then
  # Only support Rocky for now

  # Detect latest Rocky Linux version
  VERSION=$(curl -s https://download.rockylinux.org/pub/rocky/ | \
    sed 's/href=/\n&/g' | \
    awk -F'"' '/href="[0-9]+\.[0-9]+\/"/ {print $2}' | \
    sed 's/\/$//' | \
    sort -V | tail -1)

  mkdir -p /etc/yum.repos.d

  if [ ! -f /etc/yum.repos.d/Rocky-BaseOS.repo ]; then
    {
      echo "[baseos]"
      echo "name=Rocky Linux $VERSION - BaseOS"
      echo "baseurl=https://dl.rockylinux.org/pub/rocky/$VERSION/BaseOS/x86_64/os/"
      echo "enabled=1"
      echo "gpgcheck=0"
    } > /etc/yum.repos.d/Rocky-BaseOS.repo
  fi

  if [ ! -f /etc/yum.repos.d/Rocky-AppStream.repo ]; then
    {
      echo "[appstream]"
      echo "name=Rocky Linux $VERSION - AppStream"
      echo "baseurl=https://dl.rockylinux.org/pub/rocky/$VERSION/AppStream/x86_64/os/"
      echo "enabled=1"
      echo "gpgcheck=0"
    } > /etc/yum.repos.d/Rocky-AppStream.repo
  fi

  # Create /etc/os-release for Rocky
  MAJOR=$(echo "$VERSION" | cut -d. -f1)
  cat > /etc/os-release <<EOF
NAME="Rocky Linux"
VERSION="$VERSION (Red Quartz)"
ID="rocky"
VERSION_ID="$VERSION"
PLATFORM_ID="platform:el$MAJOR"
PRETTY_NAME="Rocky Linux $VERSION (Red Quartz)"
ANSI_COLOR="0;34"
CPE_NAME="cpe:/o:rocky:rocky:$VERSION"
HOME_URL="https://rockylinux.org/"
BUG_REPORT_URL="https://bugs.rockylinux.org/"
EOF
else
  # If Rocky is present, extract VERSION from os-release
  VERSION=$(awk -F= '/^VERSION_ID=/{gsub(/"/,"",$2);print $2}' /etc/os-release)
fi

dnf --releasever=$VERSION update
dnf --releasever=$VERSION clean all
dnf --releasever=$VERSION install -y makecache
dnf --releasever=$VERSION install -y rpm
dnf --releasever=$VERSION install -y epel-release --nogpgcheck
dnf --releasever=$VERSION install -y dnf-plugins-core rsync grub2 grub2-tools kbd 
dnf install -y https://dl.fedoraproject.org/pub/epel/8/Everything/x86_64/Packages/t/terminus-fonts-console-4.48-1.el8.noarch.rpm --nogpgcheck
setfont ter-118b

if [ ! -d "/mnt" ]; then
    mkdir /mnt
fi
echo -ne "
-------------------------------------------------------------------------
                    Installing Prerequisites
-------------------------------------------------------------------------
"
dnf --releasever=$VERSION config-manager --set-enabled epel
dnf --releasever=$VERSION install -y gdisk btrfs-progs
echo -ne "
-------------------------------------------------------------------------
                    Creating Filesystems
-------------------------------------------------------------------------
"
# @description Creates the btrfs subvolumes.
createsubvolumes () {
    btrfs subvolume create /mnt/@
    btrfs subvolume create /mnt/@home
}

# @description Mount all btrfs subvolumes after root has been mounted.
mountallsubvol () {
    mount -o "${MOUNT_OPTIONS}",subvol=@home "${partition3}" /mnt/home
}

# @description BTRFS subvolulme creation and mounting.
subvolumesetup () {
# create nonroot subvolumes
    createsubvolumes
# unmount root to remount with subvolume
    umount /mnt
# mount @ subvolume
    mount -o "${MOUNT_OPTIONS}",subvol=@ "${partition3}" /mnt
# make directories home, .snapshots, var, tmp
    mkdir -p /mnt/home
# mount subvolumes
    mountallsubvol
}

if [[ "${DISK}" =~ "nvme" ]]; then
    partition2=${DISK}p2
    partition3=${DISK}p3
else
    partition2=${DISK}2
    partition3=${DISK}3
fi

if [[ "${FS}" == "btrfs" ]]; then
    mkfs.fat -F32 -n "EFIBOOT" "${partition2}"
    mkfs.btrfs -f "${partition3}"
    mount -t btrfs "${partition3}" /mnt
    subvolumesetup
elif [[ "${FS}" == "ext4" ]]; then
    mkfs.fat -F32 -n "EFIBOOT" "${partition2}"
    mkfs.ext4 "${partition3}"
    mount -t ext4 "${partition3}" /mnt
elif [[ "${FS}" == "luks" ]]; then
    mkfs.fat -F32 "${partition2}"
# enter luks password to cryptsetup and format root partition
    echo -n "${LUKS_PASSWORD}" | cryptsetup -y -v luksFormat "${partition3}" -
# open luks container and ROOT will be place holder
    echo -n "${LUKS_PASSWORD}" | cryptsetup open "${partition3}" ROOT -
# now format that container
    mkfs.btrfs "${partition3}"
# create subvolumes for btrfs
    mount -t btrfs "${partition3}" /mnt
    subvolumesetup
    ENCRYPTED_PARTITION_UUID=$(blkid -s UUID -o value "${partition3}")
fi

BOOT_UUID=$(blkid -s UUID -o value "${partition2}")

sync
if ! mountpoint -q /mnt; then
    echo "ERROR! Failed to mount ${partition3} to /mnt after multiple attempts."
    exit 1
fi
mkdir -p /mnt/boot
mount -U "${BOOT_UUID}" /mnt/boot/

if ! grep -qs '/mnt' /proc/mounts; then
    echo "Drive is not mounted can not continue"
    echo "Rebooting in 3 Seconds ..." && sleep 1
    echo "Rebooting in 2 Seconds ..." && sleep 1
    echo "Rebooting in 1 Second ..." && sleep 1
    reboot now
fi

