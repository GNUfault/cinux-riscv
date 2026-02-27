cmake_minimum_required(VERSION 3.10)
project(CINUX LANGUAGES C ASM)

# architecture
set(CMAKE_SYSTEM_NAME Generic)
set(CMAKE_SYSTEM_PROCESSOR riscv64)

# c compiler
set(CMAKE_C_COMPILER clang)
set(CMAKE_ASM_COMPILER clang)
set(CMAKE_OBJCOPY llvm-objcopy)

# clang flags
set(COMMON_FLAGS "--target=riscv64-unknown-elf -march=rv64gc -mabi=lp64d -mcmodel=medany -mno-red-zone")
set(CMAKE_C_FLAGS "${COMMON_FLAGS} -O3 -ffreestanding -nostdlib -Wall -Wextra")
set(CMAKE_ASM_FLAGS "${COMMON_FLAGS}")

# includes
include_directories(
    ${CMAKE_CURRENT_SOURCE_DIR}/kernel/include
)

# 3. executable setup
add_executable(kernel.elf 
    kernel/src/entry.s 
    kernel/src/main.c
    kernel/src/uart.s
)

# linker options
target_link_options(kernel.elf PRIVATE 
    "-fuse-ld=lld"
    "-T${CMAKE_CURRENT_SOURCE_DIR}/kernel/linker.ld"
    "-nostdlib"
    "-static"
)

# post build
add_custom_command(TARGET kernel.elf POST_BUILD
    COMMAND llvm-objcopy -O binary kernel.elf kernel.bin
    COMMENT "Generating raw binary for U-Boot..."
)