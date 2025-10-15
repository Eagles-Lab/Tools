#!/bin/bash

CURRENT_DIR=$(dirname "$0")
ROOT_DIR=$(cd "$CURRENT_DIR/.." && pwd)

# 导入日志模块
source $ROOT_DIR/logger.sh

# 检查并安装软件包
install_package() {
    if ! rpm -q "$1" &>/dev/null; then
        log_info "正在安装 $1"
        if ! yum -y install "$1"; then
            log_error "安装 $1 失败"
            return 1
        fi
    else
        log_info "软件包 $1 已安装"
    fi
    return 0
}

# 获取当前IP地址
get_current_ip() {
    local ip=$(ip route get 1 | awk '{print $7; exit}')
    if [ -n "$ip" ]; then
        echo "$ip"
        return 0
    else
        log_error "无法获取当前IP地址"
        return 1
    fi
}

# 根据IP地址设置主机名
set_hostname_by_ip() {
    local ip=$1
    local hostname_from_hosts=$(grep "$ip" /etc/hosts | awk '{print $2}')
    if [ -n "$hostname_from_hosts" ]; then
        log_info "根据IP地址 $ip 设置主机名为 $hostname_from_hosts"
        hostnamectl set-hostname "$hostname_from_hosts"
        return 0
    else
        log_warn "在hosts文件中未找到IP $ip 对应的主机名记录"
        return 1
    fi
}

# 验证IP地址格式
validate_ip() {
    local ip=$1
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        for i in {1..4}; do
            if [ $(echo "$ip" | cut -d. -f$i) -gt 255 ]; then
                return 1
            fi
        done
        return 0
    else
        return 1
    fi
}

# 解压压缩包至指定目录
extract_archive() {
    local archive_file=$1
    local extract_dir=$2
    
    command -v tar >/dev/null || {
        log_error "tar命令未找到，请确保tar已安装"
        return 1
    }

    check_archive "$archive_file" || return 1

    mkdir -p "$extract_dir"

    log_info "正在解压 '$archive_file' 到 '$extract_dir'..."
    if ! tar -xzf "$archive_file" -C "$extract_dir" >/dev/null 2>&1; then
        log_error "解压失败: '$archive_file'"
        return 1
    fi
    log_info "解压成功!"
    return 0
}

# 检查压缩包是否需要解压
check_archive_unchanged() {
    local archive_file=$1
    local hash_file=$2
    local extract_base_dir=$3
    
    # 计算压缩包的MD5哈希值
    local archive_hash=$(md5sum "$archive_file" | cut -d' ' -f1)
    
    # 检查是否存在之前的哈希值记录
    if [ -f "$hash_file" ] && [ "$(cat $hash_file)" == "$archive_hash" ]; then
        log_info "压缩包内容未变更，跳过解压步骤"
        return 0
    fi
    
    # 如果目录已存在，先删除
    [ -d "$extract_base_dir" ] && rm -rf "$extract_base_dir"
    
    # 解压压缩包
    if ! extract_archive "$archive_file" "$extract_base_dir"; then
        return 1
    fi
    
    # 保存新的哈希值
    echo "$archive_hash" > "$hash_file"
    return 2
}

# 将文件名转换为正确的镜像名称
convert_filename_to_image() {
    local filename="$1"
    local basename=$(basename "$filename" .tar)
    
    if [[ $basename =~ ^registry.k8s.io-ingress-nginx- ]]; then
        # 处理 registry.k8s.io/ingress-nginx/ 开头的镜像
        local component="${basename#registry.k8s.io-ingress-nginx-}"
        # 对于包含多个连字符的版本号，需要特殊处理
        if [[ $component =~ (.*)-v([^-]*)(-.*)$ ]]; then
            local name="${BASH_REMATCH[1]}"
            local version="v${BASH_REMATCH[2]}${BASH_REMATCH[3]}"
        else
            local name="${component%-*}"
            local version="${component##*-}"
            [[ $version == v* ]] || version="v$version"
        fi
        echo "registry.k8s.io/ingress-nginx/$name:$version"
    elif [[ $basename =~ ^calico- ]]; then
        # 处理 calico 镜像
        local component="${basename#calico-}"
        local name="${component%-*}"
        local version="${component##*-}"
        echo "calico/$name:$version"
    else
        # 处理其他通用格式
        echo "$basename" | sed 's/-/\//g' | sed 's/__/:/g'
    fi
}

# 从指定源下载文件
download_file() {
    local filename="$1"
    local sources=(
        "http://10.3.0.11:8889/pkg"
        "http://file.eagleslab.com:8889/pkg"
    )
    
    for source in "${sources[@]}"; do
        local url="${source}/${filename}"
        log_info "正在尝试从 ${url} 下载文件..."
        
        if curl -f -# -o "${filename}" "${url}"; then
            log_info "文件下载成功: ${filename}"
            return 0
        else
            log_warn "从 ${source} 下载失败，尝试下一个源..."
        fi
    done
    
    log_error "所有源都下载失败"
    return 1
}