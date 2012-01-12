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

#import "MSScannerController.h"

#import "MSOverlayController.h"
#import "MSImage.h"
#import "MBProgressHUD.h"

#include "moodstocks_sdk.h"

#if MS_HAS_AVFF
/* Auto-sync feature (when app starts or re-enters foreground) */
static const BOOL kMSScannerAutoSync = YES;

/**
 * Enabled barcode formats: configure it according to your needs
 * Here only EAN-13 and QR Code formats are enabled.
 * Feel free to add `MS_BARCODE_FMT_EAN8` if you want in addition to decode EAN-8.
 */
static NSInteger kMSBarcodeFormats = MS_BARCODE_FMT_EAN13 |
                                     MS_BARCODE_FMT_QRCODE;
#endif

/* Private stuff */
@interface MSScannerController ()

#if MS_HAS_AVFF
- (void)deviceOrientationDidChange;
- (AVCaptureDevice *)cameraWithPosition:(AVCaptureDevicePosition)position;
- (AVCaptureDevice *)backFacingCamera;
+ (AVCaptureConnection *)connectionWithMediaType:(NSString *)mediaType fromConnections:(NSArray *)connections;

- (void)applicationDidEnterBackground;
- (void)applicationWillEnterForeground;
#endif

- (void)startCapture;
- (void)stopCapture;

- (void)sync;
- (void)backgroundSync;

@end


@implementation MSScannerController

@synthesize videoPreviewView = _videoPreviewView;
#if MS_HAS_AVFF
@synthesize captureSession;
@synthesize previewLayer;
@synthesize orientation;
#endif

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        self.navigationItem.title = @"AR Sample";
        self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh
                                                                                                target:self
                                                                                                action:@selector(backgroundSync)] autorelease];
        _overlayController = [[MSOverlayController alloc] init];
        _processFrames = NO;
        _ts = -1;
        [[MSScanner sharedInstance] setDelegate:self];
    }
    return self;
}

- (void)dealloc
{
    [self stopCapture];
    
    [_overlayController release];
    _overlayController = nil;
    
    [_result release];
    _result = nil;
    
    [[MSScanner sharedInstance] setDelegate:nil];
    
    [super dealloc];
}

#pragma mark - Private stuff

#if MS_HAS_AVFF
- (void)deviceOrientationDidChange {	
    UIDeviceOrientation deviceOrientation = [[UIDevice currentDevice] orientation];
    
	if (deviceOrientation == UIDeviceOrientationPortrait)
		self.orientation = AVCaptureVideoOrientationPortrait;
	else if (deviceOrientation == UIDeviceOrientationPortraitUpsideDown)
		self.orientation = AVCaptureVideoOrientationPortraitUpsideDown;
	else if (deviceOrientation == UIDeviceOrientationLandscapeLeft)
		self.orientation = AVCaptureVideoOrientationLandscapeRight;
	else if (deviceOrientation == UIDeviceOrientationLandscapeRight)
		self.orientation = AVCaptureVideoOrientationLandscapeLeft;
}

- (AVCaptureDevice *)cameraWithPosition:(AVCaptureDevicePosition)position {
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *device in devices) {
        if ([device position] == position) {
            return device;
        }
    }
    
    return nil;
}

- (AVCaptureDevice *)backFacingCamera {
    return [self cameraWithPosition:AVCaptureDevicePositionBack];
}

+ (AVCaptureConnection *)connectionWithMediaType:(NSString *)mediaType fromConnections:(NSArray *)connections {
    for ( AVCaptureConnection *connection in connections ) {
		for ( AVCaptureInputPort *port in [connection inputPorts] ) {
			if ( [[port mediaType] isEqual:mediaType] ) {
				return connection;
			}
		}
	}
    
	return nil;
}

- (void)applicationDidEnterBackground {
    // Nothing to do so far
}

