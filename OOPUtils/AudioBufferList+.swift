//
//  AudioBufferList+.swift
//  OOPUtils
//
//  Created by OOPer in cooperation with shlab.jp, on 2015/2/1.
//
//
/*
Copyright (c) 2015, OOPer(NAGATA, Atsuyuki)
All rights reserved.

Use of any parts(functions, classes or any other program language components)
of this file is permitted with no restrictions, unless you
redistribute or use this file in its entirety without modification.
In this case, providing any sort of warranties or not is the user's responsibility.

Redistribution and use in source and/or binary forms, without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice,
this list of conditions and the following disclaimer.
2. Redistributions in binary form must reproduce the above copyright notice,
this list of conditions and the following disclaimer in the documentation
and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

import AVFoundation

func align(size: Int, to unit: Int) -> Int {
    assert(unit > 0)
    return ((size + unit - 1) / unit) * unit
}
/*
func AudioBufferList_getAudioBufferPtr(ptrAudioBufferList: UnsafeMutablePointer<Void>, index: Int) -> UnsafeMutablePointer<AudioBuffer> {
    var ptr = UnsafeMutablePointer<CChar>(ptrAudioBufferList)
    ptr = ptr.advancedBy(AudioBufferList_size(index))
    return UnsafeMutablePointer(ptr)
}
func AudioBufferList_getAudioBuffer(ptrAudioBufferList: UnsafeMutablePointer<Void>, _ index: Int) -> AudioBuffer {
    return AudioBufferList_getAudioBufferPtr(ptrAudioBufferList, index: index).memory
}
func AudioBufferList_getDataPtr<T>(ptrAudioBufferList: UnsafeMutablePointer<Void>, _ index: Int) -> UnsafeMutablePointer<T> {
    return UnsafeMutablePointer(AudioBufferList_getAudioBuffer(ptrAudioBufferList, index).mData)
}
func AudioBufferList_getDataSize(ptrAudioBufferList: UnsafeMutablePointer<Void>, index: Int) -> Int {
    return Int(AudioBufferList_getAudioBuffer(ptrAudioBufferList, index).mDataByteSize)
}
*/
private func AudioBufferList_size(count: Int) -> Int {
    return align(strideof(UInt32), to: alignof(AudioBuffer)) + strideof(AudioBuffer) * count
}
private func AudioBufferList_alloc(count: Int) -> UnsafeMutablePointer<AudioBufferList> {
    let size = AudioBufferList_size(count)
    let ptr = UnsafeMutablePointer<CChar>.alloc(size)
    return UnsafeMutablePointer(ptr)
}
/*
func AudioBufferList_dealloc(inout ptrAudioBufferList: UnsafeMutablePointer<AudioBufferList>, count: Int) {
    var ptr = UnsafeMutablePointer<CChar>(ptrAudioBufferList)
    let size = AudioBufferList_size(count)
    ptr.dealloc(size)
    ptr = nil
}
*/

//
// Experimental extension version
//

/// Needed to avoid current Swift limitation. You should not use this protocol explicitly.
/// Remember, AudioBufferList must be the only type which conforms to AudioBufferListType.
protocol AudioBufferListType {
    var mNumberBuffers: UInt32 {get set}
    var mBuffers: (AudioBuffer) {get set}
}
extension AudioBufferList: AudioBufferListType {
    static func alloc(numberBuffers: Int) -> UnsafeMutablePointer<AudioBufferList> {
        assert(numberBuffers > 0)
        let ptr = AudioBufferList_alloc(numberBuffers)
        ptr.memory.mNumberBuffers = UInt32(numberBuffers)
        return ptr
    }
}
/// We want to write the constraint as Memory == AudioBufferList,
/// but, as for now, Swift does not accept.
/// Remember, AudioBufferList must be the only type which conforms to AudioBufferListType.
extension UnsafeMutablePointer where Memory: AudioBufferListType {
    mutating func dispose() {
        let ptr = UnsafeMutablePointer<CChar>(self)
        let count = Int(self.memory.mNumberBuffers)
        let size = AudioBufferList_size(count)
        ptr.dealloc(size)
        self = nil
    }
    
    var numberBuffers: Int {
        return Int(self.memory.mNumberBuffers)
    }
    
    func audioBufferPtr(index: Int) -> UnsafeMutablePointer<AudioBuffer> {
        var ptr = UnsafeMutablePointer<RawByte>(self)
        ptr = ptr.advancedBy(AudioBufferList_size(index))
        return UnsafeMutablePointer<AudioBuffer>(ptr)
    }
    
    func audioBuffer(index: Int) -> AudioBuffer {
        return self.audioBufferPtr(index).memory
    }
    
    func data<T>(index: Int) -> UnsafeMutablePointer<T> {
        return UnsafeMutablePointer<T>(self.audioBuffer(index).mData)
    }
    
    func setData(ptr: UnsafeMutablePointer<Void>, atIndex index: Int) {
        return self.audioBufferPtr(index).memory.mData = ptr
    }
    
    func byteSize(index: Int) -> Int {
        return Int(self.audioBuffer(index).mDataByteSize)
    }
    
    func setByteSize(size: Int, atIndex index: Int) {
        return self.audioBufferPtr(index).memory.mDataByteSize = UInt32(size)
    }
    
    func numberChannels(index: Int) -> Int {
        return Int(self.audioBuffer(index).mNumberChannels)
    }
    
    func setNumberChannels(numberChannels: Int, atIndex index: Int) {
        return self.audioBufferPtr(index).memory.mNumberChannels = UInt32(numberChannels)
    }
}