#include <CommonCrypto/CommonCrypto.h>
#include <CoreFoundation/CoreFoundation.h>
#include <mach-o/loader.h>
#include <mach/mach.h>
#import "offsets.h"
#include <stdio.h>
#include <sys/syscall.h>

#define VISSHADOW 0x008000
#ifdef __arm64e__
# define CPU_DATA_RTCLOCK_DATAP_OFF (0x190)
#else
# define CPU_DATA_RTCLOCK_DATAP_OFF (0x198)
#endif
#define VM_KERNEL_LINK_ADDRESS (0xFFFFFFF007004000ULL)
#define kCFCoreFoundationVersionNumber_iOS_13_0_b2 (1656)
#define kCFCoreFoundationVersionNumber_iOS_13_0_b1 (1652.20)

#define KADDR_FMT "0x%" PRIX64
#define VM_KERN_MEMORY_CPU (9)
#define RD(a) extract32(a, 0, 5)
#define RN(a) extract32(a, 5, 5)
#define IS_RET(a) ((a) == 0xD65F03C0U)
#define ADRP_ADDR(a) ((a) & ~0xFFFULL)
#define ADRP_IMM(a) (ADR_IMM(a) << 12U)
#define IO_OBJECT_NULL ((io_object_t)0)
#define ADD_X_IMM(a) extract32(a, 10, 12)
#define LDR_X_IMM(a) (sextract64(a, 5, 19) << 2U)
#define IS_ADR(a) (((a) & 0x9F000000U) == 0x10000000U)
#define IS_ADRP(a) (((a) & 0x9F000000U) == 0x90000000U)
#define IS_ADD_X(a) (((a) & 0xFFC00000U) == 0x91000000U)
#define IS_LDR_X(a) (((a) & 0xFF000000U) == 0x58000000U)
#define LDR_X_UNSIGNED_IMM(a) (extract32(a, 10, 12) << 3U)
#define IS_LDR_X_UNSIGNED_IMM(a) (((a) & 0xFFC00000U) == 0xF9400000U)
#define ADR_IMM(a) ((sextract64(a, 5, 19) << 2U) | extract32(a, 29, 2))

#ifndef SEG_TEXT_EXEC
# define SEG_TEXT_EXEC "__TEXT_EXEC"
#endif

#ifndef SECT_CSTRING
# define SECT_CSTRING "__cstring"
#endif

#ifndef MIN
# define MIN(a, b) ((a) < (b) ? (a) : (b))
#endif

typedef uint64_t kaddr_t;
typedef mach_port_t io_object_t;
typedef io_object_t io_service_t;
typedef io_object_t io_connect_t;
typedef io_object_t io_registry_entry_t;

typedef struct {
	struct section_64 s64;
	char *data;
} sec_64_t;

typedef struct {
	sec_64_t sec_text, sec_cstring;
} pfinder_t;

typedef struct {
	kaddr_t key, val;
} dict_entry_t;


kern_return_t
        mach_vm_write(vm_map_t, mach_vm_address_t, vm_offset_t, mach_msg_type_number_t);


kern_return_t
        mach_vm_read_overwrite(vm_map_t, mach_vm_address_t, mach_vm_size_t, mach_vm_address_t, mach_vm_size_t *);

kern_return_t
        mach_vm_machine_attribute(vm_map_t, mach_vm_address_t, mach_vm_size_t, vm_machine_attribute_t, vm_machine_attribute_val_t *);

kern_return_t
        mach_vm_region(vm_map_t, mach_vm_address_t *, mach_vm_size_t *, vm_region_flavor_t, vm_region_info_t, mach_msg_type_number_t *, mach_port_t *);

extern const mach_port_t kIOMasterPortDefault;

static kaddr_t allproc, our_task;
static kaddr_t proc;
static task_t tfp0 = MACH_PORT_NULL;

static uint32_t
extract32(uint32_t val, unsigned start, unsigned len) {
	return (val >> start) & (~0U >> (32U - len));
}

