//
//  main.m
//  EFPHelper
//
//  Created by Bin on 2024/9/12.
//

#import <Cocoa/Cocoa.h>
#import "FileProvider/NSFileProviderManager.h"
#import "OSLog/OSLog.h"


//执行挂载
void mountWebDAVForFileProvider(void) {
    // 在异步队列中执行挂载操作
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSLog(@"执行挂载操作");
        [NSFileProviderManager removeAllDomainsWithCompletionHandler:^(NSError * _Nullable error) {
            NSFileProviderDomain *domain =
            [[NSFileProviderDomain alloc] initWithIdentifier:@"cloud.lazycat.client"
                                                 displayName:@""];
            [NSFileProviderManager addDomain:domain completionHandler:^(NSError * _Nullable error) {
                printf("err %s \n", [error.debugDescription UTF8String]);
            }];
            
        }];
    });
}


//取消挂载
void unmountWebDAVForFileProvider(void) {
    os_log(OS_LOG_DEFAULT, "开始取消 FileProvider 挂载");
    NSLog(@"取消挂载操作");
    // 创建域对象
    NSString *domainIdentifier = @"cloud.lazycat.client";
    NSString *domainDisplayName = @"懒猫微服";
    NSFileProviderDomain *domain = [[NSFileProviderDomain alloc] initWithIdentifier:domainIdentifier displayName:domainDisplayName];
    
    os_log(OS_LOG_DEFAULT, "即将尝试移除 domain: %@", domain.identifier);
    
    // 调用 remove 方法来卸载 FileProvider
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSFileProviderManager removeDomain:domain completionHandler:^(NSError * _Nullable error) {
            if (error) {
                os_log_error(OS_LOG_DEFAULT, "移除 FileProvider 域失败: %@", error.localizedDescription);
                NSLog(@"移除 FileProvider 域失败: %@", error.localizedDescription);
            } else {
                os_log(OS_LOG_DEFAULT, "FileProvider 域成功卸载: %@", domain.identifier);
                NSLog(@"FileProvider 域成功卸载: %@", domain.identifier);
                
                // 在移除完成后，退出应用
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[NSApplication sharedApplication] terminate:nil];
                });
            }
        }];
    });
}


int main(int argc, const char * argv[]) {
    @autoreleasepool {
        // Setup code that might create autoreleased objects goes here.
    }
    printf("hello\n");
    
    // 解析命令行参数
    NSMutableDictionary<NSString *, NSString *> *argumentsDict = [NSMutableDictionary dictionary];
    for (int i = 1; i < argc; i++) {
        NSString *argument = [NSString stringWithUTF8String:argv[i]];
        NSRange range = [argument rangeOfString:@"="];
        if (range.location != NSNotFound) {
            NSString *key = [argument substringToIndex:range.location];
            NSString *value = [argument substringFromIndex:range.location + 1];
            argumentsDict[key] = value;
        }
    }
    // 获取传入的参数
    NSString *action = argumentsDict[@"--action"];
    NSString *url = argumentsDict[@"--url"];
    NSString *cookie = argumentsDict[@"--cookie"];
    
    if ([action isEqualToString:@"mount"]) {
        if (url && cookie) {
            // 从 App Group 共享数据
            NSUserDefaults *userDefaults = [[NSUserDefaults alloc] initWithSuiteName:@"groups.cloud.lazycat.clients"];
            [userDefaults setObject:url forKey:@"FileProviderURL"];
            [userDefaults setObject:cookie forKey:@"FileProviderCookie"];
            [userDefaults synchronize];
            NSLog(@"CommandLine 接收到传值 URL: %@, Cookie: %@", url, cookie);
            mountWebDAVForFileProvider();
        } else {
            NSLog(@"缺少 URL 或 Cookie 参数");
        }
    } else if ([action isEqualToString:@"cancel"]) {
        // 在异步队列中执行取消挂载操作
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            unmountWebDAVForFileProvider();
        });
    } else {
        NSLog(@"没有传值，未知操作: %@", action);
    }
    
    
    [[NSApplication sharedApplication] run];
    return 1;
}


