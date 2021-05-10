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

#import "Event.h"
#import "LogMonitor.h"


@interface AVMonitor : NSObject <UNUserNotificationCenterDelegate>

//video log monitor
@property(nonatomic, retain)LogMonitor* videoLogMonitor;

//audio log monitor
@property(nonatomic, retain)LogMonitor* audioLogMonitor;

//clients
@property(nonatomic, retain)NSMutableArray* videoClients;

//audio clients
@property(nonatomic, retain)NSMutableArray* audioClients;

//audio (mic) callback
@property(nonatomic, copy)AudioObjectPropertyListenerBlock listenerBlock;

//camera state
@property NSControlStateValue cameraState;

//microphone state
@property NSControlStateValue microphoneState;

//last microphone state
@property(nonatomic, retain)Event* lastMicEvent;

/* METHODS */

//start
-(void)start;

//stop
-(void)stop;

@end

