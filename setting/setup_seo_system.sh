#!/usr/bin/env bash
# set -e # 状态码非0则退出脚本
# set -o pipefail # 管道只有在所有命令都成功的情况下才会返回成功状态，需要配合set -e不然不退出只是返回状态
# set -u # 在运行时遇到未定义的变量则退出脚本
# set -x # 开启调试模式debug

export PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
script_current_path=$(cd "$(dirname "$0")" ; pwd)
cd $script_current_path


# 定义 JSON 文件路径
json_file="setup_seo_system.json"

declare -A actions
index=1

# 读取json
while IFS="=" read -r key value; do
    actions["$index"]=$value
    keys+=("$key")
    ((index++))
done < <(jq -r 'to_entries | .[] | "\(.key)=\(.value)"' "$json_file")


echo "请选择一个操作："
for ((i=0; i<${#keys[@]}; i+=2)); do
    printf "%2d). %-30s %2d). %-30s\n" "$((i+1))" "${keys[i]}" "$((i+2))" "${keys[i+1]}"
    # echo "$((i+1))). ${keys[i]}  $((i+2))). ${keys[i+1]}"
done

# 读取用户选择
read -r -p "请输入有效的数字: " choice


disable_firewall() {
    echo "Disabling firewall..."
    ( 
        set -x
        systemctl stop firewalld 
        systemctl disable firewalld
    )
    echo "Firewall disabled."
}


disable_selinux(){
    echo "Disabling selinux..."
    ( 
        set -x
        setenforce 0 
        cp -a /etc/selinux/config /etc/selinux/config.bak_`date "+%Y%m%d%H%M%S"`
        sed -i '/SELINUX/s/enforcing/disabled/' /etc/selinux/config
    )
}

disable_swap() {
    echo "Disabling swap..."
    ( 
        set -x
        cp -a /etc/fstab /etc/fstab.bak_`date "+%Y%m%d%H%M%S"`
        swapoff -a
        sed -i '/swap/s/^/#/' /etc/fstab
    )
}

enable_cpu_irqbalance(){
    yum -y install irqbalance
    systemctl enable irqbalance
    systemctl start irqbalance
    systemctl status irqbalance
}

enable_firewall() {
    echo "执行：开启firewalld服务"
    # 在此处添加实际的命令
}

enable_selinux() {
    echo "执行：开启selinux策略"
    # 在此处添加实际的命令
}


# 检查选择的有效性并执行相应的函数
if [[ $choice -ge 0 && $choice -le ${#actions[@]} ]]; then
    # 动态执行函数
    ${actions[$choice]}
else
    echo "无效的选择，请输入1-${#actions[@]}之间的数字。"
fi
