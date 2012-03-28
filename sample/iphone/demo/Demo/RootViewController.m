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
#import "MBProgressHUD.h"
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
        // This is to make sure the app auto-syncs when it re-enters the foreground
        // You are free to adapt this policy according to your needs
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationWillEnterForeground)
                                                     name:UIApplicationWillEnterForegroundNotification
                                                   object:nil];
        
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
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.navigationItem.title = @"Demo";
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
    // See comments within the CTOR for more details
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
    
    // Here the policy is to display a "Loading" HUD at cold start only
    // to prevent the end user from accessing the scanner while the database
    // is still fully empty and thus nothing is scannable.
    // You are free to adapt this policy according to your needs
    if ([scanner count:nil] == 0) {
        MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
        [hud setMinSize:CGSizeMake(220, 220)];
        [hud setLabelText:@"Syncing"];
    }
}

- (void)scannerDidSync:(MSScanner *)scanner {
    MSDLog(@" [MOODSTOCKS SDK] DID SYNC. DATABASE SIZE = %d IMAGE(S)", [scanner count:nil]);
    
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
    [MBProgressHUD hideHUDForView:self.view animated:YES];
}

- (void)scanner:(MSScanner *)scanner failedToSyncWithError:(NSError *)error {
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
    [MBProgressHUD hideHUDForView:self.view animated:YES];
    
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
