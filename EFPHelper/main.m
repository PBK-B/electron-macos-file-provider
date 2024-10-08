//
//  main.m
//  EFPHelper
//
//  Created by Bin on 2024/9/12.
//

#import <Cocoa/Cocoa.h>
#import "FileProvider/NSFileProviderManager.h"
#import "OSLog/OSLog.h"
#import "EFPHelper-Swift.h"
//执行挂载
void mountWebDAVForFileProvider(void) {
    // 在异步队列中执行挂载操作
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSLog(@"执行挂载操作");
        NSString *domainIdentifier = @"cloud.lazycat.client";
        NSString *domainDisplayName = @"懒猫微服";
        NSFileProviderDomain *domain = [[NSFileProviderDomain alloc] initWithIdentifier:domainIdentifier displayName:domainDisplayName];
        [NSFileProviderManager  removeDomain:domain completionHandler:^(NSError * _Nullable error) {
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
                NSString *info = [NSString stringWithFormat:@"FileProvider 域成功卸载: %@",domain.identifier];
                os_log(OS_LOG_DEFAULT, "FileProvider 域成功卸载: %@", domain.identifier);
                [FileProviderLogger logAppInformation:info];
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
            NSString *appGourpId = @"group.cloud.lazycat.clients";
            NSArray *appGroups = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"com.apple.security.application-groups"];
            if (appGroups && [appGroups count] > 0) {
                appGourpId = [appGroups firstObject];
                NSLog(@"App Groups ID: %@", appGourpId);
            }
            NSUserDefaults *userDefaults = [[NSUserDefaults alloc] initWithSuiteName:appGourpId];
            [userDefaults setObject:url forKey:@"WebDAV——URL"];
            [userDefaults setObject:cookie forKey:@"WebDAV——Cookie"];
            [userDefaults synchronize];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                
                NSUserDefaults *temp_userDefaults = [[NSUserDefaults alloc]initWithSuiteName:appGourpId];
                NSString *info = [NSString stringWithFormat:@"CommandLine 接收到传值 URL: %@, Cookie: %@",[temp_userDefaults stringForKey:@"WebDAV——Cookie"],[temp_userDefaults stringForKey:@"WebDAV——URL"]];
                [FileProviderLogger logAppInformation:info];
                
                //执行File挂载操作
                mountWebDAVForFileProvider();
            });
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
    return 0;
}


