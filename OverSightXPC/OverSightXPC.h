//
//  OverSightXPC.h
//  OverSightXPC
//
//  Created by Patrick Wardle on 8/16/16.
//  Copyright (c) 2016 Objective-See. All rights reserved.
//

#import "XPCProtocol.h"
#import <Foundation/Foundation.h>

/* DEFINES */


// This object implements the protocol which we have defined. It provides the actual behavior for the service. It is 'exported' by the service to make it available to the process hosting the service over an NSXPCConnection.
@interface OverSightXPC : NSObject <XPCProtocol>

/* PROPERTIES */

//flag indicating video is action
@property BOOL videoActive;

//list of procs that have send Mach msg to *Assistant
@property(nonatomic, retain)NSMutableDictionary* machSenders;

@end