- (void)applicationWillEnterForeground {
    if (!kMSScannerAutoSync) return;
    
    // Start up a sync automatically (if there is not one pending)
    if (![[MSScanner sharedInstance] isSyncing]) {
        [self backgroundSync];
    }
}
#endif

- (void)startCapture {
#if MS_HAS_AVFF
    // == MOODSTOCKS SDK SETUP
    NSError *err;
    MSScanner *scanner = [MSScanner sharedInstance];
    if (![scanner open:&err]) {
        ms_errcode ecode = [err code];
        if (ecode == MS_CREDMISMATCH) {
            // DO NOT USE IN PRODUCTION: THIS IS A HELP MESSAGE FOR DEVELOPERS
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
            NSLog(@"\n\n [START CAPTURE] SCANNER OPEN ERROR: %@", errStr);
        }
        else {
            NSString *errStr = [NSString stringWithCString:ms_errmsg(ecode) encoding:NSUTF8StringEncoding];
            NSLog(@" [START CAPTURE] SCANNER OPEN ERROR: %@", errStr);
        }
    }
    else {
        NSInteger count = [scanner count:nil];
        if (count <= 0)
            [self sync];
        else {
            if (kMSScannerAutoSync) [self backgroundSync];
            
            NSDictionary *state = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], @"ready",
                                   [NSNumber numberWithBool:!!(kMSBarcodeFormats & MS_BARCODE_FMT_EAN8)],   @"decode_ean_8",
                                   [NSNumber numberWithBool:!!(kMSBarcodeFormats & MS_BARCODE_FMT_EAN13)],  @"decode_ean_13",
                                   [NSNumber numberWithBool:!!(kMSBarcodeFormats & MS_BARCODE_FMT_QRCODE)], @"decode_qrcode",
                                   [NSNumber numberWithInteger:count],                                      @"images", nil];
            [_overlayController scanner:self stateUpdated:state];
            _processFrames = YES;
        }
    }
    
    // == NOTIFICATIONS SETUP
    [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(deviceOrientationDidChange) name:UIDeviceOrientationDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidEnterBackground) name:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillEnterForeground) name:UIApplicationWillEnterForegroundNotification object:nil];
    self.orientation = AVCaptureVideoOrientationPortrait;
    
    // == CAMERA SETUP
	if ([[self backFacingCamera] hasFlash]) {
		if ([[self backFacingCamera] lockForConfiguration:nil]) {
			if ([[self backFacingCamera] isFlashModeSupported:AVCaptureFlashModeAuto])
                [[self backFacingCamera] setFlashMode:AVCaptureFlashModeAuto];
			[[self backFacingCamera] unlockForConfiguration];
		}
	}
    
	if ([[self backFacingCamera] hasTorch]) {
		if ([[self backFacingCamera] lockForConfiguration:nil]) {
			if ([[self backFacingCamera] isTorchModeSupported:AVCaptureTorchModeAuto])
                [[self backFacingCamera] setTorchMode:AVCaptureTorchModeAuto];
			[[self backFacingCamera] unlockForConfiguration];
		}
	}
    
    // == CAPTURE SESSION SETUP
    AVCaptureDeviceInput* newVideoInput            = [[AVCaptureDeviceInput alloc] initWithDevice:[self backFacingCamera] error:nil];
    AVCaptureVideoDataOutput *newCaptureOutput     = [[AVCaptureVideoDataOutput alloc] init];
    newCaptureOutput.alwaysDiscardsLateVideoFrames = YES; 
    videoDataOutputQueue = dispatch_queue_create("MSScannerController", DISPATCH_QUEUE_SERIAL);
    [newCaptureOutput setSampleBufferDelegate:self queue:videoDataOutputQueue];
    NSDictionary *outputSettings                   = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_32BGRA]
                                                                                 forKey:(id)kCVPixelBufferPixelFormatTypeKey];
    [newCaptureOutput setVideoSettings:outputSettings];
    
    AVCaptureSession* cSession = [[AVCaptureSession alloc] init];
    self.captureSession = cSession;
    [cSession release];
    
    // == FRAMES RESOLUTION
    // These are recommended settings: do not change
    if ([self.captureSession canSetSessionPreset:AVCaptureSessionPreset1280x720])
        [self.captureSession setSessionPreset:AVCaptureSessionPreset1280x720];
    
    if ([self.captureSession canAddInput:newVideoInput]) {
        [self.captureSession addInput:newVideoInput];
    }
    else {
        // Fallback to 480x360 (e.g. on 3GS devices)
        if ([self.captureSession canSetSessionPreset:AVCaptureSessionPresetMedium])
            [self.captureSession setSessionPreset:AVCaptureSessionPresetMedium];
        if ([self.captureSession canAddInput:newVideoInput]) {
            [self.captureSession addInput:newVideoInput];
        }
    }
    
    if ([self.captureSession canAddOutput:newCaptureOutput])
        [self.captureSession addOutput:newCaptureOutput];
    
    [newVideoInput release];
    [newCaptureOutput release];
    
    // == VIDEO PREVIEW SETUP
    if (!self.previewLayer)
        self.previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:self.captureSession];
    
    CALayer* viewLayer = [_videoPreviewView layer];
    [viewLayer setMasksToBounds:YES];
    
    [self.previewLayer setFrame:[_videoPreviewView bounds]];
    
    if ([self.previewLayer isOrientationSupported])
        [self.previewLayer setOrientation:AVCaptureVideoOrientationPortrait];
    [self.previewLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill];
    
    [viewLayer insertSublayer:self.previewLayer below:[[viewLayer sublayers] objectAtIndex:0]];
    
    [self.captureSession startRunning];    
