#!/bin/bash
#Author: Federico Lodovici
#This script downloades latest kernel sources, compiles them and configures bootloader

#Variable declaration
HEIGHT=15
WIDTH=60
CHOICE_HEIGHT=4
BACKTITLE="Simple Kernel Config"
MENU="Choose one of the following options:"74
SELECTION0=(1 "Install"
         2 "Upgrade")

SELECTION1=(1 "Use mainline kernel sources"
         2 "Use stable kernel sources")

SELECTION2=(1 "Configure graphically using menuconfig"
         2 "Configure verbosely new options"	
      	 3 "Use defaults for new options"
	)

SELECTION3=(1 "Configure graphically using menuconfig"
         2 "Choose a .config file from disk"
	 3 "Use a generic configuration"
	)

SELECTION4=(1 "systemd-boot/Goofiboot"
         2 "Grub"
	 3 "efibootmgr"
	)

DISTRONAME=$(lsb_release -si)
OPTIONS=$(cat /proc/cmdline | grep root=)
ARCH=$(uname -m)
CORENUMBER=$(grep -c ^processor /proc/cpuinfo)
BOOTPART=""
EFIPART=""
EFIDIR=""
INSTALL=false

#function declaration
#configure the bootloader
function editbootloaderconfig {
 	if (dialog --backtitle "$BACKTITLE" \
		   --title "Configure Bootloader" \
                   --yesno "Do you want to configure manually the bootloader?" $HEIGHT $WIDTH )then
		dialog --backtitle "$BACKTITLE" --title "$1" --editbox $1 $HEIGHT $WIDTH 2> "${INPUT}"
		cp ${INPUT} $1
	fi }

#gui
_gui () {
CHOICE0=$(dialog --backtitle "$BACKTITLE" \
                 --title "Menu" \
		 --cancel-label "Exit" \
                 --menu "What you want to do?" \
		 $HEIGHT $WIDTH $CHOICE_HEIGHT \
                 "${SELECTION0[@]}" \
                 2>&1 >/dev/tty)
#check if exit is pressed
if (($? == 1)); then
	exit 
fi
case $CHOICE0 in
        1)
            INSTALL=true
            ;;
        2)
            INSTALL=false
            ;;
esac 


CHOICE1=$(dialog --backtitle "$BACKTITLE" \
                 --title "Select sources" \
                 --menu "$MENU" \
		 $HEIGHT $WIDTH $CHOICE_HEIGHT \
                 "${SELECTION1[@]}" \
                 2>&1 >/dev/tty)
if [ $? -eq 1 ]; then
           _gui
        fi	

if (dialog --backtitle "$BACKTITLE" \
	   --title "Boot and EFI Partition" \
           --yesno "You need to mount a boot or an EFI partition?" \
           $HEIGHT $WIDTH ) then
        PARTS=$(dialog --backtitle "$BACKTITLE" \
		      --no-cancel \
 	                --title "Set boot or efi partition" \
	                --form "Enter your boot and/or EFI partition (ex. /dev/sda1), leave the form blank if you haven't one of the two:" \
			 $HEIGHT $WIDTH  0\
        		"Boot Partition:" 1 1 "$BOOTPART"         1 16 20 0 \
        		"EFI Partition:"  2 1 "$EFIPART"       	 2 16 20 0 \
       			3>&1 1>&2 2>&3)
	PARTS=(${PARTS[@]})
        BOOTPART=${PARTS[0]}
	EFIPART=${PARTS[1]}          
	mount $BOOTPART /boot  > /dev/null 2>&1
	if [ -d "/boot/efi" ]; then
		mount $EFIPART /boot/efi > /dev/null 2>&1
		EFIDIR=efi
	else 
		mount $EFIPART /boot/EFI > /dev/null 2>&1
		EFIDIR=EFI
	fi
	if [ $? -eq 1 ]; then
           _gui
        fi	  
fi

if [ "$INSTALL" = false ]; then
		CHOICE2=$(dialog \
				--backtitle "$BACKTITLE" \
				--title "Set config method (Advanced)" \
				--menu "$MENU" \
				$HEIGHT $WIDTH $CHOICE_HEIGHT \
				"${SELECTION2[@]}" \
				2>&1 >/dev/tty)
		if [ $? -eq 1 ]; then
		      _gui
		    fi
	else
		CHOICE2=$(dialog \
				--backtitle "$BACKTITLE" \
				--title "Set config method (Advanced)" \
				--menu "$MENU" \
				$HEIGHT $WIDTH $CHOICE_HEIGHT \
				"${SELECTION3[@]}" \
				2>&1 >/dev/tty)
		if [ $? -eq 1 ]; then
		      _gui
		    fi
	fi


