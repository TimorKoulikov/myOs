ASM=nasm
CC=gcc
CC16=/usr/bin/watcom/binl64/wcc
LD16=/usr/bin/watcom/binl64ccd/wlink

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
	dd if=$(BUILD_DIR)/stage1.bin of=$(TARGET) conv=notrunc
	mcopy -i $(TARGET) $(BUILD_DIR)/stage2.bin "::stage2.bin"
	mcopy -i $(TARGET) $(BUILD_DIR)/kernel.bin "::kernel.bin"

#
## Kernel
#
kernel:$(BUILD_DIR)/kernel.bin

$(BUILD_DIR)/kernel.bin: always 
	$(MAKE) -C $(SRC_DIR)/kernel BUILD_DIR=$(abspath $(BUILD_DIR))

#
##Bootloader
#
bootloader: stage1 stage2

stage1: $(BUILD_DIR)/stage1.bin 

$(BUILD_DIR)/stage1.bin: always
	$(MAKE) -C $(SRC_DIR)/bootloader/stage1 BUILD_DIR=$(abspath $(BUILD_DIR))

stage2: $(BUILD_DIR)/stage2.bin 

$(BUILD_DIR)/stage2.bin: always
	$(MAKE) -C $(SRC_DIR)/bootloader/stage2 BUILD_DIR=$(abspath $(BUILD_DIR))



###
always:
	mkdir -p $(BUILD_DIR)

debug:
	bochs -f bochs_config

run:
	qemu-system-i386 -fda $(TARGET)

clean:
	$(MAKE) -C $(SRC_DIR)/bootloader/stage1 BUILD_DIR=$(abspath $(BUILD_DIR)) clean
	$(MAKE) -C $(SRC_DIR)/bootloader/stage2 BUILD_DIR=$(abspath $(BUILD_DIR)) clean
	$(MAKE) -C $(SRC_DIR)/kernel BUILD_DIR=$(abspath $(BUILD_DIR)) clean
	rm -rf $(BUILD_DIR)/* 	