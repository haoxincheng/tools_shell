#!/usr/bin/env bash
# set -e # 状态码非0则退出脚本
# set -o pipefail # 管道只有在所有命令都成功的情况下才会返回成功状态，需要配合set -e不然不退出只是返回状态
# set -u # 在运行时遇到未定义的变量则退出脚本
# set -x # 开启调试模式debug

export PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
script_current_path=$(cd "$(dirname "$0")" || exit; pwd)

DNS1="114.114.114.114"
DNS2="8.8.8.8"

# color
declare red_color="\033[91m"   
declare green_color="\033[92m"
declare golden_color="\033[93m" 
declare purple_color="\033[95m"
declare blue_color="\033[96m"
declare color_end="\033[0m" 

function echo_info() {
  echo -e "${blue_color}$*${color_end}"
}
function echo_suss() {
  echo -e "${golden_color}$*${color_end}"
}
function echo_error() {
  echo -e "${red_color}$*${color_end}"
}

# 获取当前的动态IP，这个代码有bug，如果这个接口有2个IP脚本就无法跑了
#interfaces=$(ip addr show | awk '/dynamic/ {print $NF}')

interfaces=$(ip addr show | awk '
/^[0-9]+: / {
    if (interface != "" && ip_count == 1 && dynamic_ip_count == 1) {
        print interface
    }
    interface = $2
    sub(":", "", interface)
    ip_count = 0
    dynamic_ip_count = 0
}

/inet / {
    ip_count++
}

/inet / && /dynamic/ {
    dynamic_ip_count++
}

END {
    if (interface != "" && ip_count == 1 && dynamic_ip_count == 1) {
        print interface
    }
}
')

# 检查是否获取到接口
if [ -z "$interfaces" ]; then
    echo_error "ERROR：No dhcp network interfaces found, exitd."
    exit 1
fi

# 函数用于选择网络接口
select_interface() {
    echo "Available dhcp network interfaces:"
    select interface in $interfaces; do
        if [[ -n "$interface" ]]; then
            echo "You have selected interface: $interface"
            echo $interface
            return
        else
            echo "Invalid selection, please try again."
        fi
    done
}

select_interface

# 获取当前接口的IP地址、子网掩码和网关
current_ip=$(ip -4 addr show $interface | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
current_netmask=$(ip -4 addr show $interface | grep -oP '(?<=inet\s)\d+(\.\d+){3}/\d+' | cut -d'/' -f2)
current_gateway=$(ip -4 addr show $interface | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | sed 's/\.[0-9]\+$/\.2/')

# 检查是否获取到有效的 IP、子网掩码和网关
if [[ -z "$current_ip" ]] || [[ -z "$current_netmask" ]] ; then
    echo "Unable to retrieve IP or netmask for interface $interface, exitd!"
    exit 1
fi

echo "Current IP: $current_ip"
echo "Current Netmask: $current_netmask"
echo "Current Gateway: $current_gateway"
echo "Current DNS1: $DNS1"
echo "Current DNS2: $DNS2"
echo " "
# 备份原配置文件
config_file="/etc/sysconfig/network-scripts/ifcfg-$interface"
cp "$config_file" "${config_file}".bak-$(date "+%Y%m%d%H%M%S")

# 修改配置文件
cat <<EOL > "$config_file"
TYPE=Ethernet
BOOTPROTO=static
UUID=$(uuidgen)
NAME=$interface
DEVICE=$interface
ONBOOT=yes
IPADDR=$current_ip
PREFIX=$current_netmask
GATEWAY=$current_gateway
DNS1=${DNS1}
DNS2=${DNS2}
EOL

# 重启网络服务
(
    set -x;
    cat "$config_file"
    ls -dl "$config_file"
)
echo ""
echo_info "[INFO] Please run it manually, it will take effect after running."
echo_suss "ifdown $interface && ifup $interface"
