#!/bin/bash
source ./lib.bash

#################################################
loadkeys ru
setfont cyr-sun16

#################################################
echo "===HOSTNAME==="
N_HOSTNAME=$(askForName)
echo -e "===HOSTNAME IS $N_HOSTNAME===\n"

#################################################
echo "===ROOT PASSWORD==="
N_ROOTPASS=$(askForPassword)
echo -e "===ROOT PASSWORD IS SET===\n"

#################################################
echo "===NEW USER==="
echo "Need you new user?"
select N_yn in "Yes" "No"; do
    case $N_yn in
        Yes)
            N_USERNAME=$(askForName "username")
            N_USERPASSWORD=$(askForPassword)
            break;;
        No) break;;
    esac
done
unset $N_yn

####################################################################
# Find out in what mode the operating system was loaded
if [ -d "/sys/firmware/efi/" ]; then
    N_BOOTMODE=gpt
else
    N_BOOTMODE=msdos
fi
echo "===BOOTMODE: $N_BOOTMODE==="

# select architecture.
# ARCH=$(</sys/firmware/efi/fw_platform_size)

# select the firts disk for install
N_DEVINSTALL=$(lsblk -l | grep sd | head -1 | awk '{print $1}')
echo "===DRIVE SELECTED: $N_DEVINSTALL==="

# create new partition table
parted "/dev/$N_DEVINSTALL" --script mklabel $N_BOOTMODE

if [ $N_BOOTMODE == "gpt" ]; then
    parted "/dev/$N_DEVINSTALL" --script mkpart ESP fat32 1Mib 513Mib
    parted "/dev/$N_DEVINSTALL" --script mkpart primary ext4 1000MiB 100%

    mkfs.fat -F32 "/dev/${N_DEVINSTALL}1"
    mkfs.ext4 -F "/dev/${N_DEVINSTALL}2"

    mount "/dev/${N_DEVINSTALL}2" "/mnt"
    mkdir "/mnt/boot"
    mount "/dev/${N_DEVINSTALL}1" "/mnt/boot"
else
    parted "/dev/$N_DEVINSTALL" --script mkpart primary ext4 1MiB 100%
    parted "/dev/$N_DEVINSTALL" --script set 1 boot on

    mkfs.ext4 -F "/dev/${N_DEVINSTALL}1" "/mnt"
fi
fdisk -l "/dev/$N_DEVINSTALL"

####################################################################
# base OS install
pacstrap -K "/mnt" $(<packages_base.list)
genfstab -U "/mnt" > "/mnt/etc/fstab"
arch-chroot "/mnt"

####################################################################
# set time
ln -sf "/usr/share/zoneinfo/Asia/Novosibirsk" "/etc/localtime"
hwclock --systohc

echo $N_HOSTNAME > "/etc/hostname"

####################################################################
# locale generation
sed -i "/en_US.UTF-8/s/^#//g" /etc/locale.gen
sed -i "/ru_RU.UTF-8/s/^#//g" /etc/locale.gen
locale-gen
echo "LANG=ru_RU.UTF8" > "/etc/locale.conf"
export LANG=ru_RU.UTF8

echo -e "KEYMAP=ru\nFONT=cyr-sun16" > "/etc/vconsole.conf"

####################################################################
# create users
echo -e "$N_ROOTPASS\n$N_ROOTPASS" | passwd root
echo "%wheel ALL=(ALL:ALL) ALL" > "/etc/sudoers.d/wheel"

# create new user
if [ ! -z $N_USERNAME ]; then
    useradd -m -G wheel,storage,power -s /bin/zsh $N_USERNAME
    echo -e "$N_USERPASSWORD\n$N_USERPASSWORD" | passwd $N_USERNAME
fi

####################################################################
# pacman update
echo -e "[multilib]\nInclude = /etc/pacman.d/mirrorlist"  >> /etc/pacman.conf
pacman -Syy

# Grub install
if [ $N_BOOTMODE =="gpt" ];then
    pacman -Syu --noconfirm  efibootmgr
    grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=grub
else
    grub-install --recheck --targen=i386-pc "/dev/$N_DEVINSTALL"

fi
grub-mkconfig -o /boot/grub/grub.cfg

####################################################################

# GUI install
pacman -Syu --noconfirm $(<packages_gui.list)
systemctl enable sddm

# ПЕРЕВЕДИ SDDM на WAYLAND
# https://wiki.archlinux.org/title/SDDM#Running_under_Wayland
