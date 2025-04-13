#!/bin/bash

# 文件路径
LOG_FILE="$HOME/bitz_mining.log"
SCREEN_SESSION="eclipse"

# 检查命令是否成功执行
check_error() {
    if [ $? -ne 0 ]; then
        current_time=$(date '+%Y-%m-%d %H:%M:%S')
        echo "[$current_time] 错误：$1" >> $LOG_FILE
        exit 1
    fi
}

# 选项 1：部署项目
deploy_project() {
    current_time=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$current_time] 开始部署项目..." >> $LOG_FILE

    # 安装 screen
    if ! command -v screen >/dev/null 2>&1; then
        echo "[$current_time] screen 未安装，正在安装..." >> $LOG_FILE
        sudo apt update
        sudo apt install -y screen
        check_error "screen 安装失败"
    fi

    # 安装 Rust
    echo "[$current_time] 安装 Rust..." >> $LOG_FILE
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    check_error "Rust 安装失败"
    source $HOME/.cargo/env

    # 安装依赖
    echo "[$current_time] 安装依赖..." >> $LOG_FILE
    sudo apt update
    sudo apt install -y build-essential pkg-config libssl-dev clang
    if [ $? -ne 0 ]; then
        sudo apt-get update --fix-missing
        sudo apt-get install --reinstall python3-apt
        sudo apt install -y build-essential pkg-config libssl-dev clang
        check_error "依赖安装失败"
    fi

    # 安装 Solana CLI
    echo "[$current_time] 安装 Solana CLI..." >> $LOG_FILE
    sh -c "$(curl -sSfL https://release.solana.com/v1.18.2/install)"
    check_error "Solana CLI 安装失败"
    export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"
    echo 'export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"' >> ~/.bashrc
    solana --version
    check_error "Solana CLI 验证失败"

    # 创建 Solana 钱包
    echo "[$current_time] 创建 Solana 钱包..." >> $LOG_FILE
    solana-keygen new --no-passphrase
    check_error "钱包创建失败"

    # 安装 BITZ CLI
    echo "[$current_time] 安装 BITZ CLI..." >> $LOG_FILE
    cargo install bitz
    check_error "BITZ CLI 安装失败"

    # 配置 Solana 为 Eclipse 网络
    echo "[$current_time] 配置 Solana 为 Eclipse 网络..." >> $LOG_FILE
    solana config set --url https://bitz-000.eclipserpc.xyz/
    check_error "Solana 配置失败"

    echo "[$current_time] 部署完成，请充值 0.005 ETH 到地址：$(solana address)" >> $LOG_FILE
}

# 选项 2：启动挖矿
start_mining() {
    current_time=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$current_time] 启动挖矿..." >> $LOG_FILE

    # 提示输入 CPU 核心数
    read -p "请输入要使用的 CPU 核心数（建议保留 1-2 核心，例如 8）： " cores
    if ! [[ "$cores" =~ ^[0-9]+$ ]] || [ "$cores" -lt 1 ]; then
        cores=8
        echo "[$current_time] 无效的核心数，使用默认值 8..." >> $LOG_FILE
    fi

    # 检查并删除已存在的 Screen 会话
    if screen -ls | grep -q "$SCREEN_SESSION"; then
        echo "[$current_time] 检测到同名 Screen 会话 $SCREEN_SESSION，正在删除..." >> $LOG_FILE
        screen -S $SCREEN_SESSION -X quit
        sleep 1
    fi

    # 创建新的 Screen 会话
    echo "[$current_time] 创建 Screen 会话 $SCREEN_SESSION..." >> $LOG_FILE
    screen -dmS $SCREEN_SESSION bash -c "export PATH=$PATH:$HOME/.local/share/solana/install/active_release/bin:$HOME/.cargo/bin; \
        if ! command -v bitz >/dev/null 2>&1; then \
            echo '[$current_time] 错误：bitz 命令不可用，请先运行项 1 部署项目！' | tee -a $LOG_FILE; \
            exit 1; \
        fi; \
        bitz collect --cores $cores 2>&1 | tee -a $LOG_FILE"

    sleep 2
    if screen -ls | grep -q "$SCREEN_SESSION"; then
        echo "[$current_time] Screen 会话 $SCREEN_SESSION 已创建" >> $LOG_FILE
    else
        echo "[$current_time] 错误：Screen 会话 $SCREEN_SESSION 创建失败" >> $LOG_FILE
        return 1
    fi
}

# 主菜单
main_menu() {
    while true; do
        echo -e "\n=== BITZ 挖矿交互脚本 ==="
        echo "1. 部署项目"
        echo "2. 启动挖矿"
        echo "0. 退出脚本"
        read -p "请输入选项 (0-2)： " choice

        case $choice in
            1)
                deploy_project
                ;;
            2)
                start_mining
                ;;
            0)
                current_time=$(date '+%Y-%m-%d %H:%M:%S')
                echo "[$current_time] 退出脚本..." >> $LOG_FILE
                exit 0
                ;;
            *)
                current_time=$(date '+%Y-%m-%d %H:%M:%S')
                echo "[$current_time] 无效选项，请输入 0-2！" >> $LOG_FILE
                ;;
        esac
    done
}

# 检查先决条件
current_time=$(date '+%Y-%m-%d %H:%M:%S')
if [ ! -f /etc/lsb-release ]; then
    echo "[$current_time] 此脚本仅支持 Ubuntu Linux 系统！" >> $LOG_FILE
    exit 1
fi
if [ $(id -u) -ne 0 ]; then
    echo "[$current_time] 请以 root 或 sudo 权限运行！" >> $LOG_FILE
    exit 1
fi

# 启动脚本
main_menu