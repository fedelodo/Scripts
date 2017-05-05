# Simple Kernel Config
Is a simple script written in bash who helps to download and configure latest mainline and stable kernel version.

## Requirements

1. `dialogs`.
2. `pv`.
3. `systemd-boot or goofiboot`.
4. `build-essential` or similar package for your distro

## How to use

1. Download the script.
2. Execute  `chmod +x simplekernelconfig.sh`.
3. Run  `./simplekernelconfig.sh` as root.

##TODO

1. A decent main menu.
2. Support other bootloaders.
3. Add the support to patches (maybe with a sort of "patch repo").
4. Clean the code.
5. Add the support to initrd creation.