#endif
}

- (void)stopCapture {
#if MS_HAS_AVFF
    [captureSession stopRunning];
    
    AVCaptureInput* input = [captureSession.inputs objectAtIndex:0];
    [captureSession removeInput:input];
    
    AVCaptureVideoDataOutput* output = (AVCaptureVideoDataOutput*) [captureSession.outputs objectAtIndex:0];
    [captureSession removeOutput:output];
    
    if (videoDataOutputQueue)
		dispatch_release(videoDataOutputQueue);
    
    [self.previewLayer removeFromSuperlayer];
    
    self.previewLayer = nil;
    self.captureSession = nil;
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIDeviceOrientationDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillEnterForegroundNotification object:nil];
    [[UIDevice currentDevice] endGeneratingDeviceOrientationNotifications];
#endif
}

#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate

#if MS_HAS_AVFF
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    if (!_processFrames)
        return;
    
    // Variables that hold *current* scanning result
    NSString *result = nil;
    MSResultType resultType = MSSCANNER_NONE;
    
    // -------------------------------------------------
    // Frame conversion
    // -------------------------------------------------
    MSScanner *scanner = [MSScanner sharedInstance];
    MSImage *qry = [[MSImage alloc] initWithBuffer:sampleBuffer orientation:self.orientation];
    
    // -------------------------------------------------
    // Previous result locking
    // -------------------------------------------------
    BOOL lock = NO;
    if (_result != nil && _losts < 2) {
        NSInteger found = 0;
        if (_resultType == MSSCANNER_IMAGE) {
            found = [scanner match:qry uid:_result error:nil] ? 1 : -1;
        }
        else if (_resultType == MSSCANNER_QRCODE) {
            MSBarcode *barcode = [scanner decode:qry formats:MS_BARCODE_FMT_QRCODE error:nil];
            found = [[barcode getText] isEqualToString:_result] ? 1 : -1;
        }
        
        if (found == 1) {
            // The current frame matches with the previous result
            lock = YES;
            _losts = 0;
        }
        else if (found == -1) {
            // The current frame looks different so release the lock
            // if there is enough consecutive "no match"
            _losts++;
            lock = (_losts >= 2) ? NO : YES;
        }
    }
    
    if (lock) {
        // Re-use the previous result and skip searching / decoding
        // the current frame
        result = _result;
        resultType = _resultType;
    }
    
    BOOL freshResult = NO;
    
    // -------------------------------------------------
    // Image search
    // -------------------------------------------------
    if (result == nil) {
        NSError *err  = nil;
        NSString *imageID = [scanner search:qry error:&err];
        if (err != nil) {
            ms_errcode ecode = [err code];
            if (ecode != MS_EMPTY) {
                NSString *errStr = [NSString stringWithCString:ms_errmsg(ecode) encoding:NSUTF8StringEncoding];
                NSLog(@" SEARCH ERROR: %@", errStr);
            }
        }
        
        if (imageID != nil) {
            freshResult = YES;
            result = imageID;
            resultType = MSSCANNER_IMAGE;
        }
    }
    
    // -------------------------------------------------
    // Barcode decoding
    // -------------------------------------------------
    // NOTE: barcode decoding is optional. To enhance global speed feel free
    // to get rid of this section if you don't need to decode barcodes
    if (result == nil) {
        NSError *err  = nil;
        MSBarcode *barcode = [scanner decode:qry formats:kMSBarcodeFormats error:&err];
        if (err != nil) {
            ms_errcode ecode = [err code];
            NSString *errStr = [NSString stringWithCString:ms_errmsg(ecode) encoding:NSUTF8StringEncoding];
            NSLog(@" BARCODE ERROR: %@", errStr);
        }
        
        if (barcode != nil) {
            freshResult = YES;
            result = [barcode getText];
            switch (barcode.format) {
                case MS_BARCODE_FMT_EAN8:
                    resultType = MSSCANNER_EAN_8;
                    break;
                    
                case MS_BARCODE_FMT_EAN13:
                    resultType = MSSCANNER_EAN_13;
                    break;
                    
                case MS_BARCODE_FMT_QRCODE:
                    resultType = MSSCANNER_QRCODE;
                    break;
                    
                default:
                    resultType = MSSCANNER_NONE;
                    break;
            }
        }
    }
    
    // -------------------------------------------------
    // Notify the overlay
    // -------------------------------------------------
    if (result != nil) {
        _ts = [[NSDate date] timeIntervalSince1970];
        if (freshResult) _losts = 0;
        
        // Refresh the UI if a *new* result has been found
        if (![_result isEqualToString:result]) {
            [_result release];
            _result = [result copy];
            _resultType = resultType;
            _losts = 0;
            
            // This UI action must be dispatched into the main thread
            CFRunLoopPerformBlock(CFRunLoopGetMain(), kCFRunLoopCommonModes, ^(void) {
                NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:result, @"value",
                                      [NSNumber numberWithInteger:resultType],        @"type", nil];
                NSDictionary *state = [NSDictionary dictionaryWithObject:dict forKey:@"result"];
                [_overlayController scanner:self stateUpdated:state];
            });
        }
    }
    else if (_ts > 0) {
        NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
        if (now - _ts >= 1.5 /* seconds */) {
            // This UI action must be dispatched into the main thread
            CFRunLoopPerformBlock(CFRunLoopGetMain(), kCFRunLoopCommonModes, ^(void) {
                NSDictionary *state = [NSDictionary dictionaryWithObject:[NSDictionary dictionary] forKey:@"result"];
                [_overlayController scanner:self stateUpdated:state];
            });
            
            [_result release];
            _result = nil;   
            _resultType = MSSCANNER_NONE;
            
            _ts = -1;
        }
    }
    
    [qry release];
    return;
}
#endif

