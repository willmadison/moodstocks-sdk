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

#import <Foundation/Foundation.h>

#if !TARGET_IPHONE_SIMULATOR
#import <AVFoundation/AVFoundation.h>
#endif

#include "moodstocks_sdk.h"

#import "MSImage.h"
#import "MSBarcode.h"

/**
 * Type of a scanning result
 */
typedef enum {
    MSSCANNER_NONE = -1,
    MSSCANNER_IMAGE,
    MSSCANNER_EAN_8,
    MSSCANNER_EAN_13,
    MSSCANNER_QRCODE
} MSResultType;

@protocol MSScannerDelegate;

/**
 * Wrapper around Moodstocks SDK scanner object
 *
 * The scanner offers an unified interface to perform:
 * - local database syncronization with offline content,
 * - offline search over the local database of image records,
 * - remote search on Moodstocks API,
 * - 1D/2D barcode decoding.
 */
@interface MSScanner : NSObject {
    NSString *_dbPath;
    id<MSScannerDelegate> _delegate;
    ms_scanner_t *_scanner;
    NSOperationQueue *_syncQueue;
    NSOperationQueue *_searchQueue;
}

@property (nonatomic, assign) id<MSScannerDelegate> delegate;
@property (nonatomic, readonly) ms_scanner_t *handle;

/**
 * Obtain the singleton instance
 */
+ (MSScanner *)sharedInstance;

#if !TARGET_IPHONE_SIMULATOR
/**
 * Open the scanner and connect it to the database file
 */
- (BOOL)open:(NSError **)error;
/**
 * Close the scanner and disconnect it from the database file
 */
- (BOOL)close:(NSError **)error;

/**
 * Synchronize the local database with offline content from Moodstocks API
 *
 * This method runs in the background so you can safely call it from the main thread.
 *
 * Take care to implement the ad hoc `MSScannerDelegate` protocol methods since
 * this method keeps its delegate notified.
 *
 * NOTE: this method requires an Internet connection.
 */
- (void)sync;

/**
 * Check if a sync is pending
 */
- (BOOL)isSyncing;

/**
 * Get the total number of images recorded into the local database
 */
- (NSInteger)count:(NSError **)error;

/**
 * Get an array made of all images identifiers found into the local database
 */
- (NSArray *)info:(NSError **)error;

/**
 * Perform an offline image search over the local database
 */
- (NSString *)search:(MSImage *)qry error:(NSError **)error;

/**
 * Match a query image againts a reference from the local database
 */
- (BOOL)match:(MSImage *)qry uid:(NSString *)uid error:(NSError **)error;

/**
 * Perform a remote image search on Moodstocks API
 *
 * This method runs in the background so you can safely call it from the main thread.
 *
 * Take care to implement the ad hoc `MSScannerDelegate` protocol methods since
 * this method keeps its delegate notified.
 *
 * NOTE: this method requires an Internet connection.
 */
- (void)apiSearch:(MSImage *)qry;

/**
 * Cancel any pending API search(es)
 */
- (void)cancelApiSearch;

/**
 * Perform 1D / 2D barcode decoding
 *
 * `formats` specifies the barcode format to decode (added by bitwise-or) amond these ones:
 *
 *  MS_BARCODE_FMT_EAN8
 *  MS_BARCODE_FMT_EAN13
 *  MS_BARCODE_FMT_QRCODE
 *
 * e.g. `int formats = MS_BARCODE_FMT_EAN13 | MS_BARCODE_FMT_QRCODE;`
 */
- (MSBarcode *)decode:(MSImage *)qry formats:(int)formats error:(NSError **)error;
#endif

@end

/**
 * Scanner protocol for asynchronous network operations
 *
 * NOTE: these methods are always called on main thread
 */
@protocol MSScannerDelegate <NSObject>
@required
/**
 * Dispatched when a synchronization is about to start
 */
- (void)scannerWillSync:(MSScanner *)scanner;

/**
 * Dispatched when a synchronization is completed
 */
- (void)scannerDidSync:(MSScanner *)scanner;

/**
 * Dispatched when a synchronization failed
 */
- (void)scanner:(MSScanner *)scanner failedToSyncWithError:(NSError *)error;

@optional
/**
 * Dispatched when an online search (aka API search) is completed
 *
 * NOTE: `resultID` is `nil` when there is no match
 */
- (void)scanner:(MSScanner *)scanner didSearchWithResult:(NSString *)resultID;

/**
 * Dispatched when an online search (aka API search) failed
 */
- (void)scanner:(MSScanner *)scanner failedToSearchWithError:(NSError *)error;
@end
