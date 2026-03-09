#!/bin/bash
# Docker自动化部署脚本优化版

set -e  # 遇到错误立即退出
set -u  # 使用未定义变量时报错

# 颜色输出函数
red_echo() {
    echo -e "\033[31m$1\033[0m"
}

green_echo() {
    echo -e "\033[32m$1\033[0m"
}

# 检查网络连通性
green_echo "正在检查网络连接..."
if ! ping -c 4 baidu.com > /dev/null 2>&1; then
    red_echo "错误: 网络连接失败，请检查网络配置"
    exit 1
fi
green_echo "网络连接正常"

# 检查是否为root用户
if [ "$EUID" -ne 0 ]; then 
    red_echo "错误: 请使用root用户执行此脚本"
    exit 1
fi

# 检查系统版本
if [ ! -f /etc/centos-release ]; then
    red_echo "错误: 此脚本仅支持CentOS系统"
    exit 1
fi

# 安装Docker依赖环境
green_echo "正在安装Docker依赖包..."
yum install -y yum-utils device-mapper-persistent-data lvm2

# 添加docker yum源
green_echo "正在配置Docker yum源..."
yum-config-manager --add-repo http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo

# 清除原有缓存并创建新缓存
yum clean all
yum makecache fast

# 安装docker
green_echo "正在安装Docker..."
yum install -y docker-ce docker-ce-cli containerd.io

# 停止已运行的Docker服务
systemctl stop docker 2>/dev/null || true

# 配置Docker镜像加速器
green_echo "正在配置Docker镜像加速器..."
mkdir -p /etc/docker
cat > /etc/docker/daemon.json <<EOF
{
    "registry-mirrors": [
        "https://docker.m.daocloud.io",
        "https://dockerproxy.com",
        "https://docker.mirrors.ustc.edu.cn",
        "https://docker.nju.edu.cn",
        "https://iju9kaj2.mirror.aliyuncs.com",
        "https://hub-mirror.c.163.com"
    ],
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "100m",
        "max-file": "3"
    },
    "storage-driver": "overlay2",
    "exec-opts": ["native.cgroupdriver=systemd"]
}
EOF

# 启动Docker服务
green_echo "正在启动Docker服务..."
systemctl daemon-reload
systemctl start docker
systemctl enable docker

# 验证安装
green_echo "验证Docker安装..."
if docker --version &>/dev/null; then
    docker_version=$(docker --version | awk '{print $3}' | cut -d',' -f1)
    green_echo "Docker ${docker_version} 安装成功!"
    
    # 测试Docker运行
    if docker run hello-world &>/dev/null; then
        green_echo "Docker运行正常"
    else
        red_echo "警告: Docker运行测试失败"
    fi
else
    red_echo "错误: Docker安装失败"
    exit 1
fi

# 显示配置信息
green_echo "\nDocker配置信息:"
echo "配置文件: /etc/docker/daemon.json"
echo "服务状态: $(systemctl is-active docker)"
echo "开机启动: $(systemctl is-enabled docker)"

green_echo "\nDocker自动化部署完成!"
