TEXT_COLOR_RED="\033[91m";
RESET_COLOR="\033[0m";

if [ "$(cat /etc/hostname)" != "archiso" ]; then
    echo -e "$TEXT_COLOR_RED Boot into ArchLive flash drives $RESET_COLOR"
    exit 0
fi

if ! pacman -Q dialog &> /dev/null; then
    echo -e "$TEXT_COLOR_RED The dialog package is not installed $RESET_COLOR"
    echo -e " - Try enter this: $TEXT_COLOR_RED pacman -S dialog $RESET_COLOR"
    exit 0
fi

if ! pacman -Q git &> /dev/null; then
    echo -e "$TEXT_COLOR_RED The git package is not installed $RESET_COLOR"
    echo -e " - Try enter this: $TEXT_COLOR_RED pacman -S git $RESET_COLOR"
    exit 0
fi

disks_name=($(lsblk -d -n -o NAME))
disks_size=($(lsblk -d -n -o SIZE))

options=()
for index in "${!disks_name[@]}"; do
    options+=("$index")
    options+=("/dev/${disks_name[index]} ${disks_size[index]}")
done

dialog --clear --title "Installing Arch Linux" --menu "Select disk:" 15 40 3 "${options[@]}" 2>temp.txt

if [[ $? -ne 0 ]]; then
    exit 0
fi

selected_disk_name="${disks_name[$(<temp.txt)]}"
selected_disk_size="${disks_size[$(<temp.txt)]}"
selected_disk_parted_separator=""

if [[ $selected_disk_name == *"nvme"* ]]; then
    elected_disk_parted_separator="p"
fi

user_username=""
while true; do
    dialog --title "Installing Arch Linux" --inputbox "Enter your username:" 7 40 2>temp.txt

    if [[ $? -ne 0 ]]; then
        exit 0
    fi

    user_username=$(<temp.txt)
    if [[ -n "$user_username" ]]; then
        break
    else
        dialog --title "Error" --msgbox "Username cannot be empty. Please try again." 6 40
    fi
done

user_password=""
while true; do
    dialog --title "Installing Arch Linux" --inputbox "Enter your user $user_username password:" 7 40 2>temp.txt

    if [[ $? -ne 0 ]]; then
        exit 0
    fi

    user_password=$(<temp.txt)
    if [[ -n "$user_password" ]]; then
        break
    else
        dialog --title "Error" --msgbox "Password cannot be empty. Please try again." 6 40
    fi
done

root_password=""
while true; do
    dialog --title "Installing Arch Linux" --inputbox "Enter your root password:" 7 40 2>temp.txt

    if [[ $? -ne 0 ]]; then
        exit 0
    fi

    root_password=$(<temp.txt)
    if [[ -n "$root_password" ]]; then
        break
    else
        dialog --title "Error" --msgbox "Password cannot be empty. Please try again." 6 40
    fi
done

dialog --title "Installing Arch Linux" --yesno "\
Is that correct?
Disk:
    Name: ${selected_disk_name} ${selected_disk_size}
User:
    Name: ${user_username}
    Password: ${user_password}
Root:
    Password: ${root_password}
" 10 40

if [[ $? -ne 0 ]]; then
    exit 0
fi

dialog --title "Installing Arch Linux" --gauge "Starting Arch Linux installation..." 10 70 0
sleep 1

dialog --title "Installing Arch Linux" --gauge "Wiping disk metadata..." 10 70 10
wipefs --all /dev/${selected_disk_name} > /dev/null

dialog --title "Installing Arch Linux" --gauge "Creating partition table..." 10 70 20
parted /dev/${selected_disk_name} mklabel gpt > /dev/null

dialog --title "Installing Arch Linux" --gauge "Creating EFI partition..." 10 70 30
parted /dev/${selected_disk_name} mkpart primary fat32 1MiB 1024MiB > /dev/null
parted /dev/${selected_disk_name} set 1 esp on > /dev/null

dialog --title "Installing Arch Linux" --gauge "Creating primary ext4 partition..." 10 70 40
parted /dev/${selected_disk_name} mkpart primary ext4 1024MiB 100% > /dev/null

dialog --title "Installing Arch Linux" --gauge "Formatting EFI partition..." 10 70 50
yes | mkfs.vfat /dev/${selected_disk_name}${selected_disk_parted_separator}1 > /dev/null

dialog --title "Installing Arch Linux" --gauge "Formatting ext4 partition..." 10 70 60
yes | mkfs.ext4 /dev/${selected_disk_name}${selected_disk_parted_separator}2 > /dev/null

dialog --title "Installing Arch Linux" --gauge "Mounting ext4 partition..." 10 70 70
mount /dev/${selected_disk_name}${selected_disk_parted_separator}2 /mnt > /dev/null
mkdir -p /mnt/boot/efi

dialog --title "Installing Arch Linux" --gauge "Mounting EFI partition..." 10 70 80
mount /dev/${selected_disk_name}${selected_disk_parted_separator}1 /mnt/boot/efi > /dev/null

