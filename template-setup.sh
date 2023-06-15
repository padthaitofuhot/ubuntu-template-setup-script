#!/usr/bin/env bash

#    A simple setup script for Ubuntu templates.
#    Copyright (C) 2023 Travis Wichert
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <https://www.gnu.org/licenses/>.

o() {
    printf "%s\n" "${*}"
}

asksure() {
    read -p "${*} <y/N> " -r -e
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        return 0
    else
        return 1
    fi
}

ask() {
    local _prompt
    local _answer
    
    _prompt="${*}"
    _answer=''
    
    while true; do
        read -p "${_prompt} " -r -e _answer
        if asksure "Is \"${_answer}\" correct?"; then 
            printf "%s" "${_answer}"
            break
        fi
    done
}

checkip() {
    echo "${*}" | grep -q '^[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*$'
    return $?
}

checkhostname() {
    echo "${*}" | grep -q '^[a-z][a-z0-9-]*$'
    return $?
}

checkprefix() {
    echo "${*}" | grep -q '^[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*\/[0-9]*$'
    return $?
}

init_hostname() {
    hostnamectl set-hostname "${MY_HOSTNAME}"
    hostnamectl set-hostname "${MY_HOSTNAME}" --pretty
    hostname "${MY_HOSTNAME}"
}

init_machineid() {
    rm -vf /etc/machine-id && systemd-machine-id-setup
}

init_ssh() {
    rm -vf /etc/ssh/ssh_host_*
    dpkg-reconfigure openssh-server
}

init_network() {
    rm -vf /etc/netplan/00-installer-config.yaml
    envsubst <<EOF >/etc/netplan/00-net-config.yaml
# This is the network config written by 'subiquity'
network:
  ethernets:
    ens18:
      addresses:
      - ${MY_PREFIX}
      nameservers:
        addresses:
        - 10.10.10.10
        search: []
      routes:
      - to: default
        via: ${MY_GATEWAY}
  version: 2
EOF
    netplan generate
}

##############################################################################
o "Ubuntu Template Setup v1.9.0"
o "~~~~~~~~~~~~~~~~~~~~~~~~~~~~"

##### Check if Root #####
if ! [[ "${UID}" -eq 0 ]]; then
    o "Setup script must be run as root. Please run like this:"
    o "sudo bash ${0}"
    exit 1
fi

#### Change Password #####
if ! [[ "${1}" == "--skip-password" ]]; then
    o "First, change the password:"
    i=1
    until passwd; do
        if [[ $((i++)) -ge 3 ]]; then
            o "Skipped by persistence..."
            o "Make sure the password is actually changed, please."
            break
        fi
        o "Attempt ${i}/3 (or run with --skip-password to skip)"
    done
else
    o "Skipping password change..."
    o "Make sure the password is actually changed, please."
fi

##### Init Hostname #####
export MY_HOSTNAME=''
until checkhostname "${MY_HOSTNAME}"; do
    MY_HOSTNAME="$(ask "hostname:")"
done

##### Init Prefix #####
export MY_PREFIX=''
until checkprefix "${MY_PREFIX}"; do
    MY_PREFIX="$(ask "ip/cidr (ex. 192.168.0.8/24):")"
done

##### Init Gateway #####
export MY_GATEWAY=''
until checkip "${MY_GATEWAY}"; do
    MY_GATEWAY="$(ask "gateway (ex. 192.168.0.1):")"
done    

#### Run Init #####
if ! asksure "Ready to install?"; then
    exit 1
fi

o "Init hostname"
init_hostname
o "Init machine-id" 
init_machineid
o "Init ssh keys"
init_ssh
o "Init network"
init_network

o "All done!"

##### Reboot #####
if asksure "Would you like to reboot now?"; then
    o "Rebooting..."
    reboot
fi

o "Make sure to reboot!"
