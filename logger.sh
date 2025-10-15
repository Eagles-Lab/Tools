#!/bin/bash

# 设置日志颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 日志级别
LOG_LEVEL_DEBUG=0
LOG_LEVEL_INFO=1
LOG_LEVEL_WARN=2
LOG_LEVEL_ERROR=3

# 默认日志级别
CURRENT_LOG_LEVEL=$LOG_LEVEL_INFO

# 设置日志级别
set_log_level() {
    CURRENT_LOG_LEVEL=$1
}

# 获取当前时间
get_datetime() {
    date '+%Y-%m-%d %H:%M:%S'
}

# 日志函数
log_debug() {
    if [ $CURRENT_LOG_LEVEL -le $LOG_LEVEL_DEBUG ]; then
        echo -e "[$(get_datetime)] ${NC}[DEBUG]${NC} $1"
    fi
}

log_info() {
    if [ $CURRENT_LOG_LEVEL -le $LOG_LEVEL_INFO ]; then
        echo -e "[$(get_datetime)] ${GREEN}[INFO]${NC} $1"
    fi
}

log_warn() {
    if [ $CURRENT_LOG_LEVEL -le $LOG_LEVEL_WARN ]; then
        echo -e "[$(get_datetime)] ${YELLOW}[WARN]${NC} $1"
    fi
}

log_error() {
    if [ $CURRENT_LOG_LEVEL -le $LOG_LEVEL_ERROR ]; then
        echo -e "[$(get_datetime)] ${RED}[ERROR]${NC} $1"
    fi
}