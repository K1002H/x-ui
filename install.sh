#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

cur_dir=$(pwd)

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}错误：${plain} 必须使用root用户运行此脚本！\n" && exit 1

# check os
if [[ -f /etc/redhat-release ]]; then
    release="centos"
elif cat /etc/issue | grep -Eqi "debian"; then
    release="debian"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
elif cat /proc/version | grep -Eqi "debian"; then
    release="debian"
elif cat /proc/version | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
else
    echo -e "${red}未检测到系统版本，请联系脚本作者！${plain}\n" && exit 1
fi

arch=$(arch)

if [[ $arch == "x86_64" || $arch == "x64" || $arch == "amd64" ]]; then
    arch="amd64"
elif [[ $arch == "aarch64" || $arch == "arm64" ]]; then
    arch="arm64"
elif [[ $arch == "s390x" ]]; then
    arch="s390x"
else
    arch="amd64"
    echo -e "${red}检测架构失败，使用默认架构: ${arch}${plain}"
fi

echo "架构: ${arch}"

if [ $(getconf WORD_BIT) != '32' ] && [ $(getconf LONG_BIT) != '64' ]; then
    echo "本软件不支持 32 位系统(x86)，请使用 64 位系统(x86_64)，如果检测有误，请联系作者"
    exit -1
fi

os_version=""

# os version
if [[ -f /etc/os-release ]]; then
    os_version=$(awk -F'[= ."]' '/VERSION_ID/{print $3}' /etc/os-release)
fi
if [[ -z "$os_version" && -f /etc/lsb-release ]]; then
    os_version=$(awk -F'[= ."]+' '/DISTRIB_RELEASE/{print $2}' /etc/lsb-release)
fi

if [[ x"${release}" == x"centos" ]]; then
    if [[ ${os_version} -le 6 ]]; then
        echo -e "${red}请使用 CentOS 7 或更高版本的系统！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    if [[ ${os_version} -lt 16 ]]; then
        echo -e "${red}请使用 Ubuntu 16 或更高版本的系统！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "${red}请使用 Debian 8 或更高版本的系统！${plain}\n" && exit 1
    fi
fi

install_base() {
    if [[ x"${release}" == x"centos" ]]; then
        yum install wget curl tar -y
    else
        apt install wget curl tar -y
    fi
}

#This function will be called when user installed xy out of sercurity
config_after_install() {
    echo -e "${yellow}出于安全考虑，安装/更新完成后需要强制修改端口与账户密码${plain}"
    read -p "确认是否继续?[y/n]": config_confirm
    if [[ x"${config_confirm}" == x"y" || x"${config_confirm}" == x"Y" ]]; then
        read -p "请设置您的账户名:" config_account
        echo -e "${yellow}您的账户名将设定为:${config_account}${plain}"
        read -p "请设置您的账户密码:" config_password
        echo -e "${yellow}您的账户密码将设定为:${config_password}${plain}"
        read -p "请设置面板访问端口:" config_port
        echo -e "${yellow}您的面板访问端口将设定为:${config_port}${plain}"
        echo -e "${yellow}确认设定,设定中${plain}"
        /usr/local/xy/xy setting -username ${config_account} -password ${config_password}
        echo -e "${yellow}账户密码设定完成${plain}"
        /usr/local/xy/xy setting -port ${config_port}
        echo -e "${yellow}面板端口设定完成${plain}"
    else
        echo -e "${red}已取消,所有设置项均为默认设置,请及时修改${plain}"
    fi
}

install_xy() {
    systemctl stop xy
    cd /usr/local/

    if [ $# == 0 ]; then
        last_version=$(curl -Ls "https://ghapi.fullcloud.tk/repos/K1002H/xy/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        if [[ ! -n "$last_version" ]]; then
            echo -e "${red}检测 xy 版本失败，可能是超出 Github API 限制，请稍后再试，或手动指定 xy 版本安装${plain}"
            exit 1
        fi
        echo -e "检测到 xy 最新版本：${last_version}，开始安装"
        wget -N --no-check-certificate -O /usr/local/xy-linux-${arch}.tar.gz https://gh.fullcloud.tk/https://github.com/K1002H/xy/releases/download/${last_version}/xy-linux-${arch}.tar.gz
        if [[ $? -ne 0 ]]; then
            echo -e "${red}下载 xy 失败，请确保你的服务器能够下载 Github 的文件${plain}"
            exit 1
        fi
    else
        last_version=$1
        url="https://gh.fullcloud.tk/https://github.com/K1002H/xy/releases/download/${last_version}/xy-linux-${arch}.tar.gz"
        echo -e "开始安装 xy v$1"
        wget -N --no-check-certificate -O /usr/local/xy-linux-${arch}.tar.gz ${url}
        if [[ $? -ne 0 ]]; then
            echo -e "${red}下载 xy v$1 失败，请确保此版本存在${plain}"
            exit 1
        fi
    fi

    if [[ -e /usr/local/xy/ ]]; then
        rm /usr/local/xy/ -rf
    fi

    tar zxvf xy-linux-${arch}.tar.gz
    rm xy-linux-${arch}.tar.gz -f
    cd xy
    chmod +x xy bin/xy-linux-${arch}
    cp -f xy.service /etc/systemd/system/
    wget --no-check-certificate -O /usr/bin/xy https://gh.fullcloud.tk/https://raw.githubusercontent.com/K1002H/xy/main/xy.sh
    chmod +x /usr/local/xy/xy.sh
    chmod +x /usr/bin/xy
    config_after_install
    #echo -e "如果是全新安装，默认网页端口为 ${green}54321${plain}，用户名和密码默认都是 ${green}admin${plain}"
    #echo -e "请自行确保此端口没有被其他程序占用，${yellow}并且确保 54321 端口已放行${plain}"
    #    echo -e "若想将 54321 修改为其它端口，输入 xy 命令进行修改，同样也要确保你修改的端口也是放行的"
    #echo -e ""
    #echo -e "如果是更新面板，则按你之前的方式访问面板"
    #echo -e ""
    systemctl daemon-reload
    systemctl enable xy
    systemctl start xy
    echo -e "${green}xy v${last_version}${plain} 安装完成，面板已启动，"
    echo -e ""
    echo -e "xy 管理脚本使用方法: "
    echo -e "----------------------------------------------"
    echo -e "xy              - 显示管理菜单 (功能更多)"
    echo -e "xy start        - 启动 xy 面板"
    echo -e "xy stop         - 停止 xy 面板"
    echo -e "xy restart      - 重启 xy 面板"
    echo -e "xy status       - 查看 xy 状态"
    echo -e "xy enable       - 设置 xy 开机自启"
    echo -e "xy disable      - 取消 xy 开机自启"
    echo -e "xy log          - 查看 xy 日志"
    echo -e "xy v2-ui        - 迁移本机器的 v2-ui 账号数据至 xy"
    echo -e "xy update       - 更新 xy 面板"
    echo -e "xy install      - 安装 xy 面板"
    echo -e "xy uninstall    - 卸载 xy 面板"
    echo -e "----------------------------------------------"
}

echo -e "${green}开始安装${plain}"
install_base
install_xy $1
