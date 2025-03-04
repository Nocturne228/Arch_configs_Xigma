#!/bin/sh

set -x

# WIFI_NAME="CU_jagp"
HOST_NAME="xiaoma"
USER_ID="nocturne"

mkdir ~/baks
cp /etc/pacman.conf ~/baks/pacman.conf
cp /etc/locale.gen ~/baks/locale.gen
cp /etc/mkinitcpio.conf ~/baks/mkinitcpio.conf
cp /etc/sudoers ~/baks/sudoers
cp /etc/fstab ~/baks/fstab
cp /etc/default/grub ~/baks/grub

echo "写入主机名"
echo $HOST_NAME > /etc/hostname

systemctl enable dhcpcd
systemctl enable NetworkManager

echo "设置时区"
ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
hwclock --systohc

echo "生成 locale"
sed -i 's/^#\(en_US.UTF-8 UTF-8\)/\1/' /etc/locale.gen
sed -i 's/^#\(zh_CN.UTF-8 UTF-8\)/\1/' /etc/locale.gen
locale-gen
echo 'LANG=en_US.UTF-8' > /etc/locale.conf

echo "设置root用户密码"
passwd root

echo "将GRUB安装到EFI分区"
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=ARCH

sed -i '/^HOOKS=\([^)]*\)/s/\(filesystems\)/\1 btrfs/' /etc/mkinitcpio.conf
mkinitcpio -P

sed -i 's/^#\(Color\)/\1/' /etc/pacman.conf
sed -i 's/^#\(ParallelDownloads\)/\1/' /etc/pacman.conf

sed -i 's/\(GRUB_CMDLINE_LINUX_DEFAULT=".*\)loglevel=3\(.*\)quiet/\1loglevel=5\2nowatchdog/' /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg

echo "修改sudoers文件"
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

echo "添加新用户"
useradd -m -G wheel $USER_ID
passwd $USER_ID

echo "退出系统"

echo "卸载所有挂载的分区"
echo "umount -R /mnt"

echo "重启"
echo "reboot"

exit