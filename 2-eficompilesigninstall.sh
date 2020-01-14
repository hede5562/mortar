#!/usr/bin/env bash
# We should sign and use our new EFI file before we require signatures. Better to be safe right?
source /etc/mortar/mortar.env

if [ "$1" == "--interactive" ]; then
	read -p "Enter full path to the kernel file (likely in /boot): " KERNELFILE
	read -p "Enter full path to the initramfs/initrd img file (likely in /boot): " INITRAMFSFILE
	read -p "Do you want to attempt automatic addition of the new efi file to the UEFI boot menu? (y/N): " installprompt
	case "$installprompt" in
	    [yY]*) INSTALLENTRY=true ;;
	    *) INSTALLENTRY=false ;;
	esac
else
	KERNELFILE="$1"
	INITRAMFSFILE="$2"
	if [ "$3" == "--install-entry" ]; then INSTALLENTRY=true; fi
fi

if [ -z $KERNELFILE ]; then KERNELFILE='/boot/vmlinuz-linux'; fi
if [ -z $INITRAMFSFILE ]; then INITRAMFSFILE='/boot/initramfs-linux.img'; fi

testexist() {
	if ! [ -f "$2" ]; then echo "Usage: $0 kernelpath initramfspath"; echo "Could not locate $1 at $2"; exit 1; fi
}

testexist CMDLINEFILE "$CMDLINEFILE"
testexist KERNELFILE "$KERNELFILE"
testexist INITRAMFSFILE "$INITRAMFSFILE"
testexist EFISTUBFILE "$EFISTUBFILE"
testexist os-release /etc/os-release
UNSIGNEDEFIPATH="$TARGET_EFI.unsigned"
SIGNEDEFIPATH="$TARGET_EFI"

objcopy \
    --add-section .osrel=/etc/os-release --change-section-vma .osrel=0x20000 \
    --add-section .cmdline="$CMDLINEFILE" --change-section-vma .cmdline=0x30000 \
    --add-section .linux="$KERNELFILE" --change-section-vma .linux=0x40000 \
    --add-section .initrd="$INITRAMFSFILE" --change-section-vma .initrd=0x3000000 \
    "$EFISTUBFILE" "$UNSIGNEDEFIPATH"

if [ -f "$UNSIGNEDEFIPATH" ]; then echo "Created $UNSIGNEDEFIPATH"; else echo "Failed to create joined efi file at $UNSIGNEDEFIPATH"; exit 1; fi
echo "Signing..."

# Sign the new file. 
sbsign --key "$SECUREBOOT_DB_KEY" --cert "$SECUREBOOT_DB_CRT" --output "$SIGNEDEFIPATH" "$UNSIGNEDEFIPATH"

if [ -f "$SIGNEDEFIPATH" ]; then echo "Created signed $SIGNEDEFIPATH"; else echo "Failed to create signed efi file at $SIGNEDEFIPATH"; exit 1; fi
#echo "Removing unsigned efi file..."
#if (rm "$UNSIGNEDEFIPATH"); then echo "Removed unsigned file."; else echo "Failed to remove unsigned file."; fi

if [ "$INSTALLENTRY" == "true" ]; then
	EFI_DISK=$(mount | grep "$EFI_ROOT" | cut -f1 -d' ')
	mutilatedpath=$(printf "%s" '\'"$EFI_DIR" "$EFI_NAME" | sed 's/\//\\/g')
	echo "Attempting to install new efi file into UEFI boot menu..."
	if (efibootmgr -c -d "$EFI_DISK" -l "$mutilatedpath" -L "$PRETTY_NAME"); then echo "Added boot entry."; else echo "Error adding boot entry."; fi
fi
