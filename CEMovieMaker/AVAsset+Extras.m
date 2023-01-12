#import "AVAsset+Extras.h"
#import <objc/runtime.h>


@implementation AVPlayerItem (Extras)

- (void)setOriginalPaths:(NSArray *)originalPaths {
    objc_setAssociatedObject(self, @selector(originalPaths), originalPaths, OBJC_ASSOCIATION_RETAIN);
}

- (NSArray *)originalPaths {
    return objc_getAssociatedObject(self, @selector(originalPaths));
}

- (void)setAlternateTitle:(NSString *)alternateTitle {
    objc_setAssociatedObject(self, @selector(alternateTitle), alternateTitle, OBJC_ASSOCIATION_RETAIN);
}

- (NSString *)alternateTitle {
    return objc_getAssociatedObject(self, @selector(alternateTitle));
}
@end

@implementation AVAsset (Extras)

- (void)setExportRange:(CMTimeRange)exportRange {
    NSValue *enc = [NSValue valueWithBytes:&exportRange objCType:@encode(CMTimeRange)];
    objc_setAssociatedObject(self, @selector(exportRange), enc, OBJC_ASSOCIATION_RETAIN);
}

- (CMTimeRange)exportRange {
    NSValue *assoc = objc_getAssociatedObject(self, @selector(exportRange));
    CMTimeRange r;
    [assoc getValue:&r];
    return r;
}

- (AVAssetTrack *)firstMuxedTrack {
    return [[self tracksWithMediaType:AVMediaTypeMuxed] firstObject];
}

- (AVAssetTrack *)firstVideoTrack {
    return [[self tracksWithMediaType:AVMediaTypeVideo] firstObject];
}

- (AVAssetTrack *)firstAudioTrack {
    return [[self tracksWithMediaType:AVMediaTypeAudio] firstObject];
}

- (CGFloat)timeDifference {
    CMTime v = [self firstVideoTrack].timeRange.duration;
    CMTime a = [self firstAudioTrack].timeRange.duration;
    return (CMTimeGetSeconds(v) - CMTimeGetSeconds(a));
}

- (NSURL *)assetURLIfApplicable {
    if([self isKindOfClass:[AVURLAsset class]]){
        return [(AVURLAsset *)self URL];
    }
    return nil;
}

- (NSString *)assetPathIfApplicable {
    if([self isKindOfClass:[AVURLAsset class]]){
        return [[(AVURLAsset *)self URL] path];
    }
    return nil;
}

- (BOOL)hasClosedCaptions {
    AVMediaSelectionGroup *group = [self mediaSelectionGroupForMediaCharacteristic:AVMediaCharacteristicLegible];
    NSPredicate *pred = [NSPredicate predicateWithFormat:@"mediaType == %@",AVMediaTypeClosedCaption];
    AVMediaSelectionOption *opt = [[group.options filteredArrayUsingPredicate:pred] firstObject];
    return (opt != nil);
}

- (BOOL)isHD {
    AVAssetTrack *track = [[self tracksWithMediaCharacteristic:AVMediaCharacteristicVisual] firstObject];
    CGSize trackSize = [track naturalSize];
    return trackSize.width >= 1280;
}
@end
