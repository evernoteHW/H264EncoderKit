//
//  H264DeconderKit.swift
//  H264EncoderKit
//
//  Created by WeiHu on 2016/11/17.
//  Copyright © 2016年 WeiHu. All rights reserved.
//

import UIKit
import VideoToolbox

class H264DeconderKit: NSObject {
    
    static let defaultAttributes:[NSString: AnyObject] = [
        kCVPixelBufferPixelFormatTypeKey: Int(kCVPixelFormatType_32BGRA) as AnyObject,
        kCVPixelBufferIOSurfacePropertiesKey: [:] as AnyObject,
        kCVPixelBufferOpenGLESCompatibilityKey: true as AnyObject,
        ]
    
    public var outputWidth: Int = 720
    public var outputHeight: Int = 1280
    
    private var deEncodingSession: VTDecompressionSession?
    
    private var sps: UnsafeMutableRawPointer?
    private var pps: UnsafeMutableRawPointer?
  
    private var formatDescriptionOut: UnsafeMutablePointer<CMFormatDescription?>?
    private var spsSize: Int = 0
    private var ppsSize: Int = 0
    
    private var frameCount: Int = 0
    fileprivate var attributes:[NSString:  AnyObject] {
        return H264DeconderKit.defaultAttributes
    }
    fileprivate var _session:VTDecompressionSession? = nil
    fileprivate var session:VTDecompressionSession! {
        get {
            if (_session == nil)  {
                guard let formatDescription:CMFormatDescription = formatDescription else {
                    return nil
                }
                var record:VTDecompressionOutputCallbackRecord = VTDecompressionOutputCallbackRecord(
                    decompressionOutputCallback: vt_decompression_callback,
                    decompressionOutputRefCon: unsafeBitCast(self, to: UnsafeMutableRawPointer.self)
                )
                guard VTDecompressionSessionCreate(
                    kCFAllocatorDefault,
                    formatDescription,
                    nil,
                    attributes as CFDictionary?,
                    &record,
                    &_session ) == noErr else {
                        return nil
                }
                //                invalidateSession = false
            }
            return _session!
        }
        set {
            if let session:VTDecompressionSession = _session {
                VTDecompressionSessionInvalidate(session)
            }
            _session = newValue
        }
    }
    
    
    override init() {
        super.init()
    
        
    }
    // MARK: - Init
    public convenience init(outputWidth: Int, outputHeight: Int)
    {
        self.init()
        
        self.outputWidth = outputWidth
        self.outputHeight = outputHeight
        
        
    }
    
    func deEncode(size: Int, buffer: UnsafeMutablePointer<UInt8>) -> CVPixelBuffer? {
        //这里可以强转的原因是 因为通过
        var outputPixelBuffer: UnsafeMutableRawPointer?
        var blockBuffer: CMBlockBuffer?
        var status = CMBlockBufferCreateWithMemoryBlock(kCFAllocatorDefault, buffer, size, kCFAllocatorNull, nil, 0, size, 0, &blockBuffer)
        if status == kCMBlockBufferNoErr {
            let sampleBuffer: UnsafeMutablePointer<CMSampleBuffer?> = UnsafeMutablePointer<CMSampleBuffer?>.allocate(capacity: 1)
            let sampleSizeArray = [size]
            status = CMSampleBufferCreateReady(kCFAllocatorDefault, blockBuffer, formatDescriptionOut?.pointee, 1, 0, nil, 1, sampleSizeArray, sampleBuffer)
            if status == kCMBlockBufferNoErr,let sampleBuffer_pointee = sampleBuffer.pointee, let deEncodingSession = deEncodingSession {
//                VTDecompressionSessionDecodeFrame(_ session: VTDecompressionSession, _ sampleBuffer: CMSampleBuffer, _ decodeFlags: VTDecodeFrameFlags, _ sourceFrameRefCon: UnsafeMutableRawPointer?, _ infoFlagsOut: UnsafeMutablePointer<VTDecodeInfoFlags>?) -> OSStatus

                let flags: VTDecodeFrameFlags  = VTDecodeFrameFlags(rawValue: 0);
                var flagOut: VTDecodeInfoFlags  = VTDecodeInfoFlags(rawValue: 0);
                let _ = VTDecompressionSessionDecodeFrame(deEncodingSession, sampleBuffer_pointee, flags, &outputPixelBuffer, &flagOut)
                print(kVTVideoDecoderMalfunctionErr)
//                switch decodeStatus {
//                case kVTInvalidSessionErr:
//                    print("IOS8VT: Invalid session, reset decoder session")
//                case kVTVideoDecoderBadDataErr:
//                    print("IOS8VT: decode failed status=\(decodeStatus)(Bad data)")
//                case noErr:
//                    print("IOS8VT: decode failed status=\(decodeStatus)")
//                default:
//                    break
//                }
            }
        }
        free(outputPixelBuffer)
        return nil
    }
    
