#!/usr/bin/env bash
# We should sign and use our new EFI file before we require signatures. Better to be safe right?
source /etc/mortar/mortar.env

KERNELFILE="$1"
INITRAMFSFILE="$2"

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
UNSIGNEDEFIPATH="$EFI_DIR$EFI_NAME.unsigned"
SIGNEDEFIPATH="$EFI_DIR$EFI_NAME"

objcopy \
    --add-section .osrel=/etc/os-release --change-section-vma .osrel=0x20000 \
    --add-section .cmdline="$CMDLINEFILE" --change-section-vma .cmdline=0x30000 \
    --add-section .linux="$KERNELFILE" --change-section-vma .linux=0x40000 \
    --add-section .initrd="$INITRAMFSFILE" --change-section-vma .initrd=0x3000000 \
    "$EFISTUBFILE" "$UNSIGNEDEFIPATH"

if [ -f "$UNSIGNEDEFIPATH" ]; then echo "Created "$UNSIGNEDEFIPATH"; else echo "Failed to create joined efi file at "$UNSIGNEDEFIPATH"; exit 1; fi
echo "Signing..."

# Sign the new file. 
sbsign --key "$SECUREBOOT_DB_KEY" --cert "$SECUREBOOT_DB_CRT" --output "$SIGNEDEFIPATH" "$UNSIGNEDEFIPATH"

if [ -f "$SIGNEDEFIPATH" ]; then echo "Created signed "$SIGNEDEFIPATH"; else echo "Failed to create signed efi file at "$SIGNEDEFIPATH"; exit 1; fi
#echo "Removing unsigned efi file..."
#if (rm "$UNSIGNEDEFIPATH"); then echo "Removed unsigned file."; else echo "Failed to remove unsigned file."; fi
