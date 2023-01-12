//
//  MovieMaker.swift
//  CEMovieMaker
//
//  Created by Kevin Bradley on 1/11/23.
//  Copyright © 2023 Cameron Ehrlich. All rights reserved.
//

import Foundation
import AVFoundation
import UIKit
import Photos

@objc class VideoWriter: NSObject {
    
    let renderSettings: RenderSettings
    
    var videoWriter: AVAssetWriter!
    var videoWriterInput: AVAssetWriterInput!
    var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor!
    
    var isReadyForData: Bool {
        return videoWriterInput?.isReadyForMoreMediaData ?? false
    }
    
    /*
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
     */
    
    @objc class func multiplexVideo(_ URL: URL, audioAsset: AVAsset) -> AVPlayerItem {
        let videoAsset = AVAsset(url: URL)
        let mixAsset = AVMutableComposition()
        var vt = videoAsset.firstVideoTrack()
        if vt == nil {
            vt = audioAsset.firstVideoTrack()
        }
        var at = audioAsset.firstAudioTrack()
        if at == nil {
            at = videoAsset.firstAudioTrack()
        }
        print("audioTrack: \(at)")
        let audioTrack = mixAsset.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
        try? audioTrack?.insertTimeRange(at.timeRange, of: at, at: CMTime.zero)
        let videoTrack = mixAsset.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
        try? videoTrack?.insertTimeRange(vt.timeRange, of: vt, at: CMTime.zero)
        let playerItem = AVPlayerItem(asset: mixAsset)
        if let audioA = audioAsset as? AVURLAsset {
            playerItem.originalPaths = [URL, audioA.url];
        }
        return playerItem
    }
    
    class func pixelBufferFromImage(image: UIImage, pixelBufferPool: CVPixelBufferPool, size: CGSize) -> CVPixelBuffer {
        
        var pixelBufferOut: CVPixelBuffer?
        
        let status = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pixelBufferPool, &pixelBufferOut)
        if status != kCVReturnSuccess {
            fatalError("CVPixelBufferPoolCreatePixelBuffer() failed")
        }
        
        let pixelBuffer = pixelBufferOut!
        
        CVPixelBufferLockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
        
        let data = CVPixelBufferGetBaseAddress(pixelBuffer)
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(data: data, width: Int(size.width), height: Int(size.height),
                                bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer), space: rgbColorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue)
        
        context!.clear(CGRect(x:0,y: 0,width: size.width,height: size.height))
        
        let horizontalRatio = size.width / image.size.width
        let verticalRatio = size.height / image.size.height
        //aspectRatio = max(horizontalRatio, verticalRatio) // ScaleAspectFill
        let aspectRatio = min(horizontalRatio, verticalRatio) // ScaleAspectFit
        
        let newSize = CGSize(width: image.size.width * aspectRatio, height: image.size.height * aspectRatio)
        
        let x = newSize.width < size.width ? (size.width - newSize.width) / 2 : 0
        let y = newSize.height < size.height ? (size.height - newSize.height) / 2 : 0
        
        context?.draw(image.cgImage!, in: CGRect(x:x,y: y, width: newSize.width, height: newSize.height))
        CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
        
        return pixelBuffer
    }
    
    init(renderSettings: RenderSettings) {
        self.renderSettings = renderSettings
    }
    
    func start() {
        
        let avOutputSettings: [String: Any] = [
            AVVideoCodecKey: renderSettings.avCodecKey,
            AVVideoWidthKey: NSNumber(value: Float(renderSettings.size.width)),
            AVVideoHeightKey: NSNumber(value: Float(renderSettings.size.height))
        ]
        
        func createPixelBufferAdaptor() {
            let sourcePixelBufferAttributesDictionary = [
                kCVPixelBufferPixelFormatTypeKey as String: NSNumber(value: kCVPixelFormatType_32ARGB),
                kCVPixelBufferWidthKey as String: NSNumber(value: Float(renderSettings.size.width)),
                kCVPixelBufferHeightKey as String: NSNumber(value: Float(renderSettings.size.height))
            ]
            pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: videoWriterInput,
                                                                      sourcePixelBufferAttributes: sourcePixelBufferAttributesDictionary)
        }
        
        func createAssetWriter(outputURL: URL) -> AVAssetWriter {
            guard let assetWriter = try? AVAssetWriter(outputURL: outputURL, fileType: AVFileType.mp4) else {
                fatalError("AVAssetWriter() failed")
            }
            
            guard assetWriter.canApply(outputSettings: avOutputSettings, forMediaType: AVMediaType.video) else {
                fatalError("canApplyOutputSettings() failed")
            }
            
            return assetWriter
        }
        
        videoWriter = createAssetWriter(outputURL: renderSettings.outputURL)
        videoWriterInput = AVAssetWriterInput(mediaType: AVMediaType.video, outputSettings: avOutputSettings)
        
        if videoWriter.canAdd(videoWriterInput) {
            videoWriter.add(videoWriterInput)
        }
        else {
            fatalError("canAddInput() returned false")
        }
        
        // The pixel buffer adaptor must be created before we start writing.
        createPixelBufferAdaptor()
        
        if videoWriter.startWriting() == false {
            fatalError("startWriting() failed")
        }
        
        videoWriter.startSession(atSourceTime: CMTime.zero)
        
        precondition(pixelBufferAdaptor.pixelBufferPool != nil, "nil pixelBufferPool")
    }
    
    func render(appendPixelBuffers: ((VideoWriter)->Bool)?, completion: (()->Void)?) {
        
        precondition(videoWriter != nil, "Call start() to initialze the writer")
        
        let queue = DispatchQueue(label: "mediaInputQueue")
        videoWriterInput.requestMediaDataWhenReady(on: queue) {
            let isFinished = appendPixelBuffers?(self) ?? false
            if isFinished {
                self.videoWriterInput.markAsFinished()
                self.videoWriter.finishWriting() {
                    DispatchQueue.main.async {
                        completion?()
                    }
                }
            }
            else {
                // Fall through. The closure will be called again when the writer is ready.
            }
        }
    }
    
    func addImage(image: UIImage, withPresentationTime presentationTime: CMTime) -> Bool {
        
        precondition(pixelBufferAdaptor != nil, "Call start() to initialze the writer")
        
        let pixelBuffer = VideoWriter.pixelBufferFromImage(image: image, pixelBufferPool: pixelBufferAdaptor.pixelBufferPool!, size: renderSettings.size)
        return pixelBufferAdaptor.append(pixelBuffer, withPresentationTime: presentationTime)
    }
}

