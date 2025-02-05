//
//  CEMovieMaker.m
//  CEMovieMaker
//
//  Created by Cameron Ehrlich on 9/17/14.
//  Copyright (c) 2014 Cameron Ehrlich. All rights reserved.
//

#import "CEMovieMaker.h"
#import "AVAsset+Extras.h"

inline CEProgressClass * CEMakeProgress(double elapsedTime, double totalTime, double remainingTime, int pid, NSString * _Nullable processingFile) {
    CEProgressClass *pc = [CEProgressClass new];
    pc.elapsedTime = elapsedTime;
    pc.totalTime = totalTime;
    pc.remainingTime = remainingTime;
    pc.pid = pid;
    pc.processingFile = processingFile;
    return pc;
}

@implementation CEProgressClass

- (NSString *)description {
    NSString *og = [super description];
    return [NSString stringWithFormat:@"%@ elapsed: %f total: %f remaining: %f for: %@", og, _elapsedTime, _totalTime, _remainingTime, _processingFile];
}

@end

@interface CEMovieMaker()
@property AVAssetExportSession *exportSession;
@property NSTimer *exportTimer;
@property NSDate *start;
@end

typedef UIImage*(^CEMovieMakerUIImageExtractor)(NSObject* inputObject);

@implementation CEMovieMaker

- (void)savePlayerItem:(AVPlayerItem *)playerItem toOutputFile:(NSString *)outputFile usingPreset:(NSString *)preset progress:(taskProgressBlock)progressBlock completion:(void(^)(BOOL success, NSString *error))completionBlock {
    self.start = [NSDate date];
    if ([FM fileExistsAtPath:outputFile]){
        [FM removeItemAtPath:outputFile error:nil];
    }
    self.exportSession = [AVAssetExportSession exportSessionWithAsset:playerItem.asset presetName:preset];
    self.exportSession.timeRange = playerItem.asset.exportRange;
    self.exportTimer = [NSTimer scheduledTimerWithTimeInterval:0.1 repeats:true block:^(NSTimer * _Nonnull timer) {
        NSTimeInterval sec = [[NSDate date] timeIntervalSinceDate:self.start];
        CGFloat progress = self.exportSession.progress;
        //DLog(@"progress: %f", progress);
        if(self.exportSession.progress == 1 || self.exportSession.status == AVAssetExportSessionStatusCancelled || self.exportSession.status == AVAssetExportSessionStatusCompleted || self.exportSession.status == AVAssetExportSessionStatusFailed) {
            //DLog(@"doneski");
            [self.exportTimer invalidate];
            self.exportTimer = nil;
        } else {
            double speed = progress/sec;
            double left = (1.0 - progress)/speed;
            if (progressBlock) {
                progressBlock(CEMakeProgress(self.exportSession.progress, 1.0, left, -1, outputFile.lastPathComponent));
            }
        }
    }];
    
    NSURL *outputURL = [NSURL fileURLWithPath:outputFile];
    self.exportSession.outputURL = outputURL;
    self.exportSession.outputFileType = AVFileTypeMPEG4;
    
    [self.exportSession exportAsynchronouslyWithCompletionHandler:^{
        switch ([self.exportSession status]) {
            case AVAssetExportSessionStatusFailed:
                
                NSLog(@"Export failed: %@", [[self.exportSession error] localizedDescription]);
                NSLog(@"%@", [[self.exportSession error] localizedFailureReason]);
                NSLog(@"%@", [[self.exportSession error] localizedRecoveryOptions]);
                NSLog(@"%@", [[self.exportSession error] localizedRecoverySuggestion]);
                if (completionBlock){
                    completionBlock(false, [[self.exportSession error] localizedDescription]);
                }
                break;
            case AVAssetExportSessionStatusCancelled:
                if (completionBlock){
                    completionBlock(false, @"Export canceled");
                }
                NSLog(@"Export canceled");
                break;
            default:
                if (completionBlock){
                    completionBlock(true, nil);
                }
                NSLog(@"Export succeded");
                break;
        }
    }];
}

