#include <mach-o/loader.h>
#include <mach-o/dyld.h>
#include <stdio.h>
#include <Foundation/Foundation.h>

int main(int argc,const char *argv[]) {
  if(argc == 2) {
    NSString *filePath = [NSString stringWithUTF8String:argv[1]];
    BOOL patchSuccess = NO;
    if([[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
        NSMutableData *data = [NSMutableData dataWithContentsOfFile:filePath];
        void *bytes = [data mutableBytes];
        struct mach_header *mh = (struct mach_header *)bytes;
        uint32_t ncmds = mh->ncmds;
        struct load_command* cmd = NULL;
        cmd = (struct load_command*)((char *)mh + sizeof(struct mach_header_64));
        for(uint32_t i = 0;i<ncmds;i++) {
            uint32_t cmdsize = cmd->cmdsize;
            if(cmd->cmd == LC_ENCRYPTION_INFO || cmd->cmd == LC_ENCRYPTION_INFO_64) {
                struct encryption_info_command *encryption_info = (struct encryption_info_command*)cmd;
                encryption_info->cryptoff = 0;
                encryption_info->cryptsize = 0;
                encryption_info->cryptid = 1;
                if([[NSFileManager defaultManager] copyItemAtPath:filePath toPath:[filePath stringByAppendingString:@".bak"] error:nil]) {
                    patchSuccess = [data writeToFile:filePath atomically:YES];
                }
                break;
            }
            cmd = (struct load_command*)((char *)cmd + cmdsize);
        }
    }
    printf("%s\n",patchSuccess ? "patch success": "patch failed");
  } else {
    printf("input error\n");
  }
  return 0;
}
