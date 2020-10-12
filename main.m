#include <stdio.h>
#import <Foundation/Foundation.h>
#include <sys/syscall.h>
#include "vnode.h"

void showUsage() {
	printf("Usage: vnodebypass [OPTION]...\n");
	printf("Hide jailbreak files using VNODE that provides an internal representation of a file or directory or defines an interface to a file.\n\n");
	printf("Option:\n");
	printf("-s,  --save             Get vnode with file index and save path to /tmp/vnodeMem.txt\n");
	printf("-h,  --hide             Hide jailbreak files\n");
	printf("-r,  --revert           Revert jailbreak files\n");
	printf("-R,  --recovery         To prevent kernel panic, vnode_usecount and vnode_iocount will be substracted 1 and remove /tmp/vnodeMem.txt\n");
	printf("-c,  --check            Check if jailbreak file exists using SVC #0x80 SYS_access.\n");
}

int main(int argc, char *argv[], char *envp[]) {
	setuid(0);
	setgid(0);

	if(getuid() != 0 && getgid() != 0) {
		printf("Require vnodebypass to be run as root!\n");
		return -1;
	}

	if (argc != 2) {
		showUsage();
		return -1;
	}

	if((strcmp(argv[1], "-s") == 0 || strcmp(argv[1], "--save") == 0))
		saveVnode();
	else if((strcmp(argv[1], "-h") == 0 || strcmp(argv[1], "--hide") == 0))
		hideVnode();
	else if((strcmp(argv[1], "-r") == 0 || strcmp(argv[1], "--revert") == 0))
		revertVnode();
	else if((strcmp(argv[1], "-R") == 0 || strcmp(argv[1], "--recovery") == 0))
		recoveryVnode();
	else if((strcmp(argv[1], "-c") == 0 || strcmp(argv[1], "--check") == 0))
		checkFile();
	else
		showUsage();

	return 0;
}
