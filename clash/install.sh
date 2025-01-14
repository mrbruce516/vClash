#! /bin/sh
#########################################################
# Clash Process Control script for ASUS/merlin firmware compiled by Koolshare
# Writen by Awkee (next4nextjob(at)gmail.com)
# Website: https://vlike.work
#########################################################

KSHOME="/koolshare"

source ${KSHOME}/scripts/base.sh

app_name="clash"
DIR=$(cd $(dirname $0); pwd)
module=${DIR##*/}

# 软硬件基本信息 #
MODEL=""            # 路由器设备型号
ARCH=""             # CPU架构
FW_TYPE_NAME=""     # 固件类型名称
BUILD_VERSION=""    # 固件版本信息

BIN_LIST="${app_name} yq uri_decoder jq"

# 反馈问题链接
open_issue="给开发者反馈一下这个问题吧！ https://github.com/learnhard-cn/vClash/issues/"

LOGGER() {
    logger -s -t "`date +%Y年%m月%d日%H:%M:%S`:clash" "$@"
}

# ================================== INSTALL_CHECK 安装前的系统信息检查 =========================

exit_install() {
    case "$1" in
    0)
        LOGGER "恭喜您!安装完成！"
        exit 0
    ;;
    *)
        LOGGER "糟糕！ 不支持 `uname -m` 平台呀！ 您的路由器型号:$MODEL ,固件类型： $FW_TYPE_NAME ,固件版本：$BUILD_VERSION ,$open_issue"
        exit $1
    ;;
    esac
}

get_arch(){
    # 暂时支持ARM芯片，这将决定使用哪个编译版本可执行程序
    case `uname -m` in
        armv7l)     # ARM平台
            if grep -i vfpv3 /proc/cpuinfo >/dev/null 2>&1 ; then
                ARCH="armv7"
            elif grep -i vfpv1 /proc/cpuinfo >/dev/null 2>&1 ; then
                ARCH="armv6"
            else
                ARCH="armv5"
            fi
        ;;
        aarch64)    # hnd(High end)平台
            ARCH="armv8"  # hnd 平台 可以使用 armv5/v6/v7/v8 可执行程序
        ;;

        *)
            exit_install 1
            exit 0
        ;;
    esac
}

get_model(){
	local ODMPID=$(nvram get odmpid)
	local PRODUCTID=$(nvram get productid)
	if [ -n "${ODMPID}" ];then
		MODEL="${ODMPID}"
	else
		MODEL="${PRODUCTID}"
	fi
}

get_fw_type() {
    local KS_TAG=$(nvram get extendno|grep koolshare)
    if [ -d "$KSHOME" ];then
        if [ -n "${KS_TAG}" ];then
            FW_TYPE_CODE="2"
            FW_TYPE_NAME="koolshare官改固件"
        else
            FW_TYPE_CODE="4"
            FW_TYPE_NAME="koolshare梅林改版固件"
        fi
    else
        if [ "$(uname -o|grep Merlin)" ];then
            FW_TYPE_CODE="3"
            FW_TYPE_NAME="梅林原版固件"
        else
            FW_TYPE_CODE="1"
            FW_TYPE_NAME="华硕官方固件"
        fi
    fi
}

# 固件平台支撑检测
platform_test() {
    # 固件平台支撑检测
    #   原则： 最少的条件，做大的容错性(白话：能用就让安装)
    #
    # 检测最基本的支撑条件：
    #   1. 固件版本检测
    #   2. 基础依赖环境： koolshare软件中心、skipdb(数据库)
    get_model
    
    # 固件版本检测
    get_fw_type
    get_arch
    BUILD_VERSION="$(nvram get buildno| cut -d '.' -f1)"
    if [ "$BUILD_VERSION" != "380" -a "$BUILD_VERSION" != "386" -a "$BUILD_VERSION" != "384" ]; then
        LOGGER "本插件仅支持华硕官改/梅林改版固件的380、384和386版本!而您的固件版本为: $BUILD_VERSION"
        exit_install 2
    fi

    if [ -d "/koolshare" -a -f "/usr/bin/skipd" ];then
        ks_ver=$(dbus get softcenter_version)
        if [ "$ks_ver" = "" ] ; then
            LOGGER "找不到 软件中心版本 信息！"
            exit_install 3
        fi
        LOGGER "软件中心版本: $ks_ver (大于v1.5即可),机型：${MODEL} ${FW_TYPE_NAME} 符合安装要求！"
    else
        LOGGER "/koolshare目录与skipd检测失败!"
        exit_install 4
    fi
}

# 清理旧文件，升级情况需要
remove_files() {
    
    if [ -d "/koolshare/${app_name}" ] ; then
        LOGGER 开始 清理旧文件
        rm -rf /koolshare/${app_name}
        rm -rf /koolshare/scripts/${app_name}_*
        rm -rf /koolshare/webs/Module_${app_name}.asp
        for fn in ${BIN_LIST}; do
            rm -f /koolshare/bin/${fn}
        done
        rm -rf /koolshare/res/icon-${app_name}.png
        rm -rf /koolshare/res/${app_name}_*
        rm -rf /koolshare/init.d/S??${app_name}.sh
        LOGGER 完成 清理旧文件
    fi
}

