//
//  AVMonitor.h
//  Application
//
//  Created by Patrick Wardle on 4/30/21.
//  Copyright © 2021 Objective-See. All rights reserved.
//

@import Cocoa;
@import Foundation;
@import UserNotifications;

#import <CoreAudio/CoreAudio.h>
#import <CoreMedia/CoreMedia.h>
#import <Foundation/Foundation.h>
#import <CoreMediaIO/CMIOHardware.h>
#import <AVFoundation/AVCaptureDevice.h>

#import "Event.h"
#import "LogMonitor.h"


@interface AVMonitor : NSObject <UNUserNotificationCenterDelegate>

//log monitor
@property(nonatomic, retain)LogMonitor* logMonitor;

//camera attributions
@property(nonatomic, retain)NSMutableArray* cameraAttributions;

//audio attributions
@property(nonatomic, retain)NSMutableArray* audioAttributions;

//built in mic
@property(nonatomic, retain)AVCaptureDevice* builtInMic;

//built in camera
@property(nonatomic, retain)AVCaptureDevice* builtInCamera;

//inital mic state
@property NSControlStateValue initialMicState;

//initial camera state
@property NSControlStateValue initialCameraState;

//last camera client
@property NSInteger lastCameraClient;

//last camera off
@property(nonatomic, retain)AVCaptureDevice* lastCameraOff;

//last mic client
@property NSInteger lastMicClient;

//last mic off
@property(nonatomic, retain)AVCaptureDevice* lastMicOff;

//audio listeners
@property(nonatomic, retain)NSMutableDictionary* audioListeners;

//camera listeners
@property(nonatomic, retain)NSMutableDictionary* cameraListeners;

//per device events
@property(nonatomic, retain)NSMutableDictionary* deviceEvents;

//last alert (default) interaction
@property(nonatomic, retain)NSDate* lastNotificationDefaultAction;

/* METHODS */

//start
-(void)start;

//enumerate active devices
-(NSMutableArray*)enumerateActiveDevices;

//stop
-(void)stop;

@end

