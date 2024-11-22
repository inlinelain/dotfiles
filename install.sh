wipefs --all /dev/nvme0n1
parted /dev/nvme0n1 mklabel gpt
parted /dev/nvme0n1 mkpart primary fat32 1MiB 1024MiB
parted /dev/nvme0n1 set 1 esp on
parted /dev/nvme0n1 mkpart primary ext4 1024MiB 100%
yes | mkfs.vfat /dev/nvme0n1p1
yes | mkfs.ext4 /dev/nvme0n1p2
mount /dev/nvme0n1p2 /mnt
mkdir -p /mnt/boot/efi
mount /dev/nvme0n1p1 /mnt/boot/efi
pacstrap /mnt base base-devel linux linux-firmware linux-headers curl grub efibootmgr networkmanager wayland zsh git neovim python-pillow swaybg nodejs firefox htop pulseaudio alsa-lib alsa-utils pulsemixer sway wlroots seatd waybar grim wl-clipboard ranger kitty imagemagick unzip ripgrep lazygit neofetch ttc-iosevka ttf-iosevka-nerd
# pacstrap /mnt base base-devel linux linux-firmware linux-headers curl grub networkmanager efibootmgr
genfstab /mnt >> /mnt/etc/fstab
cp -pr ./etc/hostname /mnt/etc/hostname
cp -pr ./etc/pacman.conf /mnt/etc/pacman.conf
cp -pr ./etc/locale.gen /mnt/etc/locale.gen
arch-chroot /mnt /bin/zsh -c "locale-gen"
git clone https://github.com/ohmyzsh/ohmyzsh.git ./etc/skel/.oh-my-zsh
git clone https://github.com/alexanderjeurissen/ranger_devicons.git ./etc/skel/.config/ranger/plugins/ranger_devicons
git clone https://github.com/zsh-users/zsh-autosuggestions ./etc/skel/.oh-my-zsh/plugins/zsh-autosuggestions
cp -pr ./etc/skel /mnt/etc/skel
arch-chroot /mnt /bin/zsh -c "useradd -m -s /bin/zsh inlinelain"
rm -fr /mnt/home/inlinelain
cp -pr ./etc/skel /mnt/home/inlinelain
arch-chroot /mnt /bin/zsh -c "echo "inlinelain:inlinelain" | chpasswd"
arch-chroot /mnt /bin/zsh -c "echo \"inlinelain ALL=(ALL:ALL) ALL\" | tee -a /etc/sudoers"
arch-chroot /mnt /bin/zsh -c "sudo systemctl enable NetworkManager"
arch-chroot /mnt /bin/zsh -c "timedatectl set-timezone Europe/Moscow"
arch-chroot /mnt /bin/zsh -c "timedatectl set-ntp true"
arch-chroot /mnt /bin/zsh -c "grub-install /dev/nvme0n1"
cp -pr ./boot/grub/themes/grub /mnt/boot/grub/themes/grub
cp -pr ./etc/default/grub /mnt/etc/default/grub
arch-chroot /mnt /bin/zsh -c "grub-mkconfig -o /boot/grub/grub.cfg"
arch-chroot /mnt /bin/zsh -c "echo "root:inlinelain" | chpasswd"
chmod -R 777 /mnt/home/inlinelain
chmod g-w,o-w -R /mnt/home/inlinelain/.oh-my-zsh/custom
umount -R /mnt
reboot
