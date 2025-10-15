#!/bin/bash

CURRENT_DIR=$(dirname "$0")
ROOT_DIR=$(cd "$CURRENT_DIR/.." && pwd)

# 导入日志模块
source "${ROOT_DIR}/logger.sh"

# 检查命令是否存在
check_command() {
    if ! command -v "$1" &>/dev/null; then
        log_error "命令 $1 不存在，请先安装"
        return 1
    fi
    return 0
}

# 检查网卡是否存在
check_nic() {
    if ! ip link show "$1" &>/dev/null; then
        log_error "网卡 $1 不存在"
        exit 1
    fi
}

# 检查文件是否存在
check_file() {
    if [ -f "$1" ]; then
        log_warn "文件 $1 已存在"
        return 1
    fi
    return 0
}

# 检查目录是否存在
check_directory() {
    if [ ! -d "$1" ]; then
        log_info "创建目录 $1"
        mkdir -p "$1"
    fi
}

# 检查服务状态
check_service() {
    if systemctl is-active "$1" &>/dev/null; then
        log_warn "服务 $1 已在运行"
        return 1
    fi
    return 0
}

# 检查压缩包是否存在并且可读
check_archive() {
    local archive_file=$1
    if [ ! -f "$archive_file" ]; then
        log_error "压缩包 '$archive_file' 不存在"
        return 1
    fi
    if [ ! -r "$archive_file" ]; then
        log_error "没有压缩包 '$archive_file' 的读取权限"
        return 1
    fi
    return 0
}

