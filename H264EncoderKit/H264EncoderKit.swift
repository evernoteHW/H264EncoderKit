//
//  H264EncoderKit.swift
//  H264EncoderKit
//
//  Created by WeiHu on 2016/11/16.
//  Copyright © 2016年 WeiHu. All rights reserved.
//

import UIKit
import AVFoundation
import VideoToolbox


public final class H264EncoderKit: NSObject {
    
    private var inputWidth: Int = 0
    private var inputHeight: Int = 0
    public var outputWidth: Int = 0
    public var outputHeight: Int = 0
    private var aQueue: DispatchQueue?
    private var encodingSession: VTCompressionSession?
    
    private var sps: NSData?
    private var pps: NSData?
    
    private var frameCount: Int = 0
    
    override init() {
        super.init()
       
        print(yuvFile())
        
        self.commmitConfiguration()
    }
    // MARK: - Init
    public convenience init(inputWidth: Int, inputHeight: Int)
    {
        self.init()
        
        self.inputWidth = inputWidth
        self.inputHeight = inputHeight
        
        self.outputWidth = inputWidth
        self.outputHeight = inputHeight
        
        self.commmitConfiguration()
    }
    
    func encode(sampleBuffer: CMSampleBuffer) {
        //这里可以强转的原因是 因为通过
        if let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer), let encodingSession = encodingSession{
            frameCount += 1
            /*! @field value The value of the CMTime. value/timescale = seconds. */
            let presentationTimeStamp = CMTimeMake(Int64(frameCount), 1000)
            let flags = UnsafeMutablePointer<VTEncodeInfoFlags>.allocate(capacity: 1)
            let statusCode = VTCompressionSessionEncodeFrame(encodingSession, imageBuffer, presentationTimeStamp, CMTimeMake(1, 12), nil, nil, flags)
            if statusCode != noErr {
                return
            }
        }
    }
    
    private func commmitConfiguration(){
     
        let status = VTCompressionSessionCreate(nil, Int32(self.inputWidth), Int32(self.inputHeight), kCMVideoCodecType_H264, nil, nil, nil, vt_compression_callback, nil, &encodingSession)
        if status != noErr {
            return
        }
        
        if let encodingSession = encodingSession{
            
            // 设置实时编码输出（避免延迟）
            VTSessionSetProperty(encodingSession, kVTCompressionPropertyKey_RealTime, kCFBooleanTrue)
            VTSessionSetProperty(encodingSession, kVTCompressionPropertyKey_ProfileLevel, kVTProfileLevel_H264_Baseline_AutoLevel)
            
            // 设置关键帧（GOPsize)间隔
            var frameInterval: Int = 2
            if let frameIntervalRef = CFNumberCreate(kCFAllocatorDefault, CFNumberType.intType, &frameInterval){
                VTSessionSetProperty(encodingSession, kVTCompressionPropertyKey_MaxKeyFrameInterval, frameIntervalRef)
            }
            
            // 设置期望帧率
            var fps: Int = 2
            if let fpsRef = CFNumberCreate(kCFAllocatorDefault, CFNumberType.intType, &fps){
                VTSessionSetProperty(encodingSession, kVTCompressionPropertyKey_ExpectedFrameRate, fpsRef);
            }
            
            //设置码率，上限，单位是bps
            var bitRate = self.inputWidth * self.inputHeight ;
            if let bitRateRef = CFNumberCreate(kCFAllocatorDefault, CFNumberType.sInt32Type, &bitRate){
                VTSessionSetProperty(encodingSession, kVTCompressionPropertyKey_AverageBitRate, bitRateRef)
            }
            
            //设置码率，均值，单位是byte
            var bitRateLimit = self.inputWidth * self.inputHeight;
            if let bitRateLimitRef = CFNumberCreate(kCFAllocatorDefault, CFNumberType.sInt32Type, &bitRateLimit){
                VTSessionSetProperty(encodingSession, kVTCompressionPropertyKey_DataRateLimits, bitRateLimitRef)
            }
            
            VTCompressionSessionPrepareToEncodeFrames(encodingSession)  
        }
    }

    // MARK: - Compression callback 一个问号都不能少 血的教训
    private var vt_compression_callback:VTCompressionOutputCallback = {(outputCallbackRefCon: UnsafeMutableRawPointer?, sourceFrameRefCon: UnsafeMutableRawPointer?, status: OSStatus, infoFlags: VTEncodeInfoFlags, sampleBuffer: CMSampleBuffer?) in
        //真正的 264 编码后数据
        
        guard let sampleBuffer:CMSampleBuffer = sampleBuffer, status == noErr else {
            return
        }
        if !CMSampleBufferDataIsReady(sampleBuffer){
            print("数据没有准备好")
            return
        }
        //是否关键帧
        let isKeyframe = !CFDictionaryContainsKey(unsafeBitCast(CFArrayGetValueAtIndex(CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, true), 0), to: CFDictionary.self), unsafeBitCast(kCMSampleAttachmentKey_NotSync, to: UnsafeRawPointer.self))
        
        if isKeyframe{
            //设置 PPS SPS
            if let videoDesc = CMSampleBufferGetFormatDescription(sampleBuffer){

                var sps: UnsafeMutablePointer<UnsafePointer<UInt8>?> = UnsafeMutablePointer<UnsafePointer<UInt8>?>.allocate(capacity: 1)
                var pps: UnsafeMutablePointer<UnsafePointer<UInt8>?> = UnsafeMutablePointer<UnsafePointer<UInt8>?>.allocate(capacity: 1)
                var spsLength: UnsafeMutablePointer<Int> = UnsafeMutablePointer<Int>.allocate(capacity: 1)
                var ppsLength: UnsafeMutablePointer<Int> = UnsafeMutablePointer<Int>.allocate(capacity: 1)
                var spsCount: UnsafeMutablePointer<Int> = UnsafeMutablePointer<Int>.allocate(capacity: 1)
                var ppsCount: UnsafeMutablePointer<Int> = UnsafeMutablePointer<Int>.allocate(capacity: 1)
                
                
                var statusCode = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(videoDesc, 0, sps, spsLength, spsCount, nil)
                if statusCode != noErr{
                    print("sps 失败")
                }
                statusCode = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(videoDesc, 1, pps, ppsLength, ppsCount, nil)
                if statusCode != noErr{
                    print("pps 失败")
                }
              
                if  let sps_pointee = sps.pointee, let pps_pointee = pps.pointee{
                    var sampleData = Data()
                    
                    let naluStart:[UInt8] = [0x00, 0x00, 0x00, 0x01]
                    sampleData.append(naluStart, count: naluStart.count)
                    sampleData.append(sps_pointee, count: spsLength.pointee)
                    
                    sampleData.append(naluStart, count: naluStart.count)
                    sampleData.append(pps_pointee, count: ppsLength.pointee)
                    
                    H264FileHandle.shareInstance.fileHandle.write(sampleData)
                    
                    sps.deallocate(capacity: 1)
                    pps.deallocate(capacity: 1)
                    spsLength.deallocate(capacity: 1)
                    ppsLength.deallocate(capacity: 1)
                    spsCount.deallocate(capacity: 1)
                    ppsCount.deallocate(capacity: 1)
                    
                    sps.deinitialize()
                    pps.deinitialize()
                    spsLength.deinitialize()
                    ppsLength.deinitialize()
                    spsCount.deinitialize()
                    ppsCount.deinitialize()
                }
            }
            //写入视频数据
            
            if let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer){
                var totalLength = Int()
                var length = Int()
                var dataPointer: UnsafeMutablePointer<Int8>?

                let state = CMBlockBufferGetDataPointer(blockBuffer, 0, &length, &totalLength, &dataPointer)
                
                if state == noErr, let dataPointer = dataPointer {
                    var bufferOffset = 0;
                    let AVCCHeaderLength = 4
                    
                    while bufferOffset < totalLength - AVCCHeaderLength {
                        
                        var NALUnitLength:UInt32 = 0
                        memcpy(&NALUnitLength, dataPointer + bufferOffset, AVCCHeaderLength)
                        NALUnitLength = CFSwapInt32BigToHost(NALUnitLength)
                        
                        var naluStart:[UInt8] = [0x00, 0x00, 0x00, 0x01]
                        var buffer = Data()
                        buffer.append(&naluStart, count: naluStart.count)
                        
                        let dataPointer_: UnsafeMutablePointer<UInt8> = unsafeBitCast(dataPointer, to: UnsafeMutablePointer<UInt8>.self)
                        buffer.append(dataPointer_ + bufferOffset + AVCCHeaderLength, count: Int(NALUnitLength))
                        
                        H264FileHandle.shareInstance.fileHandle.write(buffer)
                        bufferOffset += (AVCCHeaderLength + Int(NALUnitLength))
                        
                    }
                }
            }
        }
    
    }
    func yuvFile() -> String {
        do{
            let h264file = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.documentDirectory, FileManager.SearchPathDomainMask.userDomainMask, true)[0]
            let toFile =  "\(h264file)/test.h264"
            if FileManager.default.fileExists(atPath: toFile){
                try FileManager.default.removeItem(atPath: toFile)
            }
            if FileManager.default.createFile(atPath: toFile, contents: nil, attributes: nil){
                print("创建成功")
            }
            return toFile
            
        }catch let error{
            print(error)
        }
        
        return ""
    }

}

