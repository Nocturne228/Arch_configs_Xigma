# 安装archlinux

记录在家里老电脑上安装archlinux(btrfs) + hyprland的过程：

## 配置

- Laptop：DELL Inspiron 5480

- CPU：Intel(R) Core(TM) 8th Generation i7-8565U CPU @ 1.80GHz(8 CPUs), ~2.0GHz
- BIOS: 2.1.0
- SSD (HD0)：KBG30ZMS128G NVMe TOSHIBA 128GB
- HDD (HD1)：ST1000LM035-1RK172 (1TB)
- Integrated graphics：Intel UHD Graphics 620
- Discrete graphics：Nvidia GeForce MX130

## 空白分区

我选择在HD1上分出128G的空白分区装系统，如果已经全部被分配，可以备份数据后选择分区进行压缩得到未分配区域。

另外Windows的UEFI分区也位于此，Arch可以共用这段UEFI分区，这影响到后面的分区及格式化过程。

## 刻录启动U盘

在镜像站下载arch iso镜像文件，我选择清华TUNA[镜像站](https://mirrors.tuna.tsinghua.edu.cn/archlinux/iso/latest/)，目前最新版本是[archlinux-2025.02.01-x86_64](https://mirrors.tuna.tsinghua.edu.cn/archlinux/iso/latest/archlinux-2025.02.01-x86_64.iso)，注意架构是x86_64，ARM架构移步[此处](https://mirrors.tuna.tsinghua.edu.cn/archlinuxarm/)。（一般建议校验PGP签名文件，这里懒得动了）

Windows下可以使用[ventoy](https://www.ventoy.net/cn/doc_start.html)或者[Rufus](https://rufus.ie/)或者[etcher](https://github.com/balena-io/etcher)进行优盘刻录（但是我使用Rufus刻录后电脑无法正常识别安装程序，改用[UltralISO](https://www.ultraiso.com/download.html)才成功）

注意启动方式需要设置为UEFI，进行写入。

# 安装

打开电脑，开机时按F12进入PE启动页面，需要先进入BIOS界面关闭Security Boot选项，另外找到Boot Mode改为UEFI。保存设置后退出自动重启，再次按F12进入PE界面，选择UEFI开头的U盘选项，进入安装程序。

注意启动界面可能有如下提示：

```
[0K]Started 0penSSH Daemon
```

说明ssh服务已启动，可以通过ssh连接进行安装，不必再手打命令了。

---

检验是否为UEFI 64位模式（如下命令应该输出64 ）

```bash
cat /sys/firmware/efi/fw_platform_size
```

禁用reflector服务，避免系统自动选择镜像源：

```bash
systemctl stop reflector
```

设置时区并更新同步系统时钟

```bash
timedatectl set-timezone Asia/Shanghai
timedatectl set-ntp true
timedatectl status
```

# 联网

无线连接使用 iwctl 命令进行，按照如下步骤进行网络连接：

```bash
iwctl                           #执行iwctl命令，进入交互式命令行
device list                     #列出设备名，比如无线网卡看到叫 wlan0
station wlan0 scan              #扫描网络
station wlan0 get-networks      #列出网络 比如想连接YOUR-WIRELESS-NAME这个无线
station wlan0 connect YOUR-WIRELESS-NAME #进行连接 输入密码即可
exit                            #成功后exit退出
```

ping操作尝试是否能够ping通

```
ping www.baidu.org
```

查看本机IP地址：

```bash
ip a
```

ens33中的inet后面就是IP地址，`passwd`设置root账户的密码后用其他机器通过`ssh root@ip_addr`连接。

```
passwd
```

# 分区

使用lsblk查看磁盘状态

可以看到20G的磁盘名称为sda，这是虚拟机中的界面，实际上我的电脑中sda磁盘大小为128G，包括Windows的512MB的EFI分区，这就是后续分区操作的磁盘。

现在执行命令进入交互式分区程序（注意磁盘名称，如果是NVMe磁盘名称可能是nvme0n1

```bash
cfdisk /dev/sda
```

分区架构选择gpt类型

选择New操作创建分区，这里是虚拟中的分配，我的实际分配情况为：sda4--512MB EFI System；sda5--1.2G Linux Swap；sda6--剩余全部作为Linux filesystem

这里简单作为示例参考如下：sda1--512MB EFI System；sda2--2G Linux Swap；sda3--剩余全部作为Linux filesystem

将改动写入磁盘后退出，执行命令查看效果：

```bash
fdisk -l
```

接下来**格式化**各个分区：

```
# mkfs.fat -F32 /dev/sda1 如果是与Windows公用的EFI区域就不要格式化
mkswap /dev/sda2
mkfs.btrfs /dev/sda3 -f
```

挂载Linux filesystem

```
mount -t btrfs -o compress=zstd /dev/sda3 /mnt
df -h
```

创建BTRFS子卷：

```bash
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume list -p /mnt
```

卸载/mnt:

```
umount /mnt
```

依次挂载根目录、home目录、启动目录、交换区：

```bash
mount -t btrfs -o subvol=/@,compress=zstd /dev/sda3 /mnt
mkdir /mnt/home
mount -t btrfs -o subvol=/@home,compress=zstd /dev/sda3 /mnt/home
mkdir -p /mnt/boot
mount /dev/sda1 /mnt/boot
swapon /dev/sda2
```

挂载完成后查看分区状态：

```bash
df -h
free
```

# 安装

设置镜像源：

```bash
vim /etc/pacman.d/mirrorlist
```

在开头加上镜像源：

```
Server = https://mirrors.tuna.tsinghua.edu.cn/archlinux/$repo/os/$arch
Server = https://mirrors.ustc.edu.cn/archlinux/$repo/os/$arch
```

更新

```bash
pacman -Sy
```

安装必需的包：

```bash
pacstrap -K /mnt base base-devel linux linux-firmware linux-headers btrfs-progs fish grub efibootmgr os-prober openssl networkmanager dhcpcd neovim intel-ucode man-db man-pages texinfo git
```





# 配置

### 生成fstab文件

fstab 用来定义磁盘分区。生成fstab文件并挂载配置：

```bash
genfstab -U /mnt > /mnt/etc/fstab
```

把环境切换到新系统的/mnt 下

```bash
arch-chroot /mnt
```

### 网络配置

设置主机名和配置：

```bash
nvim /etc/hostname	# 设置主机名
```

启动网络服务

```bash
systemctl enable dhcpcd
systemctl enable NetworkManager
```

### 时区设置

设置时区，在/etc/localtime 下用/usr 中合适的时区创建符号连接。如下设置上海时区，将当前的正确 UTC 时间写入硬件时间。

```bash
ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
hwclock --systohc
```

Locale 决定了地域、货币、时区日期的格式、字符排列方式和其他本地化标准。设置地区偏好：在`/etc/locale.gen`中去掉en_US.UTF-8 UTF-8和zh_CN.UTF-8 UTF-8前面的注释

```bash
nvim /etc/locale.gen
```

生成 locale并向 /etc/locale.conf 导入内容

```
locale-gen
echo 'LANG=en_US.UTF-8' > /etc/locale.conf
```

### 设置root用户密码

```bash
passwd root
```

### 引导

将GRUB安装到EFI分区

```bash
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=ARCH
```

如果出现No error reported，GRUB此时已经成功安装到EFI磁盘分区了。

![grub](D:\notes\posts\arch-install.assets\grub.png)

### 配置Initramnfs

编辑`/etc/mkinitcpio.conf`  文件：

```bash
nvim /etc/mkinitcpio.conf
```

在HOOKS中加入`btrfs`，然后运行

```bash
mkinitcpio -P
```

### 配置pacman

取消Color和ParallelDownloads前的注释，可以加上一行 ILoveCandy  吃豆人彩蛋

```bash
nvim /etc/pacman.conf
```

### 启动优化

编辑/etc/default/grub 文件，去掉`GRUB_CMDLINE_LINUX_DEFAULT`一行中最后的 `quiet` 参数，同时把 `log level` 的数值从 3 改成 5。这样是为了后续如果出现系统错误，方便排错。同时在同一行加入 `nowatchdog` 参数，这可以显著提高开关机速度。

```bash
nvim /etc/default/grub
```

生成配置文件

```bash
sudo grub-mkconfig -o /boot/grub/grub.cfg
```



### 添加新用户

添加新用户

```bash
useradd -m -G wheel nocturne
```

设置密码

```bash
passwd nocturne
```

为wheel组中的用户添加sudo权限

```bash
nvim /etc/sudoers
```

找到如下内容，取消注释，`:w!`强制保存

```
## Uncomment to allow members of group wheelto execute any command
# %wheeL ALL=(ALL:ALL) ALL
```

### 设置用户shell

登入用户，将shell设置为fish

```bash
su nocturne
chsh -s /usr/bin/fish
```

Ctrl+D 退出用户登陆

```bash
su nocturne
```

再次进入到用户，可以看到shell已经变了

### 最后一步

`Ctrl + D`退出系统，卸载`/mnt`

```bash
umount -R /mnt
```

重启，此时记得拔掉U盘，否则会再次进入安装程序。重启后已经成功安装Arch系统。

# 安装后

现在安装一些所需的软件包。

### 联网

连接无线网络的交互式程序：

```bash
nmtui
```

此命令可以在终端界面中连接无线网络，也可以使用命令行：

```bash
nmcli device wifi connect <网络名> password <密码>
```

安装ssh服务

```bash
sudo pacman -S openssh
```

启动

```bash
systemctl start sshd
```

### Nvidia驱动

查看显卡

```bash
lspci -k | grep -A 2 -E "(VGA|3D)"
```

台式机装的nvidia-dkms没问题，笔记本有问题，改成装nvidia而不是nvidia-dkms

```
# sudo pacman -S nvidia-dkms nvidia-utils nvidia-settings	# 台式机
sudo pacman -S nvidia nvidia-utils nvidia-settings	# 笔记本
```

在`GRUB_CMDLINE_LINUX`中添加`nvidia_drm.modeset=1`

```bash
sudo nvim /etc/default/grub
```

生成配置文件

```bash
sudo grub-mkconfig -o /boot/grub/grub.cfg
```

在MODULES中加入`nvidia nvidia_modeset nvidia_uvm nvidia_drm`，并将`kms`从HOOKS中去掉

```bash
sudo nvim /etc/mkinitcpio.conf
```

生成配置文件

```bash
sudo mkinitcpio -P
```

重启

```bash
reboot
```

输入`nvidia-smi`验证是否安装成功

创建`nvidia.book`文件

```bash
sudo mkdir -p /etc/pacman.d/hooks/
sudo nvim /etc/pacman.d/hooks/nvidia.hook
```

在`/etc/pacman.d/hooks/nvidia.hook`中写入

```bash
[Trigger]
Operation=Install
Operation=Upgrade
Operation=Remove
Type=Package
Target=nvidia
Target=linux
# Change the linux part above if a different kernel is used

[Action]
Description=Update NVIDIA module in initcpio
Depends=mkinitcpio
When=PostTransaction
NeedsTargets
Exec=/bin/sh -c 'while read -r trg; do case $trg in linux*) exit 0; esac; done; /usr/bin/mkinitcpio -P'
```

# 安装桌面环境

## 安装yay

AUR 为 archlinux user repository。任何用户都可以上传自己制作的 AUR 包，这也是 Arch Linux 可用软件众多的原因。使用 [yay](https://github.com/Jguer/yay) 或 [paru](https://github.com/Morganamilo/paru) 可以安装 AUR 中的包。

```bash
sudo pacman -S --needed git base-devel && git clone https://aur.archlinux.org/yay-bin.git && cd yay-bin && makepkg -si
```

## 安装hyprland桌面

我使用的是JaKooLit大佬的安装脚本：[Arch-Hyprland](https://github.com/JaKooLit/Arch-Hyprland)，只需要运行如下命令：

```bash
git clone --depth=1 https://github.com/JaKooLit/Arch-Hyprland.git ~/Arch-Hyprland
cd ~/Arch-Hyprland
chmod +x install.sh
./install.sh
```

hyprland使用dotfiles配置，位于另一个仓库，不过在执行前面的安装脚本时似乎会自动安装，地址如下：[Hyprland-Dots](https://github.com/JaKooLit/Hyprland-Dots)

## 配置oh-my-zsh

Arch-hyprland默认将shell设置为zsh，但是经常会因为网络问题无法安装oh-my-zsh，官方提供了墙内的镜像文件，手动执行命令如下：

| Method    | Command                                           |
| --------- | ------------------------------------------------- |
| **curl**  | `sh -c "$(curl -fsSL https://install.ohmyz.sh/)"` |
| **wget**  | `sh -c "$(wget -O- https://install.ohmyz.sh/)"`   |
| **fetch** | `sh -c "$(fetch -o - https://install.ohmyz.sh/)"` |

-------

### 手动安装hyprland

```bash
sudo pacman -S hyprland kitty waybar
```

> 另外，如果想要获取编译最新的hyprland源代码，从AUR安装：
>
> ```bash
> yay -S hyprland-git
> ```
>
> 安装 `hyprland-meta` 包以自动获取和编译 hypr* 生态系统内所有组件的最新 git 版本。
>
> ```bash
> yay -S hyprland-meta-git
> ```
>
> 

创建hyprland配置目录，将默认配置文件复制过去。

```bash
mkdir .config/hypr -p
cp /usr/share/hypr/hyprland.conf ~/.config/hypr/
nvim ~/.config/hypr/hyprland.conf
```

配置文件添加NVIDIA环境变量

```bash
env = LIBVA_DRIVER_NAME,nvidia
env = XDG_SESSION_TYPE,wayland
env = GBM_BACKEND,nvidia-drm
env = __GLX_VENDOR_LIBRARY_NAME,nvidia
env = WLR_NO_HARDWARE_CURSORS,1
```

