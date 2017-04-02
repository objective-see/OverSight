//
//  ProcessMonitor.h
//  OverSight
//
//  Created by Patrick Wardle on 9/01/16.
//  Copyright (c) 2015 Objective-See. All rights reserved.
//


#import <CoreAudio/CoreAudio.h>
#import <CoreMedia/CoreMedia.h>
#import <Foundation/Foundation.h>
#import <CoreMediaIO/CMIOHardware.h>
#import <AVFoundation/AVFoundation.h>

#import "RemeberWindowController.h"

/* DEFINES */

#define VIDEO_DISABLED 0x0
#define VIDEO_ENABLED  0x1

#define DEVICE_INACTIVE @0x0
#define DEVICE_ACTIVE   @0x1

@interface AVMonitor : NSObject <NSUserNotificationCenterDelegate>
{
    
    
}

/* PROPERTIES */

//apple mic (AVCaptureHALDevice)
@property(nonatomic, retain)AVCaptureDevice* mic;

//apple camera (AVCaptureDALDevice)
@property(nonatomic, retain)AVCaptureDevice* camera;

//flag indicating audio (mic) is active
@property BOOL audioActive;

//flag indicating video (camera) is active
@property BOOL videoActive;

//monitor thread
@property(nonatomic, retain)NSThread* videoMonitorThread;

//remember popup/window controller
@property(nonatomic, retain)RememberWindowController* rememberWindowController;

//last event
@property(nonatomic, retain)NSDictionary* lastEvent;

//last notification
@property(nonatomic, retain)NSString* lastNotification;

//whitelisted procs
@property(nonatomic, retain)NSMutableArray* whiteList;

//activation alerts that were displayed
@property(nonatomic, retain)NSMutableDictionary* activationAlerts;



/* METHODS */

//load whitelist
-(void)loadWhitelist;

//kicks off thread to monitor
-(BOOL)monitor;

//monitor for new procs
-(void)monitor4Procs;

//determine if audio is active
-(void)setAudioDevStatus:(AudioObjectID)deviceID;

//determine if video is active
-(void)setVideoDevStatus:(CMIOObjectID)deviceID;

@end
