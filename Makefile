all: boot.bin
boot.bin: boot.asm kernal.asm
	nasm -f bin boot.asm -o boot.bin
	# nasm -f bin kernel.asm -o kernel.bin
	dd if=/dev/zero of=floppy.img bs=1024 count=1440 # create blank floppy image of 1.4 mb of 0's
	dd if=boot.bin of=floppy.img seek=0 count=100 conv=notrunc # copy over starting at first sector (seek = 0) and 2 sectors(count = 2)
	# dd if=kernel.bin of=floppy.img seek=1 count=1 conv=notrunc # copy over starting at first sector (seek = 0) and 2 sectors(count = 2)
run:
	qemu-system-x86_64 -drive file=floppy.img,format=raw,index=0,media=disk
clean:
	rm boot.bin
	rm floppy.img