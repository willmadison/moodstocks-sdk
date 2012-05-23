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
        // This is usefule to turn on auto-sync when the app re-enters the foreground
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationWillEnterForeground)
                                                     name:UIApplicationWillEnterForegroundNotification
                                                   object:nil];
        
        // IMPORTANT: here we trigger a synchronization at startup. In a real application context
        //            you would have to carefully decide *when* and *how* to sync (i.e. with an UI
        //            indicator or not) according to your needs.
        //            We strongly recommend you to inform the user via ad-hoc UI elements at least at the
        //            very first synchronization (i.e. when the scanner is empty) so that to prevent him
        //            from accessing the scanner when the database is still empty.
        //
        //            See `scannerWillSync` below for more details
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

#pragma mark -
#pragma mark Synchronization

- (void)applicationWillEnterForeground {
    // --
    // OPTIONAL
    // --
    // Uncomment the line below if you want to trigger a sync each time the app
    // re-enters the foreground. See comments within the CTOR for more details
    
    /*
    [self sync];
    */
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
    
    // NOTE: the synchronization always operates in the background and you are
    //       free to display a splash view, etc or nothing at all, at your convenience.
    //       Here we systematically display a splash view but you could omit it (for e.g.)
    //       if the scanner is not empty (i.e. the scanner has already been synchronized
    //       successfully in the past) with a check like:
    //       if ([scanner count:nil] == 0) { /* ... */ }
    [_splashView setIsAnimating:YES];
    [_splashView setProgress:0.0f];
    [_splashView setText:@"Initializing..."];
    [_splashView setHidden:NO];
}

// --
// OPTIONAL
// --
//    This to display the sync progress on the UI side. Feel free to remove this method if
//    you choose to not display the determinate progress. Also feel free to adjust the way the
//    info is displayed to the end user (i.e. wording, progress bar vs round progress, etc)
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
        
        // Fail silently when we are not at cold start
        // Feel free to adapt this to your needs
        if ([scanner count:nil] > 0)
            return;
        
        [[[[UIAlertView alloc] initWithTitle:@"Sync error"
                                     message:errStr
                                    delegate:nil
                           cancelButtonTitle:@"OK"
                           otherButtonTitles:nil] autorelease] show];
    }
}
#endif

@end
