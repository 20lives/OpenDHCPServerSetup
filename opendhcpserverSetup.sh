#!/bin/bash

set -e

work_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
bridge="br1"
bridge_ip="192.168.0.1"
subnet_mask="255.255.255.0"
bridge_subnet="$(echo "${bridge_ip}" | rev | cut -d "." -f2- | rev)"

dhcp_serv_inst="opendhcpV1.75.tar.gz"
cfg_file="/opt/opendhcp/opendhcp.ini"
dns_servers=""

function print_usage {
    cat <<EOU
  Usage:
    ${BASH_SOURCE[0]} [--config-only] [--dns-servers[=<list_servers>] [--help]

  Options:
    --config-only                   - create new config file w/o server installation
    --dns-servers                   - add Google DNS (8.8.8.8) to DHCP config (default: no DNS)
    --dns-servers=1.1.1.1,8.8.8.4   - add specified DNS servers to DHCP config (default: no DNS)
    --help                          - show this information
EOU
}

function download_server {
    wget "https://downloads.sourceforge.net/project/dhcpserver/Open%20DHCP%20Server%20%28Regular%29/${dhcp_serv_inst}"
    if [ ! -f "${work_dir}/${dhcp_serv_inst}" ]; then
        echo "DHCP Server Installation file is missing"
        exit 1
    fi
}

function configure_bridge {
    cat >"/etc/sysconfig/network-scripts/ifcfg-$bridge" <<EOC
DEVICE=$bridge
TYPE=Bridge
ONBOOT=yes
DELAY=0
BOOTPROTO=static
IPADDR=$bridge_ip
NETMASK=$subnet_mask
BROADCAST=$bridge_subnet.255
NETWORK=$bridge_subnet.0
EOC
}

function install_server {
    tar -xf "${work_dir}/${dhcp_serv_inst}" -C /opt/
    rm -fv "${work_dir}/${dhcp_serv_inst}"
    chmod 755 /opt/opendhcp/opendhcpd
    ln -sf /opt/opendhcp/rc.opendhcp /etc/init.d/opendhcp
    chmod 755 /etc/init.d/opendhcp
    chkconfig --add opendhcp
    chkconfig opendhcp on
    configure_bridge
    ifup "${bridge}"
}

function restart_server {
    service opendhcp restart
}

function configure_server {
    cat >"${cfg_file}" <<EOC
[LISTEN_ON]
${bridge_ip}
[LOGGING]
LogLevel=None
[GLOBAL_OPTIONS]
SubNetMask=$subnet_mask
Router=$bridge_ip
EOC
    if [ -n "${dns_servers}" ]; then
        cat >>"${cfg_file}" <<EOC
DomainServer=${dns_servers}
EOC
    fi

    # QemuHCK setup manager
    for i in {2..99}; do
        i2=$(printf "%02d" "${i}")

        cat >>"${cfg_file}" <<EOC
[56:00:${i2}:00:dd:dd]
IP=${bridge_subnet}.${i}
EOC
    done

    # VirtHCK setup manager
    for i in {2..99}; do
        i2=$(printf "%02d" "${i}")

        cat >>"${cfg_file}" <<EOC
[56:00:${i2}:00:${i2}:dd]
IP=${bridge_subnet}.${i}
EOC
    done
}

skip_install=false
for i in "$@"; do
  case $i in
    --config-only)
      skip_install=true
      ;;
    --dns-servers)
      dns_servers="8.8.8.8"
      ;;
    --dns-servers=*)
      dns_servers="${i/*=/}"
      ;;
    --help)
      print_usage
      exit 0
      ;;
    *)
      echo "Unknown option: $i"
      print_usage
      exit 1
      ;;
  esac
done

if [ "${skip_install}" = "false" ]; then
    download_server
    install_server
fi

configure_server
restart_server
