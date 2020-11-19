#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#include "vnode.h"
#include "kernel.h"
#include "SVC_Caller.h"
#include "libdimentio.h"

#define vnodeMemPath "/tmp/vnodeMem.txt"

NSArray* hidePathList = nil;

void initPath() {
	hidePathList = [NSArray arrayWithObjects:
	                @"/.bootstrapped_electra",
	                @"/Applications/Anemone.app",
	                @"/Applications/Cydia.app",
	                @"/Applications/SafeMode.app",
	                @"/bin/bash",
	                @"/bin/bunzip2",
	                @"/bin/bzip2",
	                @"/bin/cat",
	                @"/bin/chgrp",
	                @"/bin/chmod",
	                @"/bin/chown",
	                @"/bin/cp",
	                @"/bin/grep",
	                @"/bin/gzip",
	                @"/bin/kill",
	                @"/bin/ln",
	                @"/bin/ls",
	                @"/bin/mkdir",
	                @"/bin/mv",
	                @"/bin/sed",
	                @"/bin/sh",
	                @"/bin/su",
	                @"/bin/tar",
	                @"/binpack",
	                @"/bootstrap",
	                @"/chimera",
	                @"/electra",
	                @"/etc/apt",
	                @"/etc/profile",
	                @"/jb",
	                @"/Library/dpkg/info/com.inoahdev.launchinsafemode.list",
	                @"/Library/dpkg/info/com.inoahdev.launchinsafemode.md5sums",
	                @"/Library/Frameworks/CydiaSubstrate.framework",
	                @"/Library/MobileSubstrate/DynamicLibraries/FlyJB.dylb",
	                @"/Library/MobileSubstrate/MobileSubstrate.dylib",
	                @"/Library/PreferenceBundles/LaunchInSafeMode.bundle",
	                @"/Library/PreferenceLoader/Preferences/LaunchInSafeMode.plist",
	                @"/Library/Themes",
	                @"/private/var/binpack",
	                @"/private/var/checkra1n.dmg",
	                @"/private/var/lib/apt",
	                @"/usr/bin/diff",
	                @"/usr/bin/hostinfo",
	                @"/usr/bin/killall",
	                @"/usr/bin/passwd",
	                @"/usr/bin/recache",
	                @"/usr/bin/tar",
	                @"/usr/bin/which",
	                @"/usr/bin/xargs",
	                @"/usr/lib/libjailbreak.dylib",
	                @"/usr/lib/libsubstitute.0.dylib",
	                @"/usr/lib/libsubstitute.dylib",
	                @"/usr/lib/libsubstrate.dylib",
	                @"/usr/lib/SBInject",
	                @"/usr/lib/SBInject.dylib",
	                @"/usr/lib/TweakInject",
	                @"/usr/lib/TweakInject.dylib",
	                @"/usr/lib/TweakInjectMapsCheck.dylib",
	                @"/usr/libexec/sftp-server",
	                @"/usr/sbin/sshd",
	                @"/usr/share/terminfo",
	                @"/var/mobile/Library/.sbinjectSafeMode",
	                @"/var/mobile/Library/Preferences/jp.akusio.kernbypass.plist",
	                nil
	               ];
}

void saveVnode(){
	if(access(vnodeMemPath, F_OK) == 0) {
		printf("Already exist /tmp/vnodeMem.txt, Please vnode recovery first!\n");
		return;
	}

	init_kernel();
	find_task(getpid(), &our_task);
	printf("this_proc: " KADDR_FMT "\n", this_proc);

	FILE *fp = fopen(vnodeMemPath, "w");

	initPath();
	int hideCount = (int)[hidePathList count];
	uint64_t vnodeArray[hideCount];

	for(int i = 0; i < hideCount; i++) {
		const char* hidePath = [[hidePathList objectAtIndex:i] UTF8String];
		int file_index = open(hidePath, O_RDONLY);

		if(file_index == -1)
			continue;

		vnodeArray[i] = get_vnode_with_file_index(file_index, this_proc);
		printf("hidePath: %s, vnode[%d]: 0x%" PRIX64 "\n", hidePath, i, vnodeArray[i]);
		printf("vnode_usecount: 0x%" PRIX32 ", vnode_iocount: 0x%" PRIX32 "\n", kernel_read32(vnodeArray[i] + off_vnode_usecount), kernel_read32(vnodeArray[i] + off_vnode_iocount));
		fprintf(fp, "0x%" PRIX64 "\n", vnodeArray[i]);
		close(file_index);
	}
	fclose(fp);
	mach_port_deallocate(mach_task_self(), tfp0);
	printf("Saved vnode to /tmp/vnodeMem.txt\nMake sure vnode recovery to prevent kernel panic!\n");
}

void hideVnode(){
	init_kernel();
	if(access(vnodeMemPath, F_OK) == 0) {
		FILE *fp = fopen(vnodeMemPath, "r");
		uint64_t savedVnode;
		int i = 0;
		while(!feof(fp))
		{
			if ( fscanf(fp, "0x%" PRIX64 "\n", &savedVnode) == 1)
			{
				printf("Saved vnode[%d] = 0x%" PRIX64 "\n", i, savedVnode);
				hide_path(savedVnode);
			}
			i++;
		}
	}
	mach_port_deallocate(mach_task_self(), tfp0);
	printf("Hide file!\n");
}

void revertVnode(){
	init_kernel();
	if(access(vnodeMemPath, F_OK) == 0) {
		FILE *fp = fopen(vnodeMemPath, "r");
		uint64_t savedVnode;
		int i = 0;
		while(!feof(fp))
		{
			if ( fscanf(fp, "0x%" PRIX64 "\n", &savedVnode) == 1)
			{
				printf("Saved vnode[%d] = 0x%" PRIX64 "\n", i, savedVnode);
				show_path(savedVnode);
			}
			i++;
		}
	}
	mach_port_deallocate(mach_task_self(), tfp0);
	printf("Show file!\n");
}

void recoveryVnode(){
	init_kernel();
	if(access(vnodeMemPath, F_OK) == 0) {
		FILE *fp = fopen(vnodeMemPath, "r");
		uint64_t savedVnode;
		int i = 0;
		while(!feof(fp))
		{
			if ( fscanf(fp, "0x%" PRIX64 "\n", &savedVnode) == 1)
			{
				kernel_write32(savedVnode + off_vnode_iocount, kernel_read32(savedVnode + off_vnode_iocount) - 1);
				kernel_write32(savedVnode + off_vnode_usecount, kernel_read32(savedVnode + off_vnode_usecount) - 1);
				printf("Saved vnode[%d] = 0x%" PRIX64 "\n", i, savedVnode);
				printf("vnode_usecount: 0x%" PRIX32 ", vnode_iocount: 0x%" PRIX32 "\n", kernel_read32(savedVnode + off_vnode_usecount), kernel_read32(savedVnode + off_vnode_iocount));
			}
			i++;
		}
		remove(vnodeMemPath);
	}
	mach_port_deallocate(mach_task_self(), tfp0);
	printf("Recovered vnode! No more kernel panic when you shutdown.\n");
}

void checkFile(){
	initPath();
	int hideCount = (int)[hidePathList count];
	for(int i = 0; i < hideCount; i++) {
		const char* hidePath = [[hidePathList objectAtIndex:i] UTF8String];
		int ret = 0;
		ret = SVC_Access(hidePath);
		printf("hidePath: %s, errno: %d\n", hidePath, ret);
	}
	printf("Done check file!\n");
}
