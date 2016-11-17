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
    
    private var inputWidth: Int = 480
    private var inputHeight: Int = 640
    public var outputWidth: Int = 0
    public var outputHeight: Int = 0
    private var aQueue: DispatchQueue?
    private var encodingSession: VTCompressionSession?
    
    private var sps: NSData?
    private var pps: NSData?
    
    var frameCount: Int = 0
    
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
        if let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer){
            frameCount += 1
            /*! @field value The value of the CMTime. value/timescale = seconds. */
            let presentationTimeStamp = CMTimeMake(Int64(frameCount), 300)
            //包含 编码的信息
            var flags: VTEncodeInfoFlags = VTEncodeInfoFlags()
            let statusCode = VTCompressionSessionEncodeFrame(encodingSession!, imageBuffer, presentationTimeStamp, kCMTimeInvalid, nil, nil, &flags)
            if statusCode != noErr {
                return
            }
            if flags.rawValue == 1{
                
            }
            
        }
        
    }
    
    private func commmitConfiguration(){
        
        let status = VTCompressionSessionCreate(nil, Int32(self.inputWidth), Int32(self.inputHeight), kCMVideoCodecType_H264, nil, nil, nil, vt_compression_callback, nil, &encodingSession)
        if status != noErr {
            return
        }
        
        if let encodingSession = encodingSession{
            //toolbox session 属性设置
            VTSessionSetProperty(encodingSession, kVTCompressionPropertyKey_RealTime, kCFBooleanTrue)
//            VTSessionSetProperty(encodingSession, kVTCompressionPropertyKey_AllowFrameReordering, kCFBooleanFalse)
//            VTSessionSetProperty(encodingSession, kVTCompressionPropertyKey_AverageBitRate, Int(1280*720) as CFTypeRef)
//            VTSessionSetProperty(encodingSession, kVTCompressionPropertyKey_ExpectedFrameRate, NSNumber(value: 30.0))
//            VTSessionSetProperty(encodingSession, kVTCompressionPropertyKey_MaxKeyFrameInterval, 240 as CFTypeRef)
            VTSessionSetProperty(encodingSession, kVTCompressionPropertyKey_ProfileLevel, kVTProfileLevel_H264_Main_AutoLevel)
//            VTSessionSetProperty(encodingSession, kVTCompressionPropertyKey_MaxKeyFrameIntervalDuration, NSNumber(value: 2.0))
            
            VTCompressionSessionPrepareToEncodeFrames(encodingSession)  
        }
    }

    // MARK: - Compression callback 一个问号都不能少 血的教训
    private var vt_compression_callback:VTCompressionOutputCallback = {(outputCallbackRefCon: UnsafeMutableRawPointer?, sourceFrameRefCon: UnsafeMutableRawPointer?, status: OSStatus, infoFlags: VTEncodeInfoFlags, sampleBuffer: CMSampleBuffer?) in
        //真正的 264 编码原图
        var sampleData: Data = Data()
        guard let sampleBuffer:CMSampleBuffer = sampleBuffer, status == noErr else {
            return
        }
        if !CMSampleBufferDataIsReady(sampleBuffer){
            print("数据没有准备好")
            return
        }
        
        
        let encoder:H264EncoderKit = unsafeBitCast(outputCallbackRefCon, to: H264EncoderKit.self)
        //是否关键帧
        let isKeyframe = !CFDictionaryContainsKey(unsafeBitCast(CFArrayGetValueAtIndex(CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, true), 0), to: CFDictionary.self), unsafeBitCast(kCMSampleAttachmentKey_NotSync, to: UnsafeRawPointer.self))
        
        if isKeyframe{
            //设置 PPS SPS
            print("isKeyframe")
            if let videoDesc = CMSampleBufferGetFormatDescription(sampleBuffer){

        

                var sps: UnsafePointer<UInt8>?
                var pps: UnsafePointer<UInt8>?
                var spsLength: Int = 0
                var ppsLength: Int = 0
                var spsCount: Int = 0
                var ppsCount: Int = 0
                
                
                var statusCode = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(videoDesc, 0, &sps, &spsLength, &spsCount, nil)
                if statusCode != noErr{
                    print("sps 失败")
                }
                statusCode = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(videoDesc, 1, &pps, &ppsLength, &ppsCount, nil)
                if statusCode != noErr{
                    print("pps 失败")
                }
                print("\(spsLength)---- \(spsCount) --- \(sps)")
                print("\(ppsLength)---- \(ppsCount) --- \(pps)")

                if let sps = sps, let pps = pps{
                    let naluStart:[UInt8] = [0x00, 0x00, 0x00, 0x01]
                    sampleData.append(naluStart, count: naluStart.count)
                    sampleData.append(sps, count: spsLength)
                    
                    sampleData.append(naluStart, count: naluStart.count)
                    sampleData.append(pps, count: ppsLength)
                    
                    H264FileHandle.shareInstance.fileHandle.write(sampleData)
                    
                }
              
            }
            //写入视频数据
            
            if let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer){
                var totalLength = Int()
                var length = Int()
                var dataPointer: UnsafeMutablePointer<Int8>?

                let state = CMBlockBufferGetDataPointer(blockBuffer, 0, &length, &totalLength, &dataPointer)
                
                if state == noErr {
                    var bufferOffset = 0;
                    let AVCCHeaderLength = 4
                    
                    while bufferOffset < totalLength - AVCCHeaderLength {
                        var NALUnitLength:UInt32 = 0
                        memcpy(&NALUnitLength, dataPointer! + bufferOffset, AVCCHeaderLength)
                        NALUnitLength = CFSwapInt32BigToHost(NALUnitLength)
                        
                        var naluStart:[UInt8] = [0x00, 0x00, 0x00, 0x01]
                        var buffer = Data()
                        buffer.append(&naluStart , count: naluStart.count)
                        
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

