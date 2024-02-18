#!/bin/bash

askForPassword(){
    for ((;;)); do
        echo -n "Write password: ">&2
        read -s A_pass1
        echo -ne "\nRepeat password: ">&2
        read -s A_pass2

        if [ -z $A_pass1 ] && [ -z $A_pass2 ]; then
            echo -e "\nPassword not be empty!\n">&2
            continue
        fi
        if [ ! "$A_pass1" == "$A_pass2" ]; then
            echo -e "\nPasswords is different!\n">&2
            continue
        fi
        echo "">&2
        break
    done
echo $A_pass1
unset A_pass1 A_pass2
}

askForName(){
    for ((;;));do
        echo -n "Write new $1: ">&2
        read A_name

        if [ -z $A_name ]; then
            echo -e "$1 not be empty!\n">&2
            continue
        fi
        break
    done
echo $A_name
unset A_name
}
