#!/bin/sh

echo "查看显卡配置"
lspci -k | grep -A 2 -E "(VGA|3D)"

echo "安装显卡驱动"
# sudo pacman -S nvidia-dkms nvidia-utils nvidia-settings	# 台式机
sudo pacman -S nvidia nvidia-utils nvidia-settings	# 笔记本

echo "配置GRUB_CMDLINE_LINUX设置为drm模式"
sudo sed -i '/^GRUB_CMDLINE_LINUX=""/ s/""/"nvidia_drm.modeset=1"/' /etc/default/grub
sudo grub-mkconfig -o /boot/grub/grub.cfg

echo "配置mkinitcpio"
# 修改MODULES行，添加NVIDIA模块
sudo sed -i 's/MODULES=()/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' /etc/mkinitcpio.conf
# 从HOOKS中移除kms
sudo sed -i 's/\(HOOKS=([^)]*\)kms\([^)]*)\)/\1\2/' /etc/mkinitcpio.conf
# 验证修改
echo "修改后的内容："
grep "^MODULES" /etc/mkinitcpio.conf
grep "^HOOKS" /etc/mkinitcpio.conf

echo "生成新的initramfs"
sudo mkinitcpio -P

echo "重启系统"
echo "reboot"
sleep 2
sudo reboot