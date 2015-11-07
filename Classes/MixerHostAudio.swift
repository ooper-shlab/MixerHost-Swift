//
//  MixerHostAudio.swift
//  MixerHost
//
//  Translated by OOPer in cooperation with shlab.jp, on 2015/11/7.
//
//
/*
    File: MixerHostAudio.h
    File: MixerHostAudio.m
Abstract: Audio object: Handles all audio tasks for the application.
 Version: 1.0

Disclaimer: IMPORTANT:  This Apple software is supplied to you by Apple
Inc. ("Apple") in consideration of your agreement to the following
terms, and your use, installation, modification or redistribution of
this Apple software constitutes acceptance of these terms.  If you do
not agree with these terms, please do not use, install, modify or
redistribute this Apple software.

In consideration of your agreement to abide by the following terms, and
subject to these terms, Apple grants you a personal, non-exclusive
license, under Apple's copyrights in this original Apple software (the
"Apple Software"), to use, reproduce, modify and redistribute the Apple
Software, with or without modifications, in source and/or binary forms;
provided that if you redistribute the Apple Software in its entirety and
without modifications, you must retain this notice and the following
text and disclaimers in all such redistributions of the Apple Software.
Neither the name, trademarks, service marks or logos of Apple Inc. may
be used to endorse or promote products derived from the Apple Software
without specific prior written permission from Apple.  Except as
expressly stated in this notice, no other rights or licenses, express or
implied, are granted by Apple herein, including but not limited to any
patent rights that may be infringed by your derivative works or by other
works in which the Apple Software may be incorporated.

The Apple Software is provided by Apple on an "AS IS" basis.  APPLE
MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS
FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND
OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.

IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL
OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION,
MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED
AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE),
STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE
POSSIBILITY OF SUCH DAMAGE.

Copyright (C) 2010 Apple Inc. All Rights Reserved.

*/


import AudioToolbox
import AVFoundation

let NUM_FILES = 2

//#if !CA_PREFER_FIXED_POINT
//typealias MyAudioUnitSampleType = Float32
//let kMyAudioFormatFlagsAudioUnit = kAudioFormatFlagIsFloat | kAudioFormatFlagsNativeEndian | kAudioFormatFlagIsPacked | kAudioFormatFlagIsNonInterleaved
//#else
typealias MyAudioUnitSampleType = Int32
let kMyAudioFormatFlagsAudioUnit = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagsNativeEndian | kAudioFormatFlagIsPacked | kAudioFormatFlagIsNonInterleaved | (AudioFormatFlags(kAudioUnitSampleFractionBits) << kLinearPCMFormatFlagsSampleFractionShift)
//#endif

// Data structure for mono or stereo sound, to pass to the application's render callback function,
//    which gets invoked by a Mixer unit input bus when it needs more audio to play.
struct SoundStruct {
    
    var isStereo: Bool = false           // set to true if there is data in the audioDataRight member
    var frameCount: UInt32 = 0         // the total number of frames in the audio data
    var sampleNumber: UInt32 = 0       // the next audio sample to play
    var audioDataLeft: UnsafeMutablePointer<MyAudioUnitSampleType> = nil     // the complete left (or mono) channel of audio data read from an audio file
    var audioDataRight: UnsafeMutablePointer<MyAudioUnitSampleType> = nil    // the complete right channel of audio data read from an audio file
    
}




//MARK: Mixer input bus render callback

