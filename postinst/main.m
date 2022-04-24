#import <NSTask.h>
#include <stdio.h>

int main(int argc, char *argv[], char *envp[]) {
  @autoreleasepool {
    NSString *randomName = [[NSUUID UUID].UUIDString componentsSeparatedByString:@"-"].firstObject;
    printf("%s\n", randomName.UTF8String);

    NSMutableDictionary *appInfo = [NSMutableDictionary
        dictionaryWithContentsOfFile:@"/Applications/vnodebypass.app/Info.plist"];
    appInfo[@"CFBundleExecutable"] = randomName;
    [appInfo writeToFile:@"/Applications/vnodebypass.app/Info.plist" atomically:YES];

    if (rename("/usr/bin/vnodebypass",
               [NSString stringWithFormat:@"/usr/bin/%@", randomName].UTF8String) != 0) {
      printf("Failed to rename /usr/bin/vnodebypass");
      return 1;
    }
    if (rename("/Applications/vnodebypass.app/vnodebypass",
               [NSString stringWithFormat:@"/Applications/vnodebypass.app/%@", randomName]
                   .UTF8String) != 0) {
      printf("Failed to rename /Applications/vnodebypass.app");
      return 1;
    }
    if (rename("/Applications/vnodebypass.app",
               [NSString stringWithFormat:@"/Applications/%@.app", randomName].UTF8String) != 0) {
      printf("Failed to rename /Applications/vnodebypass.app");
      return 1;
    }
    if (rename("/usr/share/vnodebypass",
               [NSString stringWithFormat:@"/usr/share/%@", randomName].UTF8String) != 0) {
      printf("Failed to rename /usr/share/vnodebypass");
      return 1;
    }

    NSString *dpkgInfo =
        [NSString stringWithContentsOfFile:@"/var/lib/dpkg/info/kr.xsf1re.vnodebypass.list"
                                  encoding:NSUTF8StringEncoding
                                     error:nil];
    dpkgInfo = [dpkgInfo stringByReplacingOccurrencesOfString:@"vnodebypass" withString:randomName];
    [dpkgInfo writeToFile:@"/var/lib/dpkg/info/kr.xsf1re.vnodebypass.list"
               atomically:YES
                 encoding:NSUTF8StringEncoding
                    error:nil];

    printf("Running uicache...\n");

    NSTask *task = [NSTask new];
    task.launchPath = @"/usr/bin/uicache";
    task.arguments = @[ @"-a" ];
    [task launch];
    [task waitUntilExit];
    return 0;
  }
}