- (instancetype)initWithSettings:(NSDictionary *)videoSettings;
{
    self = [self init];
    if (self) {
        NSError *error;
        
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *documentsDirectory = [paths firstObject];
        NSString *tempPath = [documentsDirectory stringByAppendingFormat:@"/export.mov"];
        
        
        if ([[NSFileManager defaultManager] fileExistsAtPath:tempPath]) {
            [[NSFileManager defaultManager] removeItemAtPath:tempPath error:&error];
            if (error) {
                NSLog(@"Error: %@", error.debugDescription);
            }
        }
        
        _fileURL = [NSURL fileURLWithPath:tempPath];
        _assetWriter = [[AVAssetWriter alloc] initWithURL:self.fileURL
                                                 fileType:AVFileTypeQuickTimeMovie error:&error];
        if (error) {
            NSLog(@"Error: %@", error.debugDescription);
        }
        NSParameterAssert(self.assetWriter);
        
        _videoSettings = videoSettings;
        _writerInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo
                                                          outputSettings:videoSettings];
        NSParameterAssert(self.writerInput);
        NSParameterAssert([self.assetWriter canAddInput:self.writerInput]);
        
        [self.assetWriter addInput:self.writerInput];
        //NSMutableDictionary *bufferAttributes = [NSMutableDictionary new];
        //bufferAttributes[(NSString*)kCVPixelBufferPixelFormatTypeKey] = @(kCVPixelFormatType_32ARGB);
        
        NSDictionary *bufferAttributes = @{(NSString*)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32ARGB),
                                           (NSString*)kCVPixelBufferWidthKey: [self.videoSettings objectForKey:AVVideoWidthKey],
                                           (NSString*)kCVPixelBufferHeightKey: [self.videoSettings objectForKey:AVVideoHeightKey]
        };
        //NSDictionary *bufferAttributes = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:kCVPixelFormatType_32ARGB], kCVPixelBufferPixelFormatTypeKey, nil];
        
        _bufferAdapter = [[AVAssetWriterInputPixelBufferAdaptor alloc] initWithAssetWriterInput:self.writerInput sourcePixelBufferAttributes:bufferAttributes];
        _frameTime = CMTimeMake(1, 10);
    }
    return self;
}

- (void) createMovieFromImageURLs:(NSArray CE_GENERIC_URL*)urls withCompletion:(CEMovieMakerCompletion)completion;
{
    [self createMovieFromSource:urls extractor:^UIImage *(NSObject *inputObject) {
        return [UIImage imageWithData: [NSData dataWithContentsOfURL:((NSURL*)inputObject)]];
    } withCompletion:completion];
}

- (void) createMovieFromImages:(NSArray CE_GENERIC_IMAGE *)images withCompletion:(CEMovieMakerCompletion)completion;
{
    [self createMovieFromSource:images extractor:^UIImage *(NSObject *inputObject) {
        return (UIImage*)inputObject;
    } withCompletion:completion];
}

- (void)createMovieFromImage:(UIImage *)image duration:(NSInteger)duration withCompletion:(CEMovieMakerCompletion)completion {
    self.completionBlock = completion;
    [self.assetWriter startWriting];
    [self.assetWriter startSessionAtSourceTime:kCMTimeZero];
    
    dispatch_queue_t mediaInputQueue = dispatch_queue_create("mediaInputQueue", NULL);
    [self.writerInput requestMediaDataWhenReadyOnQueue:mediaInputQueue usingBlock:^{
        if ([self.writerInput isReadyForMoreMediaData]) {
            CVPixelBufferRef sampleBuffer = [self newPixelBufferFromCGImage:[image CGImage]];
            [self.bufferAdapter appendPixelBuffer:sampleBuffer withPresentationTime:kCMTimeZero];
            //CMTime presentTime = CMTimeAdd(kCMTimeZero, CMTimeMakeWithSeconds(duration, NSEC_PER_SEC));
            [self.bufferAdapter appendPixelBuffer:sampleBuffer withPresentationTime:CMTimeMakeWithSeconds(duration/2, 600)];
            CFRelease(sampleBuffer);
        }
        [self.writerInput markAsFinished];
        [self.assetWriter finishWritingWithCompletionHandler:^{
            dispatch_async(dispatch_get_main_queue(), ^{
                self.completionBlock(self.fileURL);
            });
        }];
        
        CVPixelBufferPoolRelease(self.bufferAdapter.pixelBufferPool);
    }];
}

