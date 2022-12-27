#include "kernel.h"

//set offset
#define kCFCoreFoundationVersionNumber_iOS_12_0    (1535.12)
#define kCFCoreFoundationVersionNumber_iOS_13_0_b2 (1656)
#define kCFCoreFoundationVersionNumber_iOS_13_0_b1 (1652.20)
#define kCFCoreFoundationVersionNumber_iOS_14_0_b1 (1740)

uint32_t off_p_pid = 0;
uint32_t off_p_pfd = 0;
uint32_t off_fd_ofiles = 0;
uint32_t off_fp_fglob = 0;
uint32_t off_fg_data = 0;
uint32_t off_vnode_iocount = 0;
uint32_t off_vnode_usecount = 0;
uint32_t off_vnode_vflags = 0;

int offset_init() {
	if(kCFCoreFoundationVersionNumber >= kCFCoreFoundationVersionNumber_iOS_14_0_b1) {
		// ios 14
		printf("iOS 14.x offset selected!!!\n");
		off_p_pid = 0x68;
		off_p_pfd = 0xf8;
		off_fd_ofiles = 0x0;
		off_fp_fglob = 0x10;
		off_fg_data = 0x38;
		off_vnode_iocount = 0x64;
		off_vnode_usecount = 0x60;
		off_vnode_vflags = 0x54;
		return 0;
	}

	if(kCFCoreFoundationVersionNumber >= kCFCoreFoundationVersionNumber_iOS_13_0_b2) {
		// ios 13
		printf("iOS 13.x offset selected!!!\n");
		off_p_pid = 0x68;
		off_p_pfd = 0x108;
		off_fd_ofiles = 0x0;
		off_fp_fglob = 0x10;
		off_fg_data = 0x38;
		off_vnode_iocount = 0x64;
		off_vnode_usecount = 0x60;
		off_vnode_vflags = 0x54;
		return 0;
	}

	if(kCFCoreFoundationVersionNumber <= kCFCoreFoundationVersionNumber_iOS_13_0_b1
	   && kCFCoreFoundationVersionNumber >= kCFCoreFoundationVersionNumber_iOS_12_0) {
		//ios 12
		printf("iOS 12.x offset selected!!!\n");
		off_p_pid = 0x60;
		off_p_pfd = 0x100;
		off_fd_ofiles = 0x0;
		off_fp_fglob = 0x8;
		off_fg_data = 0x38;
		off_vnode_iocount = 0x64;
		off_vnode_usecount = 0x60;
		off_vnode_vflags = 0x54;
		return 0;
	}

	return -1;
}

//get vnode
uint64_t get_vnode_with_file_index(int file_index, uint64_t proc) {
	uint64_t filedesc = kernel_read64(proc + off_p_pfd);
	uint64_t fileproc = kernel_read64(filedesc + off_fd_ofiles);
	uint64_t openedfile = kernel_read64(fileproc  + (sizeof(void*) * file_index));
	uint64_t fileglob = kernel_read64(openedfile + off_fp_fglob);
	uint64_t vnode = kernel_read64(fileglob + off_fg_data);

	uint32_t usecount = kernel_read32(vnode + off_vnode_usecount);
	uint32_t iocount = kernel_read32(vnode + off_vnode_iocount);

	kernel_write32(vnode + off_vnode_usecount, usecount + 1);
	kernel_write32(vnode + off_vnode_iocount, iocount + 1);

	return vnode;
}

//hide and show file using vnode
#define VISSHADOW 0x008000
void hide_path(uint64_t vnode){
	uint32_t v_flags = kernel_read32(vnode + off_vnode_vflags);
	kernel_write32(vnode + off_vnode_vflags, (v_flags | VISSHADOW));
}

void show_path(uint64_t vnode){
	uint32_t v_flags = kernel_read32(vnode + off_vnode_vflags);
	kernel_write32(vnode + off_vnode_vflags, (v_flags &= ~VISSHADOW));
}

int init_kernel() {

  printf("======= init_kernel =======\n");

  if(dimentio_init(0, NULL, NULL) != KERN_SUCCESS) {
    printf("failed dimentio_init!\n");
		return 1;
  }

//	if(init_tfp0() != KERN_SUCCESS) {
//		printf("failed get_tfp0!\n");
//		return 1;
//	}
//
	if(kbase == 0) {
		printf("failed get_kbase\n");
		return 1;
	}

	kern_return_t err = offset_init();
	if (err) {
		printf("offset init failed: %d\n", err);
		return 1;
	}

	return 0;
}
