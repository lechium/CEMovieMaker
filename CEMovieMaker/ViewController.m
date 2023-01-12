//
//  ViewController.m
//  CEMovieMaker
//
//  Created by Cameron Ehrlich on 9/17/14.
//  Copyright (c) 2014 Cameron Ehrlich. All rights reserved.
//

#import "ViewController.h"
#import "CEMovieMaker.h"
#import "AVAsset+Extras.h"
#import <AVKit/AVKit.h>
@import MediaPlayer;

@interface ViewController ()

@property (nonatomic, strong) CEMovieMaker *movieMaker;

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    [button setImage:[UIImage imageNamed:@"icon2"] forState:UIControlStateNormal];
    [button setFrame:CGRectMake(0, 0, self.view.bounds.size.width, 100)];
    [button.imageView setContentMode:UIViewContentModeScaleAspectFit];
    [button addTarget:self action:@selector(process:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:button];
}

- (AVPlayerItem *)multiplexVideo:(NSURL *)videoURL withAudio:(AVAsset *)audioAsset  {
    //AVAsset *audioAsset = [AVAsset assetWithURL:audioURL];
    AVAsset *videoAsset = [AVAsset assetWithURL:videoURL];
    NSError *error = nil;
    AVMutableComposition* mixAsset = [[AVMutableComposition alloc] init];
    AVAssetTrack *vt = [videoAsset firstVideoTrack];
    if (vt == nil) {
        vt = [audioAsset firstVideoTrack];
    }
    __block AVAssetTrack *at = [audioAsset firstAudioTrack];
    NSLog(@"duratioN: %f", CMTimeGetSeconds(audioAsset.duration));
    if (at == nil) {
        at = [videoAsset firstAudioTrack];
        if (!at) {
            AVPlayerItem *pi = [AVPlayerItem playerItemWithAsset:audioAsset];
            //AVPlayer *player = [AVPlayer playerWithPlayerItem:pi];
            //[player play];
            /*
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                at = [[[pi tracks] firstObject] assetTrack];
                NSLog(@"audio track: %@ t:%@ pi: %@", at, [pi tracks], pi);
            });*/
            at = [[[pi tracks] firstObject] assetTrack];
        }
    }
    NSLog(@"audioTrack: %@", at);
    AVMutableCompositionTrack* audioTrack = [mixAsset addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
    [audioTrack insertTimeRange:at.timeRange ofTrack:at atTime:kCMTimeZero error: &error];
    AVMutableCompositionTrack* videoTrack = [mixAsset addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
    [videoTrack insertTimeRange:vt.timeRange ofTrack:vt atTime:kCMTimeZero error: &error];
    //DLog(@"timeDiff: %f", [mixAsset timeDifference]);
    AVPlayerItem *playerItem = [AVPlayerItem playerItemWithAsset:mixAsset];
    AVURLAsset *as = (AVURLAsset *)audioAsset;
    playerItem.originalPaths = @[videoURL, as.URL];
    playerItem.alternateTitle = [videoURL.lastPathComponent.stringByDeletingPathExtension stringByAppendingPathExtension:@"mp4"];
    return playerItem;
}

- (void)process:(id)sender
{
    NSMutableArray *frames = [[NSMutableArray alloc] init];
    
    UIImage *icon1 = [UIImage imageNamed:@"icon1"];
    UIImage *icon2 = [UIImage imageNamed:@"icon2"];
    UIImage *icon3 = [UIImage imageNamed:@"icon3"];
    NSURL *audioURL = [NSURL URLWithString:@"audioURL"];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        AVAsset *audioAsset = [AVAsset assetWithURL:audioURL];
        NSURL *imageURL = [NSURL URLWithString:@"imageURL"];
        NSData *imageData = [NSData dataWithContentsOfURL:imageURL];
        UIImage *image = [UIImage imageWithData:imageData];
        NSInteger duration = CMTimeGetSeconds(audioAsset.duration)/2;//(1841696/1000)/2;
        NSDictionary *settings = [CEMovieMaker videoSettingsWithCodec:AVVideoCodecH264 withWidth:image.size.width andHeight:image.size.height];
        self.movieMaker = [[CEMovieMaker alloc] initWithSettings:settings];
        /*
        for (NSInteger i = 0; i < 10; i++) {
            [frames addObject:icon1];
            [frames addObject:icon2];
            [frames addObject:icon3];
        }

        [self.movieMaker createMovieFromImages:[frames copy] withCompletion:^(NSURL *fileURL){
            [self viewMovieAtUrl:fileURL];
        }];
         */
        
        [self.movieMaker createMovieFromImage:image duration:duration withCompletion:^(NSURL *fileURL) {
            NSLog(@"fileULR: %@", fileURL);
            AVPlayerItem *playerItem = [self multiplexVideo:fileURL withAudio:audioAsset];
            AVPlayerViewController *vc = [[AVPlayerViewController alloc] init];
            AVPlayer *player = [[AVPlayer alloc] initWithPlayerItem:playerItem];
            vc.player = player;
            [self presentViewController:vc animated:true completion:nil];
//            [self viewMovieAtUrl:fileURL];
        }];
    });

}

- (void)viewMovieAtUrl:(NSURL *)fileURL
{
    MPMoviePlayerViewController *playerController = [[MPMoviePlayerViewController alloc] initWithContentURL:fileURL];
    [playerController.view setFrame:self.view.bounds];
    [self presentMoviePlayerViewControllerAnimated:playerController];
    [playerController.moviePlayer prepareToPlay];
    [playerController.moviePlayer play];
    [self.view addSubview:playerController.view];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
