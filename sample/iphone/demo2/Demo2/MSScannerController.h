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

#import <UIKit/UIKit.h>

#import "MSAvailability.h"

@protocol MSScannerControllerDelegate;

#if MS_SDK_REQUIREMENTS
  #import <AVFoundation/AVFoundation.h>
#endif

#import "MSScanner.h"
#import "MSActivityView.h"

/** Current scanner state */
typedef enum {
    MS_SCAN_STATE_DEFAULT = 0,
    MS_SCAN_STATE_SEARCH
} MSScanState;

@interface MSScannerController : UIViewController
#if MS_SDK_REQUIREMENTS
<AVCaptureVideoDataOutputSampleBufferDelegate, MSScannerDelegate>
#endif
{
    // Scanning state
    MSScanState _state;
    
    // Scanning UI
    UIView *_videoPreviewView;
    
#if MS_SDK_REQUIREMENTS
    // Scanning capture logic
    AVCaptureSession*           captureSession;
    AVCaptureVideoPreviewLayer* previewLayer;
    AVCaptureVideoOrientation   orientation;
    dispatch_queue_t            videoDataOutputQueue;
#endif
    
    // Scanning toolbar
    UIBarButtonItem* _dismissButton;
    UIBarButtonItem* _captureButton;
    UIToolbar* _toolbar;
    
    // Scanning result
    MSActivityView *_activityView;
    
    id<MSScannerControllerDelegate> _delegate;
}

@property (nonatomic, retain) UIView *videoPreviewView;
#if MS_SDK_REQUIREMENTS
@property (nonatomic, retain) AVCaptureSession *captureSession;
@property (nonatomic, retain) AVCaptureVideoPreviewLayer *previewLayer;
@property (nonatomic, assign) AVCaptureVideoOrientation orientation;
#endif
@property (nonatomic, assign) BOOL oldDevice;
@property (nonatomic, assign) id<MSScannerControllerDelegate> delegate;

@end
