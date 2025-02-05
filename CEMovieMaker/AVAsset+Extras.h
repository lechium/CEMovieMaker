#import <AVFoundation/AVFoundation.h>
#import <objc/runtime.h>

NS_ASSUME_NONNULL_BEGIN

@interface AVPlayerItem (Extras)
@property NSString *alternateTitle;
@property NSArray *originalPaths;
@end

@interface AVAsset (Extras)
@property CMTimeRange exportRange;
- (NSURL *)assetURLIfApplicable;
- (BOOL)isHD;
- (BOOL)hasClosedCaptions;
- (NSString *)assetPathIfApplicable;
- (AVAssetTrack * _Nullable)firstVideoTrack;
- (AVAssetTrack * _Nullable)firstAudioTrack;
- (CGFloat)timeDifference;
- (AVAssetTrack * _Nullable)firstMuxedTrack;
@end

NS_ASSUME_NONNULL_END
