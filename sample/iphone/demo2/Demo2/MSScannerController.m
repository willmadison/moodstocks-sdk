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

#import "MSResultView.h"

#import <CoreVideo/CoreVideo.h> /* for kCVPixelBufferPixelFormatTypeKey */

#include "moodstocks_sdk.h"

#if MS_SDK_REQUIREMENTS
/**
 * Enabled barcode formats: configure it according to your needs
 * Here only EAN-13 and QR Code formats are enabled.
 * Feel free to add `MS_BARCODE_FMT_EAN8` if you want in addition to decode EAN-8.
 */
static NSInteger kMSBarcodeFormats = MS_BARCODE_FMT_EAN13 |
                                     MS_BARCODE_FMT_QRCODE;
#endif

/* UI settings */
static const NSInteger kMSScanInfoMargin = 5;
static const NSInteger kMSInfoFontSize   = 14;

@interface MSScannerController ()

#if MS_SDK_REQUIREMENTS
- (void)deviceOrientationDidChange;
- (AVCaptureDevice *)cameraWithPosition:(AVCaptureDevicePosition)position;
- (AVCaptureDevice *)backFacingCamera;
+ (AVCaptureConnection *)connectionWithMediaType:(NSString *)mediaType fromConnections:(NSArray *)connections;
#endif

- (void)startCapture;
- (void)stopCapture;

- (void)dismissAction;
- (void)captureAction;
- (void)cancelAction;

- (void)apiSearch:(MSImage *)qry;
- (void)showSearching;
- (void)hideSearching;

- (void)showActivityView;

@end

// Standard toolbar height is 44 pixels: we use 54 pixels here in combination
// with a full screen layout so that the video preview is as close as possible
// of the 4:3 aspect ratio, i.e. width = 320 pixels, height = 426 pixels
static const CGFloat kMSScannerToolbarHeight = 54.0f; // pixels

// This is to make sure the capture button is centered (work around)
static CGFloat kMSScannerRightFixedSpace = 140; // pixels

@implementation MSScannerController

@synthesize videoPreviewView = _videoPreviewView;
#if MS_SDK_REQUIREMENTS
@synthesize captureSession;
@synthesize previewLayer;
@synthesize orientation;
#endif
@synthesize oldDevice;
@synthesize delegate = _delegate;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        self.wantsFullScreenLayout = YES;
        self.hidesBottomBarWhenPushed = YES;
        
        _state = MS_SCAN_STATE_DEFAULT;
    }
    return self;
}

