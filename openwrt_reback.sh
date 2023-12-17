#!/bin/bash

# 停止并删除OpenWrt Docker容器
echo "正在停止并删除OpenWrt Docker容器..."
docker stop openwrt
docker rm openwrt

# 删除Docker网络
echo "正在删除Docker网络 'macnet'..."
docker network rm macnet

# 关闭并删除macvlan虚拟接口
echo "正在关闭并删除macvlan虚拟接口 'mac0'..."
sudo ip link delete mac0

# 恢复网络接口的默认设置
# 需要找到之前脚本中使用的接口名称，这里假设为 INTERFACE
# 可以通过查看脚本或通过命令手动确定正确的接口
INTERFACE=$(ip link | grep -Eo '^[0-9]+: [^:]+:' | awk '{print $2}' | tr -d ':' | grep -v "lo" | head -n 1)
echo "正在将网络接口 $INTERFACE 恢复为默认设置..."
sudo ip link set $INTERFACE promisc off

echo "网络设置已还原。"

# 可选：卸载nmap
# read -p "是否卸载nmap？(y/n) " -n 1 -r
# echo
# if [[ $REPLY =~ ^[Yy]$ ]]; then
#     echo "正在卸载nmap..."
#     sudo apt remove -y nmap
# fi

echo "操作完成。"
