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
    
    public var outputWidth: Int = 720
    public var outputHeight: Int = 1280
    
    private var deEncodingSession: VTDecompressionSession?
    
    private var sps: UnsafeMutablePointer<UInt8>?
    private var pps: UnsafeMutablePointer<UInt8>?
  
    private var spsSize: Int = 0
    private var ppsSize: Int = 0
    
    private var frameCount: Int = 0
    
    override init() {
        super.init()
    
        self.commmitConfiguration()
    }
    // MARK: - Init
    public convenience init(outputWidth: Int, outputHeight: Int)
    {
        self.init()
        
        self.outputWidth = outputWidth
        self.outputHeight = outputHeight
        
        self.commmitConfiguration()
    }
    
    func deEncode(size: Int, buffer: UnsafeMutablePointer<UInt8>) -> CVPixelBuffer? {
        //这里可以强转的原因是 因为通过
     
        return nil
    }
    
    private func commmitConfiguration(){
        
        //创建解码Session
//        let parameterSetPointers: UnsafePointer<UnsafePointer<UInt8>> = UnsafePointer<UnsafePointer<UInt8>>.init(bitPattern: 1)!
//        let parameterSetSizes = UnsafePointer<Int>.init(bitPattern: 1)!
//        let formatDescriptionOut = UnsafeMutablePointer<CMFormatDescription?>.allocate(capacity: 1)
//        let statusCode = CMVideoFormatDescriptionCreateFromH264ParameterSets(kCFAllocatorDefault, 2, parameterSetPointers, parameterSetSizes, 4, formatDescriptionOut)
//        if statusCode != noErr{
//            return
//        }
//        var decompressionOutputRefCon: UnsafeMutableRawPointer?
//        var callBackRecord = VTDecompressionOutputCallbackRecord(decompressionOutputCallback: vt_decompression_callback, decompressionOutputRefCon: &decompressionOutputRefCon)
//        if decompressionOutputRefCon != nil {
//            
//        }
//        if let formatDescriptionOut_pointee = formatDescriptionOut.pointee{
//            VTDecompressionSessionCreate(kCFAllocatorDefault, formatDescriptionOut_pointee, nil, nil, &callBackRecord, &deEncodingSession)
//            
//            if let deEncodingSession = deEncodingSession{
//                //设置码率，上限，单位是bps
//                var bitRate = self.outputWidth * self.outputHeight ;
//                if let bitRateRef = CFNumberCreate(kCFAllocatorDefault, CFNumberType.sInt32Type, &bitRate){
//                    VTSessionSetProperty(deEncodingSession, kCVPixelFormatType_420YpCbCr8BiPlanarFullRange as! CFString, bitRateRef)
//                }
//                VTDecompressionSessionCanAcceptFormatDescription(deEncodingSession, formatDescriptionOut_pointee)
//                
//            }
//        }
    }

    // MARK: - Compression callback 一个问号都不能少 血的教训
    private var vt_decompression_callback: VTDecompressionOutputCallback = {(decompressionOutputRefCon: UnsafeMutableRawPointer?, sourceFrameRefCon: UnsafeMutableRawPointer?, status: OSStatus, infoFlags: VTDecodeInfoFlags, pixelBuffer: CVImageBuffer?, presentationTimeStamp: CMTime, presentationDuration: CMTime) in
        //真正的 264 编码后数据
        let outputPixelBuffer = unsafeBitCast(sourceFrameRefCon, to: CVPixelBuffer.self)
    
    }
    
    func decodeFile(fileName: String, fileExt: String) {
        let parser = H264InputStream()
        
    
        while true {
            let vp: VideoPacket? = parser.nextPacket()
            if let vp = vp {
                let nalSize = vp.size - 4
                let pNalSize: UnsafeMutablePointer<UInt8> = unsafeBitCast(nalSize, to: UnsafeMutablePointer<UInt8>.self)
                vp.buffer[0] = pNalSize.pointee + 3
                vp.buffer[1] = pNalSize.pointee + 2
                vp.buffer[2] = pNalSize.pointee + 1
                vp.buffer[3] = pNalSize.pointee
                
                var pixelBuffer: CVPixelBuffer?
                let nalType = vp.buffer[4] & 0x1F
                switch nalType {
                    case 0x05:
                        pixelBuffer = self.deEncode(size: vp.size,buffer: vp.buffer )
                    case 0x07:
                        spsSize = vp.size - 4
                        sps = unsafeBitCast(malloc(spsSize), to: UnsafeMutablePointer<UInt8>.self)
                        memcpy(sps, vp.buffer + 4, spsSize);
                    case 0x08:
                        ppsSize = vp.size - 4;
                        pps = unsafeBitCast(malloc(ppsSize), to: UnsafeMutablePointer<UInt8>.self)
                        memcpy(pps, vp.buffer + 4, ppsSize);
                default:
                    pixelBuffer = self.deEncode(size: vp.size,buffer: vp.buffer )
                }
                //渲染数据
                print(pixelBuffer ?? "error")
            }
        }
    }

}
