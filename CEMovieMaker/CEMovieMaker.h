//
//  CEMovieMaker.h
//  CEMovieMaker
//
//  Created by Cameron Ehrlich on 9/17/14.
//  Copyright (c) 2014 Cameron Ehrlich. All rights reserved.
//

@import AVFoundation;
@import Foundation;
@import UIKit;

#define FM [NSFileManager defaultManager]

NS_ASSUME_NONNULL_BEGIN
@class CEProgressClass;

typedef void(^taskProgressBlock)(CEProgressClass * _Nonnull pc);
typedef void(^CEMovieMakerCompletion)(NSURL *fileURL);

#if __has_feature(objc_generics) || __has_extension(objc_generics)
    #define CE_GENERIC_URL <NSURL *>
    #define CE_GENERIC_IMAGE <UIImage *>
#else
    #define CE_GENERIC_URL
    #define CE_GENERIC_IMAGE
#endif

@interface CEProgressClass: NSObject

CEProgressClass * CEMakeProgress(double elapsedTime, double totalTime, double remainingTime, int pid, NSString * _Nullable processingFile);

@property double elapsedTime;
@property double totalTime;
@property double remainingTime;
@property int pid;
@property (nonatomic, strong) NSString *processingFile;

@end

@interface CEMovieMaker : NSObject

@property (nonatomic, strong) AVAssetWriter *assetWriter;
@property (nonatomic, strong) AVAssetWriterInput *writerInput;
@property (nonatomic, strong) AVAssetWriterInputPixelBufferAdaptor *bufferAdapter;
@property (nonatomic, strong) NSDictionary *videoSettings;
@property (nonatomic, assign) CMTime frameTime;
@property (nonatomic, strong) NSURL *fileURL;
@property (nonatomic, copy) CEMovieMakerCompletion completionBlock;
- (void)savePlayerItem:(AVPlayerItem *)playerItem toOutputFile:(NSString *)outputFile usingPreset:(NSString *)preset progress:(taskProgressBlock)progressBlock completion:(void(^)(BOOL success, NSString *error))completionBlock;
- (instancetype)initWithSettings:(NSDictionary *)videoSettings;
- (void)createMovieFromImageURLs:(NSArray CE_GENERIC_URL*)urls withCompletion:(CEMovieMakerCompletion)completion;
- (void)createMovieFromImages:(NSArray CE_GENERIC_IMAGE*)images withCompletion:(CEMovieMakerCompletion)completion;
- (void)createMovieFromImage:(UIImage *)image duration:(NSInteger)duration withCompletion:(CEMovieMakerCompletion)completion;
+ (NSDictionary *)videoSettingsWithCodec:(NSString *)codec withWidth:(CGFloat)width andHeight:(CGFloat)height;
@end

NS_ASSUME_NONNULL_END