#pragma mark - View lifecycle

- (void)loadView {
    [super loadView];
    
    _videoPreviewView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height)];
    _videoPreviewView.backgroundColor = [UIColor blackColor];
    _videoPreviewView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    _videoPreviewView.autoresizesSubviews = YES;
    [self.view addSubview:_videoPreviewView];
    
    [_overlayController.view setFrame:CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height)];
    [self.view addSubview:_overlayController.view];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.navigationController.navigationBar.barStyle = UIBarStyleBlack;
    self.navigationController.navigationBar.tintColor = nil;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    [self startCapture];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    
    [self stopCapture];
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    
    [_videoPreviewView release];
    _videoPreviewView = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
	return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

#pragma mark - Synchronization

- (void)sync {
#if MS_HAS_AVFF
    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
	[hud setLabelText:@"Syncing"];	
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        [[MSScanner sharedInstance] sync:nil];
		dispatch_async(dispatch_get_main_queue(), ^{
            // Whatever happened start processing frames now
            NSDictionary *state = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], @"ready",
                                   [NSNumber numberWithBool:!!(kMSBarcodeFormats & MS_BARCODE_FMT_EAN8)],   @"decode_ean_8",
                                   [NSNumber numberWithBool:!!(kMSBarcodeFormats & MS_BARCODE_FMT_EAN13)],  @"decode_ean_13",
                                   [NSNumber numberWithBool:!!(kMSBarcodeFormats & MS_BARCODE_FMT_QRCODE)], @"decode_qrcode", nil];
            [_overlayController scanner:self stateUpdated:state];
            _processFrames = YES;
            
			[MBProgressHUD hideHUDForView:self.view animated:YES];
		});
	});