static uint64_t
sextract64(uint64_t val, unsigned start, unsigned len) {
	return (uint64_t)((int64_t)(val << (64U - len - start)) >> (64U - len));
}

static kern_return_t
init_tfp0(void) {
	kern_return_t ret = task_for_pid(mach_task_self(), 0, &tfp0);
	mach_port_t host;
	pid_t pid;

	if(ret != KERN_SUCCESS) {
		host = mach_host_self();
		if(MACH_PORT_VALID(host)) {
			printf("host: 0x%" PRIX32 "\n", host);
			ret = host_get_special_port(host, HOST_LOCAL_NODE, 4, &tfp0);
			printf("I think you're using unc0ver, But load it anyway.\n");
			return ret;     //TO USE UNC0VER, TEMPORARY
		}
		mach_port_deallocate(mach_task_self(), host);
	}
	if(ret == KERN_SUCCESS && MACH_PORT_VALID(tfp0)) {
		if(pid_for_task(tfp0, &pid) == KERN_SUCCESS && pid == 0) {
			return ret;
		}
		mach_port_deallocate(mach_task_self(), tfp0);
	}
	printf("Failed to init tfp0.\n");
	return KERN_FAILURE;
}

static kern_return_t
kread_buf(kaddr_t addr, void *buf, mach_vm_size_t sz) {
	mach_vm_address_t p = (mach_vm_address_t)buf;
	mach_vm_size_t read_sz, out_sz = 0;

	while(sz != 0) {
		read_sz = MIN(sz, vm_kernel_page_size - (addr & vm_kernel_page_mask));
		if(mach_vm_read_overwrite(tfp0, addr, read_sz, p, &out_sz) != KERN_SUCCESS || out_sz != read_sz) {
			return KERN_FAILURE;
		}
		p += read_sz;
		sz -= read_sz;
		addr += read_sz;
	}
	return KERN_SUCCESS;
}


static kern_return_t
kread_addr(kaddr_t addr, kaddr_t *val) {
	return kread_buf(addr, val, sizeof(*val));
}

static kern_return_t
kwrite_buf(kaddr_t addr, const void *buf, mach_msg_type_number_t sz) {
	vm_machine_attribute_val_t mattr_val = MATTR_VAL_CACHE_FLUSH;
	mach_vm_address_t p = (mach_vm_address_t)buf;
	mach_msg_type_number_t write_sz;

	while(sz != 0) {
		write_sz = (mach_msg_type_number_t)MIN(sz, vm_kernel_page_size - (addr & vm_kernel_page_mask));
		if(mach_vm_write(tfp0, addr, p, write_sz) != KERN_SUCCESS || mach_vm_machine_attribute(tfp0, addr, write_sz, MATTR_CACHE, &mattr_val) != KERN_SUCCESS) {
			return KERN_FAILURE;
		}
		p += write_sz;
		sz -= write_sz;
		addr += write_sz;
	}
	return KERN_SUCCESS;
}

static kaddr_t
get_kbase(kaddr_t *kslide) {
	mach_msg_type_number_t cnt = TASK_DYLD_INFO_COUNT;
	vm_region_extended_info_data_t extended_info;
	task_dyld_info_data_t dyld_info;
	kaddr_t addr, rtclock_datap;
	struct mach_header_64 mh64;
	mach_port_t obj_nm;
	mach_vm_size_t sz;

	if(task_info(tfp0, TASK_DYLD_INFO, (task_info_t)&dyld_info, &cnt) == KERN_SUCCESS && dyld_info.all_image_info_size != 0) {
		*kslide = dyld_info.all_image_info_size;
		return VM_KERNEL_LINK_ADDRESS + *kslide;
	}
	cnt = VM_REGION_EXTENDED_INFO_COUNT;
	for(addr = 0; mach_vm_region(tfp0, &addr, &sz, VM_REGION_EXTENDED_INFO, (vm_region_info_t)&extended_info, &cnt, &obj_nm) == KERN_SUCCESS; addr += sz) {
		mach_port_deallocate(mach_task_self(), obj_nm);
		if(extended_info.user_tag == VM_KERN_MEMORY_CPU && extended_info.protection == VM_PROT_DEFAULT) {
			if(kread_addr(addr + CPU_DATA_RTCLOCK_DATAP_OFF, &rtclock_datap) != KERN_SUCCESS) {
				break;
			}
			printf("rtclock_datap: " KADDR_FMT "\n", rtclock_datap);
			rtclock_datap = trunc_page_kernel(rtclock_datap);
			do {
				if(rtclock_datap <= VM_KERNEL_LINK_ADDRESS) {
					return 0;
				}
				rtclock_datap -= vm_kernel_page_size;
				if(kread_buf(rtclock_datap, &mh64, sizeof(mh64)) != KERN_SUCCESS) {
					return 0;
				}
			} while(mh64.magic != MH_MAGIC_64 || mh64.cputype != CPU_TYPE_ARM64 || mh64.filetype != MH_EXECUTE);
			*kslide = rtclock_datap - VM_KERNEL_LINK_ADDRESS;
			return rtclock_datap;
		}
	}
	return 0;
}

