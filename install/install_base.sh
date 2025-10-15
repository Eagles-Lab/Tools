#!/bin/bash

CURRENT_DIR=$(dirname "$0")
ROOT_DIR=$(cd "$CURRENT_DIR/.." && pwd)

# 导入日志模块和检查工具模块
source $ROOT_DIR/logger.sh
source $ROOT_DIR/utils/check_utils.sh
source $ROOT_DIR/utils/utils.sh

# 检查root权限
if [ "$(id -u)" != "0" ]; then
  log_error "必须使用root用户执行安装脚本"
  exit 1
fi

# 执行基础安装流程
run_base_install() {
    cd $ROOT_DIR
    download_file images.tar.gz
    download_file kubernetes-1.29.2-150500.1.1.tar.gz
    log_info "正在执行 ▶ 初始化网络配置"
    bash init/init_network.sh || { log_error "初始化网络配置失败"; exit 1; }
    log_info "正在执行 ▶ 系统参数优化"
    bash init/init_system_config.sh || { log_error "系统参数优化失败"; exit 1; }
    log_info "正在执行 ▶ 安装Docker CE"
    bash install/install_docker_ce.sh || { log_error "安装Docker CE失败"; exit 1; }
    log_info "正在执行 ▶ 安装cri-docker"
    bash install/install_cri_docker.sh || { log_error "安装cri-docker失败"; exit 1; }
    log_info "正在执行 ▶ 加载容器镜像"
    bash utils/load_images.sh images.tar.gz || { log_error "加载容器镜像失败"; exit 1; }
    log_info "正在执行 ▶ 安装kubelet"
    bash install/install_kubelet.sh || { log_error "安装kubelet失败"; exit 1; }
    log_info "${name} 完成"
}