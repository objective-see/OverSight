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

#import "LogMonitor.h"

@interface AVMonitor : NSObject <UNUserNotificationCenterDelegate>

//log monitor
@property(nonatomic, retain)LogMonitor* logMonitor;

//clients
@property(nonatomic, retain)NSMutableArray* clients;

//camera state
@property NSControlStateValue cameraState;

//microphone state
@property NSControlStateValue microphoneState;

/* METHODS */

//start
-(void)start;

//stop
-(void)stop;

@end