static kern_return_t
find_section(kaddr_t sg64_addr, struct segment_command_64 sg64, const char *sect_name, struct section_64 *sp) {
	kaddr_t s64_addr, s64_end;

	for(s64_addr = sg64_addr + sizeof(sg64), s64_end = s64_addr + (sg64.cmdsize - sizeof(*sp)); s64_addr < s64_end; s64_addr += sizeof(*sp)) {
		if(kread_buf(s64_addr, sp, sizeof(*sp)) != KERN_SUCCESS) {
			break;
		}
		if(strncmp(sp->segname, sg64.segname, sizeof(sp->segname)) == 0 && strncmp(sp->sectname, sect_name, sizeof(sp->sectname)) == 0) {
			return KERN_SUCCESS;
		}
	}
	return KERN_FAILURE;
}

static void
sec_reset(sec_64_t *sec) {
	memset(&sec->s64, '\0', sizeof(sec->s64));
	sec->data = NULL;
}

static void
sec_term(sec_64_t *sec) {
	free(sec->data);
	sec_reset(sec);
}

static kern_return_t
sec_init(sec_64_t *sec) {
	if((sec->data = malloc(sec->s64.size)) != NULL) {
		if(kread_buf(sec->s64.addr, sec->data, sec->s64.size) == KERN_SUCCESS) {
			return KERN_SUCCESS;
		}
		sec_term(sec);
	}
	return KERN_FAILURE;
}

static void
pfinder_reset(pfinder_t *pfinder) {
	sec_reset(&pfinder->sec_text);
	sec_reset(&pfinder->sec_cstring);
}

static void
pfinder_term(pfinder_t *pfinder) {
	sec_term(&pfinder->sec_text);
	sec_term(&pfinder->sec_cstring);
	pfinder_reset(pfinder);
}

static kern_return_t
pfinder_init(pfinder_t *pfinder, kaddr_t kbase) {
	kern_return_t ret = KERN_FAILURE;
	struct segment_command_64 sg64;
	kaddr_t sg64_addr, sg64_end;
	struct mach_header_64 mh64;
	struct section_64 s64;

	pfinder_reset(pfinder);
	if(kread_buf(kbase, &mh64, sizeof(mh64)) == KERN_SUCCESS && mh64.magic == MH_MAGIC_64 && mh64.cputype == CPU_TYPE_ARM64 && mh64.filetype == MH_EXECUTE) {
		for(sg64_addr = kbase + sizeof(mh64), sg64_end = sg64_addr + (mh64.sizeofcmds - sizeof(sg64)); sg64_addr < sg64_end; sg64_addr += sg64.cmdsize) {
			if(kread_buf(sg64_addr, &sg64, sizeof(sg64)) != KERN_SUCCESS) {
				break;
			}
			if(sg64.cmd == LC_SEGMENT_64) {
				if(strncmp(sg64.segname, SEG_TEXT_EXEC, sizeof(sg64.segname)) == 0 && find_section(sg64_addr, sg64, SECT_TEXT, &s64) == KERN_SUCCESS) {
					pfinder->sec_text.s64 = s64;
					printf("sec_text_addr: " KADDR_FMT ", sec_text_sz: 0x%" PRIX64 "\n", s64.addr, s64.size);
				} else if(strncmp(sg64.segname, SEG_TEXT, sizeof(sg64.segname)) == 0 && find_section(sg64_addr, sg64, SECT_CSTRING, &s64) == KERN_SUCCESS) {
					pfinder->sec_cstring.s64 = s64;
					printf("sec_cstring_addr: " KADDR_FMT ", sec_cstring_sz: 0x%" PRIX64 "\n", s64.addr, s64.size);
				}
			}
			if(pfinder->sec_text.s64.size != 0 && pfinder->sec_cstring.s64.size != 0) {
				if(sec_init(&pfinder->sec_text) == KERN_SUCCESS) {
					ret = sec_init(&pfinder->sec_cstring);
				}
				break;
			}
		}
	}
	if(ret != KERN_SUCCESS) {
		pfinder_term(pfinder);
	}
	return ret;
}

