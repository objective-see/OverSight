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


/* DEFINES */

#define VIDEO_DISABLED 0x0
#define VIDEO_ENABLED  0x1

#define EVENT_SOURCE @"source"
#define EVENT_DEVICE @"device"
#define EVENT_DEVICE_STATUS @"status"
#define EVENT_PROCESS_ID @"processID"

#define SOURCE_AUDIO @0x1
#define SOURCE_VIDEO @0x2

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

/* METHODS */

//kicks off thread to monitor
-(BOOL)monitor;

//monitor for new procs
-(void)monitor4Procs;

//determine if audio is active
-(void)setAudioDevStatus:(AudioObjectID)deviceID;

//determine if video is active
-(void)setVideoDevStatus:(CMIOObjectID)deviceID;

@end
