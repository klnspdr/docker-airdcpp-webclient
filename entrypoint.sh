#!/bin/bash
set -x

# Remove unencrypted backup of WebServer.xml (not used anymore)
rm -f /.airdcpp/WebServer.xml.bak

# Create symlink to configuration directory
ln -sf /.airdcpp /airdcpp-webclient/config

# If configuration doesn't exist, create defaults
if [[ ! -r /.airdcpp/DCPlusPlus.xml ]]
then
    cp /.default-config/* /.airdcpp
fi

if [[ "$(id -u)" -ne 0 ]]
then
    # Container is run as a normal user
    echo "Any read/write error to configuration files is most likely due to permission issues."
    echo "Make sure that all files in /.airdcpp are owned by $(id -u):$(id -g)."

    # Start airdcppd
    exec /airdcpp-webclient/airdcppd "$@"
else
    # Container is run as root

    # Check PUID/PGID values
    if [[ -z "${PUID}" || -z "${PGID}" ]]
    then
        echo "PUID and PGID variables must be set when container is run as root."
        exit 1
    fi
    if [[ "${PUID}" -lt 101 || "${PGID}" -lt 100 ]]
    then
        echo "PUID must be >= 101 and PGID must be >= 100."
        echo "If you need to use a lower ID, start container with --user <uid>:<gid> instead."
        exit 1
    fi

    # Create airdcpp user and group if needed
    if [[ "$(id -u airdcpp &>/dev/null)" != "${PUID}" || "$(id -g airdcpp)" != "${PGID}" ]]
    then
        groupdel airdcpp &>/dev/null
        userdel airdcpp &>/dev/null
        groupadd -f -g ${PGID} airdcpp || exit 1
        useradd -u ${PUID} -g ${PGID} --no-create-home -s /usr/sbin/nologin airdcpp || exit 1
    fi

    # Set ownership of config files and make all files writable
    chown -R ${PUID}:${PGID} /.airdcpp
    chmod -R u+w /.airdcpp/*

    # Start airdcppd
    exec runuser -u airdcpp -g airdcpp -- /airdcpp-webclient/airdcppd "$@"
fi
