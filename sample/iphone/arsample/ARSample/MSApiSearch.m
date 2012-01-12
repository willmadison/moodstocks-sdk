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

#import "MSApiSearch.h"

@interface MSApiSearch ()
- (void)didSearchWithResult:(NSString *)resultID;
- (void)failedToSearchWithError:(NSError *)error;
@end

@implementation MSApiSearch

@synthesize delegate = _delegate;

- (id)initWithScanner:(MSScanner *)scanner query:(MSImage *)qry {
    self = [super init];
    if (self) {
        _scanner = scanner;
        _query = [qry retain];
        _delegate = nil;
        
    }
    return self;
}

- (void)dealloc {
    _scanner = nil;
    [_query release];
    _query = nil;
    _delegate = nil;
    
    [super dealloc];
}

- (void)main {
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    
#if !TARGET_IPHONE_SIMULATOR
    NSString *resultID = nil;
    NSError *error = nil;
    BOOL searchCancelled = NO;
    
    if (![self isCancelled]) {
        char *uid = NULL;
        ms_errcode ecode = ms_scanner_api_search([_scanner handle], [_query image], &uid);
        if (ecode == MS_SUCCESS) {
            if (uid != NULL) {
                resultID = [NSString stringWithCString:uid encoding:NSUTF8StringEncoding];
                free(uid);
            }
        }
        else {
            error = [NSError errorWithDomain:@"moodstocks-sdk" code:ecode userInfo:nil];
        }
    }
    else {
        searchCancelled = YES;
    }
    
    if (![self isCancelled]) {
        if (!error) {
            [self performSelectorOnMainThread:@selector(didSearchWithResult:) withObject:resultID waitUntilDone:YES];
        }
        else {
            [self performSelectorOnMainThread:@selector(failedToSearchWithError:) withObject:error waitUntilDone:YES];
        }
    }
    else {
        searchCancelled = YES;
    }
    
    if (searchCancelled) {
        error = [NSError errorWithDomain:@"moodstocks-sdk" code:-1 /* cancel error */ userInfo:nil];
        [self performSelectorOnMainThread:@selector(failedToSearchWithError:) withObject:error waitUntilDone:YES];
    }
#endif
    
    [pool release];
}

#pragma mark - Private

- (void)didSearchWithResult:(NSString *)resultID {
    if ([_delegate respondsToSelector:@selector(scanner:didSearchWithResult:)]) {
        [_delegate scanner:_scanner didSearchWithResult:resultID];
    }
}

- (void)failedToSearchWithError:(NSError *)error {
    if ([_delegate respondsToSelector:@selector(scanner:failedToSearchWithError:)]) {
        [_delegate scanner:_scanner failedToSearchWithError:error];
    }
}

@end
