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

#import "MSImage.h"

#if !TARGET_IPHONE_SIMULATOR
/**
 * Creates an image with Moodstocks format from a camera frame buffer
 *
 * The pixel format *must* be 32-bit BGRA (i.e `kCVPixelFormatType_32BGRA`)
 * otherwise the method returns a NULL pointer
 *
 * The caller must manage deletion
 */
ms_img_t *MSCreateImageFromSampleBuffer(CMSampleBufferRef sbuf);

/**
 * Same as above, but with a provided device orientation that determines
 * the "real" orientation of the image (e.g. see EXIF orientation for more details)
 *
 * The caller must manage deletion
 */
ms_img_t *MSCreateImageFromSampleBuffer2(CMSampleBufferRef sbuf, AVCaptureVideoOrientation orientation);
#endif

@implementation MSImage

@synthesize image = _img;

- (id)init {
    self = [super init];
    if (self) {
        _img = NULL;
    }
    return self;
}

#if !TARGET_IPHONE_SIMULATOR
- (id)initWithBuffer:(CMSampleBufferRef)buf {
    self = [self init];
    if (self) {
        _img = MSCreateImageFromSampleBuffer(buf);
    }
    return self;
}

- (id)initWithBuffer:(CMSampleBufferRef)buf
         orientation:(AVCaptureVideoOrientation)orientation {
    self = [self init];
    if (self) {
        _img = MSCreateImageFromSampleBuffer2(buf, orientation);
    }
    return self;
}
#endif

- (void)dealloc {
#if !TARGET_IPHONE_SIMULATOR
    if (_img) ms_img_del(_img);
#endif
    _img = NULL;
    
    [super dealloc];
}

@end

#if !TARGET_IPHONE_SIMULATOR
ms_img_t *MSCreateImageFromSampleBuffer(CMSampleBufferRef sbuf) {
    return MSCreateImageFromSampleBuffer2(sbuf, -1);
}

ms_img_t *MSCreateImageFromSampleBuffer2(CMSampleBufferRef sbuf, AVCaptureVideoOrientation orientation) {
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sbuf);
    
    if (CVPixelBufferGetPixelFormatType(imageBuffer) != kCVPixelFormatType_32BGRA)
        return NULL;
    
    CVPixelBufferLockBaseAddress(imageBuffer, 0); 
    
    void *data = CVPixelBufferGetBaseAddress(imageBuffer); 
    size_t bpr = CVPixelBufferGetBytesPerRow(imageBuffer); 
    size_t width = CVPixelBufferGetWidth(imageBuffer); 
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    
    ms_pix_fmt_t fmt = MS_PIX_FMT_RGB32;
    ms_ori_t ori = MS_UNDEFINED_ORI;
    switch (orientation) {
        case AVCaptureVideoOrientationPortrait:
            ori = MS_LEFT_BOTTOM_ORI;
            break;
            
        case AVCaptureVideoOrientationLandscapeRight:
            ori = MS_TOP_LEFT_ORI;
            break;
            
        case AVCaptureVideoOrientationLandscapeLeft:
            ori = MS_BOTTOM_RIGHT_ORI;
            break;
            
        case AVCaptureVideoOrientationPortraitUpsideDown:
            ori = MS_RIGHT_TOP_ORI;
            break;
            
        default:
            break;
    }
    
    ms_img_t *img;
    ms_errcode ecode = ms_img_new(data, width, height, bpr, fmt, ori, &img);
    
    CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
    
    return (ecode == MS_SUCCESS) ? img : NULL;
}
#endif
