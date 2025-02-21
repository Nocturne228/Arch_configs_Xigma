#bin/sh

#!/bin/sh

REPO_URL=""

echo "创建 nvidia.hook 文件"
sudo mkdir -p /etc/pacman.d/hooks
sudo touch /etc/pacman.d/hooks/nvidia.hook

# 将内容写入 nvidia.hook 文件
cat <<EOL > /etc/pacman.d/hooks/nvidia.hook
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
Exec=/bin/sh -c 'while read -r trg; do case \$trg in linux*) exit 0; esac; done; /usr/bin/mkinitcpio -P'
EOL

echo "nvidia.hook 文件已创建并写入成功！"

echo "安装hyprland"
sudo pacman -S hyprland kitty waybar xorg-xrdb clangd

echo "创建hyprland配置文件"
mkdir ~/.config/hypr -p
cp /usr/share/hypr/hyprland.conf ~/.config/hypr/
nvim ~/.config/hypr/hyprland.conf

echo "修改hyprland配置文件"
echo "添加NVIDIA环境变量"
sed -i '/^env = HYPRCURSOR_SIZE,24$/a \
env = LIBVA_DRIVER_NAME,nvidia\
env = XDG_SESSION_TYPE,wayland\
env = GBM_BACKEND,nvidia-drm\
env = __GLX_VENDOR_LIBRARY_NAME,nvidia\
env = WLR_NO_HARDWARE_CURSORS,1' ~/.config/hypr/hyprland.conf

echo "配置neovim"
mkdir ~/configs
mkdir ~/.config/nvim
mkdir ~/.config/kitty
mkdir ~/.config/waybar
cp ~/configs/nvim ~/.config/ -r
cp kitty ~/.config/ -r
cp hypr ~/.config/ -r
cp waybar ~/.config/ -r

echo "手动启动waybar"
echo "waybar -c ~/.config/waybar/Waybar-3.0/config -s ~/.config/waybar/Waybar-3.0/style.css"
echo "除了第一次配置，以后会自动启动waybar"