- (void) createMovieFromSource:(NSArray *)images extractor:(CEMovieMakerUIImageExtractor)extractor withCompletion:(CEMovieMakerCompletion)completion {
    self.completionBlock = completion;
    
    [self.assetWriter startWriting];
    [self.assetWriter startSessionAtSourceTime:kCMTimeZero];
    
    dispatch_queue_t mediaInputQueue = dispatch_queue_create("mediaInputQueue", NULL);
    
    __block NSInteger i = 0;
    
    NSInteger frameNumber = [images count];
    
    [self.writerInput requestMediaDataWhenReadyOnQueue:mediaInputQueue usingBlock:^{
        while (YES){
            if (i >= frameNumber) {
                break;
            }
            if ([self.writerInput isReadyForMoreMediaData]) {

                CVPixelBufferRef sampleBuffer;
                @autoreleasepool {
                    UIImage* img = extractor([images objectAtIndex:i]);
                    if (img == nil) {
                        i++;
                        NSLog(@"Warning: could not extract one of the frames");
                        continue;
                    }
                    sampleBuffer = [self newPixelBufferFromCGImage:[img CGImage]];
                }
                if (sampleBuffer) {
                    if (i == 0) {
                        [self.bufferAdapter appendPixelBuffer:sampleBuffer withPresentationTime:kCMTimeZero];
                    }else{
                        CMTime lastTime = CMTimeMake(i-1, self.frameTime.timescale);
                        CMTime presentTime = CMTimeAdd(lastTime, self.frameTime);
                        [self.bufferAdapter appendPixelBuffer:sampleBuffer withPresentationTime:presentTime];
                    }
                    CFRelease(sampleBuffer);
                    i++;
                }
            }
        }
        
        [self.writerInput markAsFinished];
        [self.assetWriter finishWritingWithCompletionHandler:^{
            dispatch_async(dispatch_get_main_queue(), ^{
                self.completionBlock(self.fileURL);
            });
        }];
        
        CVPixelBufferPoolRelease(self.bufferAdapter.pixelBufferPool);
    }];
}


- (CVPixelBufferRef)newPixelBufferFromCGImage:(CGImageRef)image {
    NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
                             [NSNumber numberWithBool:YES], kCVPixelBufferCGImageCompatibilityKey,
                             [NSNumber numberWithBool:YES], kCVPixelBufferCGBitmapContextCompatibilityKey,
                             nil];
    
    CVPixelBufferRef pxbuffer = NULL;
    
    CGFloat frameWidth = [[self.videoSettings objectForKey:AVVideoWidthKey] floatValue];
    CGFloat frameHeight = [[self.videoSettings objectForKey:AVVideoHeightKey] floatValue];
    
    CVReturn status = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, self.bufferAdapter.pixelBufferPool, &pxbuffer);
    /*
    CVReturn status = CVPixelBufferCreate(kCFAllocatorDefault,
                                          frameWidth,
                                          frameHeight,
                                          kCVPixelFormatType_32ARGB,
                                          (__bridge CFDictionaryRef) options,
                                          &pxbuffer);
    */
    NSParameterAssert(status == kCVReturnSuccess && pxbuffer != NULL);
    
    CVPixelBufferLockBaseAddress(pxbuffer, 0);
    void *pxdata = CVPixelBufferGetBaseAddress(pxbuffer);
    NSParameterAssert(pxdata != NULL);
    
    CGColorSpaceRef rgbColorSpace = CGColorSpaceCreateDeviceRGB();
    
    CGContextRef context = CGBitmapContextCreate(pxdata,
                                                 frameWidth,
                                                 frameHeight,
                                                 8,
                                                 CVPixelBufferGetBytesPerRow(pxbuffer),
                                                 rgbColorSpace,
                                                 (CGBitmapInfo)kCGImageAlphaNoneSkipFirst);
    NSParameterAssert(context);
    CGContextConcatCTM(context, CGAffineTransformIdentity);
    CGContextDrawImage(context, CGRectMake(0,
                                           0,
                                           CGImageGetWidth(image),
                                           CGImageGetHeight(image)),
                       image);
    CGColorSpaceRelease(rgbColorSpace);
    CGContextRelease(context);
    
    CVPixelBufferUnlockBaseAddress(pxbuffer, 0);
    
    return pxbuffer;
}

+ (NSDictionary *)videoSettingsWithCodec:(NSString *)codec withWidth:(CGFloat)width andHeight:(CGFloat)height {
    
    if ((int)width % 16 != 0 ) {
        NSLog(@"Warning: video settings width must be divisible by 16.");
    }
    NSDictionary *videoSettings = @{AVVideoCodecKey : AVVideoCodecTypeH264,
                                    AVVideoWidthKey : [NSNumber numberWithInt:(int)width],
                                    AVVideoHeightKey : [NSNumber numberWithInt:(int)height]};
    
    return videoSettings;
}

@end