- (void)dealloc {
    [self stopCapture];
    
    _delegate = nil;
    
#if MS_SDK_REQUIREMENTS
    [[MSScanner sharedInstance] cancelApiSearch];
#endif
    
    [super dealloc];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

#pragma mark - Private

#if MS_SDK_REQUIREMENTS
- (void)deviceOrientationDidChange {	
    UIDeviceOrientation deviceOrientation = [[UIDevice currentDevice] orientation];
    
	if (deviceOrientation == UIDeviceOrientationPortrait)
		self.orientation = AVCaptureVideoOrientationPortrait;
	else if (deviceOrientation == UIDeviceOrientationPortraitUpsideDown)
		self.orientation = AVCaptureVideoOrientationPortraitUpsideDown;
	
	// AVCapture and UIDevice have opposite meanings for landscape left and right
    // (AVCapture orientation is the same as UIInterfaceOrientation)
	else if (deviceOrientation == UIDeviceOrientationLandscapeLeft)
		self.orientation = AVCaptureVideoOrientationLandscapeRight;
	else if (deviceOrientation == UIDeviceOrientationLandscapeRight)
		self.orientation = AVCaptureVideoOrientationLandscapeLeft;
	
	// Ignore device orientations for which there is no corresponding still image orientation (e.g. UIDeviceOrientationFaceUp)
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
#endif

- (void)startCapture {
#if MS_SDK_REQUIREMENTS
    [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(deviceOrientationDidChange) name:UIDeviceOrientationDidChangeNotification object:nil];
    self.orientation = AVCaptureVideoOrientationPortrait;
    
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
    AVCaptureStillImageOutput* newStillImageOutput = [[AVCaptureStillImageOutput alloc] init];
    videoDataOutputQueue = dispatch_queue_create("MSScannerController", DISPATCH_QUEUE_SERIAL);
    [newCaptureOutput setSampleBufferDelegate:self queue:videoDataOutputQueue];
    NSDictionary *outputSettings                   = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_32BGRA]
                                                                                 forKey:(id)kCVPixelBufferPixelFormatTypeKey];
    [newCaptureOutput setVideoSettings:outputSettings];
    [newStillImageOutput setOutputSettings:outputSettings];
    
    AVCaptureSession *cSession = [[AVCaptureSession alloc] init];
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
    
    if ([self.captureSession canAddOutput:newStillImageOutput])
        [self.captureSession addOutput:newStillImageOutput];
    
    [newCaptureOutput release];
    [newVideoInput release];
    [newStillImageOutput release];
    
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
#if MS_SDK_REQUIREMENTS
    [captureSession stopRunning];
    
    AVCaptureInput* input = [captureSession.inputs objectAtIndex:0];
    [captureSession removeInput:input];
    
    AVCaptureVideoDataOutput* videoOutput = (AVCaptureVideoDataOutput*) [captureSession.outputs objectAtIndex:0];
    [captureSession removeOutput:videoOutput];
    
    AVCaptureStillImageOutput* imageOutput = (AVCaptureStillImageOutput*) [captureSession.outputs objectAtIndex:0];
    [captureSession removeOutput:imageOutput];
    
    if (videoDataOutputQueue)
        dispatch_release(videoDataOutputQueue);
    
    [self.previewLayer removeFromSuperlayer];
    
    self.previewLayer = nil;
    self.captureSession = nil;
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIDeviceOrientationDidChangeNotification object:nil];
	[[UIDevice currentDevice] endGeneratingDeviceOrientationNotifications];
#endif
}

#pragma mark - UIViewController

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    [self startCapture];
}

- (void)loadView {
    [super loadView];
    
    _videoPreviewView = [[UIView alloc] initWithFrame:CGRectMake(0, 0,
                                                                 self.view.frame.size.width,
                                                                 self.view.frame.size.height - kMSScannerToolbarHeight)];
    _videoPreviewView.backgroundColor = [UIColor blackColor];
    _videoPreviewView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    _videoPreviewView.autoresizesSubviews = YES;
    [self.view addSubview:_videoPreviewView];
    
    // Toolbar with image picker button
    _dismissButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                                   target:self
                                                                   action:@selector(dismissAction)];
    _captureButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCamera
                                                                   target:self
                                                                   action:@selector(captureAction)];
    
    UIBarButtonItem* space  = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                                                             target:nil
                                                                             action:nil] autorelease];
    UIBarButtonItem* fspace = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace
                                                                             target:nil
                                                                             action:nil] autorelease];
    fspace.width = kMSScannerRightFixedSpace;
    
    _toolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, self.view.frame.size.height - kMSScannerToolbarHeight,
                                                           self.view.frame.size.width,
                                                           kMSScannerToolbarHeight)];
    _toolbar.barStyle = UIBarStyleBlack;
    _toolbar.tintColor = nil;
    _toolbar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    _toolbar.items = [NSArray arrayWithObjects:_dismissButton, space, _captureButton, fspace, nil];
    [self.view addSubview:_toolbar];
    
    // Activity view for scanning results
    _activityView = [[MSActivityView alloc] initWithFrame:CGRectZero text:@""];
    [_activityView sizeToFit];
    _activityView.frame = CGRectMake(0, self.view.frame.size.height - kMSScannerToolbarHeight,
                                     self.view.frame.size.width,
                                     _activityView.frame.size.height);
    [self.view insertSubview:_activityView belowSubview:_toolbar];
    
    // Instructions
    UIFont *font = [UIFont systemFontOfSize:kMSInfoFontSize];
    UILineBreakMode breakMode = UILineBreakModeWordWrap;
    
    CGFloat offsetY = [UIScreen mainScreen].applicationFrame.origin.y;
    
    NSMutableArray *userInfo = [NSMutableArray array];
    [userInfo addObject:@" Point to the object or barcode of interest. "];
    [userInfo addObject:@" If it takes too long, snap it. "];
    
    for (int i = 0; i < 2; i++) {
        NSString *text = [userInfo objectAtIndex:i];
        
        offsetY += kMSScanInfoMargin;
        
        CGSize textSize = [text sizeWithFont:font
                           constrainedToSize:CGSizeMake(self.view.frame.size.width, CGFLOAT_MAX)
                               lineBreakMode:breakMode];
        
        UILabel* userInfoLabel        = [[[UILabel alloc] init] autorelease];
        userInfoLabel.contentMode     = UIViewContentModeCenter;
        userInfoLabel.lineBreakMode   = breakMode;
        userInfoLabel.numberOfLines   = 0; // i.e. no limit
        userInfoLabel.backgroundColor = [[[UIColor alloc] initWithRed:0 green:0 blue:0 alpha:0.5] autorelease];
        userInfoLabel.textColor       = [UIColor whiteColor];
        userInfoLabel.shadowColor     = [UIColor blackColor];
        userInfoLabel.text            = text;
        userInfoLabel.font            = font;
        userInfoLabel.frame           = CGRectMake(0.5 * (self.view.frame.size.width - textSize.width),
                                                   offsetY,
                                                   textSize.width,
                                                   textSize.height);
        
        offsetY += textSize.height;
        
        [self.view addSubview:userInfoLabel];
    }
}

