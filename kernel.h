#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#include <mach/mach.h>
#include <inttypes.h>
#include <mach-o/loader.h>
#include "libdimentio.h"

uint32_t off_p_pid;
uint32_t off_p_pfd;
uint32_t off_fd_ofiles;
uint32_t off_fp_fglob;
uint32_t off_fg_data;
uint32_t off_vnode_iocount;
uint32_t off_vnode_usecount;
uint32_t off_vnode_vflags;

int offset_init();

//read kernel
uint32_t kernel_read32(uint64_t);
uint64_t kernel_read64(uint64_t);

//write kernel
void kernel_write32(uint64_t, uint32_t);
void kernel_write64(uint64_t, uint64_t);

//get vnode
uint64_t get_vnode_with_file_index(int, uint64_t);

//hide and show file using vnode
void hide_path(uint64_t);
void show_path(uint64_t);

int init_kernel();
