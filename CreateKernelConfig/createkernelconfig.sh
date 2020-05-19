#!/bin/bash
#Author: Federico Lodovici
#This script downloades latest kernel sources, compiles them and configures bootloader

#variables

PCI_DEVICES=($(echo $(lspci -nn | awk '{print $1}') | sed 's/\n//g'))
ACPI_DEVICES=($(ls -U /sys/bus/acpi/devices/))
PNP_DEVICES=($(ls -U /sys/bus/pnp/devices/))
I2C_DEVICES=($(ls -U /sys/bus/i2c/devices/))
PLATFORM_DEVICES=($(ls -U /sys/bus/platform/devices/))
prefix="0x"
PCI_DEVICE_NUM=0
USB_DEVICE_NUM=0
PNP_DEVICE_NUM=0
FS_DEVICE_NUM=0
I2C_DEVICE_NUM=0
PLATFORM_DEVICE_NUM=0
kernelver=5.6
for i in "${PCI_DEVICES[@]}"; 
 do 
    vendor=$(cat /sys/bus/pci/devices/0000:"$i"/vendor | sed -e "s/^$prefix//")
    device=$(cat /sys/bus/pci/devices/0000:"$i"/device | sed -e "s/^$prefix//")   
    PCI_QUERY_ID[$PCI_DEVICE_NUM]="$vendor:$device"
    (( PCI_DEVICE_NUM++ )) 
 done

 for i in ${ACPI_DEVICES[@]}; 
 do 
	id=$(cat "/sys/bus/acpi/devices/$i/hid" 2>/dev/null)
    ACPI_QUERY_ID[$ACPI_DEVICE_NUM]="$id"
    (( ACPI_DEVICE_NUM++ )) 
 done

 for i in ${PNP_DEVICES[@]}; 
 do 
	id=$(cat "/sys/bus/pnp/devices/$i/id" 2>/dev/null | sed 's/\n//g ' )
    PNP_QUERY_ID[$PNP_DEVICE_NUM]="$id"
    (( PNP_DEVICE_NUM++ )) 
 done

for i in ${I2C_DEVICES[@]}; 
 do 
	id=$(cat "/sys/bus/i2c/devices/$i/name" 2>/dev/null)
    I2C_QUERY_ID[$I2C_DEVICE_NUM]="$id"
    (( I2C_DEVICE_NUM++ )) 
 done

for i in ${PLATFORM_DEVICES[@]}; 
 do 
	id=$(cat /sys/bus/platform/devices/$i/modalias 2>/dev/null | sed -e "s/^platform://" )
    PLATFORM_QUERY_ID[$PLATFORM_DEVICE_NUM]="$id"
    (( PLATFORM_DEVICE_NUM++ )) 
 done

for i in "$(mount | sed -ne 's/^.*type \([^ ]*\).*$/\1/p' -  | sort -u )"; 
 do 
	id=$i
    FS_QUERY_ID[$FS_DEVICE_NUM]="$id"
    (( FS_DEVICE_NUM++ )) 
 done

for i in "$(grep -v '^#' /etc/fstab | sed -nre 's/^[^[:space:]]+[[:space:]]+[^[:space:]]+[[:space:]]+([^[:space:]]+)[[:space:]]+.*$/\1/p' - | sort -u )"; 
 do 
	id=$i
    FS_QUERY_ID[$FS_DEVICE_NUM]="$id"
    (( FS_DEVICE_NUM++ )) 
 done

devices+=(${ACPI_QUERY_ID[@]})
devices+=(${PNP_QUERY_ID[@]})
#devices+=(${I2C_QUERY_ID[@]}) 
devices+=(${PLATFORM_QUERY_ID[@]})
devices+=(${FS_QUERY_ID[@]})

echo "acpi \n ${ACPI_QUERY_ID[@]} \n" >> listhw.list

echo "pnp \n ${PNP_QUERY_ID[@]} \n" >> listhw.list

echo "i2c \n ${I2C_QUERY_ID[@]} \n" >> listhw.list

echo "platform \n ${PLATFORM_QUERY_ID[@]} \n" >> listhw.list

echo "fs \n ${FS_QUERY_ID[@]} \n" >> listhw.list

DEVICEDB=lkddb-$kernelver.list 
echo "https://cateee.net/sources/lkddb/$DEVICEDB"
$(curl -o $DEVICEDB https://cateee.net/sources/lkddb/$DEVICEDB)

for i in ${devices[@]};
 do
    echo $(grep -w $i $DEVICEDB | awk -F':' '{print $2}') >> tmp
 done
config=$(awk '!seen[$0]++' tmp)
$(rm tmp)
echo "$config" >> config.conf