- (void)viewDidUnload {
    [super viewDidUnload];
    
    [_toolbar release];          _toolbar = nil;
    [_activityView release];     _activityView = nil;
    [_dismissButton release];    _dismissButton = nil;
    [_captureButton release];    _captureButton = nil;
    [_videoPreviewView release]; _videoPreviewView = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate

#if MS_SDK_REQUIREMENTS
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    if (_state != MS_SCAN_STATE_DEFAULT)
        return;
    
    NSString *result = nil;
    
    // -------------------------------------------------
    // Frame conversion
    // -------------------------------------------------
    MSScanner *scanner = [MSScanner sharedInstance];
    MSImage *qry = [[MSImage alloc] initWithBuffer:sampleBuffer orientation:self.orientation];
    
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
            result = [NSString stringWithFormat:@"ID: %@", imageID];
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
            NSString *barcodeStr = [barcode getText];
            switch (barcode.format) {
                case MS_BARCODE_FMT_EAN8:
                    result = [NSString stringWithFormat:@"EAN 8: %@", barcodeStr];
                    break;
                    
                case MS_BARCODE_FMT_EAN13:
                    result = [NSString stringWithFormat:@"EAN 13: %@", barcodeStr];
                    break;
                    
                case MS_BARCODE_FMT_QRCODE:
                    result = [NSString stringWithFormat:@"QR Code: %@", barcodeStr];
                    break;
            }
        }
    }
    
    // -------------------------------------------------
    // Update the result on screen
    // -------------------------------------------------
    if (result != nil) {
        // Propagate the result into the main thread
        CFRunLoopPerformBlock(CFRunLoopGetMain(), kCFRunLoopCommonModes, ^(void) {
            [self showActivityView];
            [_activityView setText:result];
        });
    }
    
    [qry release];
    return;
}
#endif

#pragma mark - Actions

- (void)dismissAction {
    [self dismissModalViewControllerAnimated:YES];
}

