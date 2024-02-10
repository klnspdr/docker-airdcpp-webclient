#!/bin/bash

check_config_permissions () {
    # Check permissions
    find /.airdcpp -print0 |
    while IFS= read -r -d '' item
    do
        if [[ ! (-r "$item" && -w "$item") ]]
        then
            echo "Can't read/write configuration."
            echo "Make sure that UID $(id -u) can read/write the"
            echo "configuraton directory and all files therin."
            exit 1
        fi
    done
}

init_config () {
    # If configuration doesn't exist, create defaults
    if [[ ! -r /.airdcpp/DCPlusPlus.xml ]]
    then
        cp /.default-config/* /.airdcpp
    fi

    # Remove unencrypted backup of WebServer.xml (not used anymore)
    rm -f /.airdcpp/WebServer.xml.bak
}

validate_id () {
    # Check PUID/PGID values
    if [[ -z "${PUID}" || -z "${PGID}" ]]
    then
        echo "PUID and PGID variables must be set when container is run as root."
        exit 1
    fi
    if [[ "${PUID}" -lt 101 || "${PGID}" -lt 101 ]]
    then
        echo "PUID must be >= 101 and PGID must be >= 101 due to existing IDs in the image."
        echo "If you need to use a lower ID, start container with --user <uid>:<gid> instead."
        exit 1
    fi
}

create_user_and_group () {
    # Create airdcpp user and group if needed
    if [[ "$(id -u airdcpp &>/dev/null)" != "${PUID}" || "$(id -g airdcpp)" != "${PGID}" ]]
    then
        groupdel airdcpp &>/dev/null
        userdel airdcpp &>/dev/null
        groupadd -f -g ${PGID} airdcpp || exit 1
        useradd -u ${PUID} -g ${PGID} --no-create-home -s /usr/sbin/nologin airdcpp || exit 1
    fi
}

take_ownership () {
    # Set ownership of config files and make all files writable
    chown -R ${PUID}:${PGID} /.airdcpp
    chmod -R u+rw /.airdcpp
}

mount_smb_share () {
    # check whether container has required capabilites to mount the smb share
    
    if capsh --print | grep -q '!cap_sys_admin\|!cap_dac_read_search'; then
        echo "The Docker container is missing one or both of the following capabilities; please add them:" && echo " - SYS_ADMIN" && echo " - DAC_READ_SEARCH"
        exit 1
    else
        # check whether all the required environment variables are supplied
        if [[ -z "${SMB_HOST}" || -z "${SMB_SHARE}" || -z "${SMB_USERNAME}" || -z "${SMB_PASSWORD}" ]]; then
            echo "Please make sure all of the following environment variables are set:" && echo " - SMB_HOST " && echo " - SMB_SHARE " && echo " - SMB_USERNAME " && echo " - SMB_PASSWORD"
            exit 1
        else
            # mount share
            mount -t cifs //"$SMB_HOST"/"$SMB_SHARE" /mnt/smb-share -o username="$SMB_USERNAME",password="$SMB_PASSWORD"

            # Check the exit status of the mount command
            if [ $? -eq 0 ]; then
                echo "SMB share mounted successfully at /mnt/smb-share"
            else
                echo "Error: failed to mount SMB share"
                exit 1
            fi
        fi
    fi

    # mount SMB share
}  

if [[ ! -z "$LOG_STARTUP" ]]
then
    set -x
fi

if [[ ! -z "$UMASK" ]]
then
    if [[ ! "$UMASK" =~ ^0?[0-7]{1,3}$ ]]
    then
        echo "The umask value $UMASK is not valid. It must be an octal number such as 0022 (or 22 without leading 0)"
        exit 1
    fi
    umask $UMASK
fi

if [[ "$container" == "podman" ]] || [[ "$(id -u)" -ne 0 ]]
then
    # Container is run as a normal user or with podman
    check_config_permissions
    init_config

    # Start airdcppd
    exec /airdcpp-webclient/airdcppd "$@"
else
    # Container is run as root
    validate_id
    create_user_and_group
    take_ownership
    init_config
    mount_smb_share

    # Start airdcppd
    exec runuser -u airdcpp -g airdcpp -- /airdcpp-webclient/airdcppd "$@"
fi
