//
//  MixerHostViewController.swift
//  MixerHost
//
//  Translated by OOPer in cooperation with shlab.jp, on 2015/11/7.
//
//
/*
    File: MixerHostViewController.h
    File: MixerHostViewController.m
Abstract: View controller: Sets up the user interface and conveys UI actions
to the MixerHostAudio object. Also responds to state-change notifications from
the MixerHostAudio object.
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


import UIKit

@objc(MixerHostViewController)
class MixerHostViewController: UIViewController {
    
    @IBOutlet var playButton: UIBarButtonItem!
    
    @IBOutlet var mixerBus0Switch: UISwitch!
    @IBOutlet var mixerBus1Switch: UISwitch!
    
    @IBOutlet var mixerBus0LevelFader: UISlider!
    @IBOutlet var mixerBus1LevelFader: UISlider!
    @IBOutlet var mixerOutputLevelFader: UISlider!
    
    var audioObject: MixerHostAudio?
    
    
    let MixerHostAudioObjectPlaybackStateDidChangeNotification = "MixerHostAudioObjectPlaybackStateDidChangeNotification"
    
    
    //MARK: -
    //MARK: User interface methods
    // Set the initial multichannel mixer unit parameter values according to the UI state
    private func initializeMixerSettingsToUI() {
        
        // Initialize mixer settings to UI
        audioObject?.enableMixerInput(0, isOn: mixerBus0Switch.isOn)
        audioObject?.enableMixerInput(1, isOn: mixerBus0Switch.isOn)
        
        audioObject?.setMixerOutputGain(mixerOutputLevelFader.value)
        
        audioObject?.setMixerInput(0, gain: mixerBus0LevelFader.value)
        audioObject?.setMixerInput(1, gain: mixerBus0LevelFader.value)
    }
    
    // Handle a change in the mixer output gain slider.
    @IBAction func mixerOutputGainChanged(_ sender: UISlider) {
        
        audioObject?.setMixerOutputGain(sender.value)
    }
    
    // Handle a change in a mixer input gain slider. The "tag" value of the slider lets this
    //    method distinguish between the two channels.
    @IBAction func mixerInputGainChanged(_ sender: UISlider) {
        
        let inputBus = sender.tag
        audioObject?.setMixerInput(UInt32(inputBus), gain: sender.value)
    }
    
    
    //MARK: -
    //MARK: Audio processing graph control
    
    // Handle a play/stop button tap
    @IBAction func playOrStop(_: AnyObject) {
        
        if audioObject?.playing ?? false {
            
            audioObject?.stopAUGraph()
            self.playButton.title = "Play"
            
        } else {
            
            audioObject?.startAUGraph()
            self.playButton.title = "Stop"
        }
    }
    
    // Handle a change in playback state that resulted from an audio session interruption or end of interruption
    @objc func handlePlaybackStateChanged(_: AnyObject) {
        
        self.playOrStop(self)
    }
    
    
    //MARK: -
    //MARK: Mixer unit control
    
    // Handle a Mixer unit input on/off switch action. The "tag" value of the switch lets this
    //    method distinguish between the two channels.
    @IBAction func enableMixerInput(_ sender: UISwitch) {
        
        let inputBus = UInt32(sender.tag)
        
        audioObject?.enableMixerInput(inputBus, isOn: sender.isOn)
        
    }
    
    
    //MARK: -
    //MARK: Remote-control event handling
    // Respond to remote control events
    override func remoteControlReceived(with receivedEvent: UIEvent?) {
        
        if receivedEvent?.type == .remoteControl {
            
            switch receivedEvent!.subtype {
                
            case .remoteControlTogglePlayPause:
                self.playOrStop(self)
                
            default:
                break
            }
        }
    }
    
    
    //MARK: -
    //MARK: Notification registration
    // If this app's audio session is interrupted when playing audio, it needs to update its user interface
    //    to reflect the fact that audio has stopped. The MixerHostAudio object conveys its change in state to
    //    this object by way of a notification. To learn about notifications, see Notification Programming Topics.
    private func registerForAudioObjectNotifications() {
        
        let notificationCenter = NotificationCenter.default
        
        notificationCenter.addObserver(self,
            selector: #selector(handlePlaybackStateChanged(_:)),
            name: Notification.Name(MixerHostAudioObjectPlaybackStateDidChangeNotification),
            object: audioObject)
    }
    
    
    //MARK: -
    //MARK: Application state management
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        let newAudioObject = MixerHostAudio()
        self.audioObject = newAudioObject
        
        self.registerForAudioObjectNotifications()
        self.initializeMixerSettingsToUI()
    }
    
    
    // If using a nonmixable audio session category, as this app does, you must activate reception of
    //    remote-control events to allow reactivation of the audio session when running in the background.
    //    Also, to receive remote-control events, the app must be eligible to become the first responder.
    override func viewDidAppear(_ animated: Bool) {
        
        super.viewDidAppear(animated)
        UIApplication.shared.beginReceivingRemoteControlEvents()
        self.becomeFirstResponder()
    }
    
    override var canBecomeFirstResponder : Bool {
        
        return true
    }
    
    
    override func didReceiveMemoryWarning() {
        // Releases the view if it doesn't have a superview.
        super.didReceiveMemoryWarning()
        
        // Release any cached data, images, etc that aren't in use.
    }
    
    
    override func viewWillDisappear(_ animated: Bool) {
        
        UIApplication.shared.endReceivingRemoteControlEvents()
        self.resignFirstResponder()
        
        super.viewWillDisappear(animated)
    }
    
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        NotificationCenter.default.removeObserver(self,
            name: Notification.Name(MixerHostAudioObjectPlaybackStateDidChangeNotification),
            object: audioObject)
        
    }
    
    
    deinit {
        
        NotificationCenter.default.removeObserver(self,
            name: Notification.Name(MixerHostAudioObjectPlaybackStateDidChangeNotification),
            object: audioObject)
        
        UIApplication.shared.endReceivingRemoteControlEvents()
    }
    
}
