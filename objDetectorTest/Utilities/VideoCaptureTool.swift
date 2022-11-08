//
//  VideoCaptureTool.swift
//  objDetectorTest
//
//  Created by raymond on 2022/11/04.
//  Copyright © 2022 IntelligentATLAS. All rights reserved.
//

import Foundation
import UIKit
import AVFoundation
import CoreVideo

public protocol VideoCaptureDelegate: AnyObject {
    func videoCapture(_ capture: VideoCapture, didCaptureVideoFrame: CVPixelBuffer?, timeStamp: CMTime)
}

public class VideoCapture: NSObject {
    public var previewLayer: AVCaptureVideoPreviewLayer?
    public var VCDelegate: VideoCaptureDelegate?
    public var fps = 20

    let captureSession = AVCaptureSession()
    let videoOutput = AVCaptureVideoDataOutput()
    let dispatchQueue = DispatchQueue(label: "Camera queue")

    var lastTimeStamp = CMTime()

    public func sessionSetup(sessionPreset: AVCaptureSession.Preset = .vga640x480, completion: @escaping (Bool) -> Void) {
        self.setupCamera(sessionPreset: sessionPreset,
                         completion: { success in
            completion(success)
        })
    }

    func setupCamera(sessionPreset: AVCaptureSession.Preset,
                     completion: @escaping (_ success: Bool) -> Void) {
        captureSession.beginConfiguration()
        captureSession.sessionPreset = sessionPreset

        guard let captureDevice = AVCaptureDevice.default(.builtInUltraWideCamera,
                                                          for: .video,
                                                          position: .back) else {
            print("Error occured: No available video device")
            return
        }

        guard let videoInput = try? AVCaptureDeviceInput(device: captureDevice) else {
            print("Error: Cannot create AVCaptureDeviceInput")
            return
        }

        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        }

        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = AVLayerVideoGravity.resizeAspect
        previewLayer.connection?.videoOrientation = .portrait
        self.previewLayer = previewLayer

        let settings: [String: Any] = [ kCVPixelBufferPixelFormatTypeKey as String: NSNumber(value: kCVPixelFormatType_32BGRA) ]

        videoOutput.videoSettings = settings
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self,
                                            queue: dispatchQueue)
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }

        videoOutput.connection(with: AVMediaType.video)?.videoOrientation = .portrait

        captureSession.commitConfiguration()

        let success = true
        completion(success)
    }

    public func start() {
        if !captureSession.isRunning {
            captureSession.startRunning()
        }
    }

    public func stop() {
        if captureSession.isRunning {
            captureSession.stopRunning()
        }
    }

}


extension VideoCapture: AVCaptureVideoDataOutputSampleBufferDelegate {
    public func captureOutput(_ output: AVCaptureOutput,
                              didDrop sampleBuffer: CMSampleBuffer,
                              from connection: AVCaptureConnection) {
        let timeStamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
    }
}