//    This callback is invoked each time a Multichannel Mixer unit input bus requires more audio
//        samples. In this app, the mixer unit has two input buses. Each of them has its own render
//        callback function and its own interleaved audio data buffer to read from.
//
//    This callback is written for an inRefCon parameter that can point to two noninterleaved
//        buffers (for a stereo sound) or to one mono buffer (for a mono sound).
//
//    Audio unit input render callbacks are invoked on a realtime priority thread (the highest
//    priority on the system). To work well, to not make the system unresponsive, and to avoid
//    audio artifacts, a render callback must not:
//
//        * allocate memory
//        * access the file system or a network connection
//        * take locks
//        * waste time
//
//    In addition, it's usually best to avoid sending Objective-C messages in a render callback.
//
//    Declared as AURenderCallback in AudioUnit/AUComponent.h. See Audio Unit Component Services Reference.
private func inputRenderCallback(
    inRefCon: UnsafeMutablePointer<Void>,      // A pointer to a struct containing the complete audio data
    //    to play, as well as state information such as the
    //    first sample to play on this invocation of the callback.
    ioActionFlags: UnsafeMutablePointer<AudioUnitRenderActionFlags>, // Unused here. When generating audio, use ioActionFlags to indicate silence
    //    between sounds; for silence, also memset the ioData buffers to 0.
    inTimeStamp: UnsafePointer<AudioTimeStamp>,   // Unused here.
    inBusNumber: UInt32,    // The mixer unit input bus that is requesting some new
    //        frames of audio data to play.
    inNumberFrames: UInt32, // The number of frames of audio to provide to the buffer(s)
    //        pointed to by the ioData parameter.
    ioData: UnsafeMutablePointer<AudioBufferList>         // On output, the audio data to play. The callback's primary
    //        responsibility is to fill the buffer(s) in the
    //        AudioBufferList.
    ) -> OSStatus {
        
        let soundStructPointerArray = UnsafeMutablePointer<SoundStruct>(inRefCon)
        let frameTotalForSound = Int(soundStructPointerArray[Int(inBusNumber)].frameCount)
        let isStereo = soundStructPointerArray[Int(inBusNumber)].isStereo
        
        // Declare variables to point to the audio buffers. Their data type must match the buffer data type.
        var dataInLeft: UnsafeMutablePointer<MyAudioUnitSampleType> = nil
        var dataInRight: UnsafeMutablePointer<MyAudioUnitSampleType> = nil
        
        dataInLeft                 = soundStructPointerArray[Int(inBusNumber)].audioDataLeft
        if isStereo {dataInRight  = soundStructPointerArray[Int(inBusNumber)].audioDataRight}
        
        // Establish pointers to the memory into which the audio from the buffers should go. This reflects
        //    the fact that each Multichannel Mixer unit input bus has two channels, as specified by this app's
        //    graphStreamFormat variable.
        var outSamplesChannelLeft: UnsafeMutablePointer<MyAudioUnitSampleType> = nil
        var outSamplesChannelRight: UnsafeMutablePointer<MyAudioUnitSampleType> = nil
        
        outSamplesChannelLeft = ioData.data(0)
        if isStereo {outSamplesChannelRight = ioData.data(1)}
        
        // Get the sample number, as an index into the sound stored in memory,
        //    to start reading data from.
        var sampleNumber = Int(soundStructPointerArray[Int(inBusNumber)].sampleNumber)
        
        // Fill the buffer or buffers pointed at by *ioData with the requested number of samples
        //    of audio from the sound stored in memory.
        for frameNumber in 0..<Int(inNumberFrames) {
            
            outSamplesChannelLeft[frameNumber]                 = dataInLeft[sampleNumber]
            if (isStereo) {outSamplesChannelRight[frameNumber]  = dataInRight[sampleNumber]}
            
            sampleNumber++
            
            // After reaching the end of the sound stored in memory--that is, after
            //    (frameTotalForSound / inNumberFrames) invocations of this callback--loop back to the
            //    start of the sound so playback resumes from there.
            if sampleNumber >= frameTotalForSound {sampleNumber = 0}
        }
        
        // Update the stored sample number so, the next time this callback is invoked, playback resumes
        //    at the correct spot.
        soundStructPointerArray[Int(inBusNumber)].sampleNumber = UInt32(sampleNumber)
        
        return noErr
}

@objc(MixerHostAudio)
class MixerHostAudio: NSObject {
    
    //MARK: -
    
    /// sample rate to use throughout audio processing chain
    var graphSampleRate: Float64 = 0
    private var sourceURLArray: [NSURL]!
    private var soundStructArray = UnsafeMutablePointer<SoundStruct>.alloc(2)
    
    // Before using an AudioStreamBasicDescription struct you must initialize it to 0. However, because these ASBDs
    // are declared in external storage, they are automatically initialized to 0.
    //### auto generated initializer initializes all elements to 0.
    /// stereo format for use in buffer and mixer input for "guitar" sound
    var stereoStreamFormat: AudioStreamBasicDescription = AudioStreamBasicDescription()
    /// mono format for use in buffer and mixer input for "beats" sound
    var monoStreamFormat: AudioStreamBasicDescription = AudioStreamBasicDescription()
    private var processingGraph: AUGraph = nil
    /// Boolean flag to indicate whether audio is playing or not
    var playing: Bool = false
    /// Boolean flag to indicate whether audio was playing when an interruption arrived
    var interruptedDuringPlayback: Bool = false
    /// the Multichannel Mixer unit
    var mixerUnit: AudioUnit = nil
    
    //MARK: -
    //MARK: Audio route change listener callback
    