#endif
}

- (void)backgroundSync {
#if MS_HAS_AVFF
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        [[MSScanner sharedInstance] sync:nil];
        dispatch_async(dispatch_get_main_queue(), ^{
            [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
        });
	});
#endif
}

#pragma mark - MSSyncDelegate

#if MS_HAS_AVFF
-(void)scannerWillSync:(MSScanner *)scanner {
    NSInteger count = [[MSScanner sharedInstance] count:nil];
    // This UI action must be dispatched into the main thread
    CFRunLoopPerformBlock(CFRunLoopGetMain(), kCFRunLoopCommonModes, ^(void) {
        NSDictionary *state = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], @"syncing",
                               [NSNumber numberWithInteger:count],                                      @"images", nil];
        [_overlayController scanner:self stateUpdated:state];
    });
}

- (void)scannerDidSync:(MSScanner *)scanner {
    NSInteger count = [[MSScanner sharedInstance] count:nil];
    // This UI action must be dispatched into the main thread
    CFRunLoopPerformBlock(CFRunLoopGetMain(), kCFRunLoopCommonModes, ^(void) {
        NSDictionary *state = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:NO], @"syncing",
                               [NSNumber numberWithInteger:count],                                     @"images", nil];
        [_overlayController scanner:self stateUpdated:state];
    });
}

- (void)scanner:(MSScanner *)scanner failedToSyncWithError:(NSError *)error {
    ms_errcode ecode = [error code];
    NSString *errStr;
    if (ecode == MS_BUSY)
        errStr = @"A sync is pending";
    else
        errStr = [NSString stringWithCString:ms_errmsg(ecode) encoding:NSUTF8StringEncoding];
    
    NSInteger count = [[MSScanner sharedInstance] count:nil];
    
    // This UI action must be dispatched into the main thread
    CFRunLoopPerformBlock(CFRunLoopGetMain(), kCFRunLoopCommonModes, ^(void) {
        [[[[UIAlertView alloc] initWithTitle:@"Sync error"
                                     message:errStr
                                    delegate:nil
                           cancelButtonTitle:@"OK"
                           otherButtonTitles:nil] autorelease] show];
        
        NSDictionary *state = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:NO], @"syncing",
                               [NSNumber numberWithInteger:count],                                     @"images", nil];
        [_overlayController scanner:self stateUpdated:state];
    });
}
#endif

@end
