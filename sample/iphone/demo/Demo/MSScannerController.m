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
#import "MSDebug.h"
#import "MSImage.h"
#import "MBProgressHUD.h"

#include "moodstocks_sdk.h"

#if MS_SDK_REQUIREMENTS
/**
 * Enabled scanning formats
 * Here we allow offline image recognition as well as EAN13 and QRCodes barcode decoding.
 * Feel free to add `MS_RESULT_TYPE_EAN8` if you want in addition to decode EAN-8.
 */
static NSInteger kMSScanOptions = MS_RESULT_TYPE_IMAGE |
                                  MS_RESULT_TYPE_EAN13 |
                                  MS_RESULT_TYPE_QRCODE;

/* Do not modify */
static void ms_avcapture_cleanup(void *p) {
    [((MSScannerController *) p) release];
}
#endif

/* Private stuff */
@interface MSScannerController ()

#if MS_SDK_REQUIREMENTS
- (void)deviceOrientationDidChange;
- (AVCaptureDevice *)cameraWithPosition:(AVCaptureDevicePosition)position;
- (AVCaptureDevice *)backFacingCamera;
#endif

- (void)startCapture;
- (void)stopCapture;

- (void)dismissAction;

@end


@implementation MSScannerController

#if MS_SDK_REQUIREMENTS
@synthesize captureSession;
@synthesize previewLayer;
@synthesize orientation;
#endif

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        UIBarButtonItem *barButton = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                                                    target:self
                                                                                    action:@selector(dismissAction)] autorelease];
        self.navigationItem.leftBarButtonItem = barButton;

#if MS_SDK_REQUIREMENTS
        [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(deviceOrientationDidChange)
                                                     name:UIDeviceOrientationDidChangeNotification
                                                   object:nil];
        self.orientation = AVCaptureVideoOrientationPortrait;
#endif
        
        _overlayController = [[MSOverlayController alloc] init];
        _processFrames = NO;
        _ts = -1;
    }
    return self;
}

- (void)dealloc {
    [_overlayController release];
    _overlayController = nil;
    
    [_result release];
    _result = nil;
    
#if MS_SDK_REQUIREMENTS
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIDeviceOrientationDidChangeNotification object:nil];
    [[UIDevice currentDevice] endGeneratingDeviceOrientationNotifications];
#endif
    
    [super dealloc];
}

#pragma mark - Private stuff

#if MS_SDK_REQUIREMENTS
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
#endif

- (void)startCapture {
#if MS_SDK_REQUIREMENTS    
    // == CAPTURE SESSION SETUP
    AVCaptureDeviceInput *newVideoInput = [[AVCaptureDeviceInput alloc] initWithDevice:[self backFacingCamera] error:nil];
    AVCaptureVideoDataOutput *newCaptureOutput = [[AVCaptureVideoDataOutput alloc] init];
    
    dispatch_queue_t videoDataOutputQueue = dispatch_queue_create("MSScannerController", DISPATCH_QUEUE_SERIAL);
    dispatch_set_context(videoDataOutputQueue, self);
    dispatch_set_finalizer_f(videoDataOutputQueue, ms_avcapture_cleanup);
    [newCaptureOutput setSampleBufferDelegate:self queue:videoDataOutputQueue];
    dispatch_release(videoDataOutputQueue);
    [self retain]; /* a release is made at `ms_avcapture_cleanup` time */
    
    NSDictionary *outputSettings = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_32BGRA]
                                                               forKey:(id)kCVPixelBufferPixelFormatTypeKey];
    [newCaptureOutput setVideoSettings:outputSettings];
    [newCaptureOutput setAlwaysDiscardsLateVideoFrames:YES];
    
    AVCaptureSession *cSession = [[AVCaptureSession alloc] init];
    self.captureSession = cSession;
    [cSession release];
    
    // == FRAMES RESOLUTION
    // NOTE: these are recommended settings, do *NOT* change
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
    
    UIView *videoPreviewView = nil;
    for (UIView *v in [self.view subviews]) {
        if ([v tag] == 1) {
            videoPreviewView = v;
            
            CALayer *viewLayer = [videoPreviewView layer];
            [viewLayer setMasksToBounds:YES];
            [self.previewLayer setFrame:[videoPreviewView bounds]];
            if ([self.previewLayer isOrientationSupported])
                [self.previewLayer setOrientation:AVCaptureVideoOrientationPortrait];
            [self.previewLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill];
            [viewLayer insertSublayer:self.previewLayer below:[[viewLayer sublayers] objectAtIndex:0]];
            
            break;
        }
    }
    
    [self.captureSession startRunning];
    
    // == OVERLAY NOTIFICATION
    NSDictionary *state = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], @"ready",
                           [NSNumber numberWithBool:!!(kMSScanOptions & MS_RESULT_TYPE_EAN8)],      @"decode_ean_8",
                           [NSNumber numberWithBool:!!(kMSScanOptions & MS_RESULT_TYPE_EAN13)],     @"decode_ean_13",
                           [NSNumber numberWithBool:!!(kMSScanOptions & MS_RESULT_TYPE_QRCODE)],    @"decode_qrcode",
                           [NSNumber numberWithInteger:[[MSScanner sharedInstance] count:nil]],     @"images", nil];
    [_overlayController scanner:self stateUpdated:state];
    
    _processFrames = YES;
