#import <NSTask.h>
#include <stdio.h>

int main(int argc, char *argv[], char *envp[]) {
  @autoreleasepool {
    NSTask *task = [NSTask new];
    task.launchPath = @"/usr/bin/uicache";

    if (strstr(argv[1], "remove") || strstr(argv[1], "upgrade")) {
      NSArray *fileList =
          [[NSString stringWithContentsOfFile:@"/var/lib/dpkg/info/kr.xsf1re.vnodebypass.list"
                                     encoding:NSUTF8StringEncoding
                                        error:nil] componentsSeparatedByString:@"\n"];
      for (NSString *file in fileList) {
        if ([file hasSuffix:@".app"]) {
          task.arguments = @[ @"-u", file ];
          [task launch];
          [task waitUntilExit];
          return 0;
        }
      }
      printf("Could not find vnodebypass.app, skipping uicache\n");
      return 0;
    }
    NSString *randomName = [[NSUUID UUID].UUIDString componentsSeparatedByString:@"-"].firstObject;

    NSMutableDictionary *appInfo = [NSMutableDictionary
        dictionaryWithContentsOfFile:@"/Applications/vnodebypass.app/Info.plist"];
    appInfo[@"CFBundleExecutable"] = randomName;
    [appInfo writeToFile:@"/Applications/vnodebypass.app/Info.plist" atomically:YES];

    NSArray *renames = @[
      @[ @"/usr/bin/vnodebypass", @"/usr/bin/%@" ],
      @[ @"/Applications/vnodebypass.app/vnodebypass", @"/Applications/vnodebypass.app/%@" ],
      @[ @"/Applications/vnodebypass.app", @"/Applications/%@.app" ],
      @[ @"/usr/share/vnodebypass", @"/usr/share/%@" ]
    ];

    for (NSArray *rename in renames) {
      NSString *oldPath = rename[0];
      NSString *newPath = [NSString stringWithFormat:rename[1], randomName];
      NSError *error;
      [[NSFileManager defaultManager] moveItemAtPath:oldPath toPath:newPath error:&error];
      if (error) {
        printf("Failed to rename %s: %s\n", oldPath.UTF8String,
               error.localizedDescription.UTF8String);
        return 1;
      }
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

    task.arguments = @[ @"-p", [NSString stringWithFormat:@"/Applications/%@.app", randomName] ];
    [task launch];
    [task waitUntilExit];
    return 0;
  }
}
