#!/bin/bash

CURRENT_DIR=$(dirname "$0")
ROOT_DIR=$(cd "$CURRENT_DIR/.." && pwd)

# 导入日志模块和检查工具模块
source $ROOT_DIR/logger.sh
source $ROOT_DIR/utils/check_utils.sh
source $ROOT_DIR/utils/utils.sh


# 检查是否以root用户运行
if [ "$(id -u)" != "0" ]; then
    log_error "此脚本必须以root用户运行"
    exit 1
fi

# 定义配置文件路径
CONFIG_FILE_PATH="${ROOT_DIR}/config/config.conf"

# 从配置文件读取配置
if [ -f "$CONFIG_FILE_PATH" ]; then
    log_info "检测到配置文件 ${CONFIG_FILE_PATH}，正在读取配置..."
    source "$CONFIG_FILE_PATH"
fi

# 获取用户输入的IP配置（如果配置文件中未定义）
if [ -z "$ip" ]; then
    log_info "请输入IP地址（例如：192.168.1.100）："
    read ip
    while ! validate_ip "$ip"; do
        log_warn "IP地址格式不正确，请重新输入："
        read ip
    done
fi

# 获取用户输入的子网掩码（如果配置文件中未定义）
if [ -z "$netmask" ]; then
    log_info "请输入子网掩码位数（例如：24）："
    read netmask
    while ! [[ "$netmask" =~ ^[0-9]+$ ]] || [ "$netmask" -lt 1 ] || [ "$netmask" -gt 32 ]; do
        log_warn "子网掩码位数不正确，请输入1-32之间的数字："
        read netmask
    done
fi

# 获取用户输入的网关地址（如果配置文件中未定义）
if [ -z "$gateway" ]; then
    log_info "请输入网关地址（例如：192.168.1.1）："
    read gateway
    while ! validate_ip "$gateway"; do
        log_warn "网关地址格式不正确，请重新输入："
        read gateway
    done
fi

# 获取网卡名称
NIC_NAME=""
if [ -d "/etc/NetworkManager/system-connections" ]; then
    # 查找第一个有效的网卡配置文件
    for file in /etc/NetworkManager/system-connections/*.nmconnection; do
        if [ -f "$file" ]; then
            # 从配置文件中提取网卡名称
            temp_name=$(grep -Po '^interface-name=\K.*' "$file" || grep -Po '^id=\K.*' "$file")
            if [ -n "$temp_name" ]; then
                NIC_NAME="$temp_name"
                break
            fi
        fi
    done
fi

# 如果没有找到网卡名称，使用默认值
if [ -z "$NIC_NAME" ]; then
    NIC_NAME="ens160"
    log_warn "未找到现有网卡配置，使用默认网卡名称：${NIC_NAME}"
fi

# 检查当前IP配置
current_ip=$(get_current_ip)
if [ $? -eq 0 ] && [ "$current_ip" = "$ip" ]; then
    # 获取当前子网掩码
    current_mask=$(ip addr show $NIC_NAME | grep -w inet | awk '{print $2}' | cut -d'/' -f2)
    if [ "$current_mask" = "$netmask" ]; then
        log_info "当前IP配置（${current_ip}/${current_mask}）与输入配置一致，无需修改"
        exit 0
    fi
fi

# 定义IP配置
IP_ADDRESS="${ip}/${netmask}"
DNS_SERVERS="114.114.114.114;114.114.115.115"

# 检查网卡是否存在
check_nic "$NIC_NAME"

# 检查网卡配置文件是否存在
CONFIG_FILE="/etc/NetworkManager/system-connections/${NIC_NAME}.nmconnection"
BACKUP_FILE="${CONFIG_FILE}.backup.$(date +%s)"

# 获取原配置文件的UUID
if [ -f "$CONFIG_FILE" ]; then
    # 检查是否已配置固定IP
    if grep -q "method=manual" "$CONFIG_FILE" && grep -q "$IP_ADDRESS" "$CONFIG_FILE"; then
        log_warn "网卡 ${NIC_NAME} 已配置为固定IP ${IP_ADDRESS}，无需重复配置"
        exit 0
    fi
    
    # 备份原配置文件
    cp "$CONFIG_FILE" "$BACKUP_FILE"
    log_info "已备份原配置文件到 ${BACKUP_FILE}"
    
    # 获取原UUID
    UUID=$(grep -Po '^uuid=\K.*' "$CONFIG_FILE" || uuidgen)
else
    # 如果配置文件不存在，生成新的UUID
    UUID=$(uuidgen)
    log_info "创建新的网卡配置文件"
fi

# 创建新的网卡配置文件
cat > "$CONFIG_FILE" << EOF
[connection]
id=${NIC_NAME}
uuid=${UUID}
type=ethernet
interface-name=${NIC_NAME}
autoconnect-priority=-999

[ethernet]

[ipv4]
method=manual
address1=${IP_ADDRESS}/${gateway}
dns=${DNS_SERVERS}

[ipv6]
method=disabled
EOF

# 设置配置文件权限
chmod 600 "$CONFIG_FILE"
log_info "已设置配置文件权限"

# 检查网卡状态并启用
log_info "正在检查网卡状态..."
if nmcli d show "$NIC_NAME" | grep -q "disconnected"; then
    log_info "网卡处于断开状态，正在启用网卡..."
    nmcli d connect "$NIC_NAME"
    sleep 2
fi

# 重启网络设备和连接
log_info "正在重启网络设备和连接..."
nmcli d r "$NIC_NAME"
nmcli c r "$NIC_NAME"
nmcli c d "$NIC_NAME"
nmcli c u "$NIC_NAME"

log_info "网卡配置完成，当前IP地址：${IP_ADDRESS}"