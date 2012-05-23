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

#import "MSOverlayController.h"

#import "MSResultView.h"

/* UI settings */
static const NSInteger kMSScanInfoMargin = 5;
static const NSInteger kMSInfoFontSize   = 14;

@interface MSOverlayController ()

// Trigger for the central target rotation
- (void)deviceOrientationDidChange;

// Method to control the visibility of scanning controls
- (void)showScannerInfo:(BOOL)show;
- (UILabel *)getLabelWithTag:(NSInteger)tag;
- (void)updateEAN;
- (void)updateQRCode;
- (void)updateImages:(NSInteger)count;

@end

@implementation MSOverlayController

@synthesize decodeEAN_8;
@synthesize decodeEAN_13;
@synthesize decodeQRCode;
@synthesize imagesCount;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(deviceOrientationDidChange) name:UIDeviceOrientationDidChangeNotification object:nil];
        
        _scanner = nil;
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIDeviceOrientationDidChangeNotification object:nil];
    
    [_actionSheet release];
    _actionSheet = nil;
    
    [super dealloc];
}

- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

#pragma mark - View lifecycle

- (void)loadView {
    CGRect frame = [UIScreen mainScreen].applicationFrame;
    CGRect navFrame = CGRectMake(0, 0, frame.size.width, frame.size.height - 44);
    self.view = [[[UIView alloc] initWithFrame:navFrame] autorelease];
    self.view.autoresizesSubviews = YES;
    self.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.view.backgroundColor = [UIColor clearColor];
    
    UIImage *targetImg = [UIImage imageNamed:@"target.png"];
    CGFloat tw = 0.5 * (self.view.frame.size.width - targetImg.size.width);
    CGFloat th = 0.5 * (self.view.frame.size.height - targetImg.size.height);
    UIImageView *targetView = [[UIImageView alloc] initWithFrame:CGRectMake(tw, th, targetImg.size.width, targetImg.size.height)];
    [targetView setImage:targetImg];
    [targetView setAlpha:0.0];
    [self.view addSubview:targetView];
    [targetView release];
    
    NSInteger tag = 0;
    UIFont *font = [UIFont systemFontOfSize:kMSInfoFontSize];
    UILineBreakMode breakMode = UILineBreakModeWordWrap;
    
    // Scanner settings
    NSMutableArray *scanInfo = [NSMutableArray array];
    [scanInfo addObject:@" [  ] EAN "];
    [scanInfo addObject:@" [  ] QR Code "];
    [scanInfo addObject:@" [✓] 0 image "];
    
    CGFloat offsetY = 0;
    for (NSString *text in scanInfo) {
        offsetY += kMSScanInfoMargin;
        
        CGSize textSize = [text sizeWithFont:font
                           constrainedToSize:CGSizeMake(self.view.frame.size.width - kMSScanInfoMargin, CGFLOAT_MAX)
                               lineBreakMode:breakMode];
        
        UILabel* infoLabel        = [[[UILabel alloc] init] autorelease];
        infoLabel.tag             = tag;
        infoLabel.contentMode     = UIViewContentModeLeft;
        infoLabel.lineBreakMode   = breakMode;
        infoLabel.numberOfLines   = 0; // i.e. no limit
        infoLabel.backgroundColor = [[[UIColor alloc] initWithRed:0 green:0 blue:0 alpha:0.5] autorelease];
        infoLabel.textColor       = [UIColor whiteColor];
        infoLabel.shadowColor     = [UIColor blackColor];
        infoLabel.text            = text;
        infoLabel.font            = font;
        infoLabel.alpha           = 0.0;
        infoLabel.frame           = CGRectMake(kMSScanInfoMargin, offsetY, textSize.width, textSize.height);
        
        offsetY += textSize.height;
        tag++;
        
        [self.view addSubview:infoLabel];
    }
    
    offsetY = self.view.frame.size.height;
    
    // Instructions
    NSMutableArray *userInfo = [NSMutableArray array];
    [userInfo addObject:@" One object/barcode at a time. "];
    [userInfo addObject:@" Place it upright. "];
    
    for (int i = 1; i >=0; i--) {
        NSString *text = [userInfo objectAtIndex:i];
        
        offsetY -= kMSScanInfoMargin;
        
        CGSize textSize = [text sizeWithFont:font
                           constrainedToSize:CGSizeMake(self.view.frame.size.width, CGFLOAT_MAX)
                               lineBreakMode:breakMode];
        
        UILabel* userInfoLabel        = [[[UILabel alloc] init] autorelease];
        userInfoLabel.tag             = tag;
        userInfoLabel.contentMode     = UIViewContentModeCenter;
        userInfoLabel.lineBreakMode   = breakMode;
        userInfoLabel.numberOfLines   = 0; // i.e. no limit
        userInfoLabel.backgroundColor = [[[UIColor alloc] initWithRed:0 green:0 blue:0 alpha:0.5] autorelease];
        userInfoLabel.textColor       = [UIColor whiteColor];
        userInfoLabel.shadowColor     = [UIColor blackColor];
        userInfoLabel.text            = text;
        userInfoLabel.font            = font;
        userInfoLabel.alpha           = 0.0;
        userInfoLabel.frame           = CGRectMake(0.5 * (self.view.frame.size.width - textSize.width),
                                                   offsetY - textSize.height,
                                                   textSize.width,
                                                   textSize.height);
        
        offsetY -= textSize.height;
        tag++;
        
        [self.view addSubview:userInfoLabel];
    }
}

