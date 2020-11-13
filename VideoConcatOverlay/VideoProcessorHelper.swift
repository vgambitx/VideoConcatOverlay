//
//  VideoProcessorHelper.swift
//  VideoConcatOverlay
//
//  Created by Volodymyr Fedorenko on 15.09.2020.
//  Copyright © 2020 -. All rights reserved.
//

import UIKit
import AVFoundation

class VideoProcessorHelper {
    
    class func thumbnail(for asset: AVAsset) -> UIImage? {
        var image: UIImage? = nil
        do {
            let assetImageGenerator = AVAssetImageGenerator(asset: asset)
            assetImageGenerator.appliesPreferredTrackTransform = true
            let cgImage = try assetImageGenerator.copyCGImage(at: CMTime(value: 0, timescale: 1), actualTime: nil)
            image = UIImage(cgImage: cgImage)
        } catch let error {
            print(error.localizedDescription)
        }
        return image
    }
    
    class func concatOverlay(first firstAsset: AVURLAsset, second secondAsset: AVURLAsset, overlay thirdAsset: AVURLAsset, scale scaleFactor: CGFloat = 0.25, completionHandler handler: @escaping (AVAssetExportSession.Status) -> Void){

        let mixComposition = AVMutableComposition()

        guard let joinedVideoTrack = mixComposition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
            let concatedAudioTrack = mixComposition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid),
            let overlayVideoTrack = mixComposition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
                handler(.failed)
                return
        }

        guard let firstVideoTrack = firstAsset.tracks(withMediaType: .video).first,
            let firstAudioTrack = firstAsset.tracks(withMediaType: .audio).first,
            let secondVideoTrack = secondAsset.tracks(withMediaType: .video).first,
            let secondAudioTrack = secondAsset.tracks(withMediaType: .audio).first,
            let thirdVideoTrack = thirdAsset.tracks(withMediaType: .video).first else {
                handler(.failed)
                return
                
        }
        let firstAssetDuration = firstAsset.duration
        let secondAssetDuration = secondAsset.duration
        

        do {
            let firstTimeRange = CMTimeRange(start: .zero, duration: firstAssetDuration)
            try joinedVideoTrack.insertTimeRange(firstTimeRange, of: firstVideoTrack, at: .zero)
            try concatedAudioTrack.insertTimeRange(firstTimeRange, of: firstAudioTrack, at: .zero)
            
            let secondTimeRange = CMTimeRange(start: .zero, duration: secondAssetDuration)
            try joinedVideoTrack.insertTimeRange(secondTimeRange, of: secondVideoTrack, at: firstAssetDuration)
            
            try overlayVideoTrack.insertTimeRange(CMTimeRange(start: .zero, duration: thirdAsset.duration), of: thirdVideoTrack, at: .zero)
            try concatedAudioTrack.insertTimeRange(secondTimeRange, of: secondAudioTrack, at: firstAssetDuration)
            
        } catch (let error) {
            print(error)
            handler(.failed)
        }

        let width = max(firstVideoTrack.naturalSize.width, secondVideoTrack.naturalSize.width)
        let height = max(firstVideoTrack.naturalSize.height, secondVideoTrack.naturalSize.height)
        
        
        let joinedLayerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: joinedVideoTrack)
        joinedLayerInstruction.setTransform(firstVideoTrack.preferredTransform, at: .zero)
        joinedLayerInstruction.setOpacity(1.0, at: .zero)
        
        let overlayLayerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: overlayVideoTrack)
        overlayLayerInstruction.setTransform(overlayVideoTrack.preferredTransform.translatedBy(x: 0.0, y: height - firstVideoTrack.naturalSize.height * scaleFactor).scaledBy(x: scaleFactor, y: scaleFactor), at: .zero)
        overlayLayerInstruction.setOpacity(1.0, at: .zero)
    
        
        let combined = AVMutableVideoCompositionInstruction()
        combined.timeRange = CMTimeRange(start: .zero, duration: max(CMTimeAdd(firstAssetDuration, secondAssetDuration), thirdAsset.duration))
        combined.backgroundColor = UIColor.clear.cgColor
        combined.layerInstructions = [overlayLayerInstruction, joinedLayerInstruction]
        
        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = CGSize(width: width, height: height)
        videoComposition.frameDuration = CMTimeMake(value: 1, timescale: 30)
        
        
        videoComposition.instructions = [combined]

        if let outputURL = outputURL() {
            exportCompositedVideo(compiledVideo: mixComposition, output: outputURL, composition: videoComposition, completionHandler: handler)
        }
    }
    
    private class func exportCompositedVideo(compiledVideo: AVMutableComposition, output outputUrl: URL, composition videoComposition: AVMutableVideoComposition, completionHandler handler: @escaping (AVAssetExportSession.Status) -> Void) {
        guard let exporter = AVAssetExportSession(asset: compiledVideo, presetName: AVAssetExportPresetHighestQuality) else { return }
        exporter.outputURL = outputUrl
        exporter.videoComposition = videoComposition
        exporter.outputFileType = .mp4
        exporter.shouldOptimizeForNetworkUse = true
        exporter.exportAsynchronously(completionHandler: {
            handler(exporter.status)
            switch exporter.status {
            case .completed:
                print("Completed")
            case .exporting:
                print("Exporting")
            case .failed:
                print("Error: \(exporter.error?.localizedDescription ?? "unknown")")
            default:
                break
            }
        })
    }
    
    class func outputURL() -> URL? {
        return FileManager.default.urls(for: .cachesDirectory, in: .allDomainsMask).first?.appendingPathComponent("test.mov")
    }
    
}