- (void)captureAction {    
#if MS_SDK_REQUIREMENTS
    AVCaptureStillImageOutput* output = (AVCaptureStillImageOutput*) [captureSession.outputs objectAtIndex:1];
    AVCaptureConnection *stillImageConnection = [[self class] connectionWithMediaType:AVMediaTypeVideo fromConnections:[output connections]];
    
    if ([stillImageConnection isVideoOrientationSupported])
        [stillImageConnection setVideoOrientation:self.orientation];
    
    void (^imageCaptureHandler)(CMSampleBufferRef sampleBuffer, NSError *error) = ^(CMSampleBufferRef sampleBuffer, NSError *error) {
        [self apiSearch:[[[MSImage alloc] initWithBuffer:sampleBuffer orientation:self.orientation] autorelease]];
    };
    
    [output captureStillImageAsynchronouslyFromConnection:stillImageConnection completionHandler:imageCaptureHandler];
    
    // Flash effect post-capture
    UIView* flashView = [[UIView alloc] initWithFrame:[_videoPreviewView frame]];
    [flashView setBackgroundColor:[UIColor whiteColor]];
    [[[self view] window] addSubview:flashView];
    
    [UIView animateWithDuration:.4f
                     animations:^{
                         [flashView setAlpha:0.f];
                     }
                     completion:^(BOOL finished){
                         [flashView removeFromSuperview];
                         [flashView release];
                     }
     ];
#endif
}

- (void)cancelAction {
#if MS_SDK_REQUIREMENTS
    [[MSScanner sharedInstance] cancelApiSearch];
#endif
}

#pragma mark - Image search

- (void)apiSearch:(MSImage *)qry {
#if MS_SDK_REQUIREMENTS
    [[MSScanner sharedInstance] apiSearch:qry withDelegate:self];
#endif
}

- (void)showSearching {
    [self showActivityView];
    [_activityView startAnimating];
    [_activityView setText:@"Searching..."];
    
    // Switch to searching toolbar
    UIBarButtonItem* cancelButton = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                                                   target:self
                                                                                   action:@selector(cancelAction)] autorelease];
    [_toolbar setItems:[NSArray arrayWithObject:cancelButton] animated:NO];
}

- (void)hideSearching {
    [_activityView stopAnimating];
    
    // Rollback to default toolbar
    UIBarButtonItem* space  = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                                                             target:nil
                                                                             action:nil] autorelease];
    UIBarButtonItem* fspace = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace
                                                                             target:nil
                                                                             action:nil] autorelease];
    fspace.width = kMSScannerRightFixedSpace;
    [_toolbar setItems:[NSArray arrayWithObjects:_dismissButton, space, _captureButton, fspace, nil] animated:YES];
}

#pragma mark - MSScannerDelegate

#if MS_SDK_REQUIREMENTS
- (void)scannerWillSearch:(MSScanner *)scanner {
    [self showSearching];
    
    _state = MS_SCAN_STATE_SEARCH;
}

- (void)scanner:(MSScanner *)scanner didSearchWithResult:(NSString *)resultID {
    [self hideSearching];
    
    if (resultID != nil) {
        [_activityView setText:[NSString stringWithFormat:@"ID = %@", resultID]];
    }
    else {
        [_activityView setText:@"No match found"];
    }
    
    _state = MS_SCAN_STATE_DEFAULT;
}

- (void)scanner:(MSScanner *)scanner failedToSearchWithError:(NSError *)error {
    [self hideSearching];
    [_activityView setText:@""];
    
    ms_errcode ecode = [error code];
    // NOTE: ignore negative error codes which are not returned by the SDK
    //       but application specific (e.g. so far -1 is returned when cancelling)
    if (ecode >= 0) {
        [_activityView setText:@"Search error"];
        
        NSString *errStr = [NSString stringWithCString:ms_errmsg(ecode) encoding:NSUTF8StringEncoding];
        
        [[[[UIAlertView alloc] initWithTitle:@"Search error"
                                     message:errStr
                                    delegate:nil
                           cancelButtonTitle:@"OK"
                           otherButtonTitles:nil] autorelease] show];
    }
    else if (ecode == -1) {
        [_activityView setText:@"Search cancelled"];
    }
    
    _state = MS_SCAN_STATE_DEFAULT;
}
#endif

#pragma mark - Activity view

- (void)showActivityView {
    CGRect frame = _activityView.frame;
    CGFloat y = frame.origin.y;
    CGFloat height = frame.size.height;
    CGFloat visibleY = self.view.frame.size.height - kMSScannerToolbarHeight - height;
    if (y <= visibleY) {
        return;
    }    
    frame.origin.y = y - height;    
    [UIView animateWithDuration:0.5 animations:^{ _activityView.frame = frame; }];
}

@end
