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

#import "MSBarcode.h"

@implementation MSBarcode

@synthesize format = _format;
@synthesize data = _data;

- (id)init {
    self = [super init];
    if (self) {
        _format = -1;
        _data = nil;
    }
    return self;
}

#if !TARGET_IPHONE_SIMULATOR
- (id)initWithFormat:(int)format data:(NSData *)data {
    self = [self init];
    if (self) {
        _format = format;
        _data = [data copy];
    }
    return self;
}

- (id)initWithResult:(ms_barcode_t *)result {
    int len;
    const char *bytes;
    ms_barcode_get_data(result, &bytes, &len);
    NSData* data = [[NSData alloc] initWithBytes:bytes length:len];
    self = [self initWithFormat:ms_barcode_get_fmt(result) data:data];
    [data release];
    return self;
}

- (NSString *)getText {
    if (_data == nil) return nil;
    return [[[NSString alloc] initWithData:_data encoding:NSASCIIStringEncoding] autorelease];
}
#endif

- (void)dealloc {
    [_data release];
    _data = nil;
    
    [super dealloc];
}

@end
