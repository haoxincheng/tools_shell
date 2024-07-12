#!/usr/bin/env bash
# set -e # 状态码非0则退出脚本
# set -o pipefail # 管道只有在所有命令都成功的情况下才会返回成功状态，需要配合set -e不然不退出只是返回状态
# set -u # 在运行时遇到未定义的变量则退出脚本
# set -x # 开启调试模式debug

export PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
script_current_path=$(cd "$(dirname "$0")" || exit; pwd)

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
NGINX_VERSIONS=(
  "1.24.0"
  "1.23.3"
  "1.22.1"
  "1.21.6"
  "1.20.2"
)

# 默认选择的 Nginx 版本
DEFAULT_VERSION=0

echo "1. case nginx version:"
for i in "${!NGINX_VERSIONS[@]}"; do
  echo "$i) ${NGINX_VERSIONS[$i]}"
done


while true ;do
  # 读取用户输入, 不允许超过列表范围
  read -r -p "input (default: ${NGINX_VERSIONS[$DEFAULT_VERSION]}): " VERSION_INDEX
  if [[ ${VERSION_INDEX} -ge 0 ]] && [[ ${VERSION_INDEX} -lt ${#NGINX_VERSIONS[@]} ]] ;then
    NGINX_VERSION=${NGINX_VERSIONS[$VERSION_INDEX]}
    echo_info "install version: ${NGINX_VERSION}"
    break
  else
    echo_error "Please check your input [ 0 ~ ${#NGINX_VERSIONS[@]} ]."
  fi

done


# 读取用户输入, 不允许超过列表范围
read -r -p "2. install_dirpath (default: /usr/local/nginx_${NGINX_VERSION}): " INSTALL_DIRPATH
[[ -z "${INSTALL_DIRPATH}" ]] && INSTALL_DIRPATH="/usr/local/nginx_${NGINX_VERSION}"
mkdir -p "${INSTALL_DIRPATH}"

sleep_time=10
echo_info "INFO: Wait for ${sleep_time} seconds, installation can be canceled 'ctrl+c' within ${sleep_time} seconds."
(set -x ;sleep ${sleep_time})

# 安装依赖工具和库
sudo yum install -y gcc pcre-devel zlib-devel make unzip

# 创建一个目录用于存放下载的源码
cd /usr/local/src || exit 1

# 下载 Nginx 源码包
if ! wget https://nginx.org/download/nginx-"$NGINX_VERSION".tar.gz ;then
  echo_error "ERROR: nginx src package download failed, script exitd!"
  exit 1
fi

# 解压源码包
tar -zxvf nginx-"$NGINX_VERSION".tar.gz
cd nginx-$NGINX_VERSION || exit 1

# 配置编译选项
./configure \
    --prefix=${INSTALL_DIRPATH} \
    --sbin-path=${INSTALL_DIRPATH}/sbin \
    --conf-path=${INSTALL_DIRPATH}/nginx.conf \
    --pid-path=${INSTALL_DIRPATH}/nginx.pid \
    --with-http_ssl_module \
    --with-http_v2_module \
    --with-http_realip_module \
    --with-http_stub_status_module \
    --with-http_gzip_static_module

# 编译并安装
make
if make install
exit 1
# 配置环境变量
echo 'export PATH=$PATH:/usr/local/nginx/sbin' >> ~/.bash_profile
source ~/.bash_profile

service_dir=/lib/systemd/system
service_name=nginx.service
# 创建 systemd 服务文件
if ! [ -f ${service_dir}/${service_name} ] ;then
  service_name="nginx_$NGINX_VERSION.service"
fi

cp -a nginx.service ${service_dir}/${service_name}
  sudo systemctl daemon-reload
  sudo systemctl start nginx
  sudo systemctl enable nginx



# 验证安装
nginx -v
