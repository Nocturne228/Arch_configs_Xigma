# Boot

Arch installation image does not support [Secure Boot](https://wiki.archlinux.org/title/Unified_Extensible_Firmware_Interface/Secure_Boot),so it should be disabled. After installed, it could be set up again.

Boot mode check, connect to Internet, update system clock.

# Partition

As for UEFI with GPT, here's the official suggestion:

|Mount point on the installed system | Partition | Partition type | Suggested size|
|------------------------------------|-----------|----------------|---------------|
|/boot|/dev/efi_system_partition|EFI system partition|1 GiB |
|\[SWAP\]|/dev/swap_partition|Linux swap|At least 4 GiB|
|/|/dev/root_partition|Linux x86-64 root (/) |Remainder of the device.|

## ESP

EFI system partition, [ESP](https://wiki.archlinux.org/title/EFI_system_partition), acts as the storage place for the **UEFI boot loaders, applications and drivers to be launched by the UEFI firmware**.

If there is a existing ESP, use it instead of creating a new one. It's recommended to make ESP 1 GiB in size if you want to install more than one kernel, ensuring it has adequate space for multiple kernels or unified kernel images, a boot loader, firmware updates files and any other operating system or OEM files. 

If you plan to mount the partition to [/boot](https://wiki.archlinux.org/title/Partitioning#/boot) and will not install more than one kernel, then 400 MiB will be sufficient.

### /boot

The /boot directory contains the [vmlinuz](https://wiki.archlinux.org/title/Vmlinuz) and [initramfs](https://wiki.archlinux.org/title/Initramfs) images as well as the boot loader configuration file and boot loader stages. It also stores data that is used before the kernel begins executing user-space programs. /boot is not required for normal system operation, but only during boot and kernel upgrades (when regenerating the initial ramdisk).


## Disk information

Execute command `lsblk` to check the disks. My PC:

```
NAME        MAJ:MIN RM   SIZE RO TYPE MOUNTPOINTS
nvme0n1     259:0    0 476.9G  0 disk 
├─nvme0n1p1 259:1    0   260M  0 part 
├─nvme0n1p2 259:2    0    16M  0 part 
├─nvme0n1p3 259:3    0 329.6G  0 part 
├─nvme0n1p4 259:4    0 146.5G  0 part 
└─nvme0n1p5 259:5    0   614M  0 part 
nvme1n1     259:6    0 931.5G  0 disk 
├─nvme1n1p1 259:7    0    16M  0 part 
├─nvme1n1p2 259:8    0 731.5G  0 part 
├─nvme1n1p3 259:9    0   512M  0 part /boot
├─nvme1n1p4 259:10   0    16G  0 part [SWAP]
└─nvme1n1p5 259:11   0 183.5G  0 part /home
                                      /
```

NVMe (non-volatile memory express) is a protocol for highly parallel data transfer with reduced system overheads per input/output (I/O) that is used in flash storage and solid-state drives (SSDs). Command `lspci` will show the hardware information:

```
...
10000:e1:00.0 Non-Volatile memory controller: Samsung Electronics Co Ltd NVMe SSD Controller PM9A1/PM9A3/980PRO
10000:e2:00.0 Non-Volatile memory controller: Samsung Electronics Co Ltd NVMe SSD Controller 980 (DRAM-less)
```

As shown, I got two Samsung NVMe SSDs installed on my laptop, the 980 (1TB) is on M.2 PCIE 3.0 X4 slot. `sudo fdisk -l` lists the partition table of disks:

```
Disk /dev/nvme1n1: 931.51 GiB, 1000204886016 bytes, 1953525168 sectors
Disk model: Samsung SSD 980 1TB                     
Units: sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 16384 bytes / 131072 bytes
Disklabel type: gpt
Disk identifier: C0BEB01C-69A7-43B3-A09B-439FC373F5A9

Device              Start        End    Sectors   Size Type
/dev/nvme1n1p1         34      32767      32734    16M Microsoft reserved
/dev/nvme1n1p2      32768 1534091263 1534058496 731.5G Microsoft basic data
/dev/nvme1n1p3 1534091264 1535139839    1048576   512M EFI System
/dev/nvme1n1p4 1535139840 1568694271   33554432    16G Linux swap
/dev/nvme1n1p5 1568694272 1953523711  384829440 183.5G Linux filesystem
```
## Format & File system

Each newly created partition must be formatted with an appropriate [file system](https://wiki.archlinux.org/title/File_systems). 


See [filesystems(5)](https://man.archlinux.org/man/filesystems.5) for a general overview and [Wikipedia:Comparison of file systems](https://en.wikipedia.org/wiki/Comparison_of_file_systems) for a detailed feature comparison.

> In computing, a file system controls how data is stored and retrieved. By separating the data into pieces and giving each piece a name, the information is easily isolated and identified. Taking its name from the way paper-based information systems are named, each group of data is called a "file". The structure and logic rules used to manage the groups of information and their names is called a "file system".

EFI system partition should be formatted to *FAT32* with [mkfs.fat(8)](https://man.archlinux.org/man/mkfs.fat.8); Swap partition should be initialized with [mkswap(8)](https://man.archlinux.org/man/mkswap.8); For linux file system, I choose [btrfs](https://wiki.archlinux.org/title/Btrfs) which becomes the default file system of the most mainstream linux desktop distro such as Fedora, OpenSUSE.

### Btrfs - B tree file system

For linux desktop user, the advantages of Btrfs are subvolumes, snapshots and compression. Especially the subvolumes management, which is more flexible and dynamical.For /, /home, /opt, etc., there's no need for a separate partition, just create and mount subvolumes.

> Btrfs is a copy-on-write filesystem for Linux aimed at implementing advanced features including error detection, fault tolerance, recovery, transparent compression, cheap snapshots, integrated volume management, and easy administration. It provides multiple device storage pooling, RAID-like functionality, fast snapshot creation, and checksumming of data and metadata. 
>
> Contributors include Facebook, Fujitsu, (open)SUSE, Oracle, and Western Digital.

### Swap

A [swap](https://wiki.archlinux.org/title/Swap) is a file or partition that provides disk space used as virtual memory. Swap space can be used for two purposes, to extend the virtual memory beyond the installed physical memory (RAM), and also for *suspend-to-disk* support.


> The size of [SWAP] should theoretically be `max(numOfCores, RAM * 2) GiB`, Since computers have gained memory capacities superior to a gibibit, the previous "twice the amount of physical RAM" rule has become outdated. A sane default size is 4 GiB.

Whether or not it is beneficial to extend the virtual memory with swap depends on the amount of installed physical memory. If the amount of physical memory is less than the amount of memory required to run all the desired programs, then it may be beneficial to enable swap. This avoids out of memory conditions, where the Linux kernel OOM killer mechanism will automatically attempt to free up memory by killing processes. To increase the amount of virtual memory to the required amount, add the necessary difference (or more) as swap space.

Enabling swap is a matter of personal preference: some prefer programs to be killed over enabling swap and others prefer enabling swap and slower system when the physical memory is exhausted.

For more information, visit [All about Linux swap space](https://www.linux.com/news/all-about-linux-swap-space/).

# Mount

All files accessible in a Unix system are arranged in one big tree, the file hierarchy, rooted at /. These files can be spread out over several devices. The mount command serves to attach the filesystem found on some device to the big file tree. The filesystem is used to control how data is stored on the device or provided in a virtual way by network or other services. For more information, view man page: `mount(8)`.

Mount the root volume to `/mnt`, enable the zstandard(zstd) compression to reduce disk usage then create subvolumes `@` and `@home`. After that, unmout it. Mount the `/@` and `/@home`, create directories `/boot` and `/home`, mount boot partition to `/boot`. Finally, mount swap partition with `swapon`.

---

# Installation

Use `pacstrap` to [install essential packages](https://wiki.archlinux.org/title/Installation_guide#Install_essential_packages) to specified root directory, which is `/mnt` here. The essential packages include: 

- base: Minimal package set to define a basic Arch Linux installation.
- base-devel: Development tools (gcc, make, e.g.)
- linux, linux-firmware: The Linux kernel and modules, and linux firmware (Wi-Fi, Drivers, e.g.).
- linux-headers: Kernel header files for kernel compiling.
- intel-code: CPU microcode updates— amd-ucode or intel-ucode —for hardware bug and security fixes
- btrfs-progs: Btrfs filesystem management tools (Create subvolumes, snapshot, e.g.).
- grub: GRUB boot loader for booting the system.
- efibootmgr: Tool for managing UEFI boot entries
- os-prober: Detects other operating systems and adds them to the GRUB menu.
- networkmanager: Network management tool that supports Wi-Fi, Ethernet, etc.
- dhcpcd: DHCP client for automatic IP address acquisition.

# Configure System

First, generate an [fstab](https://wiki.archlinux.org/title/Fstab) file.

## fstab

The `fstab(5)` file can be used to define how disk partitions, various other block devices, or remote file systems should be mounted into the file system.

## chroot

A [chroot](https://wiki.archlinux.org/title/Chroot) is an operation that changes the apparent root directory for the current running process and their children. A program that is run in such a modified environment cannot access files and commands outside that environmental directory tree. This modified environment is called a *chroot jail*.

Changing root is commonly done for performing system maintenance on systems where booting and/or logging in is no longer possible. Common examples are:

- Reinstalling the boot loader.
- Rebuilding the initramfs image.
- Upgrading or downgrading packages.
- Resetting a forgotten password.
- Building packages in a clean chroot.

See also Wikipedia:Chroot#Limitations.

----------

Localization and Network Configuration passed...

## Initramfs

An [initramfs](https://wiki.archlinux.org/title/Arch_boot_process#initramfs) (initial RAM file system) image is a [cpio](https://en.wikipedia.org/wiki/cpio) archive. Initramfs images can be generated with *mkinitcpio*, dracut or booster, and are Arch's preferred method for setting up the *early userspace*.

The purpose of the initramfs is to provide the necessary files for early userspace to successfully start the late userspace. It does not need to contain every kernel module one would ever want to use; it should only have modules required for the root device like NVMe, SATA, SAS, eMMC or USB (if booting from an external drive) and encryption.


### mkinitcpio

[mkinitcpio](https://wiki.archlinux.org/title/Mkinitcpio) is a Bash script used to create an [initial ramdisk](https://en.wikipedia.org/wiki/Initial_ramdisk) environment.

The initial ramdisk is in essence a very small environment (early userspace) which loads various kernel modules and sets up necessary things before handing over control to `init`. This makes it possible to have, for example, encrypted root file systems and root file systems on a software RAID array. mkinitcpio allows for easy extension with custom hooks, has autodetection at runtime, and many other features.

> Nowadays, the root file system may be on a wide range of hardware, from SCSI to SATA to USB drives, controlled by a variety of drive controllers from different manufacturers. Additionally, the root file system may be encrypted or compressed; within a software RAID array or a logical volume group. The simple way to handle that complexity is to pass management into userspace: an initial ramdisk. See also: [/dev/brain0 » Blog Archive » Early Userspace in Arch Linux.](https://web.archive.org/web/20150430223035/http://archlinux.me/brain0/2010/02/13/early-userspace-in-arch-linux/)
## GRUB

[GRUB](https://wiki.archlinux.org/title/GRUB) (GRand Unified Bootloader) is a [boot loader](https://wiki.archlinux.org/title/Boot_loader). Execute command below to install grub boot loader to ESP (`/boot` directory):

```Bash
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=ARCH
```

We need to edit configuration file `/etc/default/grub`, then generate the configuration file `/boot/grub/grub.cfg` loaded by GRUB each boot.
