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

#import "RootViewController.h"

#import "MSScannerController.h"
#import "MSDebug.h"

@interface RootViewController ()

- (void)scanAction;
- (void)applicationWillEnterForeground;
- (void)sync;

@end

@implementation RootViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        _lastSync = 0;
        
        // This is usefule to turn on auto-sync when the app re-enters the foreground
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationWillEnterForeground)
                                                     name:UIApplicationWillEnterForegroundNotification
                                                   object:nil];
        
        // Please refer to the synchronization policy notes below for more details
        [self sync];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIApplicationWillEnterForegroundNotification
                                                  object:nil];
    
    [super dealloc];
}

#pragma mark - View lifecycle

- (void) loadView {
    CGRect frame = [UIScreen mainScreen].applicationFrame;
    self.view = [[[UIView alloc] initWithFrame:frame] autorelease];
    self.view.autoresizesSubviews = YES;
    self.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.view.backgroundColor = [UIColor whiteColor];
    
    CGFloat bw = 160.0;
    CGFloat bh = 40.0;
    CGFloat ww = self.view.frame.size.width;
    CGFloat hh = self.view.frame.size.height - 44.0;
    
    UIButton *scanButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    [scanButton addTarget:self action:@selector(scanAction) forControlEvents:UIControlEventTouchDown];
    [scanButton setTitle:@"Scan" forState:UIControlStateNormal];
    scanButton.frame = CGRectMake(0.5 * (ww - bw), 0.5 * (hh - bh), bw, bh);
    [self.view addSubview:scanButton];
    
    _splashView = [[MSSplashView alloc] initWithFrame:CGRectMake(0, 0, ww, hh)];
    [self.view addSubview:_splashView];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.navigationItem.title = @"Demo";
}

- (void)viewDidUnload {
    [super viewDidUnload];
    
    [_splashView release];
    _splashView = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

#pragma mark - UI Actions

- (void)scanAction {
    MSScannerController *scannerController = [[MSScannerController alloc] init];
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:scannerController];
    
    [self presentModalViewController:navController animated:YES];
    
    [scannerController release];
    [navController release];
}

// -------------------------------------------------
// NOTES AROUND THE SYNCHRONIZATION POLICY
// -------------------------------------------------
//
// Here's a recap about the synchronization policy retained within this demo app:
//
//                       | SYNC                  | SHOW PROGRESS BAR  | SHOW ERROR
// -------------------------------------------------------------------------------
// (1) COLD START        | yes                   | yes                | yes
// (2) LAUNCH            | yes                   | no                 | no
// (3) ENTER FOREGROUND  | if last sync > 1 day  | no                 | no
//
// (1) Cold start = the image database is empty (i.e. no successful sync occurred yet).
//     It is thus important:
//     * to prevent the user from accessing the scanner
//     * to keep the user notified of the synchronization progress
//     * to warn the user if an error occurred (e.g. no Internet connection)
//
// (2) Launch = the app starts with a non empty database.
//     Let the sync operates seamlessly in the background and fail silently if an error
//     occurred. That way the user can directly start using the scanner while the latest
//     changes (if any) are being fetched.
//
// (3) Enter foreground = the app has been switched in background then foreground, and the
//     database is not empty. Do the same as above except avoid performing a sync except if
//     the last successful sync is too old (1 day here).
//
// IMPORTANT: keep in mind that this is an "hello world application". In a real application
//            context you would have to adapt this policy to your needs and thus carefully
//            decide *when* and *how* to sync (i.e. w/ or w/o a progress bar on the UI side).

#pragma mark -
#pragma mark Synchronization

- (void)applicationWillEnterForeground {
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    if (now - _lastSync >= 86400.0 /* seconds */)
        [self sync];
}

- (void)sync {
#if MS_SDK_REQUIREMENTS
    MSScanner *scanner = [MSScanner sharedInstance];
    
    if ([scanner isSyncing])
        return;
    
    [scanner syncWithDelegate:self];
#endif
}

#pragma mark - MSScannerDelegate

#if MS_SDK_REQUIREMENTS
-(void)scannerWillSync:(MSScanner *)scanner {
    MSDLog(@" [MOODSTOCKS SDK] WILL SYNC ");
    
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
    
    BOOL hide = ([scanner count:nil] > 0) ? YES : NO;
    [_splashView setIsAnimating:YES];
    [_splashView setProgress:0.0f];
    [_splashView setText:@"Initializing..."];
    [_splashView setHidden:hide];
}

- (void)didSyncWithProgress:(NSNumber *)current total:(NSNumber *)total {
    float progress = [current floatValue] / [total floatValue];
    int c = [current intValue];
    int t = [total intValue];
    if (c == 0) {
        [_splashView setIsAnimating:NO];
    }
    [_splashView setProgress:progress];
    [_splashView setText:[NSString stringWithFormat:@"Syncing (%d of %d)", c, t]];
    
    MSDLog(@" [MOODSTOCKS SDK] SYNC PROGRESS %.1f%%", 100 * progress);
}

- (void)scannerDidSync:(MSScanner *)scanner {
    MSDLog(@" [MOODSTOCKS SDK] DID SYNC. DATABASE SIZE = %d IMAGE(S)", [scanner count:nil]);
    
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
    [_splashView setHidden:YES];
    
    _lastSync = [[NSDate date] timeIntervalSince1970];
}

- (void)scanner:(MSScanner *)scanner failedToSyncWithError:(NSError *)error {
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
    [_splashView setHidden:YES];
    
    ms_errcode ecode = [error code];
    
    // NOTE: we ignore negative error codes which are not returned by the SDK
    //       but application specific (e.g. so far -1 is returned when cancelling)
    if (ecode >= 0 && ecode != MS_BUSY) {
        ms_errcode ecode = [error code];
        NSString *errStr = [NSString stringWithCString:ms_errmsg(ecode) encoding:NSUTF8StringEncoding];
        
        MSDLog(@" [MOODSTOCKS SDK] FAILED TO SYNC WITH ERROR: %@", errStr);
        
        if ([scanner count:nil] > 0)
            return;
        
        switch (ecode) {
            case MS_NOCONN:
                errStr = @"The Internet connection does not work.";
                break;
                
            case MS_SLOWCONN:
                errStr = @"The Internet connection is too slow.";
                break;
                
            case MS_TIMEOUT:
                errStr = @"The operation timed out.";
                break;
                
            default:
                errStr = [NSString stringWithFormat:@"An internal error occurred (code = %d).", ecode];
                break;
        }
        
        [[[[UIAlertView alloc] initWithTitle:@"Sync Error"
                                     message:[NSString stringWithFormat:@"%@ Please try again later.", errStr]
                                    delegate:nil
                           cancelButtonTitle:@"OK"
                           otherButtonTitles:nil] autorelease] show];
    }
}
#endif

@end