    private func commmitConfiguration(){
        if let _ = deEncodingSession {
            return
        }
        //创建解码Session
        let parameterSetPointers: [UnsafePointer<UInt8>] = [unsafeBitCast(sps, to: UnsafePointer<UInt8>.self),unsafeBitCast(pps, to: UnsafePointer<UInt8>.self)]
        let parameterSetSizes: [Int] = [spsSize, ppsSize]
        formatDescriptionOut = UnsafeMutablePointer<CMFormatDescription?>.allocate(capacity: 1)
        let statusCode = CMVideoFormatDescriptionCreateFromH264ParameterSets(kCFAllocatorDefault, 2, parameterSetPointers, parameterSetSizes, 4, formatDescriptionOut!)
        if statusCode != noErr{
            return
        }
        var decompressionOutputRefCon: UnsafeMutableRawPointer?
        var callBackRecord = VTDecompressionOutputCallbackRecord(decompressionOutputCallback: vt_decompression_callback, decompressionOutputRefCon: &decompressionOutputRefCon)
        if decompressionOutputRefCon != nil {
            
        }
        if let formatDescriptionOut_pointee = formatDescriptionOut?.pointee{

            guard VTDecompressionSessionCreate(kCFAllocatorDefault, formatDescriptionOut_pointee, nil, nil, &callBackRecord, &deEncodingSession) == noErr else{
            
                print("")
                return
            }
            if let deEncodingSession = deEncodingSession{
                
                var bitRate = self.outputWidth * self.outputHeight
                if let bitRateRef = CFNumberCreate(kCFAllocatorDefault, CFNumberType.sInt32Type, &bitRate){
                    VTSessionSetProperty(deEncodingSession, kCVPixelBufferPixelFormatTypeKey, bitRateRef)
                }
                VTDecompressionSessionCanAcceptFormatDescription(deEncodingSession, formatDescriptionOut_pointee)
            }
        }
    }

    // MARK: - Compression callback 一个问号都不能少 血的教训
    private var vt_decompression_callback: VTDecompressionOutputCallback = {(decompressionOutputRefCon: UnsafeMutableRawPointer?, sourceFrameRefCon: UnsafeMutableRawPointer?, status: OSStatus, infoFlags: VTDecodeInfoFlags, pixelBuffer: CVImageBuffer?, presentationTimeStamp: CMTime, presentationDuration: CMTime) in
        //真正的 264 编码后数据
//        sourceFrameRefCon.base
//        let outputPixelBuffer = unsafeBitCast(Unmanaged.passUnretained(pixelBuffer!).toOpaque(), to: CVPixelBuffer.self)
//        if let _ = sourceFrameRefCon{
//            let cvpixelBuffer = unsafeBitCast(sourceFrameRefCon, to: CVPixelBuffer.self)
//        }
//        sourceFrameRefCon_.pointee = outputPixelBuffer
        
//        outputPixelBuffer
        print(55555555555)
        
    }
    
    func decodeFile(fileName: String, fileExt: String) {
        let parser = H264InputStream()
        
        while true {
            let vp: VideoPacket? = parser.nextPacket()
            if let vp = vp {
                let nalSize = vp.size - 4
                let pNalSize = UnsafeMutablePointer<UInt8>.allocate(capacity: nalSize)
                vp.buffer[0] = pNalSize.pointee + 3
                vp.buffer[1] = pNalSize.pointee + 2
                vp.buffer[2] = pNalSize.pointee + 1
                vp.buffer[3] = pNalSize.pointee
                
                var pixelBuffer: CVPixelBuffer?
                let nalType = vp.buffer[4] & 0x1F
                switch nalType {
                    case 0x05:
                        self.commmitConfiguration()
                        pixelBuffer = self.deEncode(size: vp.size,buffer: vp.buffer )
                    case 0x07:
                        spsSize = vp.size - 4
                        sps = unsafeBitCast(malloc(spsSize), to: UnsafeMutableRawPointer.self)
                        memcpy(sps, vp.buffer + 4, spsSize);
                    case 0x08:
                        ppsSize = vp.size - 4;
                        pps = unsafeBitCast(malloc(ppsSize), to: UnsafeMutableRawPointer.self)
                        memcpy(pps, vp.buffer + 4, ppsSize);
                default:
                    pixelBuffer = self.deEncode(size: vp.size,buffer: vp.buffer )
                }
                
                //渲染数据
                if let pixelBuffer = pixelBuffer{
                    print("width===\(CVPixelBufferGetWidth(pixelBuffer))  height===\(CVPixelBufferGetHeight(pixelBuffer))")
                    
                }
            }
        }
    }
 

}
