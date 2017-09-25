//
//  Enumerator.h
//  cameraUsers
//
//  Created by Patrick Wardle on 9/9/16.
//  Copyright (c) 2016 Objective-See. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Enumerator : NSObject

/* DEFINES */

//camera assistant daemon on older macs
#define VDC_ASSISTANT @"/System/Library/Frameworks/CoreMediaIO.framework/Versions/A/Resources/VDC.plugin/Contents/Resources/VDCAssistant"

//camera assistant daemon
#define APPLE_CAMERA_ASSISTANT @"/Library/CoreMediaIO/Plug-Ins/DAL/AppleCamera.plugin/Contents/Resources/AppleCameraAssistant"

//core audio
#define CORE_AUDIO @"/usr/sbin/coreaudiod"

//lsmp binary
#define LSMP @"/usr/bin/lsmp"

//sample binary
#define SAMPLE @"/usr/bin/sample"

//path to siri
#define SIRI @"/System/Library/PrivateFrameworks/AssistantServices.framework/assistantd"


/* PROPERTIES */

//flag indicating video is active
@property BOOL videoActive;

//flag indicating mic is active
@property BOOL audioActive;

//list of procs that have send Mach msg to *Assistant
@property(nonatomic, retain)NSMutableDictionary* machSendersVideo;

//list of procs that have send Mach msg to coreaudio
@property(nonatomic, retain)NSMutableDictionary* machSendersAudio;

//list of procs that have i/o reg entries
// ->IOService:/AppleACPIPlatformExpert/IOPMrootDomain/RootDomainUserClient
@property(nonatomic, retain)NSMutableDictionary* userClients;



/* METHODS */

//singleton interface
+(id)sharedManager;

//forever, baseline by getting all current procs that have sent a mach msg to *Assistant
// ->ensures its only invoke while camera is not in use, so these are all just baselined procs
-(void)start;

//enumerate all (recent) process that appear to be using the mic
-(NSMutableArray*)enumAudioProcs;

//enumerate all (recent) process that appear to be using video
-(NSMutableArray*)enumVideoProcs:(BOOL)polling;

//set status of audio
-(void)updateAudioStatus:(BOOL)isEnabled;

//set status of video
-(void)updateVideoStatus:(BOOL)isEnabled;


@end
