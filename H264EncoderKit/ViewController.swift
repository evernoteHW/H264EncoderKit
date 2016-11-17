//
//  ViewController.swift
//  H264EncoderKit
//
//  Created by WeiHu on 2016/11/16.
//  Copyright © 2016年 WeiHu. All rights reserved.
//

import UIKit
import AVFoundation

class ViewController: UIViewController {
    var h264Encoder: H264EncoderKit!

    override func viewDidLoad() {
        super.viewDidLoad()
        self.startCamara()
        self.configureSettings()
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    func configureSettings() {
        h264Encoder = H264EncoderKit()
        
    }
    func startCamara()  {
        do{
            //自定义摄像头
            // input device
            let cameraDevice = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeVideo)
            let inputDevice = try AVCaptureDeviceInput(device: cameraDevice)
            
            // output device
            let outputDevice = AVCaptureVideoDataOutput()
            outputDevice.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String : NSNumber(value: kCVPixelFormatType_32BGRA)]
            //在某个线程进行回调 是否要在主线程回调 待研究
            outputDevice.setSampleBufferDelegate(self, queue: DispatchQueue.main)
            
            // capture session
            let captureSession = AVCaptureSession()
            captureSession.addInput(inputDevice)
            captureSession.addOutput(outputDevice)
            captureSession.beginConfiguration()
            //设置分辨率
            captureSession.canSetSessionPreset(AVCaptureSessionPreset1280x720)
            
            // connection
            if let connection = outputDevice.connection(withMediaType: AVMediaTypeVideo){
                connection.videoOrientation = .portrait;
            }
            //完成配置
            captureSession.commitConfiguration()
            
            if let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession){
                previewLayer.videoGravity = AVLayerVideoGravityResizeAspect
                previewLayer.frame = self.view.bounds
                self.view.layer.addSublayer(previewLayer)
            }
            
            captureSession.startRunning()
            
        }catch let error {
            print(error)
        }
    }
}
extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate{
    func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, from connection: AVCaptureConnection!) {
        h264Encoder.encode(sampleBuffer: sampleBuffer)
    }
}

