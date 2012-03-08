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

#import "AppDelegate.h"

#import "ViewController.h"
#import "MSDebug.h"

@implementation AppDelegate

@synthesize window = _window;
@synthesize viewController = _viewController;

- (void)dealloc
{
    [_window release];
    [_viewController release];
    [super dealloc];
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window = [[[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]] autorelease];
    
    if (!MSDeviceCompatibleWithSDK()) {
        // == DO NOT USE IN PRODUCTION AS IS: THIS IS TO ILLUSTRATE THAT YOU SHOULD DESIGN YOUR APP SO THAT
        //                                    IT DOES NOT USE THE SDK AT ALL IF YOUR DEVICE IS DETECTED AS NOT
        //                                    COMPATIBLE AT RUNTIME
        [[[[UIAlertView alloc] initWithTitle:@"Error"
                                     message:@"Your device is not compatible with the Moodstocks SDK."
                                    delegate:nil
                           cancelButtonTitle:@"OK"
                           otherButtonTitles:nil] autorelease] show];
    }
    else {
#if MS_SDK_REQUIREMENTS
        // == MOODSTOCKS SDK SETUP
        NSError *err;
        MSScanner *scanner = [MSScanner sharedInstance];
        if (![scanner open:&err]) {
            ms_errcode ecode = [err code];
            if (ecode == MS_CREDMISMATCH) {
                // == DO NOT USE IN PRODUCTION: THIS IS A HELP MESSAGE FOR DEVELOPERS
                NSString *errStr = @"there is a problem with your key/secret pair: "
                "the current pair does NOT match with the one recorded within the on-disk datastore. "
                "This could happen if:\n"
                " * you have first build & run the app without replacing the default"
                " \"ApIkEy\" and \"ApIsEcReT\" pair, and later on replaced with your real key/secret,\n"
                " * or, you have first made a typo on the key/secret pair, build & run the"
                " app, and later on fixed the typo and re-deployed.\n"
                "\n"
                "To solve your problem:\n"
                " 1) uninstall the app from your device,\n"
                " 2) make sure to properly configure your key/secret pair within MSScanner.m\n"
                " 3) re-build & run\n";
                MSDLog(@"\n\n [MOODSTOCKS SDK] SCANNER OPEN ERROR: %@", errStr);
                
                // NOTE: we purposely crash the app here so that the developer detect the problem
                [[NSException exceptionWithName:@"MSScannerException"
                                         reason:@"Credentials mismatch"
                                       userInfo:nil] raise];
                // == DO NOT USE IN PRODUCTION: THIS IS A HELP MESSAGE FOR DEVELOPERS
            }
            else {
                NSString *errStr = [NSString stringWithCString:ms_errmsg(ecode) encoding:NSUTF8StringEncoding];
                MSDLog(@" [MOODSTOCKS SDK] SCANNER OPEN ERROR: %@", errStr);
            }
        }
        else {
            [scanner syncWithDelegate:self];
        }
#endif
        
        // Override point for customization after application launch.
        self.viewController = [[[ViewController alloc] initWithNibName:@"ViewController" bundle:nil] autorelease];
        self.window.rootViewController = self.viewController;
    }
    
    [self.window makeKeyAndVisible];
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    /*
     Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
     Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
     */
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    /*
     Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
     If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
     */
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    /*
     Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
     */
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    /*
     Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
     */
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    /*
     Called when the application is about to terminate.
     Save data if appropriate.
     See also applicationDidEnterBackground:.
     */
}

#pragma mark - MSScannerDelegate

#if MS_SDK_REQUIREMENTS
- (void)scannerWillSync:(MSScanner *)scanner {
    MSDLog(@" [MSSCANNER] WILL SYNC ");
}

- (void)scannerDidSync:(MSScanner *)scanner {
    NSInteger count = [[MSScanner sharedInstance] count:nil];
    MSDLog(@" [MSSCANNER] DID SYNC. DATABASE SIZE = %d IMAGE(S)", count);
}

- (void)scanner:(MSScanner *)scanner failedToSyncWithError:(NSError *)error {
    ms_errcode ecode = [error code];
    if (ecode >= 0) {
        NSString *errStr;
        if (ecode == MS_BUSY)
            errStr = @"A sync is pending";
        else
            errStr = [NSString stringWithCString:ms_errmsg(ecode) encoding:NSUTF8StringEncoding];
        
        MSDLog(@" [MSSCANNER] FAILED TO SYNC WITH ERROR: %@", errStr);
    }
}
#endif

@end