- (void)viewDidUnload
{
    [super viewDidUnload];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

#pragma mark - Private stuff

- (void)deviceOrientationDidChange {
    UIDeviceOrientation deviceOrientation = [[UIDevice currentDevice] orientation];
    
    BOOL undefined = NO;
    CGFloat angle = 0.0;
    switch (deviceOrientation) {
        case UIDeviceOrientationPortrait:           angle =  0.0;         break;
        case UIDeviceOrientationPortraitUpsideDown: angle =  3.14159;     break;
        case UIDeviceOrientationLandscapeLeft:      angle =  3.14159/2.0; break;
        case UIDeviceOrientationLandscapeRight:     angle = -3.14159/2.0; break;
        case UIDeviceOrientationUnknown:
        case UIDeviceOrientationFaceDown:
        case UIDeviceOrientationFaceUp:
            undefined = YES;
            break;
    }
    
    if (undefined) return;
    
    UIImageView* targetView = nil;
    for (UIView *v in [self.view subviews]) {
        if ([v isKindOfClass:[UIImageView class]])
            targetView = (UIImageView *) v;
    }
    
	CGAffineTransform transform = CGAffineTransformMakeRotation(angle);
	
	[UIView beginAnimations:@"rotateTarget" context:nil];
	[UIView setAnimationDelegate:self];
	[UIView setAnimationCurve:UIViewAnimationCurveLinear];
	[UIView setAnimationDuration:0.25];
    
    targetView.transform = transform;
	
	[UIView commitAnimations];
}


- (void)showScannerInfo:(BOOL)show {
    for (UIView *v in [self.view subviews]) {
        if ([v isKindOfClass:[UIImageView class]] ||
            [v isKindOfClass:[UILabel class]])
            [v setAlpha:(show ? 1.0 : 0.0)];
    }
}

- (UILabel *)getLabelWithTag:(NSInteger)tag {
    UILabel* label = nil;
    for (UIView *v in [self.view subviews]) {
        if ([v isKindOfClass:[UILabel class]]) {
            UILabel *l = (UILabel *) v;
            if (l.tag == tag) {
                label = l;
                break;
            }
        }
    }
    
    return label;
}

- (void)updateEAN {
    UILabel * label = [self getLabelWithTag:0];
    
    if (label != nil) {
        BOOL ean = !!(self.decodeEAN_8 || self.decodeEAN_13);
        NSMutableArray *formats = [NSMutableArray array];
        if (ean) {
            if (self.decodeEAN_8)  [formats addObject:@"8"];
            if (self.decodeEAN_13) [formats addObject:@"13"];
        }
        NSString *head = ean ? @"✓" : @"  ";
        NSString *tail = ean ? [NSString stringWithFormat:@"(%@)", [formats componentsJoinedByString:@","]] : @"";
        
        NSString *text = [NSString stringWithFormat:@" [%@] EAN %@ ", head, tail];
        
        UIFont *font = [UIFont systemFontOfSize:kMSInfoFontSize];
        UILineBreakMode breakMode = UILineBreakModeWordWrap;
        CGSize textSize = [text sizeWithFont:font
                           constrainedToSize:CGSizeMake(self.view.frame.size.width - kMSScanInfoMargin, CGFLOAT_MAX)
                               lineBreakMode:breakMode];
        CGRect frame = label.frame;
        
        label.text = text;
        label.frame = CGRectMake(frame.origin.x, frame.origin.y, textSize.width, textSize.height);
    }
}

- (void)updateQRCode {
    UILabel * label = [self getLabelWithTag:1];
    
    if (label != nil) {
        NSString *text = [NSString stringWithFormat:@" [%@] QR Code ", (self.decodeQRCode ? @"✓" : @"  ")];
        
        UIFont *font = [UIFont systemFontOfSize:kMSInfoFontSize];
        UILineBreakMode breakMode = UILineBreakModeWordWrap;
        CGSize textSize = [text sizeWithFont:font
                           constrainedToSize:CGSizeMake(self.view.frame.size.width - kMSScanInfoMargin, CGFLOAT_MAX)
                               lineBreakMode:breakMode];
        CGRect frame = label.frame;
        
        label.text = text;
        label.frame = CGRectMake(frame.origin.x, frame.origin.y, textSize.width, textSize.height);
    }
}

- (void)updateImages:(NSInteger)count {
    UILabel * label = [self getLabelWithTag:2];
    
    if (label != nil) {
        NSString *text = [NSString stringWithFormat:@" [✓] %d %@",
                          count,
                          (count > 1 ? @"images" : @"image")];
        
        UIFont *font = [UIFont systemFontOfSize:kMSInfoFontSize];
        UILineBreakMode breakMode = UILineBreakModeWordWrap;
        CGSize textSize = [text sizeWithFont:font
                           constrainedToSize:CGSizeMake(self.view.frame.size.width - kMSScanInfoMargin, CGFLOAT_MAX)
                               lineBreakMode:breakMode];
        CGRect frame = label.frame;
        
        label.text = text;
        label.frame = CGRectMake(frame.origin.x, frame.origin.y, textSize.width, textSize.height);
    }
}

#pragma mark - MSScannerOverlayDelegate

- (void)scanner:(MSScannerController *)scanner stateUpdated:(NSDictionary *)state {
    _scanner = scanner;
    
    // Toggle whole scanner info (target + text)
    if ([(NSNumber *) [state objectForKey:@"ready"] boolValue]) {
        [self showScannerInfo:YES];
    }
    
    // Update EAN settings
    NSNumber *ean8 = (NSNumber *) [state objectForKey:@"decode_ean_8"];
    if (ean8 != nil)
        self.decodeEAN_8 = [ean8 boolValue];
    NSNumber *ean13 = (NSNumber *) [state objectForKey:@"decode_ean_13"];
    if (ean13 != nil)
        self.decodeEAN_13 = [ean13 boolValue];
    
    if (ean8 != nil || ean13 != nil) [self updateEAN];
    
    // Update QR Code settings
    NSNumber *qrCode = (NSNumber *) [state objectForKey:@"decode_qrcode"];
    if (qrCode != nil) {
        self.decodeQRCode = [qrCode boolValue];
        [self updateQRCode];
    }
    
    // Update image settings
    NSNumber *images = (NSNumber *) [state objectForKey:@"images"];
    if (images != nil)
        self.imagesCount = [images integerValue];
    if (images != nil) {
        [self updateImages:self.imagesCount];
    }
    
    // Update result
    MSResult *result = (MSResult *) [state objectForKey:@"result"];
    if (result != nil) {
        int type = [result getType];
        if (type != MS_RESULT_TYPE_NONE) {
            NSString *value = [result getValue];
            NSString *resultStr;
            switch (type) {
                case MS_RESULT_TYPE_IMAGE:
                    resultStr = value;
                    break;
                    
                case MS_RESULT_TYPE_EAN8:
                    resultStr = [NSString stringWithFormat:@"EAN 8: %@", value];
                    break;
                    
                case MS_RESULT_TYPE_EAN13:
                    resultStr = [NSString stringWithFormat:@"EAN 13: %@", value];
                    break;
                    
                case MS_RESULT_TYPE_QRCODE:
                    resultStr = [NSString stringWithFormat:@"QR Code: %@", value];
                    break;
                    
                default:
                    resultStr = @"<UNDEFINED>";
                    break;
            }
            
            // Retrieve and dismiss former result (if any)
            if (_actionSheet != nil) {
                [_actionSheet dismissWithClickedButtonIndex:-1 animated:NO];
                
                [_actionSheet release];
                _actionSheet = nil;
            }
            
            // Present the most up-to-date result in overlay
            //
            // NOTE: this is a very basic way to display some information / action in overlay
            //       You can think of it as an "hello world". In a real application you may want
            //       to introduce your own UI elements and animations according to your needs
            _actionSheet = [[UIActionSheet alloc] initWithTitle:resultStr
                                                       delegate:self
                                              cancelButtonTitle:@"OK"
                                         destructiveButtonTitle:nil
                                              otherButtonTitles:nil];
            _actionSheet.actionSheetStyle = UIActionSheetStyleBlackTranslucent;
            [_actionSheet showInView:self.view];
        }
    }
    
}

#pragma mark - UIActionSheetDelegate

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == 0) {
        // Tell the scanner there is no need to memorize the former result
        [_scanner reset];
    }
}

@end