@objc class RenderSettings: NSObject {
    
    @objc var size : CGSize = .zero
    @objc var fps: Int32 = 1   // frames per second
    @objc var targetDuration: Float64 = 0.0
    @objc var avCodecKey = AVVideoCodecType.h264
    @objc var videoFilename = "render"
    @objc var videoFilenameExt = "mp4"
    
    
    @objc var outputURL: URL {
        // Use the CachesDirectory so the rendered video file sticks around as long as we need it to.
        // Using the CachesDirectory ensures the file won't be included in a backup of the app.
        let fileManager = FileManager.default
        if let tmpDirURL = try? fileManager.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true) {
            return tmpDirURL.appendingPathComponent(videoFilename).appendingPathExtension(videoFilenameExt)
        }
        fatalError("URLForDirectory() failed")
    }
}

@objc class ImageAnimator: NSObject {
    
    // Apple suggests a timescale of 600 because it's a multiple of standard video rates 24, 25, 30, 60 fps etc.
    static let kTimescale: Int32 = 600
    
    @objc let settings: RenderSettings
    @objc let videoWriter: VideoWriter
    @objc var images: [UIImage]!
    
    var frameNum = 0
    
    @objc class func saveToLibrary(videoURL: URL) {
        PHPhotoLibrary.requestAuthorization { status in
            guard status == .authorized else { return }
            
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: videoURL)
            }) { success, error in
                if !success {
                    print("Could not save video to photo library:", error)
                }
            }
        }
    }
    
    class func removeFileAtURL(fileURL: URL) {
        do {
            try FileManager.default.removeItem(atPath: fileURL.path)
        }
        catch _ as NSError {
            // Assume file doesn't exist.
        }
    }
    
    @objc init(renderSettings: RenderSettings) {
        settings = renderSettings
        videoWriter = VideoWriter(renderSettings: settings)
        //images = loadImages()
    }
    @objc func render(completion: ((URL?)->Void)?) {
        
        // The VideoWriter will fail if a file exists at the URL, so clear it out first.
        ImageAnimator.removeFileAtURL(fileURL: settings.outputURL)
        
        videoWriter.start()
        videoWriter.render(appendPixelBuffers: appendPixelBuffers) {
            ImageAnimator.saveToLibrary(videoURL: self.settings.outputURL)
            completion?(self.settings.outputURL)
        }
        
    }
    
    // This is the callback function for VideoWriter.render()
    func appendPixelBuffers(writer: VideoWriter) -> Bool {
        
        let frameDuration = CMTimeMake(value: Int64(ImageAnimator.kTimescale / settings.fps), timescale: ImageAnimator.kTimescale)
        var sec = CMTimeGetSeconds(frameDuration)
        let isOne = images.count == 1
        print("frameduration: \(frameDuration) seconds: \(sec) imagesCount: \(images.count) isOne: \(isOne)")
        while !images.isEmpty {
            
            if writer.isReadyForData == false {
                // Inform writer we have more buffers to write.
                return false
            }
            let image = images.removeFirst()
            let presentationTime = CMTimeMultiply(frameDuration, multiplier: Int32(frameNum))
            var success = videoWriter.addImage(image: image, withPresentationTime: presentationTime)
            if success == false {
                fatalError("addImage() failed")
            }
            if (isOne) {
                print("td: \(settings.targetDuration)")
                if settings.targetDuration > 0 {
                    //let presentationEnd = CMTimeMultiply(frameDuration, multiplier: Int32(settings.targetDuration))
                    let presentationEnd = CMTimeMakeWithSeconds(settings.targetDuration/2, preferredTimescale: ImageAnimator.kTimescale)
                    sec = CMTimeGetSeconds(presentationEnd)
                    print("presentationEnd: \(presentationEnd) seconds: \(sec)")
                    success = videoWriter.addImage(image: image, withPresentationTime: presentationEnd)
                    if success == false {
                        print("fail")
                    }
                }
            }
            frameNum += 1
        }
        
        // Inform writer all buffers have been written.
        return true
    }
}