    // Audio session callback function for responding to audio route changes. If playing back audio and
    //   the user unplugs a headset or headphones, or removes the device from a dock connector for hardware
    //   that supports audio playback, this callback detects that and stops playback.
    //
    // Refer to AudioSessionPropertyListener in Audio Session Services Reference.
    @objc func handleRouteChange(notification: NSNotification) {
        
        // Ensure that this callback was invoked because of an audio route change
        guard notification.name == AVAudioSessionRouteChangeNotification else {return}
        
        // This callback, being outside the implementation block, needs a reference to the MixerHostAudio
        //   object, which it receives in the inUserData parameter. You provide this reference when
        //   registering this callback (see the call to AudioSessionAddPropertyListener).
        let audioObject = self
        
        // if application sound is not playing, there's nothing to do, so return.
        guard audioObject.playing else {
            
            NSLog("Audio route change while application audio is stopped.")
            return
            
        }
        
        // Determine the specific type of audio route change that occurred.
        let routeChangeDictionary = notification.userInfo!
        
        let routeChangeReasonRef = routeChangeDictionary[AVAudioSessionRouteChangeReasonKey]
        
        let routeChangeReason = routeChangeReasonRef as! UInt
        
        // "Old device unavailable" indicates that a headset or headphones were unplugged, or that
        //    the device was removed from a dock connector that supports audio output. In such a case,
        //    pause or stop audio (as advised by the iOS Human Interface Guidelines).
        if routeChangeReason == AVAudioSessionRouteChangeReason.OldDeviceUnavailable.rawValue {
            
            NSLog("Audio output device was removed; stopping audio playback.")
            let MixerHostAudioObjectPlaybackStateDidChangeNotification = "MixerHostAudioObjectPlaybackStateDidChangeNotification"
            NSNotificationCenter.defaultCenter().postNotificationName(MixerHostAudioObjectPlaybackStateDidChangeNotification, object: audioObject)
            
        } else {
            
            NSLog("A route change occurred that does not require stopping application audio.")
        }
    }
    
    
    //MARK: -
    //MARK: Initialize
    
    // Get the app ready for playback.
    override init() {
        
        super.init()
        
        self.interruptedDuringPlayback = false
        
        self.setupAudioSession()
        self.obtainSoundFileURLs()
        self.setupStereoStreamFormat()
        self.setupMonoStreamFormat()
        self.readAudioFilesIntoMemory()
        self.configureAndInitializeAudioProcessingGraph()
        
    }
    
    
    //MARK: -
    //MARK: Audio set up
    
    private func setupAudioSession() {
        
        let mySession = AVAudioSession.sharedInstance()
        
        // Specify that this object is the delegate of the audio session, so that
        //    this object's endInterruption method will be invoked when needed.
        /* The delegate property is deprecated. Instead, you should register for the NSNotifications named below. */
        /* For example:
        [[NSNotificationCenter defaultCenter] addObserver: myObject
        selector:    @selector(handleInterruption:)
        name:        AVAudioSessionInterruptionNotification
        object:      [AVAudioSession sharedInstance]];
        */
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "handleInterruption:", name: AVAudioSessionInterruptionNotification, object: mySession)
        
        // Assign the Playback category to the audio session.
        do {
            try mySession.setCategory(AVAudioSessionCategoryPlayback)
            
        } catch _ {
            
            NSLog("Error setting audio session category.")
            return
        }
        
        // Request the desired hardware sample rate.
        self.graphSampleRate = 44100.0;    // Hertz
        
        do {
            try mySession.setPreferredSampleRate(graphSampleRate)
            
        } catch _ {
            
            NSLog("Error setting preferred hardware sample rate.")
            return
        }
        
        // Activate the audio session
        do {
            try mySession.setActive(true)
            
        } catch _ {
            
            NSLog("Error activating audio session during initial setup.")
            return
        }
        
        // Obtain the actual hardware sample rate and store it for later use in the audio processing graph.
        self.graphSampleRate = mySession.sampleRate
        
