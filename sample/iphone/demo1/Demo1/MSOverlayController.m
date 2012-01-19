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

// Internal methods that implements the overlay show/hide
- (void)showResultView:(NSString *)result animation:(BOOL)anim;
- (void)hideResultViewWithAnimation:(BOOL)anim;

// Main wrappers for overlay show/hide
- (void)showResult:(NSString *)result;
- (void)hideResult;

// Method to control the visibility of scanning controls
- (void)showScannerInfo:(BOOL)show;
- (UILabel *)getLabelWithTag:(NSInteger)tag;
- (void)updateEAN;
- (void)updateQRCode;
- (void)updateImages:(NSInteger)count syncing:(BOOL)sync;

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
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIDeviceOrientationDidChangeNotification object:nil];
    
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
    [scanInfo addObject:@" [✔] 0 image "];
    
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

- (void)showResultView:(NSString *)result animation:(BOOL)anim {
    [self showScannerInfo:NO];
    
    _hasResult = YES;
    
    CGFloat margin = 10;
    UIFont *font = [UIFont systemFontOfSize:22];
    UILineBreakMode bmode = UILineBreakModeTailTruncation;
    CGSize textSize = [result sizeWithFont:font
                         constrainedToSize:CGSizeMake(self.view.frame.size.width - margin, CGFLOAT_MAX)
                             lineBreakMode:bmode];
    CGFloat tX      = 0;
    CGFloat tY      = self.view.frame.size.height;
    CGFloat tWidth  = self.view.frame.size.width;
    CGFloat tHeight = textSize.height + 2 * margin;
    
    UILabel* resultLabel        = [[UILabel alloc] init];
    resultLabel.contentMode     = UIViewContentModeLeft;
    resultLabel.lineBreakMode   = bmode;
    resultLabel.numberOfLines   = 0; // i.e. no limit
    resultLabel.backgroundColor = [UIColor clearColor];
    resultLabel.textColor       = [UIColor whiteColor];
    resultLabel.text            = result;
    resultLabel.font            = font;
    resultLabel.frame           = CGRectMake(margin, margin, textSize.width, textSize.height);
    
    MSResultView *resultView = [[[MSResultView alloc] init] autorelease];
    resultView.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.8];
    resultView.frame = CGRectMake(tX, tY, tWidth, tHeight);
    [resultView addSubview:resultLabel];
    [resultLabel release];
    
    [self.view addSubview:resultView];
    [UIView animateWithDuration:0.5 // second
                          delay:0
                        options:0
                     animations:^{
                         resultView.frame = CGRectMake(tX, tY - tHeight, tWidth, tHeight);
                     }
                     completion:^(BOOL finished){
                         // nothing to do
                     }
     ];
}

- (void)hideResultViewWithAnimation:(BOOL)anim {
    _hasResult = NO;
    
    MSResultView *resultView = nil;
    for (UIView *v in [self.view subviews]) {
        if ([v isKindOfClass:[MSResultView class]])
            resultView = (MSResultView *) v;
    }
    
    if (!resultView) {
        // Should never happen
        if (!_hasResult) {
            [self showScannerInfo:YES];
        }
        return;
    }
    
    CGFloat tX      = resultView.frame.origin.x;
    CGFloat tY      = resultView.frame.origin.y;
    CGFloat tWidth  = resultView.frame.size.width;
    CGFloat tHeight = resultView.frame.size.height;
    
    if (anim) {
        [UIView animateWithDuration:0.5 // second
                              delay:0
                            options:0
                         animations:^{
                             resultView.frame = CGRectMake(tX, tY + tHeight, tWidth, tHeight);
                         }
                         completion:^(BOOL finished){
                             [resultView removeFromSuperview];
                             // Since we are delayed, made sure to check that in
                             // the meanwhile a new result has not been set
                             if (!_hasResult) {
                                 [self showScannerInfo:YES];
                             }
                         }
         ];
    }
    else {
        [resultView removeFromSuperview];
        [self showScannerInfo:YES];
    }
}

- (void)showResult:(NSString *)result {
    MSResultView *resultView = nil;
    for (UIView *v in [self.view subviews]) {
        if ([v isKindOfClass:[MSResultView class]])
            resultView = (MSResultView *) v;
    }
    if (resultView == nil) {
        [self showResultView:result animation:YES];
    }
    else {
        [self hideResultViewWithAnimation:NO];
        [self showResultView:result animation:YES];
    }
}

- (void)hideResult {
    [self hideResultViewWithAnimation:YES];
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
        NSString *head = ean ? @"✔" : @"  ";
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
        NSString *text = [NSString stringWithFormat:@" [%@] QR Code ", (self.decodeQRCode ? @"✔" : @"  ")];
        
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

- (void)updateImages:(NSInteger)count syncing:(BOOL)sync {
    UILabel * label = [self getLabelWithTag:2];
    
    if (label != nil) {
        NSString *text = [NSString stringWithFormat:@" [✔] %d %@ %@",
                          count,
                          (count > 1 ? @"images" : @"image"),
                          sync ? @"(syncing...) " : @""];
        
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
    NSNumber *syncing = (NSNumber *) [state objectForKey:@"syncing"];
    if (images != nil || syncing != nil) {
        [self updateImages:self.imagesCount syncing:[syncing boolValue]];
    }
    
    // Update result
    NSDictionary *result = (NSDictionary *) [state objectForKey:@"result"];
    if (result != nil) {
        if ([result count] == 0) {
            [self hideResult];
        }
        else {
            NSNumber *type = (NSNumber *) [result objectForKey:@"type"];
            NSString *value = (NSString *) [result objectForKey:@"value"];
            NSString *result;
            switch ([type integerValue]) {
                case MSSCANNER_IMAGE:
                    result = value;
                    break;
                    
                case MSSCANNER_EAN_8:
                    result = [NSString stringWithFormat:@"EAN 8: %@", value];
                    break;
                    
                case MSSCANNER_EAN_13:
                    result = [NSString stringWithFormat:@"EAN 13: %@", value];
                    break;
                    
                case MSSCANNER_QRCODE:
                    result = [NSString stringWithFormat:@"QR Code: %@", value];
                    break;
                    
                default:
                    result = @"<UNDEFINED>";
                    break;
            }
            
            [self showResult:result];
        }        
    }
    
}

@end
