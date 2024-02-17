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

# Тут развилочка для выбора режима диска

# Выясняю в каком режиме выполнена загрузка
if [ -d "/sys/firmware/efi/" ]; then
    MODE=gpt
else
    MODE=msdos
fi

# ARCH=$(</sys/firmware/efi/fw_platform_size)

# Выбираю первый диск для разбивки
DEV=$(lsblk -l | grep sd | head -1 | awk '{print $1}')

# создаю новую таблицу разделов
parted "/dev/${DEV}" --script mklabel $MODE

if [ $MODE == "gpt" ]; then
    # Если режим установки GPT, создаю efi раздел
    parted "/dev/${DEV}" --script mkpart ESP fat32 1Mib 513Mib
    # Создаю основной раздел системы
    parted "/dev/${DEV}" --script mkpart primary ext4 1000MiB 100%

    # Форматирование разделов
    mkfs.fat -F32 "/dev/${DEV}1"
    mkfs.ext4 -F "/dev/${DEV}2"

    # Монтирование загрузовного раздела
    mount "/dev/${DEV}2" "/mnt"
    mkdir "/mnt/boot"
    mount "/dev/${DEV}1" "/mnt/boot"
else
    # Если режим установки MBR, создаю раздел диска
    parted "/dev/${DEV}" --script mkpart primary ext4 1MiB 100%
    # Устанавливаю корневой раздел загрузки
    parted "/dev/${DEV}" --script set 1 boot on

    # Форматирование разделов
    mkfs.ext4 -F "/dev/${DEV}1" "/mnt"
fi

####################################################################

# Установка базовой системы
pacstrap -K "/mnt" base base-devel linux linux-firmware \
less mc dhclient zsh grub networkmanager \
terminator thunar

# генерация таблицы дисков
genfstab -U "/mnt" > "/mnt/etc/fstab"

# Переключение в систему
arch-chroot "/mnt"

####################################################################

# установка времени
ln -sf "/usr/share/zoneinfo/Asia/Novosibirsk" "/etc/localtime"
hwclock --systohc

# Генерация локалей
echo -e "en_US.UTF-8 UTF-8\nru_RU.UTF-8 UTF-8" >> "/etc/locale.gen"
locale-gen
echo "LANG=ru_RU.UTF8" > "/etc/locale.conf"
export LANG=ru_RU.UTF8

# установка раскладки и шрифта для терминала
echo -e "KEYMAP=ru\nFONT=cyr-sun16" > "/etc/vconsole.conf"

####################################################################
echo $N_HOSTNAME > "/etc/hostname"

# установка пароля root
echo -e "$N_ROOTPASS\n$N_ROOTPASS" | passwd root

# Выдача группе wheel админ прав
echo "%wheel ALL=(ALL:ALL) ALL" > "/etc/sudoers.d/wheel"

# создание нового пользователя, если задано имя пользователя
if [ ! -z $N_USERNAME ]; then
    useradd -m -G wheel,storage,power -s /bin/zsh $N_USERNAME
    echo -e "$N_USERPASSWORD\n$N_USERPASSWORD" | passwd $N_USERNAME
fi

####################################################################
# Обновление баз pacman
echo -e "[multilib]\nInclude = /etc/pacman.d/mirrorlist"  >> /etc/pacman.conf
pacman -Syy

# установка grub
if [ $MODE =="gpt" ];then
    pacman -Syu --noconfirm  efibootmgr
    grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=grub
else
    grub-install --recheck --targen=i386-pc "/dev/$DEV"

fi
grub-mkconfig -o /boot/grub/grub.cfg

####################################################################

# установка графики
pacman -Syu --noconfirm hyprland xdg-desktop-portal-hyprland \
sddm

systemctl enable sddm

# ПЕРЕВЕДИ SDDM на WAYLAND
# https://wiki.archlinux.org/title/SDDM#Running_under_Wayland
