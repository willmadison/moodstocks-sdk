/**
 * Copyright (c) 2012 Moodstocks SAS
 *
 * Permission is hereby granted, free of charge, to any person obtaining
 * a copy of this software and associated documentation files (the
 * "Software"), to deal in the Software without restriction, including
 * without limitation the rights to use, copy, modify, merge, publish,
 * distribute, sublicense, and/or sell copies of the Software, and to
 * permit persons to whom the Software is furnished to do so, subject to
 * the following conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
 * LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
 * OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
 * WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

#include "moodstocks_sdk.h"

#import "MSSync.h"

@interface MSSync ()
- (void)willSync;
- (void)didSync;
- (void)failedToSyncWithError:(NSError *)error;
@end

@implementation MSSync

@synthesize delegate = _delegate;

- (id)initWithScanner:(MSScanner *)scanner {
    self = [super init];
    if (self) {
        _scanner = scanner;
        _delegate = nil;
        
    }
    return self;
}

- (void)dealloc {
    _scanner = nil;
    _delegate = nil;
    
    [super dealloc];
}

- (void)main {
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    
#if !TARGET_IPHONE_SIMULATOR
    _taskID = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            if (_taskID != UIBackgroundTaskInvalid) {
                [[UIApplication sharedApplication] endBackgroundTask:_taskID];
                _taskID = UIBackgroundTaskInvalid;
                [self cancel];
            }
        });
    }];
    
    NSError *error = nil;
    BOOL syncCancelled = NO;
    
    if (![self isCancelled]) {
        [self performSelectorOnMainThread:@selector(willSync) withObject:nil waitUntilDone:YES];
        
        ms_errcode ecode = ms_scanner_sync([_scanner handle]);
        if (ecode != MS_SUCCESS) {
            error = [NSError errorWithDomain:@"moodstocks-sdk" code:ecode userInfo:nil];
        }
    }
    else {
        syncCancelled = YES;
    }
    
    if (![self isCancelled]) {
        if (!error) {
            [self performSelectorOnMainThread:@selector(didSync) withObject:nil waitUntilDone:YES];
        }
        else {
            [self performSelectorOnMainThread:@selector(failedToSyncWithError:) withObject:error waitUntilDone:YES];
        }
    }
    else {
        syncCancelled = YES;
    }
    
    if (syncCancelled) {
        error = [NSError errorWithDomain:@"moodstocks-sdk" code:-1 /* cancel error */ userInfo:nil];
        [self performSelectorOnMainThread:@selector(failedToSyncWithError:) withObject:error waitUntilDone:YES];
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (_taskID != UIBackgroundTaskInvalid) {
            [[UIApplication sharedApplication] endBackgroundTask:_taskID];
            _taskID = UIBackgroundTaskInvalid;
        }
    });
#endif
    
    [pool release];
}

#pragma mark - Private

- (void)willSync {
    [_delegate performSelector:@selector(scannerWillSync:) withObject:_scanner];
}

- (void)didSync {
    [_delegate performSelector:@selector(scannerDidSync:) withObject:_scanner];
}

- (void)failedToSyncWithError:(NSError *)error {
    [_delegate performSelector:@selector(scanner:failedToSyncWithError:) withObject:_scanner withObject:error];
}

@end
