#!/bin/bash
#Author: Federico Lodovici
#This script downloades latest kernel sources, compiles them and configures systemd-boot

HEIGHT=15
WIDTH=60
CHOICE_HEIGHT=4
BACKTITLE="Simple Kernel Config"
MENU="Choose one of the following options:"
SELECTION1=(1 "Use mainline kernel sources"
         2 "Use stable kernel sources")

SELECTION2=(1 "Configure graphically with menuconfig"
         2 "Configure new options in verbose mode"
         3 "Apply the defaults for new option"
	 4 "Use a premade .config"
	)

DISTRONAME=$(lsb_release -si)
OPTIONS=$(cat /proc/cmdline | grep root=)
ARCH=$(uname -m)

if (( $EUID != 0 )); then
    echo "Please run as root"
    exit
fi

CHOICE1=$(dialog --clear \
                --backtitle "$BACKTITLE" \
                --title "Select sources" \
		--cancel-label "Exit" \
                --menu "$MENU" \
		$HEIGHT $WIDTH $CHOICE_HEIGHT \
                "${SELECTION1[@]}" \
                2>&1 >/dev/tty)

#check if exit is pressed
exitvalue=$?
if (($exitvalue == 1)); then
	exit 1
fi

EFI=$(dialog --backtitle "$BACKTITLE" \
 	     --title "Set efi partition" \
	     --inputbox "Enter your efi partition (ex. /dev/sda1):" \
       	     $HEIGHT $WIDTH \
	     3>&1 1>&2 2>&3)

CHOICE2=$(dialog --clear \
                --backtitle "$BACKTITLE" \
                --title "Set config method" \
                --menu "$MENU" \
                $HEIGHT $WIDTH $CHOICE_HEIGHT \
                "${SELECTION2[@]}" \
                2>&1 >/dev/tty)

CORE=$(dialog --backtitle "$BACKTITLE"\
	      --title "Set number of cores"\
	      --inputbox "Enter your number of core+1 to optimize compilation:"\
	      $HEIGHT $WIDTH\
	      3>&1 1>&2 2>&3)

mount $EFI /boot > /dev/null 2>&1

mkdir -p /usr/src
mkdir -p /usr/src/linux
cd /usr/src/linux/

case $CHOICE1 in
        1)
            KERNEL=$(curl -s https://www.kernel.org/ | grep -A1 'mainline:' | grep -oP '(?<=strong>).*(?=</strong.*)')
            ;;
        2)
            KERNEL=$(curl -s https://www.kernel.org/ | grep -A1 'stable:' | grep -oP '(?<=strong>).*(?=</strong.*)')
            ;;
esac 

#download new sources if not presents
if [ ! -f linux-$KERNEL.tar.xz ]; then
 	wget https://cdn.kernel.org/pub/linux/kernel/v${KERNEL:0:1}.x/linux-$KERNEL.tar.xz 2>&1 | \
	stdbuf -o0 awk '/[.] +[0-9][0-9]?[0-9]?%/ { print substr($0,63,3) }' | \
	dialog --backtitle "$BACKTITLE" --gauge "Downloading Sources..." $HEIGHT $WIDTH 
fi

(pv -n linux-$KERNEL.tar.xz | tar xJf - ) 2>&1 | \
dialog --backtitle "$BACKTITLE" --gauge "Extracting Sources..." $HEIGHT $WIDTH
cd linux-$KERNEL

case $CHOICE2 in
        1)  
	    cp /boot/.config .config | :
            make menuconfig
            ;;
        2)
            cp /boot/.config .config
            make oldconfig
            ;;
        3)  
            cp /boot/.config .config
            make olddefconfig 
            ;;
	4)
	    if [ $ARCH = "x86_64" ]; then
                wget -O .config http://kernel.ubuntu.com/~kernel-ppa/configs/xenial/linux/4.4.0-78.99/amd64-config.flavour.generic
                make oldefconfig
            else 
                wget -O .config http://kernel.ubuntu.com/~kernel-ppa/configs/xenial/linux/4.4.0-78.99/i386-config.flavour.generic
                make oldefconfig
           fi
           ;;                
esac 

dialog --backtitle "$BACKTITLE"  --title "Kernel Source Compiling" --msgbox "Kernel Source is now going to compile." $HEIGHT $WIDTH 
clear
(make clean && make -j$CORE && make -j$CORE modules_install )

#save .config in /boot folder
cp .config /boot/.config
cp -v arch/$ARCH/boot/bzImage /boot/vmlinuz-$KERNEL
#configure systemd-boot
touch /boot/loader/entries/$DISTRONAME-linux-$KERNEL.conf
cat > /boot/loader/entries/$DISTRONAME-linux-$KERNEL.conf << EOL
title  ${DISTRONAME}-${ARCH}-${KERNEL}
linux          /vmlinuz-${KERNEL}
options        ${OPTIONS}
EOL
sed -i '1s/.*/timeout 3/' /boot/loader/loader.conf
sed -i "2s/.*/default ${DISTRONAME}-linux-${KERNEL}/" /boot/loader/loader.conf

if (dialog --backtitle "$BACKTITLE" --title "Process Completed" --yesno "The process is completed do you want to reboot in your new kernel?" $HEIGHT $WIDTH ) then
    reboot
else
    exit
fi

