//
//  H264InputStream.swift
//  H264EncoderKit
//
//  Created by WeiHu on 2016/11/17.
//  Copyright © 2016年 WeiHu. All rights reserved.
//

import UIKit

private let inputStreamInstance = H264InputStream()

final class VideoPacket: NSObject{
    var buffer: UnsafeMutablePointer<UInt8>!
    var size: Int = 0
    
    convenience init(size: Int) {
        self.init()
        self.size = size;
        //开辟内存
        self.buffer = unsafeBitCast(malloc(size), to: UnsafeMutablePointer<UInt8>.self)
    }
    override init() {
        super.init()
  
    }
}
private let __s2: [UInt8] = [0,0,0,1]

final class H264InputStream: NSObject {
    
    var inputStream: InputStream!
    
    var buffer: UnsafeMutablePointer<UInt8>!
    var bufferSize: Int = 0
    var bufferCap: Int = 512 * 1024
    
    override init() {
        super.init()
//        let h264file = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.documentDirectory, FileManager.SearchPathDomainMask.userDomainMask, true)[0]
//        let toFile =  "\(h264file)/test.h264"
        let toFile =  Bundle.main.path(forResource: "test", ofType: "h264") ?? ""
        inputStream = InputStream(fileAtPath: toFile)
        inputStream.open()
        
        buffer = unsafeBitCast(malloc(self.bufferCap), to: UnsafeMutablePointer<UInt8>.self)
    }
    
    class var shareInstance: H264InputStream{
        return inputStreamInstance
    }
    
    func nextPacket() -> VideoPacket? {
    
        if bufferSize < bufferCap, inputStream.hasBytesAvailable {
            let readBytes = inputStream.read(unsafeBitCast(buffer, to: UnsafeMutablePointer<UInt8>.self) + bufferSize, maxLength: bufferCap - bufferSize)
            bufferSize += readBytes;
        }
        if memcmp(buffer, __s2, 4) != 0{
            return nil
        }
        if bufferSize >= 5 {
//            var a = 42
            var bufferBegin: UnsafeMutablePointer<UInt8> = buffer + 4
            let bufferEnd: UnsafeMutablePointer<UInt8> = buffer + bufferSize
            
            print(bufferBegin);
            
            
            
            while bufferBegin.pointee != bufferEnd.pointee {
//                print(bufferBegin.pointee)
                if bufferBegin.pointee == 0x01 {
                    if memcmp(bufferBegin - 3 , __s2, 4) == 0 {
                        let packetSize = bufferBegin - unsafeBitCast(buffer, to: UnsafeMutablePointer<UInt8>.self) - 3
                        let vp = VideoPacket(size: packetSize)
                        memcpy(vp.buffer, buffer, packetSize)
                        memmove(buffer, buffer + packetSize, bufferSize - packetSize)
                        bufferSize -= packetSize;
                        return vp
                    }
                }
                bufferBegin += 1
                
            }
        }
        
        return nil
    }
}
