/**
 * Copyright (c) 2011 Moodstocks SAS
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

#import "MSResultView.h"


@implementation MSResultView

- (id)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
    self.contentMode = UIViewContentModeRedraw;
    }

    return self;
}

#pragma mark -
#pragma mark UIView

- (void)drawRect:(CGRect)rect {
    CGRect contextFrame = self.bounds;
    
    // Transparent background
    UIColor* transparentColor = [[[UIColor alloc] initWithRed:0 green:0 blue:0 alpha:0.5] autorelease];
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextSaveGState(ctx);
    {
      CGContextRef context = UIGraphicsGetCurrentContext();
      CGContextSaveGState(context);
      CGContextTranslateCTM(context, CGRectGetMinX(contextFrame), CGRectGetMinY(contextFrame));
      CGContextBeginPath(context);
      CGContextTranslateCTM(ctx, CGRectGetMinX(rect), CGRectGetMinY(rect));
      CGContextBeginPath(ctx);
      CGContextAddRect(ctx, CGRectMake(0, 0, contextFrame.size.width, contextFrame.size.height));
      CGContextClosePath(ctx);
      CGContextRestoreGState(ctx);
    }
    [transparentColor setFill];
    CGContextFillPath(ctx);
    CGContextRestoreGState(ctx);

    // Top black line
    UIColor* blackColor = [UIColor blackColor];
    CGFloat width = 1;
    CGRect strokeRect = CGRectInset(contextFrame, width/2, width/2);
    { 
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSaveGState(context);
    CGContextTranslateCTM(context, CGRectGetMinX(strokeRect), CGRectGetMinY(strokeRect));
    CGContextBeginPath(context);

    CGContextSetLineWidth(context, width);
    CGContextMoveToPoint(context, 0, 0);
    CGContextAddLineToPoint(context, strokeRect.size.width, 0);
    [blackColor setStroke];
    CGContextStrokePath(context);
    CGContextRestoreGState(context);
    }

    // Top semi-transparent white line
    UIColor* whiteBorderColor = [UIColor colorWithWhite:1 alpha:0.2];
    CGRect contextFrameBis = CGRectMake(contextFrame.origin.x,
                                      contextFrame.origin.y + 1,
                                      contextFrame.size.width,
                                      contextFrame.size.height - 1);
    CGRect strokeRectBis = CGRectInset(contextFrameBis, width/2, width/2);
    { 
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSaveGState(context);
    CGContextTranslateCTM(context, CGRectGetMinX(strokeRectBis), CGRectGetMinY(strokeRectBis));
    CGContextBeginPath(context);

    CGContextSetLineWidth(context, width);
    CGContextMoveToPoint(context, 0, 0);
    CGContextAddLineToPoint(context, strokeRectBis.size.width, 0);
    [whiteBorderColor setStroke];
    CGContextStrokePath(context);
    CGContextRestoreGState(context);
    }
}

@end
