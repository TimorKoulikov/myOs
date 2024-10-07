ASM=nasm

SRC_DIR=src
BUILD_DIR=build
TARGET=$(BUILD_DIR)/main_floppy.img

.PHONY: all floppy_image kernel bootloader clean always run debug
#
##Floppy image
#
floppy_image: $(TARGET)

$(TARGET): kernel bootloader
#creating empty file in size of 1.4MB
	dd if=/dev/zero of=$(TARGET) bs=512 count=2880	
	mkfs.fat  -F 12 -n "NBOS" $(TARGET)
	dd if=$(BUILD_DIR)/bootloader.bin of=$(TARGET) conv=notrunc
	mcopy -i $(BUILD_DIR)/main_floppy.img $(BUILD_DIR)/kernel.bin "::kernel.bin"

#
## Kernel
#
kernel:$(BUILD_DIR)/kernel.bin

$(BUILD_DIR)/kernel.bin: always 
	$(ASM) $(SRC_DIR)/kernel/main.asm -f bin -o $(BUILD_DIR)/kernel.bin 
#
##Bootloader
#
bootloader: $(BUILD_DIR)/bootloader.bin

$(BUILD_DIR)/bootloader.bin: always
	$(ASM) $(SRC_DIR)/bootloader/boot.asm -f bin -o $(BUILD_DIR)/bootloader.bin


###
always:
	mkdir -p $(BUILD_DIR)

debug:
	bochs -f bochs_config

run:
	qemu-system-i386 -fda $(TARGET)

clean:
	rm -rf $(BUILD_DIR)/* 