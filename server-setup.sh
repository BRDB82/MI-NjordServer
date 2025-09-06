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
    if [[ -f /var/lib/dnf/lock ]] || pgrep -x dnf >/dev/null || pgrep -x yum >/dev/null; then
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
