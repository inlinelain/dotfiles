if [ "$(cat /etc/hostname)" != "archiso" ]; then
    echo "Boot into archiso."
    echo "You can find it at this link: https://archlinux.org/download/"
    exit -1;
fi

packages=("git" "dialog")
for package in "${packages[@]}"; do
    if ! pacman --query ${package} &> /dev/null; then
        echo "Package '${package}' was not found."
        echo "Try this: sudo pacman -Syy ${package}"
        exit -2;
    fi
done

disks_name=($(lsblk -d -n -o NAME))
disks_size=($(lsblk -d -n -o SIZE))
dialog_options=()

for index in "${!disks_name[@]}"; do
    dialog_options+=("$index")
    dialog_options+=("/dev/${disks_name[index]} ${disks_size[index]}")
done

dialog --title "Installing Arch Linux" --menu "Select disk:" 15 40 3 "${dialog_options[@]}" 2>temporary_file
config_disk_name="${disks_name[$(<temporary_file)]}"
config_disk_size="${disks_size[$(<temporary_file)]}"

config_disk_separator=""
if [[ $? -ne 0 ]]; then
    exit 0
elif [[ $config_disk_name == *"nvme"* ]]; then
    config_disk_separator="p"
fi

config_user_name=""
while true; do
    dialog --title "Installing Arch Linux" --inputbox "Enter username: " 7 40 2>temporary_file && config_user_name=$(<temporary_file)

    if [[ $? -ne 0 ]]; then
        exit 0
    elif [ "$config_user_name" != "" ] && [ "$config_user_name" != "root" ]; then
        break
    else 
        dialog --title "Installing Arch Linux" --msgbox "Invalid username. Please try again." 6 40
    fi
done

config_user_password=""
while true; do
    dialog --title "Installing Arch Linux" --inputbox "Enter $config_user_name password: " 7 40 2>temporary_file && config_user_password=$(<temporary_file)

    if [[ $? -ne 0 ]]; then
        exit 0
    elif [ "$config_user_password" != "" ]; then
        break
    else 
        dialog --title "Installing Arch Linux" --msgbox "Invalid $config_user_name password. Please try again." 6 40
    fi
done

config_root_password=""
while true; do
    dialog --title "Installing Arch Linux" --inputbox "Enter root password: " 7 40 2>temporary_file && config_root_password=$(<temporary_file)

    if [[ $? -ne 0 ]]; then
        exit 0
    elif [ "$config_root_password" != "" ]; then
        break
    else 
        dialog --title "Installing Arch Linux" --msgbox "Invalid root password. Please try again." 6 40
    fi
done

dialog --title "Installing Arch Linux" --yesno "\
Is that correct?
config_disk_name=$config_disk_name
config_disk_size=$config_disk_size
config_disk_separator=$config_disk_separator
config_user_name=$config_user_name
config_user_password=$config_user_password
config_root_password=$config_root_password
" 10 40

if [[ $? -ne 0 ]]; then
    exit 0
fi

clear

wipefs --all /dev/${config_disk_name}
parted /dev/${config_disk_name} mklabel gpt
parted /dev/${config_disk_name} mkpart primary fat32 1MiB 1024MiB
parted /dev/${config_disk_name} set 1 esp on
parted /dev/${config_disk_name} mkpart primary ext4 1024MiB 100%
yes | mkfs.vfat /dev/${config_disk_name}${config_disk_separator}1
yes | mkfs.ext4 /dev/${config_disk_name}${config_disk_separator}2

mount /dev/${config_disk_name}${config_disk_separator}2 /mnt
mkdir --parents /mnt/boot/efi
mount /dev/${config_disk_name}${config_disk_separator}1 /mnt/boot/efi

pacstrap /mnt base base-devel linux linux-firmware linux-headers curl cowsay openssh grub efibootmgr networkmanager wayland zsh git neovim python-pillow swaybg nodejs firefox htop pulseaudio alsa-lib alsa-utils pulsemixer sway wlroots seatd waybar grim wl-clipboard ranger kitty imagemagick unzip ripgrep lazygit neofetch ttc-iosevka ttf-iosevka-nerd

git clone https://github.com/ohmyzsh/ohmyzsh.git ./etc/skel/.oh-my-zsh
git clone https://github.com/alexanderjeurissen/ranger_devicons.git ./etc/skel/.config/ranger/plugins/ranger_devicons
git clone https://github.com/zsh-users/zsh-autosuggestions ./etc/skel/.oh-my-zsh/plugins/zsh-autosuggestions
cp --recursive --preserve ./etc/skel/* /mnt/etc/skel/

arch-chroot /mnt /bin/zsh -c "useradd -m -s /bin/zsh ${config_user_name}"
arch-chroot /mnt /bin/zsh -c "echo '${config_user_name}:${config_user_password}' | chpasswd"
arch-chroot /mnt /bin/zsh -c "echo '${config_user_name} ALL=(ALL:ALL) ALL' | tee -a /etc/sudoers"
echo "$config_user_name" > /mnt/etc/hostname

arch-chroot /mnt /bin/zsh -c "systemctl enable NetworkManager"

arch-chroot /mnt /bin/zsh -c "timedatectl set-timezone Europe/Moscow"
arch-chroot /mnt /bin/zsh -c "timedatectl set-ntp true"

cp --force ./etc/pacman.conf /mnt/etc/pacman.conf
arch-chroot /mnt /bin/zsh -c "pacman --sync --refresh"

cp --force ./etc/locale.gen /mnt/etc/locale.gen
arch-chroot /mnt /bin/zsh -c "locale-gen"

genfstab /mnt >> /mnt/etc/fstab

arch-chroot /mnt /bin/zsh -c "grub-install /dev/${config_disk_name}"
cp --recursive ./boot/grub/themes/grub /mnt/boot/grub/themes/grub
cp --recursive ./etc/default/grub /mnt/etc/default/grub
arch-chroot /mnt /bin/zsh -c "grub-mkconfig --output /boot/grub/grub.cfg"

arch-chroot /mnt /bin/zsh -c "chsh -s /bin/zsh root"
cp --force ./root/.zshrc /mnt/root/.zshrc

arch-chroot /mnt /bin/zsh -c "echo 'root:${config_root_password}' | chpasswd"

chmod -R 777 /mnt/home/${config_user_name}
chmod g-w,o-w -R /mnt/home/${config_user_name}/.oh-my-zsh

umount --all

rm temporary_file

dialog --title "Installing Arch Linux" --msgbox "The installation is complete, now you can restart your computer." 7 40
