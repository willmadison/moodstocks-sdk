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

#import "MSActivityView.h"

#import "MSResultView.h"

static const CGFloat kMSActivityBannerPadding = 16;
static const CGFloat kMSActivityInnerSpacing  = 10;

@implementation MSActivityView

- (id)initWithFrame:(CGRect)frame text:(NSString*)text {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        
        _resultView = [[MSResultView alloc] init];
        _resultView.backgroundColor = [UIColor clearColor];
        
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        
        _activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
        
        _label = [[UILabel alloc] init];
        _label.text = text;
        _label.backgroundColor = [UIColor clearColor];
        _label.lineBreakMode = UILineBreakModeTailTruncation;
        _label.font = [UIFont boldSystemFontOfSize:16];
        _label.textColor = [UIColor whiteColor];
        _label.shadowColor = [UIColor colorWithWhite:0 alpha:0.3];
        _label.shadowOffset = CGSizeMake(1, 1);
        
        [self addSubview:_resultView];
        [_resultView addSubview:_activityIndicator];
        [_resultView addSubview:_label];
    }
    return self;
}

- (void)dealloc {
    [_resultView release];
    [_activityIndicator release];
    [_label release];
    
    [super dealloc];
}

#pragma mark -
#pragma mark UIView

- (void)layoutSubviews {
    [super layoutSubviews];
    
    CGRect screenBounds = [UIScreen mainScreen].bounds;
    CGFloat padding = kMSActivityBannerPadding;
    CGFloat spacing = kMSActivityInnerSpacing;
    
    CGSize textSize = [_label.text sizeWithFont:_label.font];
    CGFloat indicatorSize = _activityIndicator.frame.size.height;
    CGFloat contentHeight = textSize.height > indicatorSize ? textSize.height : indicatorSize;
    CGFloat maxWidth = screenBounds.size.width;
    CGFloat width = self.frame.size.width;
    CGFloat height = self.frame.size.height;    
    if (width > maxWidth) width = maxWidth;
    
    _resultView.frame = CGRectMake(floor(self.frame.size.width/2 - width/2),
                                   floor(self.frame.size.height/2 - height/2),
                                   width, height);
    
    CGFloat leftOffset = spacing;
    if (_activityIndicator.isAnimating) {
        leftOffset += indicatorSize + spacing;
    }
    
    CGFloat textMaxWidth = (width - leftOffset);
    CGFloat textWidth = textSize.width;
    if (textWidth > textMaxWidth) textWidth = textMaxWidth;
    CGFloat y = padding + floor((height - padding*2)/2 - contentHeight/2);
    
    _label.frame = CGRectMake(leftOffset, y, textWidth, textSize.height);    
    _activityIndicator.frame = CGRectMake(spacing, y, indicatorSize, indicatorSize);
}

- (CGSize) sizeThatFits:(CGSize)size {
    CGFloat bannerPadding = kMSActivityBannerPadding;
    
    CGFloat lineHeight = _label.font.ascender - _label.font.descender + 1;
    CGFloat height = lineHeight + bannerPadding*2;
    
    return CGSizeMake(size.width, height);
}

#pragma mark -
#pragma mark Public

- (NSString*)text {
    return _label.text;
}

- (void)setText:(NSString*)text {
    _label.text = text;
    [self setNeedsLayout];
}

- (void)startAnimating {
    [_activityIndicator startAnimating];
    [self setNeedsLayout];
}

- (void)stopAnimating {
    [_activityIndicator stopAnimating];
    [self setNeedsLayout];
}

@end
