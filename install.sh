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

function show_progress {
    local message=$1
    local progress=$2
    echo "$progress" | dialog --gauge "$message" 10 70
}

show_progress "Starting Arch Linux installation..." 0
sleep 1

show_progress "Wiping disk metadata..." 10
wipefs --all /dev/${selected_disk_name}

show_progress "Creating partition table..." 20
parted /dev/${selected_disk_name} mklabel gpt

show_progress "Creating EFI partition..." 30
parted /dev/${selected_disk_name} mkpart primary fat32 1MiB 1024MiB
parted /dev/${selected_disk_name} set 1 esp on

show_progress "Creating primary ext4 partition..." 40
parted /dev/${selected_disk_name} mkpart primary ext4 1024MiB 100%

show_progress "Formatting EFI partition..." 50
yes | mkfs.vfat /dev/${selected_disk_name}${selected_disk_parted_separator}1
show_progress "Formatting ext4 partition..." 60
yes | mkfs.ext4 /dev/${selected_disk_name}${selected_disk_parted_separator}2

show_progress "Mounting ext4 partition..." 70
mount /dev/${selected_disk_name}${selected_disk_parted_separator}2 /mnt
mkdir -p /mnt/boot/efi
show_progress "Mounting EFI partition..." 80
mount /dev/${selected_disk_name}${selected_disk_parted_separator}1 /mnt/boot/efi

show_progress "Installing base system and packages..." 90
pacstrap /mnt base base-devel linux linux-firmware linux-headers curl grub efibootmgr networkmanager wayland zsh git neovim python-pillow swaybg nodejs firefox htop pulseaudio alsa-lib alsa-utils pulsemixer sway wlroots seatd waybar grim wl-clipboard ranger kitty imagemagick unzip ripgrep lazygit neofetch ttc-iosevka ttf-iosevka-nerd

show_progress "Generating fstab..." 100
genfstab /mnt >> /mnt/etc/fstab

show_progress "Copying configuration files..." 110
cp -pr ./etc/hostname /mnt/etc/hostname
cp -pr ./etc/pacman.conf /mnt/etc/pacman.conf
cp -pr ./etc/locale.gen /mnt/etc/locale.gen

show_progress "Cloning Oh My Zsh..." 120
git clone https://github.com/ohmyzsh/ohmyzsh.git ./etc/skel/.oh-my-zsh
show_progress "Cloning Ranger Devicons..." 130
git clone https://github.com/alexanderjeurissen/ranger_devicons.git ./etc/skel/.config/ranger/plugins/ranger_devicons
show_progress "Cloning Zsh Autosuggestions..." 140
git clone https://github.com/zsh-users/zsh-autosuggestions.git ./etc/skel/.oh-my-zsh/plugins/zsh-autosuggestions

show_progress "Copying skel to new user's home..." 150
cp -pr ./etc/skel /mnt/etc/skel

show_progress "Creating user..." 160
arch-chroot /mnt /bin/zsh -c "useradd -m -s /bin/zsh ${user_username}"
rm -fr /mnt/home/${user_username}
cp -pr ./etc/skel /mnt/home/${user_username}

show_progress "Setting user password..." 170
arch-chroot /mnt /bin/zsh -c "echo '${user_username}:${user_password}' | chpasswd"

show_progress "Adding user to sudoers..." 180
arch-chroot /mnt /bin/zsh -c "echo '${user_username} ALL=(ALL:ALL) ALL' | tee -a /etc/sudoers"

show_progress "Enabling NetworkManager..." 190
arch-chroot /mnt /bin/zsh -c "systemctl enable NetworkManager"

show_progress "Setting timezone..." 200
arch-chroot /mnt /bin/zsh -c "timedatectl set-timezone Europe/Moscow"

show_progress "Enabling NTP..." 210
arch-chroot /mnt /bin/zsh -c "timedatectl set-ntp true"

show_progress "Installing GRUB bootloader..." 220
arch-chroot /mnt /bin/zsh -c "grub-install /dev/${selected_disk_name}"

show_progress "Copying GRUB themes..." 230
cp -pr ./boot/grub/themes/grub /mnt/boot/grub/themes/grub
show_progress "Copying GRUB configuration..." 240
cp -pr ./etc/default/grub /mnt/etc/default/grub

show_progress "Generating GRUB configuration..." 250
arch-chroot /mnt /bin/zsh -c "grub-mkconfig -o /boot/grub/grub.cfg"

show_progress "Setting root password..." 260
arch-chroot /mnt /bin/zsh -c "echo 'root:${root_password}' | chpasswd"

show_progress "Setting permissions for user's home directory..." 270
chmod -R 777 /mnt/home/${user_username}
chmod g-w,o-w -R /mnt/home/${user_username}/.oh-my-zsh

show_progress "Unmounting filesystems..." 280
umount -R /mnt

dialog --title "Installing Arch Linux" --msgbox "The installation is complete, now you can restart your computer" 7 40
