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

//get vnode
uint64_t get_vnode_with_file_index(int, uint64_t);

//hide and show file using vnode
void hide_path(uint64_t);
void show_path(uint64_t);

int init_kernel();
