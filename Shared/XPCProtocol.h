//
//  OverSightXPCProtocol.h
//  OverSightXPC
//
//  Created by Patrick Wardle on 8/16/16.
//  Copyright (c) 2016 Objective-See. All rights reserved.
//

#import <Foundation/Foundation.h>

// The protocol that this service will vend as its API. This header file will also need to be visible to the process hosting the service.
@protocol XPCProtocol

//start enumerator
-(void)initialize:(void (^)(void))reply;

//get (new) audio procs
-(void)getAudioProcs:(void (^)(NSMutableArray *))reply;

//get (new) video procs
-(void)getVideoProcs:(void (^)(NSMutableArray *))reply;

//update status video
// ->allows enumerator to stop baselining (when active), etc
-(void)updateVideoStatus:(unsigned int)status reply:(void (^)(void))reply;

//update status video
// ->allows enumerator to stop baselining (when active), etc
-(void)updateAudioStatus:(unsigned int)status reply:(void (^)(void))reply;

//whitelist a process
-(void)whitelistProcess:(NSString*)processPath device:(NSNumber*)device reply:(void (^)(BOOL))reply;

//remove a process from the whitelist file
-(void)unWhitelistProcess:(NSString*)processPath device:(NSNumber*)device reply:(void (^)(BOOL))reply;

//kill a process
-(void)killProcess:(NSNumber*)processID reply:(void (^)(BOOL))reply;

//exit
-(void)exit;

@end
