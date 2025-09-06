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

rocky_check() {
    if [[ ! -e /etc/rocky-release ]]; then
        echo -ne "ERROR! This script must be run on Rocky Linux!\n"
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
    rocky_check
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
    options=("ext2" "ext3" "ext4" "xfs" "exit")
    select_option "${options[@]}"

    case $? in
    0) export FS=ext2;;
    1) export FS=ext3;;
    2) export FS=ext4;;
    3) export FS=xfs;;
    4) exit ;;
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
    # Filter only rotational disks (ROTA=1), exclude USB/CD-ROM
    options=($(lsblk -dn -o NAME,SIZE,ROTA | awk '$3==1{print "/dev/"$1"|"$2}'))

    select_option "${options[@]}"
    disk=${options[$?]%|*}

    echo -e "\n${disk} selected \n"
    export DISK=${disk}

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

# Starting functions
background_checks
printf "\033[H\033[J" #clear
logo
userinfo
printf "\033[H\033[J" #clear
logo
diskpart
printf "\033[H\033[J" #clear
logo
filesystem
printf "\033[H\033[J" #clear
logo
timezone
printf "\033[H\033[J" #clear
logo
keymap

echo "Setting up repositories for optimal download"

# Detect country code for potential mirror selection (not used directly in Rocky)
#iso=$(curl -4 -s ifconfig.io/country_code)

# Enable NTP for time sync
timedatectl set-ntp true

# Ensure dnf is ready and update metadata
mkdir -p /etc/yum.repos.d

echo "[baseos]
name=Rocky Linux 10 - BaseOS
baseurl=https://dl.rockylinux.org/pub/rocky/10/BaseOS/x86_64/os/
enabled=1
gpgcheck=0" | tee /etc/yum.repos.d/Rocky-BaseOS.repo

echo "[appstream]
name=Rocky Linux 10 - AppStream
baseurl=https://dl.rockylinux.org/pub/rocky/10/AppStream/x86_64/os/
enabled=1
gpgcheck=0" | tee /etc/yum.repos.d/Rocky-AppStream.repo

echo 'NAME="Rocky Linux"
VERSION="10.0 (Red Quartz)"
ID="rocky"
VERSION_ID="10.0"
PLATFORM_ID="platform:el10"
PRETTY_NAME="Rocky Linux 10.0 (Red Quartz)"
ANSI_COLOR="0;34"
CPE_NAME="cpe:/o:rocky:rocky:10.0"
HOME_URL="https://rockylinux.org/"
BUG_REPORT_URL="https://bugs.rockylinux.org/"
' > /etc/os-release

dnf --releasever=10.0 clean all
dnf --releasever=10.0 makecache

# Install useful packages
dnf --releasever=10.0 install -y rocky-release
dnf --releasever=10.0 install -y epel-release
dnf --releasever=10.0 install -y rsync grub2-tools setfont kbd

# Set console font (if applicable)
setfont lat9w-16

# Backup existing repo files
mkdir -p /etc/yum.repos.d/backup
cp /etc/yum.repos.d/*.repo /etc/yum.repos.d/backup/

echo -ne "
-------------------------------------------------------------------------
                    Repositories prepared for $iso region
-------------------------------------------------------------------------
"

# Optional: You could manually adjust repo baseurls here if you have a mirror list
# For example, using a local mirror or CDN-optimized repo

# Ensure /mnt exists
if [ ! -d "/mnt" ]; then
    mkdir /mnt
fi

echo -ne "
-------------------------------------------------------------------------
                    Formatting Disk
-------------------------------------------------------------------------
"
umount -A --recursive /mnt  # Ensure everything is unmounted

# Create a new GPT partition table
parted -s "${DISK}" mklabel gpt

# Create partitions
# BIOS Boot Partition (1 MiB)
parted -s "${DISK}" mkpart BIOSBOOT 1MiB 2MiB
parted -s "${DISK}" set 1 bios_grub on

# EFI System Partition (1 GiB)
parted -s "${DISK}" mkpart EFIBOOT fat32 2MiB 1026MiB
parted -s "${DISK}" set 2 boot on

# Root Partition (rest of disk)
parted -s "${DISK}" mkpart ROOT ext4 1026MiB 100%

# Refresh kernel partition table
partprobe "${DISK}"

echo -ne "
-------------------------------------------------------------------------
                    Creating Filesystems
-------------------------------------------------------------------------
"

if [[ "${DISK}" =~ "nvme" ]]; then
    partition2=${DISK}p2
    partition3=${DISK}p3
else
    partition2=${DISK}2
    partition3=${DISK}3
fi

if [[ "${FS}" == "ext4" ]]; then
    mkfs.fat -F32 -n "EFIBOOT" "${partition2}"
    mkfs.ext4 "${partition3}"
    mount -t ext4 "${partition3}" /mnt

elif [[ "${FS}" == "xfs" ]]; then
    mkfs.fat -F32 -n "EFIBOOT" "${partition2}"
    mkfs.xfs -f "${partition3}"
    mount -t xfs "${partition3}" /mnt

elif [[ "${FS}" == "luks" ]]; then
    mkfs.fat -F32 "${partition2}"
    echo -n "${LUKS_PASSWORD}" | cryptsetup -y -v luksFormat "${partition3}" -
    echo -n "${LUKS_PASSWORD}" | cryptsetup open "${partition3}" ROOT -
    mkfs.ext4 /dev/mapper/ROOT
    mount -t ext4 /dev/mapper/ROOT /mnt
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
    echo "Drive is not mounted, cannot continue"
    echo "Rebooting in 3 Seconds ..." && sleep 1
    echo "Rebooting in 2 Seconds ..." && sleep 1
    echo "Rebooting in 1 Second ..." && sleep 1
    reboot now
fi

echo -ne "
-------------------------------------------------------------------------
                    Rocky Linux Install on Main Drive
-------------------------------------------------------------------------
"

# Detect UEFI or BIOS
if [[ -d "/sys/firmware/efi" ]]; then
    BOOT_MODE="UEFI"
else
    BOOT_MODE="BIOS"
fi

# Install base system into /mnt
dnf --installroot=/mnt --releasever=10.0 --setopt=install_weak_deps=False -y groupinstall "Core"
dnf --installroot=/mnt --releasever=10.0 -y install linux-firmware grub2 efibootmgr

# Copy resolv.conf for networking inside chroot
cp /etc/resolv.conf /mnt/etc/resolv.conf

# Generate fstab
echo -ne "
-------------------------------------------------------------------------
                    Generating /etc/fstab
-------------------------------------------------------------------------
"
blkid | while read -r line; do
    dev=$(echo "$line" | cut -d: -f1)
    uuid=$(echo "$line" | grep -o 'UUID="[^"]*"' | cut -d'"' -f2)
    type=$(echo "$line" | grep -o 'TYPE="[^"]*"' | cut -d'"' -f2)
    mountpoint=$(findmnt -n -o TARGET "$dev")
    [[ -z "$mountpoint" ]] && continue
    echo "UUID=$uuid $mountpoint $type defaults 0 0" >> /mnt/etc/fstab
done

echo "
  Generated /etc/fstab:
"
cat /mnt/etc/fstab
