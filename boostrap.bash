#!/bin/bash
N_PROJECT=arch_hyperland

pacman -S git

if [ "${PWD##*/}" == "$N_PROJECT" ] && [ -d ".git" ]; then
    git pull origin main
else
    if [ ! -d "$N_PROJECT" ];then
        git clone https://github.com/GrimAnEye/arch_hyperland.git
        
    fi
    cd "$N_PROJECT/"
fi

chmod +x ./install.bash
bash ./install.bash
