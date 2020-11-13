//
//  VideoProcessingController.swift
//  VideoConcatOverlay
//
//  Created by Volodymyr Fedorenko on 15.09.2020.
//  Copyright © 2020 -. All rights reserved.
//

import UIKit
import AVFoundation
import MobileCoreServices
import AVKit

class VideoProcessingController: UIViewController {
    enum SelectVideoButtonTag:Int {
        case first = 0, second, third
    }
   
    @IBOutlet private weak var firstVideoPreviewImageView: UIImageView!
    @IBOutlet private weak var secondVideoPreviewImageView: UIImageView!
    @IBOutlet private weak var thirdVideoPreviewImageView: UIImageView!
    
    @IBOutlet private weak var firstVideoSelectButton: UIButton!
    @IBOutlet private weak var secondVideoSelectButton: UIButton!
    @IBOutlet private weak var thirdVideoSelectButton: UIButton!
    
    
    @IBOutlet private weak var processButton: UIButton!
    @IBOutlet private weak var processingActivityIndicator: UIActivityIndicatorView!
    
    @IBOutlet private weak var viewResultButton: UIButton!
    
    private var firstVideoAsset: AVURLAsset? {
        didSet {
            DispatchQueue.main.async { [weak self] in
                if let firstVideoAsset = self?.firstVideoAsset {
                    self?.firstVideoPreviewImageView.image = VideoProcessorHelper.thumbnail(for: firstVideoAsset)
                }
            }
        }
    }
    private var secondVideoAsset: AVURLAsset? {
        didSet {
            DispatchQueue.main.async { [weak self] in
                if let secondVideoAsset = self?.secondVideoAsset {
                    self?.secondVideoPreviewImageView.image = VideoProcessorHelper.thumbnail(for: secondVideoAsset)
                }
            }
        }
    }
    private var thirdVideoAsset: AVURLAsset?{
        didSet {
            DispatchQueue.main.async { [weak self] in
                if let thirdVideoAsset = self?.thirdVideoAsset {
                    self?.thirdVideoPreviewImageView.image = VideoProcessorHelper.thumbnail(for: thirdVideoAsset)
                }
            }
        }
    }
    private var selectionForButtonTag: SelectVideoButtonTag = .first
    
    private var pickerController = UIImagePickerController()
    private var exportedVideoURL: URL?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        pickerController.delegate = self
        pickerController.mediaTypes = [kUTTypeMovie as String]
        pickerController.sourceType = .savedPhotosAlbum
        exportedVideoURL = VideoProcessorHelper.outputURL()
    }
    
    // MARK: - Actions
    
    @IBAction private func selectVideoButtonAction(_ sender: UIButton) {
        present(pickerController, animated: true)
        selectionForButtonTag = SelectVideoButtonTag(rawValue: sender.tag) ?? .first
    }

    @IBAction private func processButtonAction(_ sender: UIButton) {
        if let firstAsset = firstVideoAsset, let secondAsset = secondVideoAsset, let thirdAsset = thirdVideoAsset {
            if let exportedVideoURL = exportedVideoURL {
                try? FileManager.default.removeItem(at: exportedVideoURL)
            }
            processingUIState()
            VideoProcessorHelper.concatOverlay(first: firstAsset, second: secondAsset, overlay: thirdAsset) { status in
                DispatchQueue.main.async {
                    switch status {
                    case .completed:
                        self.completedUIState()
                    case .failed:
                        self.failedUIState()
                    default:
                        break
                    }
                }
            }
        }
    }
    
    @IBAction private func viewResultButtonAction(_ sender: UIButton) {
        guard let videoURL = exportedVideoURL else {
            return
        }
        let player = AVPlayer(url: videoURL)
        let playerController = AVPlayerViewController()
        playerController.player = player
        present(playerController, animated: true) {
            player.play()
        }
    }
    
    // MARK: - Helpers
    
    private func updateProcessButtonState() {
        processButton.isEnabled = firstVideoAsset != nil && secondVideoAsset != nil && thirdVideoAsset != nil
    }
    
    private func completedUIState() {
        processingActivityIndicator.stopAnimating()
        firstVideoSelectButton.isEnabled = true
        secondVideoSelectButton.isEnabled = true
        thirdVideoSelectButton.isEnabled = true
        
        processButton.isEnabled = true
        
        viewResultButton.isEnabled = true
    }
    
    private func processingUIState() {
        processingActivityIndicator.startAnimating()
        firstVideoSelectButton.isEnabled = false
        secondVideoSelectButton.isEnabled = false
        thirdVideoSelectButton.isEnabled = false
        
        processButton.isEnabled = false
        
        viewResultButton.isEnabled = false
    }
    
    private func failedUIState() {
        processingActivityIndicator.stopAnimating()
        firstVideoSelectButton.isEnabled = true
        secondVideoSelectButton.isEnabled = true
        thirdVideoSelectButton.isEnabled = true
        
        processButton.isEnabled = true
        
        viewResultButton.isEnabled = false
    }
}

// MARK: - UIImagePickerControllerDelegate

extension VideoProcessingController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        if let videoURL = info[.mediaURL] as? URL {
            let asset = AVURLAsset(url: videoURL)
            
            switch selectionForButtonTag {
            case .first:
                firstVideoAsset = asset
            case .second:
                secondVideoAsset = asset
            case .third:
                thirdVideoAsset = asset
            }
        }
        dismiss(animated: true)
        updateProcessButtonState()
    }
}

