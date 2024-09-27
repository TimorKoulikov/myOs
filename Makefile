ASM=nasm

SRC_DIR=src
BUILD_DIR=build

all: $(BUILD_DIR)\main.bin

run:
	qemu-system-i386 -drive format=raw,file=$(BUILD_DIR)\main.bin
#$(BUILD_DIR)/main_floppy.img: $(BUILD_DIR)/main.bin
#	cp $(BUILD_DIR)/main.bin $(BUILD_DIR)/main_floppy.img
#	truncate -s 1440k $(BUILD_DIR)/main_floppy.img

$(BUILD_DIR)\main.bin: $(SRC_DIR)\main.asm 
#	mkdir -p $(BUILD_DIR)
	$(ASM) $(SRC_DIR)\main.asm -f bin -o $(BUILD_DIR)\main.bin 

clean:
	del $(BUILD_DIR)\*