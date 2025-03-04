#!/bin/sh

set -x

# 设置硬盘和分区大小的变量
DISK="/dev/sda"
BOOT_NO="4"
SWAP_NO="5"
LFS_NO="6"

# WIFI_NAME="CU_jagp"
HOST_NAME="xiaoma"
USER_ID="nocturne"

systemctl stop reflector
echo "禁用reflector"

timedatectl set-timezone Asia/Shanghai
timedatectl set-ntp true
echo "时区设置为上海并同步硬件时间"

EFI_PLATFORM_SIZE=$(cat /sys/firmware/efi/fw_platform_size)

if [ "$EFI_PLATFORM_SIZE" -ne 64 ]; then
  echo "错误: 当前系统不是 UEFI64 位启动模式！"
  exit 1
fi

# 先手动分区吧

# mkfs.fat -F32 ${DISK}${BOOT_NO} # 如果是与Windows公用的EFI区域就不要格式化
mkswap ${DISK}${SWAP_NO}
mkfs.btrfs ${DISK}${LFS_NO} -f

mount -t btrfs -o compress=zstd ${DISK}${LFS_NO} /mnt
echo "挂载Linux filesystem"

btrfs subvolume create /mnt/@
echo "创建子卷@"
btrfs subvolume create /mnt/@home
echo "创建子卷@home"

umount /mnt
echo "卸载/mnt"

echo "挂载文件系统"
mount -t btrfs -o subvol=/@,compress=zstd ${DISK}${LFS_NO} /mnt
mkdir /mnt/home
echo "挂载子卷@"
mount -t btrfs -o subvol=/@home,compress=zstd ${DISK}${LFS_NO} /mnt/home
mkdir -p /mnt/boot
echo "挂载子卷@home"
mount ${DISK}${BOOT_NO} /mnt/boot
echo "挂载boot"
swapon ${DISK}${SWAP_NO}
echo "启用swap"

sed -i '0,/^Server/ {s/^Server.*/Server = https:\/\/mirrors.tuna.tsinghua.edu.cn\/archlinux\/$repo\/os\/$arch\nServer = https:\/\/mirrors.ustc.edu.cn\/archlinux\/$repo\/os\/$arch/}' /etc/pacman.d/mirrorlist
echo "设置镜像源"

echo "更新"
pacman -Sy

echo "安装必需的包"
pacstrap -K /mnt base base-devel linux linux-firmware linux-headers btrfs-progs fish grub efibootmgr os-prober openssl networkmanager dhcpcd neovim intel-ucode man-db man-pages git

echo "生成fstab文件"
genfstab -U /mnt > /mnt/etc/fstab

echo "请手动进入新系统"
echo "arch-chroot /mnt/"