static kaddr_t
pfinder_xref_rd(pfinder_t pfinder, uint32_t rd, kaddr_t start, kaddr_t to) {
	uint64_t x[32] = { 0 };
	uint32_t insn;

	for(; start >= pfinder.sec_text.s64.addr && start < pfinder.sec_text.s64.addr + (pfinder.sec_text.s64.size - sizeof(insn)); start += sizeof(insn)) {
		memcpy(&insn, pfinder.sec_text.data + (start - pfinder.sec_text.s64.addr), sizeof(insn));
		if(IS_LDR_X(insn)) {
			x[RD(insn)] = start + LDR_X_IMM(insn);
		} else if(IS_ADR(insn)) {
			x[RD(insn)] = start + ADR_IMM(insn);
		} else if(IS_ADRP(insn)) {
			x[RD(insn)] = ADRP_ADDR(start) + ADRP_IMM(insn);
			continue;
		} else if(IS_ADD_X(insn)) {
			x[RD(insn)] = x[RN(insn)] + ADD_X_IMM(insn);
		} else if(IS_LDR_X_UNSIGNED_IMM(insn)) {
			x[RD(insn)] = x[RN(insn)] + LDR_X_UNSIGNED_IMM(insn);
		} else if(IS_RET(insn)) {
			memset(x, '\0', sizeof(x));
		}
		if(RD(insn) == rd) {
			if(to == 0) {
				return x[rd];
			}
			if(x[rd] == to) {
				return start;
			}
		}
	}
	return 0;
}

static kaddr_t
pfinder_xref_str(pfinder_t pfinder, const char *str, uint32_t rd) {
	const char *p, *e;
	size_t len;

	for(p = pfinder.sec_cstring.data, e = p + pfinder.sec_cstring.s64.size; p < e; p += len) {
		len = strlen(p) + 1;
		if(strncmp(str, p, len) == 0) {
			return pfinder_xref_rd(pfinder, rd, pfinder.sec_text.s64.addr, pfinder.sec_cstring.s64.addr + (kaddr_t)(p - pfinder.sec_cstring.data));
		}
	}
	return 0;
}

static kaddr_t
pfinder_allproc(pfinder_t pfinder) {
	kaddr_t ref = pfinder_xref_str(pfinder, "shutdownwait", 2);

	if(ref == 0) {
		ref = pfinder_xref_str(pfinder, "shutdownwait", 3);                                                                                                                 /* msleep */
	}
	return pfinder_xref_rd(pfinder, 8, ref, 0);
}

static kern_return_t
pfinder_init_offsets(pfinder_t pfinder) {
	if((allproc = pfinder_allproc(pfinder)) != 0) {
		printf("allproc: " KADDR_FMT "\n", allproc);
		return KERN_SUCCESS;
	}
	return KERN_FAILURE;
}

