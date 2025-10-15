#!/bin/bash

CURRENT_DIR=$(dirname "$0")
ROOT_DIR=$(cd "$CURRENT_DIR/.." && pwd)

# 导入日志和工具模块
source $ROOT_DIR/logger.sh
source $ROOT_DIR/utils/check_utils.sh

# 默认配置
REGISTRY_PORT=5000
REGISTRY_USER="admin"
REGISTRY_PASSWORD="admin123"
AUTH_DIR="/docker/auth"

# 检查Docker是否安装
check_command "docker" || {
    log_error "Docker未安装，请先安装Docker"
    exit 1
}

# 检查httpd-tools或apache2-utils是否安装
if ! command -v htpasswd &> /dev/null; then
    log_info "正在安装htpasswd工具..."
    if command -v yum &> /dev/null; then
        yum install -y httpd-tools || {
            log_error "安装httpd-tools失败"
            exit 1
        }
    elif command -v apt-get &> /dev/null; then
        apt-get update && apt-get install -y apache2-utils || {
            log_error "安装apache2-utils失败"
            exit 1
        }
    else
        log_error "未找到包管理器，请手动安装httpd-tools或apache2-utils"
        exit 1
    fi
fi

# 拉取registry镜像
log_info "拉取Docker Registry镜像..."
docker pull registry || {
    log_error "拉取registry镜像失败"
    exit 1
}

# 创建认证目录
check_directory "${AUTH_DIR}"

# 生成认证文件
log_info "生成认证文件..."
htpasswd -Bbn "${REGISTRY_USER}" "${REGISTRY_PASSWORD}" > "${AUTH_DIR}/htpasswd" || {
    log_error "生成认证文件失败"
    exit 1
}

# 检查并停止已存在的registry容器
EXISTING_CONTAINER=$(docker ps -a | grep registry | awk '{print $1}')
if [ ! -z "${EXISTING_CONTAINER}" ]; then
    log_info "停止并删除已存在的registry容器..."
    docker stop "${EXISTING_CONTAINER}" && docker rm "${EXISTING_CONTAINER}"
fi

# 启动registry容器
log_info "启动Docker Registry容器..."
docker run -d \
    -p "${REGISTRY_PORT}:5000" \
    -v "${AUTH_DIR}:/auth" \
    -e "REGISTRY_AUTH=htpasswd" \
    -e "REGISTRY_AUTH_HTPASSWD_REALM=Registry Realm" \
    -e "REGISTRY_AUTH_HTPASSWD_PATH=/auth/htpasswd" \
    --restart=always \
    --name registry \
    registry || {
        log_error "启动registry容器失败"
        exit 1
    }

# 验证服务是否正常运行
log_info "等待服务启动..."
sleep 9

if curl -s -f -k -u "${REGISTRY_USER}:${REGISTRY_PASSWORD}" "http://localhost:${REGISTRY_PORT}/v2/" > /dev/null; then
    log_info "Docker Registry 服务已成功启动"
    log_info "服务地址: localhost:${REGISTRY_PORT}"
    log_info "用户名: ${REGISTRY_USER}"
    log_info "密码: ${REGISTRY_PASSWORD}"
    log_info "使用以下命令登录:"
    log_info "docker login localhost:${REGISTRY_PORT}"
else
    log_error "服务启动失败，请检查日志"
    exit 1
fi