#endif
}

- (void)stopCapture {
#if MS_SDK_REQUIREMENTS
    [captureSession stopRunning];
    
    AVCaptureInput *input = [captureSession.inputs objectAtIndex:0];
    [captureSession removeInput:input];
    
    AVCaptureVideoDataOutput *output = (AVCaptureVideoDataOutput*) [captureSession.outputs objectAtIndex:0];
    [captureSession removeOutput:output];
    
    [self.previewLayer removeFromSuperlayer];
    
    self.previewLayer = nil;
    self.captureSession = nil;
#endif
}

#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate

#if MS_SDK_REQUIREMENTS
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    if (!_processFrames)
        return;
    
    // -------------------------------------------------
    // Camera frame conversion
    // -------------------------------------------------
    MSImage *qry = [[MSImage alloc] initWithBuffer:sampleBuffer orientation:self.orientation];
    
    // -------------------------------------------------
    // Scanning
    // -------------------------------------------------
    NSError *err = nil;
    MSResult *result = [[MSScanner sharedInstance] scan:qry options:kMSScanOptions error:&err];
    if (err != nil) {
        MSDLog(@" [MOODSTOCKS SDK] SCAN ERROR: %@", [NSString stringWithCString:ms_errmsg([err code])
                                                                       encoding:NSUTF8StringEncoding]);
    }
    
    // -------------------------------------------------
    // Overlay refreshing
    // -------------------------------------------------
    if (result != nil) {
        _ts = [[NSDate date] timeIntervalSince1970];
        
        // Refresh the UI if a *new* result has been found
        if (![_result isEqualToResult:result]) {
            [_result release];
            _result = [result copy];
            
            // This UI action must be dispatched into the main thread
            CFRunLoopPerformBlock(CFRunLoopGetMain(), kCFRunLoopCommonModes, ^(void) {
                NSDictionary *state = [NSDictionary dictionaryWithObject:result forKey:@"result"];
                [_overlayController scanner:self stateUpdated:state];
            });
        }
    }
    else if (_ts > 0) {
        // Here we control how long the overlay will persist on screen when no result is found
        // by the scanner. Feel free to configure this delay according to your needs
        NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
        if (now - _ts >= 1.5 /* seconds */) {
            // This UI action must be dispatched into the main thread
            CFRunLoopPerformBlock(CFRunLoopGetMain(), kCFRunLoopCommonModes, ^(void) {
                MSResult *emptyResult = [[[MSResult alloc] initWithType:MS_RESULT_TYPE_NONE value:nil] autorelease];
                NSDictionary *state = [NSDictionary dictionaryWithObject:emptyResult forKey:@"result"];
                [_overlayController scanner:self stateUpdated:state];
            });
            
            [_result release];
            _result = nil;
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
    
    CGRect previewFrame = CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height);
    UIView *videoPreviewView = [[[UIView alloc] initWithFrame:previewFrame] autorelease];
    videoPreviewView.tag = 1; /* to identify the video preview view */
    videoPreviewView.backgroundColor = [UIColor blackColor];
    videoPreviewView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    videoPreviewView.autoresizesSubviews = YES;
    [self.view addSubview:videoPreviewView];
    
    [_overlayController.view setTag:2];
    [_overlayController.view setFrame:CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height)];
    [self.view addSubview:_overlayController.view];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.navigationController.navigationBar.barStyle = UIBarStyleBlack;
    self.navigationController.navigationBar.tintColor = nil;
    
    [self startCapture];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
	return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

#pragma mark - Actions

- (void)dismissAction {
    [self stopCapture];
    
    [self dismissModalViewControllerAnimated:YES];
}

@end