CORE=$(dialog --backtitle "$BACKTITLE"\
	      --title "Set number of cores"\
	      --inputbox "Enter your number of core to optimize compilation, press enter to use all cores:"\
	      $HEIGHT $WIDTH\
	      $CORENUMBER \
	      3>&1 1>&2 2>&3)
if [ $? -eq 1 ]; then
     _gui
    fi

CHOICE3=$(dialog \
                --backtitle "$BACKTITLE" \
                --title "Select your bootloader" \
                --menu "$MENU" \
		$HEIGHT $WIDTH $CHOICE_HEIGHT \
                "${SELECTION4[@]}" \
                2>&1 >/dev/tty)
if [ $? -eq 1 ]; then
      _gui
     fi }

#Actual Script

if (( $EUID != 0 )); then
    echo "Please run as root"
    exit
fi

_gui
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
	    if [ "$INSTALL" = false ]; then
		    cp /boot/.config .config
		    (make oldconfig) | \
		    dialog --backtitle "$BACKTITLE" --programbox "Configuring kernel"  $HEIGHT $WIDTH
	    else
		    dialog --backtitle "$BACKTITLE" \
                           --title "Kernel Source Compiling" \
			   --msgbox "To navigate in the next box use tab or arrow keys to move between the windows. \
Within the directory or filename  windows, use the up/down arrow keys to scroll the current selection. \
Use the  space-bar  to  copy  the current selection into the text-entry window." \
				      $HEIGHT $WIDTH
	            CONFIG=$(dialog --stdout \
				    --title "Choose .config File" \
                                    --fselect /boot/ $HEIGHT $WIDTH)
                    if [ $? -eq 1 ]; then
		      _gui
		    fi
		    cp $CONFIG .config
		    make olddefconfig > /dev/null 2>&1
	    fi
	    ;;
        3)  
	    if [ "$INSTALL" = false ]; then
		    cp /boot/.config .config
		    make olddefconfig > /dev/null 2>&1
	    else
		    cd /usr/src/linux/linux-$KERNEL
		    if [ $ARCH = "x86_64" ]; then
		        wget  –-quiet  -O .config http://kernel.ubuntu.com/~kernel-ppa/configs/xenial/linux/4.4.0-78.99/amd64-config.flavour.generic
		        make oldefconfig > /dev/null 2>&1
		    else 
		        wget  –-quiet  -O .config http://kernel.ubuntu.com/~kernel-ppa/configs/xenial/linux/4.4.0-78.99/i386-config.flavour.generic
		        make oldefconfig > /dev/null 2>&1
	            fi
	    fi
            ;;	        
esac 

dialog --backtitle "$BACKTITLE" --no-cancel --no-ok --title "Kernel Source Compiling" \
       --pause "Kernel Source is now going to compile." $HEIGHT $WIDTH 5
(make clean && make -j$CORE && make -j$CORE modules_install ) | \
dialog --backtitle "$BACKTITLE" --progressbox "Compiling Sources"  $HEIGHT $WIDTH

#save .config in /boot folder
cp .config /boot/.config
cp -v arch/$ARCH/boot/bzImage /boot/vmlinuz-$KERNEL

case $CHOICE3 in
        1) #configure systemd-boot
	touch /boot/loader/entries/$DISTRONAME-linux-$KERNEL.conf
	cat > /boot/loader/entries/$DISTRONAME-linux-$KERNEL.conf << 'EOF'
	title  	       ${DISTRONAME}-${ARCH}-${KERNEL}
	linux          /vmlinuz-${KERNEL}
	options        ${OPTIONS}
	EOF
	sed -i '1s/.*/timeout 3/' /boot/loader/loader.conf
	sed -i "2s/.*/default ${DISTRONAME}-linux-${KERNEL}/" /boot/loader/loader.conf
	editbootloaderconfig (/boot/loader/loader.conf)
            ;;

        2) #configure grub
	    editbootloaderconfig (/etc/default/grub)
            grub-mkconfig -o /boot/grub/grub.cfg
            ;;
        3) #configure efibootmg
            cp /boot/vmlinuz-${KERNEL} /boot/${EFIDIR}/boot/bootx64.efi
	    efibootmgr --create --disk /dev/sda --label "$DISTRO" --loader "/${EFIDIR}/Boot/bootx64.efi"
            ;;
	           
esac 


if (dialog --backtitle "$BACKTITLE" --title "Process Completed" --yesno "The process is completed do you want to reboot in your new kernel?" $HEIGHT $WIDTH ) then
    reboot
else
    exit
fi

