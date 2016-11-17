//
//  H264FileHandle.swift
//  H264EncoderKit
//
//  Created by WeiHu on 2016/11/17.
//  Copyright © 2016年 WeiHu. All rights reserved.
//

import UIKit

private let fileHandleInstance = H264FileHandle()

class H264FileHandle: NSObject {
    
    var fileHandle: FileHandle!
    
    override init() {
        super.init()
        print("初始化一次")
        let h264file = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.documentDirectory, FileManager.SearchPathDomainMask.userDomainMask, true)[0]
        let toFile =  "\(h264file)/test.h264"
        fileHandle = FileHandle(forWritingAtPath: toFile)
    }
    class var shareInstance: H264FileHandle{
        return fileHandleInstance
    }
}