        // Register the audio route change listener callback function with the audio session.
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "handleRouteChange:", name: AVAudioSessionRouteChangeNotification, object: mySession)
    }
    
    
    private func obtainSoundFileURLs() {
        
        // Create the URLs for the source audio files. The URLForResource:withExtension: method is new in iOS 4.0.
        let guitarLoop = NSBundle.mainBundle().URLForResource("guitarStereo", withExtension: "caf")!
        
        let beatsLoop = NSBundle.mainBundle().URLForResource("beatsMono", withExtension: "caf")!
        
        // ExtAudioFileRef objects expect CFURLRef URLs, so cast to CRURLRef here
        sourceURLArray = [guitarLoop, beatsLoop]
    }
    
    
    private func setupStereoStreamFormat() {
        
        // The AudioUnitSampleType data type is the recommended type for sample data in audio
        //    units. This obtains the byte size of the type for use in filling in the ASBD.
        let bytesPerSample = UInt32(strideof(MyAudioUnitSampleType))
        
        // Fill the application audio format struct's fields to define a linear PCM,
        //        stereo, noninterleaved stream at the hardware sample rate.
        stereoStreamFormat.mFormatID          = kAudioFormatLinearPCM
        stereoStreamFormat.mFormatFlags       = kMyAudioFormatFlagsAudioUnit
        stereoStreamFormat.mBytesPerPacket    = bytesPerSample
        stereoStreamFormat.mFramesPerPacket   = 1
        stereoStreamFormat.mBytesPerFrame     = bytesPerSample
        stereoStreamFormat.mChannelsPerFrame  = 2                    // 2 indicates stereo
        stereoStreamFormat.mBitsPerChannel    = 8 * bytesPerSample
        stereoStreamFormat.mSampleRate        = graphSampleRate
        
        
        NSLog("The stereo stream format for the \"guitar\" mixer input bus:")
        self.printASBD(stereoStreamFormat)
    }
    
    
    private func setupMonoStreamFormat() {
        
        // The AudioUnitSampleType data type is the recommended type for sample data in audio
        //    units. This obtains the byte size of the type for use in filling in the ASBD.
        let bytesPerSample = UInt32(strideof(MyAudioUnitSampleType))
        
        // Fill the application audio format struct's fields to define a linear PCM,
        //        stereo, noninterleaved stream at the hardware sample rate.
        monoStreamFormat.mFormatID          = kAudioFormatLinearPCM
        monoStreamFormat.mFormatFlags       = kMyAudioFormatFlagsAudioUnit
        monoStreamFormat.mBytesPerPacket    = bytesPerSample
        monoStreamFormat.mFramesPerPacket   = 1
        monoStreamFormat.mBytesPerFrame     = bytesPerSample
        monoStreamFormat.mChannelsPerFrame  = 1;                  // 1 indicates mono
        monoStreamFormat.mBitsPerChannel    = 8 * bytesPerSample
        monoStreamFormat.mSampleRate        = graphSampleRate
        
        NSLog("The mono stream format for the \"beats\" mixer input bus:")
        self.printASBD(monoStreamFormat)
        
    }
    
    
    //MARK: -
    //MARK: Read audio files into memory
    
    private func readAudioFilesIntoMemory() {
        
        for (audioFile, sourceURL) in sourceURLArray.enumerate() {
            
            NSLog("readAudioFilesIntoMemory - file %i", Int32(audioFile))
            
            // Instantiate an extended audio file object.
            var audioFileObject: ExtAudioFileRef = nil
            
            // Open an audio file and associate it with the extended audio file object.
            var result = ExtAudioFileOpenURL(sourceURL, &audioFileObject)
            
            guard result == noErr else {
                self.printErrorMessage("ExtAudioFileOpenURL", withStatus: result)
                return
            }
            
            // Get the audio file's length in frames.
            var totalFramesInFile: UInt64 = 0
            var frameLengthPropertySize = UInt32(sizeofValue(totalFramesInFile))
            
            result =    ExtAudioFileGetProperty(
                audioFileObject,
                kExtAudioFileProperty_FileLengthFrames,
                &frameLengthPropertySize,
                &totalFramesInFile
            )
            
            guard result == noErr else {
                self.printErrorMessage("ExtAudioFileGetProperty (audio file length in frames)", withStatus: result)
                return
            }
            
            // Assign the frame count to the soundStructArray instance variable
            soundStructArray[audioFile].frameCount = UInt32(totalFramesInFile)
            
            // Get the audio file's number of channels.
            var fileAudioFormat: AudioStreamBasicDescription = AudioStreamBasicDescription()
            var formatPropertySize = UInt32(strideofValue(fileAudioFormat))
            
            result =    ExtAudioFileGetProperty(
                audioFileObject,
                kExtAudioFileProperty_FileDataFormat,
                &formatPropertySize,
                &fileAudioFormat
            )
            
            guard result == noErr else {
                self.printErrorMessage("ExtAudioFileGetProperty (file audio format)", withStatus: result)
                return
            }
            
            let channelCount = fileAudioFormat.mChannelsPerFrame
            
            // Allocate memory in the soundStructArray instance variable to hold the left channel,
            //    or mono, audio data
            soundStructArray[audioFile].audioDataLeft =
                UnsafeMutablePointer<MyAudioUnitSampleType>.alloc(Int(totalFramesInFile))
            
            var importFormat = AudioStreamBasicDescription()
            if channelCount == 2 {
                
                soundStructArray[audioFile].isStereo = true
                // Sound is stereo, so allocate memory in the soundStructArray instance variable to
                //    hold the right channel audio data
                soundStructArray[audioFile].audioDataRight =
                    UnsafeMutablePointer<MyAudioUnitSampleType>.alloc(Int(totalFramesInFile))
                importFormat = stereoStreamFormat
                
            } else if channelCount == 1 {
                
                soundStructArray[audioFile].isStereo = false
                importFormat = monoStreamFormat
                
            } else {
                
                NSLog("*** WARNING: File format not supported - wrong number of channels")
                ExtAudioFileDispose(audioFileObject)
                return
            }
            
            // Assign the appropriate mixer input bus stream data format to the extended audio
            //        file object. This is the format used for the audio data placed into the audio
            //        buffer in the SoundStruct data structure, which is in turn used in the
            //        inputRenderCallback callback function.
            
            result =    ExtAudioFileSetProperty(
                audioFileObject,
                kExtAudioFileProperty_ClientDataFormat,
                UInt32(strideofValue(importFormat)),
                &importFormat
            )
            
            guard result == noErr else {
                self.printErrorMessage("ExtAudioFileSetProperty (client data format)", withStatus: result)
                return
            }
            
            // Set up an AudioBufferList struct, which has two roles:
            //
            //        1. It gives the ExtAudioFileRead function the configuration it
            //            needs to correctly provide the data to the buffer.
            //
            //        2. It points to the soundStructArray[audioFile].audioDataLeft buffer, so
            //            that audio data obtained from disk using the ExtAudioFileRead function
            //            goes to that buffer
            
            // Allocate memory for the buffer list struct according to the number of
            //    channels it represents.
            var bufferList = AudioBufferList.alloc(Int(channelCount))
            
            guard bufferList != nil else {
                NSLog("*** malloc failure for allocating bufferList memory")
                return
            }
            
            // initialize the mNumberBuffers member
            print(bufferList.memory.mNumberBuffers)
            
            // initialize the mBuffers member to 0
            let emptyBuffer = AudioBuffer()
            for arrayIndex in 0..<Int(channelCount) {
                bufferList.audioBufferPtr(arrayIndex).memory = emptyBuffer
            }
            
            // set up the AudioBuffer structs in the buffer list
            bufferList.setNumberChannels(1, atIndex: 0)
            bufferList.setByteSize(Int(totalFramesInFile) * strideof(MyAudioUnitSampleType), atIndex: 0)
            bufferList.setData(soundStructArray[audioFile].audioDataLeft, atIndex: 0)
            
            if channelCount == 2 {
                bufferList.setNumberChannels(1, atIndex: 1)
                bufferList.setByteSize(Int(totalFramesInFile) * strideof(MyAudioUnitSampleType), atIndex: 1)
                bufferList.setData(soundStructArray[audioFile].audioDataRight, atIndex: 1)
            }
            
            // Perform a synchronous, sequential read of the audio data out of the file and
            //    into the soundStructArray[audioFile].audioDataLeft and (if stereo) .audioDataRight members.
            var numberOfPacketsToRead = UInt32(totalFramesInFile)
            
            NSLog("numberOfPacketsToRead=%d", Int32(numberOfPacketsToRead));
            result = ExtAudioFileRead(
                audioFileObject,
                &numberOfPacketsToRead,
                bufferList
            )
            
            bufferList.dispose()
            
            guard result == noErr else {
                
                self.printErrorMessage("ExtAudioFileRead failure - ", withStatus: result)
                
                // If reading from the file failed, then free the memory for the sound buffer.
                soundStructArray[audioFile].audioDataLeft.dealloc(Int(totalFramesInFile))
                soundStructArray[audioFile].audioDataLeft = nil
                
                if channelCount == 2 {
                    soundStructArray[audioFile].audioDataLeft.dealloc(Int(totalFramesInFile))
                    soundStructArray[audioFile].audioDataRight = nil
                }
                
                ExtAudioFileDispose(audioFileObject)
                return
            }
            
            NSLog("Finished reading file %i into memory", Int32(audioFile))
            
            // Set the sample index to zero, so that playback starts at the
            //    beginning of the sound.
            soundStructArray[audioFile].sampleNumber = 0
            
            // Dispose of the extended audio file object, which also
            //    closes the associated file.
            ExtAudioFileDispose(audioFileObject)
        }
    }
    
    
    //MARK: -
    //MARK: Audio processing graph setup
    
    // This method performs all the work needed to set up the audio processing graph:
    
    // 1. Instantiate and open an audio processing graph
    // 2. Obtain the audio unit nodes for the graph
    // 3. Configure the Multichannel Mixer unit
    //     * specify the number of input buses
    //     * specify the output sample rate
    //     * specify the maximum frames-per-slice
    // 4. Initialize the audio processing graph
    
    private func configureAndInitializeAudioProcessingGraph() {
        
        NSLog("Configuring and then initializing audio processing graph")
        var result = noErr
        
        //............................................................................
        // Create a new audio processing graph.
        result = NewAUGraph(&processingGraph)
        
        guard result == noErr else {
            self.printErrorMessage("NewAUGraph", withStatus: result)
            return
        }
        
        
        //............................................................................
        // Specify the audio unit component descriptions for the audio units to be
        //    added to the graph.
        
        // I/O unit
        var iOUnitDescription = AudioComponentDescription(
            componentType: kAudioUnitType_Output,
            componentSubType: kAudioUnitSubType_RemoteIO,
            componentManufacturer: kAudioUnitManufacturer_Apple,
            componentFlags: 0,
            componentFlagsMask: 0)
        
        // Multichannel mixer unit
        var MixerUnitDescription = AudioComponentDescription(
            componentType: kAudioUnitType_Mixer,
            componentSubType: kAudioUnitSubType_MultiChannelMixer,
            componentManufacturer: kAudioUnitManufacturer_Apple,
            componentFlags: 0,
            componentFlagsMask: 0)
        
        
        //............................................................................
        // Add nodes to the audio processing graph.
        NSLog("Adding nodes to audio processing graph")
        
        var iONode: AUNode = 0         // node for I/O unit
        var mixerNode: AUNode = 0      // node for Multichannel Mixer unit
        
        // Add the nodes to the audio processing graph
        result =    AUGraphAddNode(
            processingGraph,
            &iOUnitDescription,
            &iONode)
        
        guard result == noErr else {
            self.printErrorMessage("AUGraphNewNode failed for I/O unit", withStatus: result)
            return
        }
        
        
        result =    AUGraphAddNode(
            processingGraph,
            &MixerUnitDescription,
            &mixerNode
        )
        
        guard result == noErr else {
            self.printErrorMessage("AUGraphNewNode failed for Mixer unit", withStatus: result)
            return
        }
        
        
        //............................................................................
        // Open the audio processing graph
        
        // Following this call, the audio units are instantiated but not initialized
        //    (no resource allocation occurs and the audio units are not in a state to
        //    process audio).
        result = AUGraphOpen(processingGraph)
        
        guard result == noErr else {
            self.printErrorMessage("AUGraphOpen", withStatus: result)
            return
        }
        
        
        //............................................................................
        // Obtain the mixer unit instance from its corresponding node.
        
        result =    AUGraphNodeInfo(
            processingGraph,
            mixerNode,
            nil,
            &mixerUnit
        )
        
        guard result == noErr else {
            self.printErrorMessage("AUGraphNodeInfo", withStatus: result)
            return
        }
        
        
        //............................................................................
        // Multichannel Mixer unit Setup
        
        var busCount: UInt32   = 2    // bus count for mixer unit input
        let guitarBus: UInt32  = 0    // mixer unit bus 0 will be stereo and will take the guitar sound
        let beatsBus: UInt32   = 1    // mixer unit bus 1 will be mono and will take the beats sound
        
        NSLog("Setting mixer unit input bus count to: %u", busCount)
        result = AudioUnitSetProperty(
            mixerUnit,
            kAudioUnitProperty_ElementCount,
            kAudioUnitScope_Input,
            0,
            &busCount,
            UInt32(sizeofValue(busCount))
        )
        
        guard result == noErr else {
            self.printErrorMessage("AudioUnitSetProperty (set mixer unit bus count)", withStatus: result)
            return
        }
        
        
        NSLog("Setting kAudioUnitProperty_MaximumFramesPerSlice for mixer unit global scope")
        // Increase the maximum frames per slice allows the mixer unit to accommodate the
        //    larger slice size used when the screen is locked.
        var maximumFramesPerSlice: UInt32 = 4096
        
        result = AudioUnitSetProperty(
            mixerUnit,
            kAudioUnitProperty_MaximumFramesPerSlice,
            kAudioUnitScope_Global,
            0,
            &maximumFramesPerSlice,
            UInt32(sizeofValue(maximumFramesPerSlice))
        )
        
        guard result == noErr else {
            self.printErrorMessage("AudioUnitSetProperty (set mixer unit input stream format)", withStatus: result)
            return
        }
        
        
        // Attach the input render callback and context to each input bus
        for busNumber in 0..<busCount {
            
            // Setup the struture that contains the input render callback
            var inputCallbackStruct = AURenderCallbackStruct(
                inputProc: inputRenderCallback,
                inputProcRefCon: soundStructArray)
            
            NSLog("Registering the render callback with mixer unit input bus %u", busNumber)
            // Set a callback for the specified node's specified input
            result = AUGraphSetNodeInputCallback(
                processingGraph,
                mixerNode,
                busNumber,
                &inputCallbackStruct
            )
            
            guard result == noErr else {
                self.printErrorMessage("AUGraphSetNodeInputCallback", withStatus: result)
                return
            }
        }
        
        
        NSLog("Setting stereo stream format for mixer unit \"guitar\" input bus")
        result = AudioUnitSetProperty(
            mixerUnit,
            kAudioUnitProperty_StreamFormat,
            kAudioUnitScope_Input,
            guitarBus,
            &stereoStreamFormat,
            UInt32(sizeofValue(stereoStreamFormat))
        )
        
        guard result == noErr else {
            self.printErrorMessage("AudioUnitSetProperty (set mixer unit guitar input bus stream format)", withStatus: result)
            return
        }
        
        
        NSLog("Setting mono stream format for mixer unit \"beats\" input bus")
        result = AudioUnitSetProperty(
            mixerUnit,
            kAudioUnitProperty_StreamFormat,
            kAudioUnitScope_Input,
            beatsBus,
            &monoStreamFormat,
            UInt32(sizeofValue(monoStreamFormat))
        )
        
        guard result == noErr else {
            self.printErrorMessage("AudioUnitSetProperty (set mixer unit beats input bus stream format)", withStatus: result)
            return
        }
        
        
        NSLog("Setting sample rate for mixer unit output scope")
        // Set the mixer unit's output sample rate format. This is the only aspect of the output stream
        //    format that must be explicitly set.
        result = AudioUnitSetProperty(
            mixerUnit,
            kAudioUnitProperty_SampleRate,
            kAudioUnitScope_Output,
            0,
            &graphSampleRate,
            UInt32(sizeofValue(graphSampleRate))
        )
        
        guard result == noErr else {
            self.printErrorMessage("AudioUnitSetProperty (set mixer unit output stream format)", withStatus: result)
            return
        }
        
        
        //............................................................................
        // Connect the nodes of the audio processing graph
        NSLog("Connecting the mixer output to the input of the I/O unit output element")
        
        result = AUGraphConnectNodeInput (
            processingGraph,
            mixerNode,         // source node
            0,                 // source node output bus number
            iONode,            // destination node
            0                  // desintation node input bus number
        )
        
        guard result == noErr else {
            self.printErrorMessage("AUGraphConnectNodeInput", withStatus: result)
            return
        }
        
        
        //............................................................................
        // Initialize audio processing graph
        
        // Diagnostic code
        // Call CAShow if you want to look at the state of the audio processing
        //    graph.
        NSLog("Audio processing graph state immediately before initializing it:")
        CAShow(UnsafeMutablePointer(processingGraph))
        
        NSLog("Initializing the audio processing graph")
        // Initialize the audio processing graph, configure audio data stream formats for
        //    each input and output, and validate the connections between audio units.
        result = AUGraphInitialize(processingGraph)
        
        guard result == noErr else {
            self.printErrorMessage("AUGraphInitialize", withStatus: result)
            return
        }
    }
    
    
    //MARK: -
    //MARK: Playback control
    
    // Start playback
    func startAUGraph() {
        
        NSLog("Starting audio processing graph")
        let result = AUGraphStart(processingGraph)
        guard result == noErr else {
            self.printErrorMessage("AUGraphStart", withStatus: result)
            return
        }
        
        self.playing = true
    }
    
    // Stop playback
    func stopAUGraph() {
        
        NSLog("Stopping audio processing graph")
        var isRunning: DarwinBoolean = false
        var result = AUGraphIsRunning(processingGraph, &isRunning)
        guard result == noErr else {
            self.printErrorMessage("AUGraphIsRunning", withStatus: result)
            return
        }
        
        if isRunning {
            
            result = AUGraphStop(processingGraph)
            guard result == noErr else {
                self.printErrorMessage("AUGraphStop", withStatus: result)
                return
            }
            self.playing = false
        }
    }
    
    
    //MARK: -
    //MARK: Mixer unit control
    // Enable or disable a specified bus
    func enableMixerInput(inputBus: UInt32, isOn isOnValue: Bool) {
        
        NSLog("Bus %d now %@", Int32(inputBus), isOnValue ? "on" : "off")
        
        let result = AudioUnitSetParameter(
            mixerUnit,
            kMultiChannelMixerParam_Enable,
            kAudioUnitScope_Input,
            inputBus,
            isOnValue ? 1 : 0,
            0
        )
        
        guard result == noErr else {
            self.printErrorMessage("AudioUnitSetParameter (enable the mixer unit)", withStatus: result)
            return
        }
        
        
        // Ensure that the sound loops stay in sync when reenabling an input bus
        if inputBus == 0 && isOnValue {
            soundStructArray[0].sampleNumber = soundStructArray[1].sampleNumber
        }
        
        if inputBus == 1 && isOnValue {
            soundStructArray[1].sampleNumber = soundStructArray[0].sampleNumber
        }
    }
    
    
    // Set the mixer unit input volume for a specified bus
    func setMixerInput(inputBus: UInt32, gain newGain: AudioUnitParameterValue) {
        
        /*
        This method does *not* ensure that sound loops stay in sync if the user has
        moved the volume of an input channel to zero. When a channel's input
        level goes to zero, the corresponding input render callback is no longer
        invoked. Consequently, the sample number for that channel remains constant
        while the sample number for the other channel continues to increment. As a
        workaround, the view controller Nib file specifies that the minimum input
        level is 0.01, not zero.
        
        The enableMixerInput:isOn: method in this class, however, does ensure that the
        loops stay in sync when a user disables and then reenables an input bus.
        */
        let result = AudioUnitSetParameter(
            mixerUnit,
            kMultiChannelMixerParam_Volume,
            kAudioUnitScope_Input,
            inputBus,
            newGain,
            0
        )
        
        guard result == noErr else {
            self.printErrorMessage("AudioUnitSetParameter (set mixer unit input volume)", withStatus: result)
            return
        }
        
    }
    
    
    // Set the mxer unit output volume
    func setMixerOutputGain(newGain: AudioUnitParameterValue) {
        
        let result = AudioUnitSetParameter(
            mixerUnit,
            kMultiChannelMixerParam_Volume,
            kAudioUnitScope_Output,
            0,
            newGain,
            0
        )
        
        guard result == noErr else {
            self.printErrorMessage("AudioUnitSetParameter (set mixer unit output volume)", withStatus: result)
            return
        }
        
    }
    
    
    //MARK: -
    //MARK: Audio Session Delegate Methods
    @objc func handleInterruption(notification: NSNotification) {
        let type = notification.userInfo![AVAudioSessionInterruptionTypeKey] as! UInt
        switch AVAudioSessionInterruptionType(rawValue: type)! {
            // Respond to having been interrupted. This method sends a notification to the
            //    controller object, which in turn invokes the playOrStop: toggle method. The
            //    interruptedDuringPlayback flag lets the  endInterruptionWithFlags: method know
            //    whether playback was in progress at the time of the interruption.
        case .Began:
            
            NSLog("Audio session was interrupted.")
            
            if playing {
                
                self.interruptedDuringPlayback = true
                
                let MixerHostAudioObjectPlaybackStateDidChangeNotification = "MixerHostAudioObjectPlaybackStateDidChangeNotification"
                NSNotificationCenter.defaultCenter().postNotificationName(MixerHostAudioObjectPlaybackStateDidChangeNotification, object: self)
            }
            
            
            // Respond to the end of an interruption. This method gets invoked, for example,
            //    after the user dismisses a clock alarm.
        case .Ended:
            let rawFlags = notification.userInfo![AVAudioSessionInterruptionOptionKey] as! UInt
            let flags = AVAudioSessionInterruptionOptions(rawValue: rawFlags)
            
            // Test if the interruption that has just ended was one from which this app
            //    should resume playback.
            if flags.contains(.ShouldResume) {
                
                do {
                    try AVAudioSession.sharedInstance().setActive(true)
                    
                } catch _ {
                    
                    NSLog("Unable to reactivate the audio session after the interruption ended.")
                    return
                    
                }
                
                NSLog("Audio session reactivated after interruption.")
                
                if interruptedDuringPlayback {
                    
                    self.interruptedDuringPlayback = false
                    
                    // Resume playback by sending a notification to the controller object, which
                    //    in turn invokes the playOrStop: toggle method.
                    let MixerHostAudioObjectPlaybackStateDidChangeNotification = "MixerHostAudioObjectPlaybackStateDidChangeNotification"
                    NSNotificationCenter.defaultCenter().postNotificationName(MixerHostAudioObjectPlaybackStateDidChangeNotification, object: self)
                    
                }
            }
        }
    }
    
    
    //MARK: -
    //MARK: Utility methods
    
    // You can use this method during development and debugging to look at the
    //    fields of an AudioStreamBasicDescription struct.
    private func printASBD(asbd: AudioStreamBasicDescription) {
        
        let formatIDString = asbd.mFormatID.fourCharString
        
        NSLog("  Sample Rate:         %10.0f",  asbd.mSampleRate)
        NSLog("  Format ID:                 %@",    formatIDString)
        NSLog("  Format Flags:        %10X",    asbd.mFormatFlags)
        NSLog("  Bytes per Packet:    %10d",    asbd.mBytesPerPacket)
        NSLog("  Frames per Packet:   %10d",    asbd.mFramesPerPacket)
        NSLog("  Bytes per Frame:     %10d",    asbd.mBytesPerFrame)
        NSLog("  Channels per Frame:  %10d",    asbd.mChannelsPerFrame)
        NSLog("  Bits per Channel:    %10d",    asbd.mBitsPerChannel)
    }
    
    
    private func printErrorMessage(errorString: String, withStatus result: OSStatus) {
        
        let resultString = FourCharCode(bitPattern: result).possibleFourCharString
        
        NSLog(
            "*** %@ error: %d %08X %@\n",
            errorString,
            result, result, resultString
        )
    }
    
    
    //MARK: -
    //MARK: Deallocate
    
    deinit {
        
        for audioFile in 0..<NUM_FILES {
            
            let totalFramesInFile = soundStructArray[audioFile].frameCount
            if soundStructArray[audioFile].audioDataLeft != nil {
                soundStructArray[audioFile].audioDataLeft.dealloc(Int(totalFramesInFile))
                soundStructArray[audioFile].audioDataLeft = nil
            }
            
            if soundStructArray[audioFile].audioDataRight != nil {
                soundStructArray[audioFile].audioDataRight.dealloc(Int(totalFramesInFile))
                soundStructArray[audioFile].audioDataRight = nil
            }
            soundStructArray.dealloc(2)
        }
        
    }
    
}
