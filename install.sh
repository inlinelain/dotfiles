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

update_dialog() {
    local title="$1"
    local message="$2"
    local progress="$3"
    dialog --title "$title" --gauge "$message" 10 70 "$progress"
}

run_command_with_dialog() {
    local title="$1"
    local message="$2"
    local command="$3"
    local progress=0

    eval "$command" &
    pid=$!

    while kill -0 $pid 2>/dev/null; do
        for i in {0..100..10}; do
            update_dialog "$title" "$message" $((progress + i))
            sleep 1
        done
        progress=$((progress + 10))
    done

    wait $pid
    update_dialog "$title" "$message completed!" 100
    sleep 1
}

run_command_with_dialog "Installing Arch Linux" "Wiping disk metadata..." "wipefs --all /dev/${selected_disk_name}"
run_command_with_dialog "Installing Arch Linux" "Creating partition table..." "parted /dev/${selected_disk_name} mklabel gpt"
run_command_with_dialog "Installing Arch Linux" "Creating EFI partition..." "parted /dev/${selected_disk_name} mkpart primary fat32 1MiB 1024MiB && parted /dev/${selected_disk_name} set 1 esp on"
run_command_with_dialog "Installing Arch Linux" "Creating primary ext4 partition..." "parted /dev/${selected_disk_name} mkpart primary ext4 1024MiB 100%"
run_command_with_dialog "Installing Arch Linux" "Formatting EFI partition..." "yes | mkfs.vfat /dev/${selected_disk_name}${selected_disk_parted_separator}1"
run_command_with_dialog "Installing Arch Linux" "Formatting ext4 partition..." "yes | mkfs.ext4 /dev/${selected_disk_name}${selected_disk_parted_separator}2"
run_command_with_dialog "Installing Arch Linux" "Mounting ext4 partition..." "mount /dev/${selected_disk_name}${selected_disk_parted_separator}2 /mnt && mkdir -p /mnt/boot/efi"
run_command_with_dialog "Installing Arch Linux" "Mounting EFI partition..." "mount /dev/${selected_disk_name}${selected_disk_parted_separator}1 /mnt/boot/efi"
run_command_with_dialog "Installing Arch Linux" "Installing base system and packages..." "pacstrap /mnt base base-devel linux linux-firmware linux-headers curl grub efibootmgr networkmanager wayland zsh git neovim python-pillow swaybg nodejs firefox htop pulseaudio alsa-lib alsa-utils pulsemixer sway wlroots seatd waybar grim wl-clipboard ranger kitty imagemagick unzip ripgrep lazygit neofetch ttc-iosevka ttf-iosevka-nerd"
run_command_with_dialog "Installing Arch Linux" "Generating fstab..." "genfstab /mnt >> /mnt/etc/fstab"
run_command_with_dialog "Installing Arch Linux" "Copying configuration files..." "echo \"$user_username\" > /mnt/etc/hostname && cp -pr ./etc/pacman.conf /mnt/etc/pacman.conf && cp -pr ./etc/locale.gen /mnt/etc/locale.gen"
run_command_with_dialog "Installing Arch Linux" "Cloning Oh My Zsh..." "git clone https://github.com/ohmyzsh/ohmyzsh.git /mnt/etc/skel/.oh-my-zsh"
run_command_with_dialog "Installing Arch Linux" "Cloning Ranger Devicons..." "git clone https://github.com/alexanderjeurissen/ranger_devicons.git /mnt/etc/skel/.config/ranger/plugins/ranger_devicons"
run_command_with_dialog "Installing Arch Linux" "Cloning Zsh Autosuggestions..." "git clone https://github.com/zsh-users/zsh-autosuggestions.git /mnt/etc/skel/.oh-my-zsh/plugins/zsh-autosuggestions"
run_command_with_dialog "Installing Arch Linux" "Copying skel to new user's home..." "cp -pr ./etc/skel /mnt/etc/skel &> /dev/null"
run_command_with_dialog "Installing Arch Linux" "Creating user..." "arch-chroot /mnt /bin/zsh -c \"useradd -m -s /bin/zsh ${user_username}\" && rm -fr /mnt/home/${user_username} && cp -pr ./etc/skel /mnt/home/${user_username}"
run_command_with_dialog "Installing Arch Linux" "Setting user password..." "arch-chroot /mnt /bin/zsh -c \"echo '${user_username}:${user_password}' | chpasswd\""
run_command_with_dialog "Installing Arch Linux" "Adding user to sudoers..." "arch-chroot /mnt /bin/zsh -c \"echo '${user_username} ALL=(ALL:ALL) ALL' | tee -a /etc/sudoers\""
run_command_with_dialog "Installing Arch Linux" "Enabling NetworkManager..." "arch-chroot /mnt /bin/zsh -c \"systemctl enable NetworkManager\""
run_command_with_dialog "Installing Arch Linux" "Setting timezone..." "arch-chroot /mnt /bin/zsh -c \"timedatectl set-timezone Europe/Moscow\""
run_command_with_dialog "Installing Arch Linux" "Enabling NTP..." "arch-chroot /mnt /bin/zsh -c \"timedatectl set-ntp true\""
run_command_with_dialog "Installing Arch Linux" "Installing GRUB bootloader..." "arch-chroot /mnt /bin/zsh -c \"grub-install /dev/${selected_disk_name}\""
run_command_with_dialog "Installing Arch Linux" "Copying GRUB themes..." "cp -pr ./boot/grub/themes/grub /mnt/boot/grub/themes/grub"
run_command_with_dialog "Installing Arch Linux" "Copying GRUB configuration..." "cp -pr ./etc/default/grub /mnt/etc/default/grub"
run_command_with_dialog "Installing Arch Linux" "Generating GRUB configuration..." "arch-chroot /mnt /bin/zsh -c \"grub-mkconfig -o /boot/grub/grub.cfg\""
run_command_with_dialog "Installing Arch Linux" "Setting root password..." "arch-chroot /mnt /bin/zsh -c \"echo 'root:${root_password}' | chpasswd\""
run_command_with_dialog "Installing Arch Linux" "Setting permissions for user's home directory..." "chmod -R 700 /mnt/home/${user_username} && chmod g-w,o-w -R /mnt/home/${user_username}/.oh-my-zsh"
run_command_with_dialog "Installing Arch Linux" "Unmounting filesystems..." "umount -R /mnt"

dialog --title "Installing Arch Linux" --msgbox "The installation is complete, now you can restart your computer" 7 40