copy_files() {
    LOGGER 开始复制文件！
    cd /tmp/${module}/
    mkdir -p /koolshare/${app_name}

    LOGGER 复制相关二进制文件！此步时间可能较长！
    for fn in ${BIN_LIST}; do

        cp -f ./bin/${fn}_for_${ARCH} /koolshare/bin/${fn}
        chmod +x /koolshare/bin/${fn}
        LOGGER "安装可执行程序: ${fn} 完成."
    done

    LOGGER 复制相关的脚本文件！
    cp -rf ./${app_name}/ /koolshare/
    cp -f ./scripts/${app_name}_*.sh /koolshare/scripts/
    cp -f ./uninstall.sh /koolshare/scripts/uninstall_${app_name}.sh

    chmod 755 /koolshare/scripts/${app_name}_*.sh

    LOGGER 复制相关的网页文件！
    cp -rf ./webs/Module_${app_name}.asp /koolshare/webs/
    cp -rf ./res/${app_name}_* /koolshare/res/
    cp -rf ./res/icon-${app_name}.png /koolshare/res/

    LOGGER 添加自启动脚本软链接
    [ ! -L "/koolshare/init.d/S99${app_name}.sh" ] && ln -sf /koolshare/scripts/${app_name}_control.sh /koolshare/init.d/S99${app_name}.sh
    
    LOGGER 添加Clash面板页面软链接
    [ ! -L "/www/ext/dashboard" ] && ln -sf /koolshare/${app_name}/dashboard /www/ext/dashboard
}

# 设置初始化环境变量信息 #
init_env() {
    LOGGER 设置一些默认值
    # 默认不启用
    [ -z "$(eval echo '$'${app_name}_enable)" ] && dbus set ${app_name}_enable="off"

    dbus set clash_provider_file="https://cdn.jsdelivr.net/gh/learnhard-cn/free_proxy_ss@main/clash/clash.provider.yaml"
    dbus set clash_provider_file_old="https://cdn.jsdelivr.net/gh/learnhard-cn/free_proxy_ss@main/clash/clash.provider.yaml"
    dbus set clash_group_type="select"  # 默认组节点选择模式 select
    dbus set clash_trans="on"           # 默认开启透明代理模式
    dbus set clash_gfwlist_mode="off"   # 默认启用DNSMASQ黑名单列表(使用Dnsmasq的URL列表生成需要代理的ipset,并在iptables中作为使用代理判断规则)
    dbus set clash_use_local_dns="on"   # 默认启用本地DNS解析
    dbus set clash_cfddns_enable="off"  # 默认关闭DDNS解析
    
    CUR_VERSION=$(cat /koolshare/${app_name}/version)
    dbus set ${app_name}_version="$CUR_VERSION"

    # 离线安装时设置软件中心内储存的版本号和连接
    dbus set softcenter_module_${app_name}_install="1"
    dbus set softcenter_module_${app_name}_version="$CUR_VERSION"
    dbus set softcenter_module_${app_name}_title="Clash版科学上网"
    dbus set softcenter_module_${app_name}_description="Clash版科学上网 for Koolshare"
    dbus set softcenter_module_${app_name}_home_url="Module_${app_name}.asp"
}

# 判断是否需要重启，对于升级插件时需要
need_action() {
    action=$1
    if [ "$(eval echo '$'$app_name}_enable)" == "1" ]; then
        LOGGER 安装前需要的执行操作: ${action} ！
        sh /koolshare/scripts/${app_name}_control.sh ${action}
    fi

}

# 清理安装包
clean() {
    LOGGER 移除安装包！
    cd /tmp
    rm -rf /tmp/${app_name}  /tmp/${app_name}.tar.gz >/dev/null 2>&1
}

# ================================== INSTALL_START 开始安装 =========================

main() {
    LOGGER Clash版科学上网插件开始安装！

    platform_test       # 安装前平台支撑检测(只有符合条件才会继续安装)
    need_action stop    # 安装前，停止已安装应用
    remove_files        # 清理历史遗留文件，如果有
    copy_files          # 安装需要的所有文件
    init_env            # 初始化环境变量信息,设置插件信息
    need_action restart # 是否需要重启服务
    clean               # 清理安装包

    LOGGER Clash版科学上网插件安装成功！
    LOGGER "忠告: Clash运行时分配很大虚拟内存，可能在700MB左右, 如果你的内存很小，那么启动失败的概率很大！解决办法是：用U盘挂个1GB的虚拟内存!切记！"
    LOGGER "如何挂载虚拟内存： 软件中心自带 虚拟内存 插件，安装即用！"
}

main