dialog --title "Installing Arch Linux" --gauge "Installing base system and packages..." 10 70 90
pacstrap /mnt base base-devel linux linux-firmware linux-headers curl grub efibootmgr networkmanager wayland zsh git neovim python-pillow swaybg nodejs firefox htop pulseaudio alsa-lib alsa-utils pulsemixer sway wlroots seatd waybar grim wl-clipboard ranger kitty imagemagick unzip ripgrep lazygit neofetch ttc-iosevka ttf-iosevka-nerd > /dev/null

dialog --title "Installing Arch Linux" --gauge "Generating fstab..." 10 70 100
genfstab /mnt >> /mnt/etc/fstab > /dev/null

dialog --title "Installing Arch Linux" --gauge "Copying configuration files..." 10 70 110
echo "$user_username" > /mnt/etc/hostname > /dev/null
cp -pr ./etc/pacman.conf /mnt/etc/pacman.conf > /dev/null
cp -pr ./etc/locale.gen /mnt/etc/locale.gen > /dev/null

dialog --title "Installing Arch Linux" --gauge "Cloning Oh My Zsh..." 10 70 120
git clone https://github.com/ohmyzsh/ohmyzsh.git /mnt/etc/skel/.oh-my-zsh > /dev/null

dialog --title "Installing Arch Linux" --gauge "Cloning Ranger Devicons..." 10 70 130
git clone https://github.com/alexanderjeurissen/ranger_devicons.git /mnt/etc/skel/.config/ranger/plugins/ranger_devicons > /dev/null

dialog --title "Installing Arch Linux" --gauge "Cloning Zsh Autosuggestions..." 10 70 140
git clone https://github.com/zsh-users/zsh-autosuggestions.git /mnt/etc/skel/.oh-my-zsh/plugins/zsh-autosuggestions > /dev/null

dialog --title "Installing Arch Linux" --gauge "Copying skel to new user's home..." 10 70 150
cp -pr ./etc/skel /mnt/etc/skel

dialog --title "Installing Arch Linux" --gauge "Creating user..." 10 70 160
arch-chroot /mnt /bin/zsh -c "useradd -m -s /bin/zsh ${user_username}" > /dev/null
rm -fr /mnt/home/${user_username} > /dev/null
cp -pr ./etc/skel /mnt/home/${user_username} > /dev/null

dialog --title "Installing Arch Linux" --gauge "Setting user password..." 10 70 170
arch-chroot /mnt /bin/zsh -c "echo '${user_username}:${user_password}' | chpasswd" > /dev/null

dialog --title "Installing Arch Linux" --gauge "Adding user to sudoers..." 10 70 180
arch-chroot /mnt /bin/zsh -c "echo '${user_username} ALL=(ALL:ALL) ALL' | tee -a /etc/sudoers" > /dev/null

dialog --title "Installing Arch Linux" --gauge "Enabling NetworkManager..." 10 70 190
arch-chroot /mnt /bin/zsh -c "systemctl enable NetworkManager" > /dev/null

dialog --title "Installing Arch Linux" --gauge "Setting timezone..." 10 70 200
arch-chroot /mnt /bin/zsh -c "timedatectl set-timezone Europe/Moscow" > /dev/null

dialog --title "Installing Arch Linux" --gauge "Enabling NTP..." 10 70 210
arch-chroot /mnt /bin/zsh -c "timedatectl set-ntp true" > /dev/null

dialog --title "Installing Arch Linux" --gauge "Installing GRUB bootloader..." 10 70 220
arch-chroot /mnt /bin/zsh -c "grub-install /dev/${selected_disk_name}" > /dev/null

dialog --title "Installing Arch Linux" --gauge "Copying GRUB themes..." 10 70 230
cp -pr ./boot/grub/themes/grub /mnt/boot/grub/themes/grub > /dev/null

dialog --title "Installing Arch Linux" --gauge "Copying GRUB configuration..." 10 70 240
cp -pr ./etc/default/grub /mnt/etc/default/grub > /dev/null

dialog --title "Installing Arch Linux" --gauge "Generating GRUB configuration..." 10 70 250
arch-chroot /mnt /bin/zsh -c "grub-mkconfig -o /boot/grub/grub.cfg" > /dev/null

dialog --title "Installing Arch Linux" --gauge "Setting root password..." 10 70 260
arch-chroot /mnt /bin/zsh -c "echo 'root:${root_password}' | chpasswd" > /dev/null

dialog --title "Installing Arch Linux" --gauge "Setting permissions for user's home directory..." 10 70 270
chmod -R 700 /mnt/home/${user_username} > /dev/null
chmod g-w,o-w -R /mnt/home/${user_username}/.oh-my-zsh > /dev/null

dialog --title "Installing Arch Linux" --gauge "Unmounting filesystems..." 10
umount -R /mnt > /dev/null

dialog --title "Installing Arch Linux" --msgbox "The installation is complete, now you can restart your computer" 7 40