static kern_return_t
find_task(pid_t pid, kaddr_t *task) {
	proc = allproc;
	pid_t cur_pid;

	while(kread_addr(proc, &proc) == KERN_SUCCESS && proc != 0) {
		if(kread_buf(proc + koffset(KSTRUCT_OFFSET_PROC_PID), &cur_pid, sizeof(cur_pid)) == KERN_SUCCESS && cur_pid == pid) {
			printf("proc: " KADDR_FMT "\n", proc);
			return kread_addr(proc + koffset(KSTRUCT_OFFSET_PROC_TASK), task);
		}
	}
	return KERN_FAILURE;
}



////////aksuio code
static const uint32_t off_vnode_vflags = 0x54;
static const uint32_t off_vnode_iocount = 0x64;
static const uint32_t off_vnode_usecount = 0x60;

uint32_t rk32(uint64_t where) {
	uint32_t out;
	kread_buf(where, &out, sizeof(uint32_t));
	return out;
}

uint64_t rk64(uint64_t where) {
	uint64_t out;
	kread_buf(where, &out, sizeof(uint64_t));
	return out;
}

void wk32(uint64_t where, uint32_t what) {
	uint32_t _what = what;
	kwrite_buf(where, &_what, sizeof(uint32_t));
}


void wk64(uint64_t where, uint64_t what) {
	uint64_t _what = what;
	kwrite_buf(where, &_what, sizeof(uint64_t));
}

uint32_t savedVnodeOrig;

uint64_t get_vnode_with_file_index(int file_index){
//https://github.com/jakeajames/time_waste/blob/master/time_waste/offsets.m

	uint64_t filedesc = rk64(proc + koffset(KSTRUCT_OFFSET_PROC_P_FD));
	uint64_t fileproc = rk64(filedesc + koffset(KSTRUCT_OFFSET_FILEDESC_FD_OFILES));
	uint64_t openedfile = rk64(fileproc  + (sizeof(void*) * file_index));
	uint64_t fileglob = rk64(openedfile + koffset(KSTRUCT_OFFSET_FILEPROC_F_FGLOB));
	uint64_t vnode = rk64(fileglob + koffset(KSTRUCT_OFFSET_FILEGLOB_FG_DATA));

	uint32_t usecount = rk32(vnode + off_vnode_usecount);
	uint32_t iocount = rk32(vnode + off_vnode_iocount);

	//?
	wk32(vnode + off_vnode_usecount, usecount + 1);
	wk32(vnode + off_vnode_iocount, iocount + 1);

	return vnode;
}

uint64_t recovery_vnode_with_file_index(int file_index) {
	uint64_t filedesc = rk64(proc + koffset(KSTRUCT_OFFSET_PROC_P_FD));
	uint64_t fileproc = rk64(filedesc + koffset(KSTRUCT_OFFSET_FILEDESC_FD_OFILES));
	uint64_t openedfile = rk64(fileproc  + (sizeof(void*) * file_index));
	uint64_t fileglob = rk64(openedfile + koffset(KSTRUCT_OFFSET_FILEPROC_F_FGLOB));
	uint64_t vnode = rk64(fileglob + koffset(KSTRUCT_OFFSET_FILEGLOB_FG_DATA));


	wk32(vnode + off_vnode_usecount, 0x1);
	wk32(vnode + off_vnode_iocount, 0x0);

	return vnode;
}

void hide_path(uint64_t vnode){
	uint32_t v_flags = rk32(vnode + off_vnode_vflags);
	wk32(vnode + off_vnode_vflags, (v_flags | VISSHADOW));
}

void show_path(uint64_t vnode){
	if(vnode == 0) {
		printf("vnode is 0x0. Maybe No file? Skip show_path.\n");
		return;
	}

	uint32_t v_flags = rk32(vnode + off_vnode_vflags);
	wk32(vnode + off_vnode_vflags, (v_flags &= ~VISSHADOW));
}


///////////

