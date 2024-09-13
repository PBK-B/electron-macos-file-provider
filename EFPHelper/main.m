//
//  main.m
//  EFPHelper
//
//  Created by Bin on 2024/9/12.
//

#import <Cocoa/Cocoa.h>
#import "FileProvider/NSFileProviderManager.h"

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        // Setup code that might create autoreleased objects goes here.
    }
    printf("hello\n");
    
    [NSFileProviderManager removeAllDomainsWithCompletionHandler:^(NSError * _Nullable error) {
        NSFileProviderDomain *domain =
                [[NSFileProviderDomain alloc] initWithIdentifier:@"cloud.lazycat.client"
                                                     displayName:@"TestFPE"];
        [NSFileProviderManager addDomain:domain completionHandler:^(NSError * _Nullable error) {
            printf("err %s \n", [error.debugDescription UTF8String]);
        }];
        // url
        
        // XPC -> FP
        
    }];

    [[NSApplication sharedApplication] run];
    return 1;
}
