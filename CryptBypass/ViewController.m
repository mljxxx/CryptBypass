//
//  ViewController.m
//  CryptBypass
//
//  Created by xiongzai on 2024/1/8.
//

#import <UniformTypeIdentifiers/UTType.h>
#import <UniformTypeIdentifiers/UTCoreTypes.h>
#include <mach-o/loader.h>
#include <mach-o/dyld.h>
#import "ViewController.h"
#import "ZipArchive.h"

@interface ViewController () <UIDocumentPickerDelegate>
@property(nonatomic, strong) UIButton *button;
@property(nonatomic, strong) UIDocumentPickerViewController *documentPickerVC;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    _button = [UIButton buttonWithType:UIButtonTypeSystem];
    _button.frame = CGRectMake(UIScreen.mainScreen.bounds.size.width / 2 - 30,
                               UIScreen.mainScreen.bounds.size.height / 2 - 25, 60, 100);
    [_button setTitle:@"Choose" forState:UIControlStateNormal];
    [_button addTarget:self action:@selector(buttonPressed:)
      forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_button];
    // Do any additional setup after loading the view.
    UTType* ipaType = [UTType typeWithFilenameExtension:@"ipa" conformingToType:UTTypeData];
    UTType* tipaType = [UTType typeWithFilenameExtension:@"tipa" conformingToType:UTTypeData];
    // UTType* zipType = [UTType typeWithFilenameExtension:@"zip" conformingToType:UTTypeData];
    NSArray *types = @[ipaType,tipaType];
    _documentPickerVC = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:types];
    // 设置代理
    _documentPickerVC.delegate = self;
    // 设置模态弹出方式
    _documentPickerVC.modalPresentationStyle = UIModalPresentationFormSheet;
}

- (void)buttonPressed:(UIButton *)sender {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self presentViewController:self.documentPickerVC animated:YES completion:nil];
    });
}

#pragma mark - UIDocumentPickerDelegate

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    [self dismissViewControllerAnimated:YES completion:^{
        __block UIAlertController *alertController = [UIAlertController
                                                      alertControllerWithTitle:@"Processing"
                                                      message:@"Please wait, this will take a few seconds..."
                                                      preferredStyle:UIAlertControllerStyleAlert];
        
        [self presentViewController:alertController animated:YES completion:nil];
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            __block BOOL processSuccess = NO;
            __block NSString *savePath = nil;
            BOOL fileUrlAuthozied = [urls.firstObject startAccessingSecurityScopedResource];
            if (fileUrlAuthozied) {
                // 通过文件协调工具来得到新的文件地址，以此得到文件保护功能
                NSFileCoordinator *fileCoordinator = [[NSFileCoordinator alloc] init];
                NSError *error;
                [fileCoordinator coordinateReadingItemAtURL:urls.firstObject options:0 error:&error byAccessor:^(NSURL *newURL) {
                    NSString *docPath =  [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
                    NSString *fileName = [newURL lastPathComponent];
                    NSString *unzipPath = [docPath stringByAppendingPathComponent:fileName.stringByDeletingPathExtension];
                    if([SSZipArchive unzipFileAtPath:newURL.path toDestination:unzipPath]) {
                        NSLog(@"UNZIP SUCCESS");
                        __block NSString *appDir = nil;
                        [[[NSFileManager defaultManager] subpathsAtPath:[unzipPath stringByAppendingPathComponent:@"Payload"]] enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                            if([obj hasSuffix:@".app"]) {
                                appDir = obj;
                                *stop = YES;
                            }
                        }];
                        NSString *appPath = [[unzipPath stringByAppendingPathComponent:@"Payload"] stringByAppendingPathComponent:appDir];
                        NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:[appPath stringByAppendingPathComponent:@"Info.plist"]];
                        NSString *executableName = info[@"CFBundleExecutable"];
                        NSString *executablePath = [appPath stringByAppendingPathComponent:executableName];
                        if([[NSFileManager defaultManager] fileExistsAtPath:executablePath]) {
                            BOOL patchSuccess = [self bypassWithFilePath:executablePath];
                            if(patchSuccess) {
                                NSLog(@"PATCH SUCCESS");
                                savePath = [docPath stringByAppendingPathComponent:fileName];
                                processSuccess = [SSZipArchive createZipFileAtPath:savePath
                                                           withContentsOfDirectory:unzipPath
                                                               keepParentDirectory:NO
                                                                  compressionLevel:1
                                                                          password:nil
                                                                               AES:NO
                                                                   progressHandler:nil];
                                NSLog(@"%@",processSuccess ? @"ZIP SUCCESS" : @"ZIP FAILED");
                            } else {
                                NSLog(@"PATCH FAILED");
                                [[NSFileManager defaultManager] removeItemAtPath:unzipPath error:nil];
                            }
                        }
                        [[NSFileManager defaultManager] removeItemAtPath:unzipPath error:nil];
                    }
                }];
            }
            [urls.firstObject stopAccessingSecurityScopedResource];
            dispatch_async(dispatch_get_main_queue(), ^{
                [alertController dismissViewControllerAnimated:NO completion:^{
                    alertController = [UIAlertController
                                       alertControllerWithTitle:@"Process Complete!"
                                       message:processSuccess ? @"You can find it in Documents Path" : @"Process Failed"
                                       preferredStyle:UIAlertControllerStyleAlert];
                    UIAlertAction *okAction = [UIAlertAction
                                               actionWithTitle:NSLocalizedString(@"OK", @"OK action")
                                               style:UIAlertActionStyleDefault
                                               handler:^(UIAlertAction *action) {
                        [alertController dismissViewControllerAnimated:NO completion:nil];
                    }];
                    UIAlertAction *goFilzaAction = [UIAlertAction
                                                    actionWithTitle:NSLocalizedString(@"GoFilza", @"GoFilza action")
                                                    style:UIAlertActionStyleDefault
                                                    handler:^(UIAlertAction *action) {
                        [alertController dismissViewControllerAnimated:NO completion:nil];
                        NSString *urlString = [NSString stringWithFormat:@"filza://view%@", [savePath stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]]];
                        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:urlString] options:@{} completionHandler:nil];
                    }];
                    [alertController addAction:okAction];
                    if(processSuccess) {
                        [alertController addAction:goFilzaAction];
                    } else {
                        UIAlertAction *okDupAction = [UIAlertAction
                                                   actionWithTitle:NSLocalizedString(@"OK", @"OK action")
                                                   style:UIAlertActionStyleDefault
                                                   handler:^(UIAlertAction *action) {
                            [alertController dismissViewControllerAnimated:NO completion:nil];
                        }];
                        [alertController addAction:okDupAction];
                    }
                    [self presentViewController:alertController animated:YES completion:nil];
                    
                }];
            });
        });
    }];
}

- (BOOL)bypassWithFilePath:(NSString *)filePath {
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
                BOOL success = [data writeToFile:filePath atomically:YES];
                return success;
            }
            cmd = (struct load_command*)((char *)cmd + cmdsize);
        }
    }
    return NO;
}


@end