int
main(int argc, char **argv) {

	if(argc == 2 && (strcmp(argv[1], "-s") == 0 || strcmp(argv[1], "--save") == 0 || strcmp(argv[1], "--hide") == 0 || strcmp(argv[1], "-h") == 0 || strcmp(argv[1], "-r") == 0 || strcmp(argv[1], "--revert") == 0 || strcmp(argv[1], "-R") == 0 || strcmp(argv[1], "--recovery") == 0)) {

		setuid(0);
		setgid(0);
		kaddr_t kbase, kslide;
		pfinder_t pfinder;

		if(init_tfp0() == KERN_SUCCESS) {
			printf("tfp0: 0x%" PRIX32 "\n", tfp0);
			int checkDevice = init_offsets();
			if (checkDevice) {
				printf("[-] iOS version not supported. but anyway working on it.\n");
			}
			if((kbase = get_kbase(&kslide)) != 0) {
				printf("kbase: " KADDR_FMT ", kslide: " KADDR_FMT "\n", kbase, kslide);
				if(pfinder_init(&pfinder, kbase) == KERN_SUCCESS) {
					if(pfinder_init_offsets(pfinder) == KERN_SUCCESS) {
						if(find_task(getpid(), &our_task) == KERN_SUCCESS) {
							printf("It works!\n");
							printf("allproc to patch: " KADDR_FMT "\n", allproc);
							printf("proc to patch: " KADDR_FMT "\n", proc);
							printf("===== Welcome to vnodeBypass =====\n");

							NSArray<NSString*>* hidePathList = @[
								@"/bin/ls",
								@"/Applications/SafeMode.app",
								@"/.bootstrapped_electra",
								@"/bin/sed",
								@"/usr/lib/libsubstitute.0.dylib",
								@"/bin/kill",
								@"/bin/gzip",
								@"/usr/bin/which",
								@"/usr/bin/diff",
								@"/jb",
								@"/usr/lib/libjailbreak.dylib",
								@"/bin/mkdir",
								@"/Library/Frameworks/CydiaSubstrate.framework",
								@"/bin/cp",
								@"/bin/chgrp",
								@"/usr/lib/SBInject",
								@"/bin/cat",
								@"/bin/tar",
								@"/bin/chmod",
								@"/usr/share/terminfo",
								@"/bin/grep",
								@"/usr/lib/SBInject.dylib",
								@"/electra",
								@"/bin/chown",
								@"/usr/bin/tar",
								@"/usr/bin/killall",
								@"/Applications/Anemone.app",
								@"/bin/ln",
								@"/usr/bin/xargs",
								@"/bin/su",
								@"/usr/bin/recache",
								@"/etc/profile",
								@"/usr/lib/libsubstrate.dylib",
								@"/bin/bunzip2",
								@"/usr/bin/passwd",
								@"/usr/lib/libsubstitute.dylib",
								@"/etc/apt",
								@"/usr/bin/hostinfo",
								@"/bootstrap",
								@"/Library/Themes",
								@"/bin/bzip2",
								@"/usr/libexec/sftp-server",
								@"/Applications/Cydia.app",
								@"/bin/bash",
								@"/bin/sh",
								@"/bin/mv",
							];
							NSUInteger arrayLength = [hidePathList count];
							int arrayLength_int = (int)arrayLength;

							if(strcmp(argv[1], "-s") == 0 || strcmp(argv[1], "--save") == 0) {
								printf("Saving vnode now!\n");

								FILE *fp = fopen("/var/mobile/Library/Preferences/vnodeMem.txt", "w");
								printf("hidePathList = %d\n", arrayLength_int);
								uint64_t vnodeArray[arrayLength_int];
								int i;
								for(i = 0; i < arrayLength_int; i++) {
									NSString *path = [hidePathList objectAtIndex:i];
									const char *path_cs = [path cStringUsingEncoding:NSUTF8StringEncoding];
									int file_index = open([path UTF8String], O_RDONLY);
									if(file_index == -1) {
										printf("vnode[%d] => No such file or directory, path = %s\n", i, path_cs);
										vnodeArray[i] = 0x0;
									}
									else {
										vnodeArray[i] = get_vnode_with_file_index(file_index);
										printf("vnode[%d] => 0x%" PRIX64 ", path = %s\n", i, vnodeArray[i], path_cs);
										fprintf(fp, "0x%" PRIX64 "\n", vnodeArray[i]);
									}
									close(file_index);

								}
								fclose(fp);
							}

							if((strcmp(argv[1], "-h") == 0 || strcmp(argv[1], "--hide") == 0 || strcmp(argv[1], "-r") == 0 || strcmp(argv[1], "--revert") == 0)) {
								if(access("/var/mobile/Library/Preferences/vnodeMem.txt", F_OK) == -1 ) {
									printf("[-] vnodeMem.txt doesn't exist.\n");
									return -1;
								}
								FILE *fp = fopen("/var/mobile/Library/Preferences/vnodeMem.txt", "r");
								uint64_t savedVnode;
								int i = 0;
								while(!feof(fp))
								{
									if ( fscanf(fp, "0x%" PRIX64 "\n", &savedVnode) == 1)
									{
										printf("Saved vnode[%d] = 0x%" PRIX64 "\n", i, savedVnode);
										if(strcmp(argv[1], "-h") == 0 || strcmp(argv[1], "--hide") == 0) {
											hide_path(savedVnode);
										}
										else if(strcmp(argv[1], "-r") == 0 || strcmp(argv[1], "--revert") == 0) {
											show_path(savedVnode);
										}
										i++;
									}
								}
								fclose(fp);
								for(i = 0; i < arrayLength_int; i++) {
									NSString *path = [hidePathList objectAtIndex:i];
									const char *path_cs = [path cStringUsingEncoding:NSUTF8StringEncoding];

									int detectFlag = syscall(SYS_access, path_cs, F_OK);

									if(detectFlag == 0) {
										printf("[Syscall Access] DETECTED %s path\n", path_cs);
									}
									else if(detectFlag == -1) {
										printf("[Syscall Access] NOT DETECTED %s path\n", path_cs);
									}
								}
							}

							if(strcmp(argv[1], "-R") == 0 || strcmp(argv[1], "--recovery") == 0) {
								if(access("/var/mobile/Library/Preferences/vnodeMem.txt", F_OK) == -1 ) {
									printf("[-] vnodeMem.txt doesn't exist.\n");
									return -1;
								}

								printf("Recovering vnode now!\n");

								printf("hidePathList = %d\n", arrayLength_int);
								uint64_t vnodeArray[arrayLength_int];
								int i;
								for(i = 0; i < arrayLength_int; i++) {
									NSString *path = [hidePathList objectAtIndex:i];
									const char *path_cs = [path cStringUsingEncoding:NSUTF8StringEncoding];
									int file_index = open([path UTF8String], O_RDONLY);
									if(file_index == -1) {
										printf("vnode[%d] => No such file or directory, path = %s\n", i, path_cs);
										vnodeArray[i] = 0x0;
									}
									else {
										vnodeArray[i] = recovery_vnode_with_file_index(file_index);
										printf("vnode[%d] => 0x%" PRIX64 ", path = %s\n", i, vnodeArray[i], path_cs);
									}
									close(file_index);

								}

								int chkRemove = remove("/var/mobile/Library/Preferences/vnodeMem.txt");
								if(chkRemove == 0) {
									printf("Removed /var/mobile/Library/Preferences/vnodeMem.txt\n");
								}
								else if(chkRemove == -1) {
									printf("Failed to remove /var/mobile/Library/Preferences/vnodeMem.txt\n");
								}
							}

						}
					}
					pfinder_term(&pfinder);
				}
			}
			mach_port_deallocate(mach_task_self(), tfp0);
		}
	}
	else {
		printf("Usage: vnodebypass [OPTION]...\n");
		printf("Hide jailbreak files using VNODE that provides an internal representation of a file or directory or defines an interface to a file.\n\n");
		printf("Option:\n");
		printf("-s,  --save             Get vnode with file index and save path to /var/mobile/Library/Preferences/vnodeMem.txt\n");
		printf("-h,  --hide             Hide jailbreak files\n");
		printf("-r,  --revert           Revert jailbreak files\n");
		printf("-R,  --recovery         To prevent kernel panic, vnode_usecount and vnode_iocount will be back to 1, 0.\n");
	}
}
