//
//  AVMonitor.m
//  OverSight
//
//  Created by Patrick Wardle on 9/01/16.
//  Copyright (c) 2015 Objective-See. All rights reserved.
//

#import "Consts.h"
#import "Logging.h"
#import "Utilities.h"
#import "AVMonitor.h"
#import "AppDelegate.h"

#import "../Shared/XPCProtocol.h"

@implementation AVMonitor

@synthesize mic;
@synthesize camera;
@synthesize lastEvent;
@synthesize whiteList;
@synthesize audioActive;
@synthesize activationAlerts;
@synthesize lastNotification;
@synthesize videoMonitorThread;
@synthesize rememberWindowController;

//init
-(id)init
{
    //init super
    self = [super init];
    if(nil != self)
    {
        //alloc
        activationAlerts = [NSMutableDictionary dictionary];
        
        //load whitelist
        [self loadWhitelist];
    }
    
    return self;
}

//load whitelist
-(void)loadWhitelist
{
    //path
    NSString* path = nil;
    
    //init path
    path = [[APP_SUPPORT_DIRECTORY stringByExpandingTildeInPath] stringByAppendingPathComponent:FILE_WHITELIST];
    
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"loading whitelist %@", path]);
    #endif
   
    //since file is created by priv'd XPC, it shouldn't be writeable
    // ...unless somebody maliciously creates it, so we check that here
    if(YES == [[NSFileManager defaultManager] isWritableFileAtPath:path])
    {
        //err msg
        logMsg(LOG_ERR, @"whitelist is writable, so ignoring!");
        
        //bail
        goto bail;
    }
   
    //load
    self.whiteList = [NSMutableArray arrayWithContentsOfFile:path];
    
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"whitelist: %@", self.whiteList]);
    #endif
    
//bail
bail:
    
    return;
}

//grab first apple camera, or default
// ->saves into iVar 'camera'
-(void)findAppleCamera
{
    //cameras
    NSArray* cameras = nil;
    
    //grab all cameras
    cameras = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"cameras: %@", cameras]);
    #endif
    
    //look for camera that belongs to apple
    for(AVCaptureDevice* currentCamera in cameras)
    {
        //check if apple
        if(YES == [currentCamera.manufacturer isEqualToString:@"Apple Inc."])
        {
            //save
            self.camera = currentCamera;
            
            //exit loop
            break;
        }
    }
    
    //didn't find apple
    // ->grab default camera
    if(nil == self.camera)
    {
        //get default
        self.camera = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
        
        //dbg msg
        #ifdef DEBUG
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"didn't find apple camera, grabbed default: %@", self.camera]);
        #endif
    }
    
    return;
}

//grab first apple mic
// ->saves into iVar 'mic'
-(void)findAppleMic
{
    //mics
    NSArray* mics = nil;
    
    //grab all mics
    mics = [AVCaptureDevice devicesWithMediaType:AVMediaTypeAudio];
    
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"mics: %@", mics]);
    #endif
    
    //look for mic that belongs to apple
    for(AVCaptureDevice* currentMic in mics)
    {
        //check if apple
        // ->also check input source
        if( (YES == [currentMic.manufacturer isEqualToString:@"Apple Inc."]) &&
            (YES == [[[currentMic activeInputSource] inputSourceID] isEqualToString:@"imic"]) )
        {
            //save
            self.mic = currentMic;
            
            //exit loop
            break;
        }
    }
    
    //didn't find apple
    // ->grab default camera
    if(nil == self.mic)
    {
        //get default
        self.mic = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
        
        //dbg msg
        #ifdef DEBUG
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"didn't find apple 'imic', grabbed default: %@", self.mic]);
        #endif
    }
    
    return;
}

//initialiaze AV notifcations/callbacks
-(BOOL)monitor
{
    //return var
    BOOL bRet = NO;
    
    //status/err var
    BOOL wasErrors = NO;
    
    //xpc connection
    __block NSXPCConnection* xpcConnection = nil;
    
    //device's connection id
    unsigned int connectionID = 0;
    
    //selector for getting device id
    SEL methodSelector = nil;
    
    //array for devices + status
    NSMutableArray* devices = nil;
    
    //wait semaphore
    dispatch_semaphore_t waitSema = nil;
    
    //alloc XPC connection
    xpcConnection = [[NSXPCConnection alloc] initWithServiceName:@"com.objective-see.OverSightXPC"];
    
    //alloc device array
    devices = [NSMutableArray array];
    
    //set remote object interface
    xpcConnection.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:@protocol(XPCProtocol)];
    
    //resume
    [xpcConnection resume];
    
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, @"telling XPC service to begin base-lining mach messages");
    #endif
    
    //init wait semaphore
    waitSema = dispatch_semaphore_create(0);
    
    //XPC service to begin baselining mach messages
    // ->wait, since want this to compelete before doing other things!
    [[xpcConnection remoteObjectProxy] initialize:^
     {
         //signal sema
         dispatch_semaphore_signal(waitSema);
         
     }];
    
    //wait until XPC is done
    // ->XPC reply block will signal semaphore
    dispatch_semaphore_wait(waitSema, DISPATCH_TIME_FOREVER);

    //init selector
    methodSelector = NSSelectorFromString(@"connectionID");
    
    //find (first) apple camera
    // ->saves camera into iVar, 'camera'
    [self findAppleCamera];
    
    //find (first) apple mic
    // ->saves mic into iVar, 'mic'
    [self findAppleMic];
    
    //got camera
    // ->grab connection ID and invoke helper functions
    if( (nil != self.camera) &&
        (YES == [self.camera respondsToSelector:methodSelector]) )
    {
        //ignore leak warning
        // ->we know what we're doing via this 'performSelector'
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        
        //grab connection ID
        connectionID = (unsigned int)[self.camera performSelector:methodSelector withObject:nil];
        
        //restore
        #pragma clang diagnostic pop
        
        //set status
        // ->will set 'videoActive' iVar
        [self setVideoDevStatus:connectionID];
        
        //if video is already active
        // ->set status & start monitoring thread
        if(YES == self.videoActive)
        {
            //dbg msg
            #ifdef DEBUG
            logMsg(LOG_DEBUG, @"video already active, so will start polling for new video procs");
            #endif
            
            //tell XPC video is active
            [[xpcConnection remoteObjectProxy] updateVideoStatus:self.videoActive reply:^{
                
                //signal sema
                dispatch_semaphore_signal(waitSema);
            }];
            
            //wait until XPC is done
            // ->XPC reply block will signal semaphore
            dispatch_semaphore_wait(waitSema, DISPATCH_TIME_FOREVER);
            
            //alloc
            videoMonitorThread = [[NSThread alloc] initWithTarget:self selector:@selector(monitor4Procs) object:nil];
            
            //start
            [self.videoMonitorThread start];
        }
        
        //save camera/status into device array
        [devices addObject:@{EVENT_DEVICE:self.camera, EVENT_DEVICE_STATUS:@(self.videoActive)}];

        //register for video events
        if(YES != [self watchVideo:connectionID])
        {
            //err msg
            #ifdef DEBUG
            logMsg(LOG_DEBUG, @"failed to watch for video events");
            #endif
            
            //set err
            wasErrors = YES;
            
            //don't bail
            // ->can still listen for audio events
        }
    }
    //err msg
    else
    {
        //err msg
        logMsg(LOG_ERR, @"failed to find (apple) camera :(");
        
        //don't bail
        // ->can still listen for audio events
    }
    
    //watch mic
    // ->grab connection ID and invoke helper function
    if( (nil != self.mic) &&
        (YES == [self.mic respondsToSelector:methodSelector]) )
    {
        //ignore leak warning
        // ->we know what we're doing via this 'performSelector'
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        
        //grab connection ID
        connectionID = (unsigned int)[self.mic performSelector:NSSelectorFromString(@"connectionID") withObject:nil];
        
        //restore
        #pragma clang diagnostic pop
        
        //set status
        // ->will set 'videoActive' iVar
        [self setAudioDevStatus:connectionID];

        //if audio is already active
        // ->tell XPC that it's active
        //   TODO: monitor for piggybacking?
        if(YES == self.audioActive)
        {
            //dbg msg
            #ifdef DEBUG
            logMsg(LOG_DEBUG, @"audio already active");
            #endif
            
            //tell XPC audio is active
            [[xpcConnection remoteObjectProxy] updateAudioStatus:self.audioActive reply:^{
                
                //signal sema
                dispatch_semaphore_signal(waitSema);
                
            }];
            
            //wait until XPC is done
            // ->XPC reply block will signal semaphore
            dispatch_semaphore_wait(waitSema, DISPATCH_TIME_FOREVER);
        }

        //save mic/status into device array
        [devices addObject:@{EVENT_DEVICE:self.mic, EVENT_DEVICE_STATUS:@(self.audioActive)}];
        
        //register for audio events
        if(YES != [self watchAudio:connectionID])
        {
            //err msg
            #ifdef DEBUG
            logMsg(LOG_DEBUG, @"failed to watch for audio events");
            #endif
            
            //set err
            wasErrors = YES;
        }
    }
    
    //err msg
    else
    {
        //err msg
        logMsg(LOG_ERR, @"failed to find (apple) mic :(");
    }
    
    //send msg to status menu
    // ->update menu to show devices & their status
    [((AppDelegate*)[[NSApplication sharedApplication] delegate]).statusBarMenuController updateStatusItemMenu:devices];
    
    //make sure no errors occured
    if(YES != wasErrors)
    {
        //happy
        bRet = YES;
    }
    
    //cleanup XPC
    if(nil != xpcConnection)
    {
        //close connection
        [xpcConnection invalidate];
        
        //nil out
        xpcConnection = nil;
    }
    
    return bRet;
}

//determine if video is active
// ->sets 'videoActive' iVar
-(void)setVideoDevStatus:(CMIODeviceID)deviceID
{
    //status var
    OSStatus status = -1;
    
    //running flag
    UInt32 isRunning = -1;
    
    //size of query flag
    UInt32 propertySize = 0;
    
    //property address struct
    CMIOObjectPropertyAddress propertyStruct = {0};
    
    //init size
    propertySize = sizeof(isRunning);
    
    //init property struct's selector
    propertyStruct.mSelector = kAudioDevicePropertyDeviceIsRunningSomewhere;
    
    //init property struct's scope
    propertyStruct.mScope = kCMIOObjectPropertyScopeGlobal;
    
    //init property struct's element
    propertyStruct.mElement = 0;
    
    //query to get 'kAudioDevicePropertyDeviceIsRunningSomewhere' status
    status = CMIOObjectGetPropertyData(deviceID, &propertyStruct, 0, NULL, sizeof(kAudioDevicePropertyDeviceIsRunningSomewhere), &propertySize, &isRunning);
    if(noErr != status)
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"getting status of video device failed with %d", status]);
        
        //set error
        isRunning = -1;
        
        //bail
        goto bail;
    }
    
    //set iVar
    self.videoActive = isRunning;
    
//bail
bail:
    
    return;
}

//helper function
// ->determines if video went active/inactive then invokes notification generator method
-(void)handleVideoNotification:(CMIOObjectID)deviceID addresses:(const CMIOObjectPropertyAddress[]) addresses
{
    //event dictionary
    NSMutableDictionary* event = nil;

    //xpc connection
    __block NSXPCConnection* xpcConnection = nil;
    
    //wait semaphore
    dispatch_semaphore_t waitSema = nil;
    
    //devices
    NSMutableArray* devices = nil;
    
    //init dictionary for event
    event = [NSMutableDictionary dictionary];
    
    //init array for devices
    devices = [NSMutableArray array];
    
    //sync
    @synchronized (self)
    {
    
    //set status
    // ->sets 'videoActive' iVar
    [self setVideoDevStatus:deviceID];
        
    //add camera
    if(nil != self.camera)
    {
        //add
        [devices addObject:@{EVENT_DEVICE:self.camera, EVENT_DEVICE_STATUS:@(self.videoActive)}];
    }
        
    //add mic
    if(nil != self.mic)
    {
        //add
        [devices addObject:@{EVENT_DEVICE:self.mic, EVENT_DEVICE_STATUS:@(self.audioActive)}];
    }

    //send msg to status menu
    // ->update menu to show (all) devices & their status
    [((AppDelegate*)[[NSApplication sharedApplication] delegate]).statusBarMenuController updateStatusItemMenu:devices];

    //add timestamp
    event[EVENT_TIMESTAMP] = [NSDate date];
        
    //add device
    event[EVENT_DEVICE] = self.camera;
    
    //set device status
    event[EVENT_DEVICE_STATUS] = [NSNumber numberWithInt:self.videoActive];
    
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"got video change notification; is running? %x", self.videoActive]);
    #endif
    
    //alloc XPC connection
    xpcConnection = [[NSXPCConnection alloc] initWithServiceName:@"com.objective-see.OverSightXPC"];
    
    //set remote object interface
    xpcConnection.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:@protocol(XPCProtocol)];
    
    //resume
    [xpcConnection resume];
    
    //init wait semaphore
    waitSema = dispatch_semaphore_create(0);
    
    //tell XPC about video status
    // ->for example, when video is active, will stop baselining
    [[xpcConnection remoteObjectProxy] updateVideoStatus:self.videoActive reply:^{
        
        //signal sema
        dispatch_semaphore_signal(waitSema);
        
    }];
    
    //wait until XPC is done
    // ->XPC reply block will signal semaphore
    dispatch_semaphore_wait(waitSema, DISPATCH_TIME_FOREVER);
    
    //if video just started
    // ->ask for video procs from XPC
    if(YES == self.videoActive)
    {
        //dbg msg
        #ifdef DEBUG
        logMsg(LOG_DEBUG, @"video is active, so querying XPC to get video process(s)");
        #endif
        
        //set allowed classes
        [xpcConnection.remoteObjectInterface setClasses: [NSSet setWithObjects: [NSMutableArray class], [NSNumber class], nil]
                                            forSelector: @selector(getVideoProcs:) argumentIndex: 0 ofReply: YES];
        
        //invoke XPC service
        [[xpcConnection remoteObjectProxy] getVideoProcs:^(NSMutableArray* videoProcesses)
         {
             //close connection
             [xpcConnection invalidate];
             
             //nil out
             xpcConnection = nil;
             
             //dbg msg
             #ifdef DEBUG
             logMsg(LOG_DEBUG, [NSString stringWithFormat:@"video procs from XPC: %@", videoProcesses]);
            #endif
             
             //generate notification for each process
             for(NSNumber* processID in videoProcesses)
             {
                 //set pid
                 event[EVENT_PROCESS_ID] = processID;
                 
                 //generate notification
                 [self generateNotification:event];
             }
             
             //if no consumer process was found
             // ->still alert user that webcam was activated, but without details/ability to block
             if(0 == videoProcesses.count)
             {
                 //set pid
                 event[EVENT_PROCESS_ID] = @0;
                 
                 //generate notification
                 [self generateNotification:event];
             }
             
             //signal sema
             dispatch_semaphore_signal(waitSema);
             
         }];
        
        //wait until XPC is done
        // ->XPC reply block will signal semaphore
        dispatch_semaphore_wait(waitSema, DISPATCH_TIME_FOREVER);
    }
        
    //video deactivated
    // ->close XPC connection and alert user
    else
    {
        //close connection
        [xpcConnection invalidate];
        
        //nil out
        xpcConnection = nil;
        
        //generate notification
        [self generateNotification:event];
    }
    
    //poll for new video procs
    // ->this thread will exit itself as its checks the 'videoActive' iVar
    if(YES == self.videoActive)
    {
        //start monitor thread if needed
        if(YES != videoMonitorThread.isExecuting)
        {
            //dbg msg
            #ifdef DEBUG
            logMsg(LOG_DEBUG, @"(re)Starting polling/monitor thread");
            #endif
            
            //alloc
            videoMonitorThread = [[NSThread alloc] initWithTarget:self selector:@selector(monitor4Procs) object:nil];
            
            //start
            [self.videoMonitorThread start];
        }
        //no need to restart
        else
        {
            //dbg msg
            #ifdef DEBUG
            logMsg(LOG_DEBUG, @"polling/monitor thread still running");
            #endif
        }
    }
    
    }//sync
    
//bail
bail:
    
    return;
}

//register for video notifcations
// ->block will invoke method on event
-(BOOL)watchVideo:(CMIOObjectID)deviceID
{
    //ret var
    BOOL bRegistered = NO;
    
    //status var
    OSStatus status = -1;
    
    //property struct
    CMIOObjectPropertyAddress propertyStruct = {0};
    
    //init property struct's selector
    propertyStruct.mSelector = kAudioDevicePropertyDeviceIsRunningSomewhere;
    
    //init property struct's scope
    propertyStruct.mScope = kAudioObjectPropertyScopeGlobal;
    
    //init property struct's element
    propertyStruct.mElement = kAudioObjectPropertyElementMaster;
    
    //block
    // ->invoked when video changes & just calls helper function
    CMIOObjectPropertyListenerBlock listenerBlock = ^(UInt32 inNumberAddresses, const CMIOObjectPropertyAddress addresses[])
    {
        //invoke helper function
        [self handleVideoNotification:deviceID addresses:addresses];
    };
    
    //register (add) property block listener
    status = CMIOObjectAddPropertyListenerBlock(deviceID, &propertyStruct, dispatch_get_main_queue(), listenerBlock);
    if(noErr != status)
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"CMIOObjectAddPropertyListenerBlock() failed with %d", status]);
        
        //bail
        goto bail;
    }
    
    //happy
    bRegistered = YES;
    
//bail
bail:
    
    return bRegistered;
}

//determine if audio is active
// ->sets 'audioActive' iVar
-(void)setAudioDevStatus:(AudioObjectID)deviceID
{
    //status var
    OSStatus status = -1;
    
    //running flag
    UInt32 isRunning = -1;
    
    //size of query flag
    UInt32 propertySize = 0;
    
    //init size
    propertySize = sizeof(isRunning);
    
    //query to get 'kAudioDevicePropertyDeviceIsRunningSomewhere' status
    status = AudioDeviceGetProperty(deviceID, 0, false, kAudioDevicePropertyDeviceIsRunningSomewhere, &propertySize, &isRunning);
    if(noErr != status)
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"getting status of audio device failed with %d", status]);
        
        //set error
        isRunning = -1;
        
        //bail
        goto bail;
    }
    
    //set iVar
    self.audioActive = isRunning;
    
//bail
bail:
    
    return;
}

//helper function
// ->determines if audio went active/inactive then invokes notification generator method
-(void)handleAudioNotification:(AudioObjectID)deviceID
{
    //event dictionary
    NSMutableDictionary* event = nil;
    
    //xpc connection
    __block NSXPCConnection* xpcConnection = nil;
    
    //wait semaphore
    dispatch_semaphore_t waitSema = nil;
    
    //init dictionary
    event = [NSMutableDictionary dictionary];
    
    //sync
    @synchronized (self)
    {
        
    //set status
    // ->updates 'audioActive' iVar
    [self setAudioDevStatus:deviceID];
        
    //send msg to status menu
    // ->update menu to show (all) devices & their status
    [((AppDelegate*)[[NSApplication sharedApplication] delegate]).statusBarMenuController updateStatusItemMenu:@[@{EVENT_DEVICE:self.mic, EVENT_DEVICE_STATUS:@(self.audioActive)},@{EVENT_DEVICE:self.camera, EVENT_DEVICE_STATUS:@(self.videoActive)}]];

    //add timestamp
    event[EVENT_TIMESTAMP] = [NSDate date];
        
    //add device
    event[EVENT_DEVICE] = self.mic;
    
    //set device status
    event[EVENT_DEVICE_STATUS] = [NSNumber numberWithInt:self.audioActive];
    
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"got audio change notification; is running? %x", self.audioActive]);
    #endif
        
    //alloc XPC connection
    xpcConnection = [[NSXPCConnection alloc] initWithServiceName:@"com.objective-see.OverSightXPC"];
    
    //set remote object interface
    xpcConnection.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:@protocol(XPCProtocol)];
    
    //resume
    [xpcConnection resume];
    
    //init wait semaphore
    waitSema = dispatch_semaphore_create(0);
    
    //tell XPC about audio status
    // ->for example, when audio is active, will stop baselining
    [[xpcConnection remoteObjectProxy] updateAudioStatus:self.audioActive reply:^{
        
        //signal sema
        dispatch_semaphore_signal(waitSema);
        
    }];
    
    //wait until XPC is done
    // ->XPC reply block will signal semaphore
    dispatch_semaphore_wait(waitSema, DISPATCH_TIME_FOREVER);
    
    //if video just started
    // ->ask for video procs from XPC
    if(YES == self.audioActive)
    {
        //dbg msg
        #ifdef DEBUG
        logMsg(LOG_DEBUG, @"audio is active, so querying XPC to get audio process(s)");
        #endif
        
        //set allowed classes
        [xpcConnection.remoteObjectInterface setClasses: [NSSet setWithObjects: [NSMutableArray class], [NSNumber class], nil]
                                            forSelector: @selector(getAudioProcs:) argumentIndex: 0 ofReply: YES];
        
        //invoke XPC service
        [[xpcConnection remoteObjectProxy] getAudioProcs:^(NSMutableArray* audioProcesses)
         {
             //close connection
             [xpcConnection invalidate];
             
             //nil out
             xpcConnection = nil;
             
             //dbg msg
             #ifdef DEBUG
             logMsg(LOG_DEBUG, [NSString stringWithFormat:@"audio procs from XPC: %@", audioProcesses]);
             #endif
             
             //generate notification for each process
             for(NSNumber* processID in audioProcesses)
             {
                 //set pid
                 event[EVENT_PROCESS_ID] = processID;
                 
                 //generate notification
                 [self generateNotification:event];
             }
             
             //if no consumer process was found
             // ->still alert user that webcam was activated, but without details/ability to block
             if(0 == audioProcesses.count)
             {
                 //set pid
                 event[EVENT_PROCESS_ID] = @0;
                 
                 //generate notification
                 [self generateNotification:event];
             }
             
             //signal sema
             dispatch_semaphore_signal(waitSema);
             
         }];
        
        //wait until XPC is done
        // ->XPC reply block will signal semaphore
        dispatch_semaphore_wait(waitSema, DISPATCH_TIME_FOREVER);
    }
    
    //audio deactivated
    // ->close XPC connection and alert user
    else
    {
        //close connection
        [xpcConnection invalidate];
        
        //nil out
        xpcConnection = nil;
        
        //generate notification
        [self generateNotification:event];
    }

    }//sync
    
//bail
bail:
    
    return;
}

//register for audio notifcations
// ->block will invoke method on event
-(BOOL)watchAudio:(AudioObjectID)deviceID
{
    //ret var
    BOOL bRegistered = NO;
    
    //status var
    OSStatus status = -1;
    
    //property struct
    AudioObjectPropertyAddress propertyStruct = {0};
    
    //init property struct's selector
    propertyStruct.mSelector = kAudioDevicePropertyDeviceIsRunningSomewhere;
    
    //init property struct's scope
    propertyStruct.mScope = kAudioObjectPropertyScopeGlobal;
    
    //init property struct's element
    propertyStruct.mElement = kAudioObjectPropertyElementMaster;
    
    //block
    // ->invoked when audio changes & just calls helper function
    AudioObjectPropertyListenerBlock listenerBlock = ^(UInt32 inNumberAddresses, const AudioObjectPropertyAddress *inAddresses)
    {
        [self handleAudioNotification:deviceID];
    };
    
    //add property listener for audio changes
    status = AudioObjectAddPropertyListenerBlock(deviceID, &propertyStruct, dispatch_get_main_queue(), listenerBlock);
    if(noErr != status)
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"AudioObjectAddPropertyListenerBlock() failed with %d", status]);
        
        //bail
        goto bail;
    }

    //happy
    bRegistered = YES;
    
//bail
bail:
    
    return bRegistered;
}

//build and display notification
// ->handles extra logic like ignore whitelisted apps, disable alerts (if user has turned that off), etc
-(void)generateNotification:(NSMutableDictionary*)event
{
    //notification
    NSUserNotification* notification = nil;
    
    //device
    // ->audio or video
    NSNumber* deviceType = nil;
    
    //title
    NSMutableString* title = nil;
    
    //details
    // ->just name of device for now
    NSString* details = nil;
    
    //process name
    NSString* processName = nil;
    
    //process path
    NSString* processPath = nil;
    
    //log msg
    NSMutableString* sysLogMsg = nil;
    
    //preferences
    NSDictionary* preferences = nil;
    
    //flag
    BOOL matchingActivationAlert = NO;
    
    //alloc notificaiton
    notification = [[NSUserNotification alloc] init];
    
    //alloc title
    title = [NSMutableString string];
    
    //alloc log msg
    sysLogMsg = [NSMutableString string];
    
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"generating notification for %@", event]);
    #endif
    
    //get process name
    processName = getProcessName([event[EVENT_PROCESS_ID] intValue]);
    
    //get process path
    processPath = getProcessPath([event[EVENT_PROCESS_ID] intValue]);
    if(nil == processPath)
    {
        //set to something
        processPath = PROCESS_UNKNOWN;
    }
    
    //set device and title for audio
    if(YES == [event[EVENT_DEVICE] isKindOfClass:NSClassFromString(@"AVCaptureHALDevice")])
    {
        //add
        [title appendString:@"Audio Device"];
        
        //set device
        deviceType = SOURCE_AUDIO;
        
    }
    //set device and title for video
    else
    {
        //add
        [title appendString:@"Video Device"];
        
        //set device
        deviceType = SOURCE_VIDEO;
    }
    
    //ignore whitelisted processes
    // ->for activation events, can check process path
    if(YES == [DEVICE_ACTIVE isEqual:event[EVENT_DEVICE_STATUS]])
    {
        //check each
        // ->need match on path and device (camera || mic)
        for(NSDictionary* item in self.whiteList)
        {
            //check path & device
            if( (YES == [item[EVENT_PROCESS_PATH] isEqualToString:processPath]) &&
                ([item[EVENT_DEVICE] intValue] == deviceType.intValue) )
            {
                //dbg msg
                #ifdef DEBUG
                logMsg(LOG_DEBUG, [NSString stringWithFormat:@"activation alert for process %@ is whitelisted, so ignoring", item]);
                #endif
                
                //bail
                goto bail;
            }
        }
    }
    //ignore whitelisted processes
    // ->for deactivation, ignore when no activation alert was shown (cuz process will have likely died, so no pid/path, etc)
    if(YES == [DEVICE_INACTIVE isEqual:event[EVENT_DEVICE_STATUS]])
    {
        //any active alerts?
        // ->note: we make to check if the type matches
        for(NSUUID* key in self.activationAlerts.allKeys)
        {
            //same type?
            if(event[EVENT_DEVICE] == self.activationAlerts[key][EVENT_DEVICE])
            {
                //got match
                matchingActivationAlert = YES;
                
                //no need to check more
                break;
            }
        }
        
        //no match?
        // ->bail, as means process was whitelisted so no activation was shown
        if(YES != matchingActivationAlert)
        {
            //dbg msg
            #ifdef DEBUG
            logMsg(LOG_DEBUG, @"deactivation alert doesn't have an activation alert (whitelisted?), so ignoring");
            #endif

            //bail
            goto bail;
        }
    }
    
    //check if event is essentially a duplicate (facetime, etc)
    if(nil != self.lastEvent)
    {
        //less than 10 second ago?
        if(fabs([self.lastEvent[EVENT_TIMESTAMP] timeIntervalSinceDate:event[EVENT_TIMESTAMP]]) < 10)
        {
            //same process/device/action
            if( (YES == [self.lastEvent[EVENT_PROCESS_ID] isEqual:event[EVENT_PROCESS_ID]]) &&
                (YES == [self.lastEvent[EVENT_DEVICE] isEqual:event[EVENT_DEVICE]]) &&
                (YES == [self.lastEvent[EVENT_DEVICE_STATUS] isEqual:event[EVENT_DEVICE_STATUS]]) )
            {
                //dbg msg
                #ifdef DEBUG
                logMsg(LOG_DEBUG, [NSString stringWithFormat:@"alert for %@ would be same as previous (%@), so ignoring", event, self.lastEvent]);
                #endif
                
                //update
                self.lastEvent = event;
                
                //bail to ignore
                goto bail;
            }
        }
        
    }//'same' event check
    
    //update last event
    self.lastEvent = event;
    
    //always (manually) load preferences
    preferences = [NSDictionary dictionaryWithContentsOfFile:[APP_PREFERENCES stringByExpandingTildeInPath]];
    
    //check if user wants to ingnore inactive alerts
    if( (YES == [preferences[PREF_DISABLE_INACTIVE] boolValue]) &&
        (YES == [DEVICE_INACTIVE isEqual:event[EVENT_DEVICE_STATUS]]) )
    {
        //dbg msg
        #ifdef DEBUG
        logMsg(LOG_DEBUG, @"user has decided to ingore 'inactive' events, so ingoring A/V going to disable state");
        #endif
        
        //bail
        goto bail;
    }
    
    //add action
    // ->device went inactive
    if(YES == [DEVICE_INACTIVE isEqual:event[EVENT_DEVICE_STATUS]])
    {
        //add
        [title appendString:@" became inactive"];
    }
    //add action
    // ->device went active
    else
    {
        //add
        [title appendString:@" became active"];
    }
    
    //set details
    // ->name of device
    details = ((AVCaptureDevice*)event[EVENT_DEVICE]).localizedName;
    
    //ALERT 1:
    // ->activate alert with lots of info
    if( (YES == [DEVICE_ACTIVE isEqual:event[EVENT_DEVICE_STATUS]]) &&
        (0 != [event[EVENT_PROCESS_ID] intValue]) )
        
    {
        //set other button title
        notification.otherButtonTitle = @"allow";
        
        //set action title
        notification.actionButtonTitle = @"block";
        
        //remove action button
        notification.hasActionButton = YES;
        
        //set pid/name/device into user info
        // ->allows code to whitelist proc and/or kill proc (later) if user clicks 'block'
        notification.userInfo = @{EVENT_PROCESS_ID:event[EVENT_PROCESS_ID], EVENT_PROCESS_PATH:processPath, EVENT_PROCESS_NAME:processName, EVENT_DEVICE:deviceType, EVENT_ALERT_TYPE:ALERT_ACTIVATE};
        
        //set details
        // ->name of process using it / icon too?
        [notification setInformativeText:[NSString stringWithFormat:@"process: %@ (%@)", processName, event[EVENT_PROCESS_ID]]];
    }
    
    //ALERT 2:
    // ->activate alert, with no process info
    else if( (YES == [DEVICE_ACTIVE isEqual:event[EVENT_DEVICE_STATUS]]) &&
         (0 == [event[EVENT_PROCESS_ID] intValue]) )
    {
        //set other button title
        notification.otherButtonTitle = @"ok";
        
        //remove action button
        notification.hasActionButton = NO;
        
        //set type
        notification.userInfo = @{EVENT_DEVICE:deviceType, EVENT_ALERT_TYPE:ALERT_ACTIVATE};
    }
    
    //ALERT 3:
    // ->inactive alert, with no process info
    else
    {
        //set other button title
        notification.otherButtonTitle = @"ok";
        
        //remove action button
        notification.hasActionButton = NO;
        
        //set type
        notification.userInfo = @{EVENT_DEVICE:deviceType, EVENT_ALERT_TYPE:ALERT_INACTIVE};
    }
    
    //log event?
    if(YES == [preferences[PREF_LOG_ACTIVITY] boolValue])
    {
        //init msg
        [sysLogMsg appendString:@"OVERSIGHT: "];
        
        //no process?
        // ->just add title / details
        if( (nil == processName) ||
            (YES == [processName isEqualToString:PROCESS_UNKNOWN]) )
        {
            //add
            [sysLogMsg appendFormat:@"%@ (%@)", title, details];
        }
        
        //process
        // ->add title / details / process name / process path
        else
        {
            //add
            [sysLogMsg appendFormat:@"%@ (%@, process: %@/%@)", title, details, processName, processPath];
        }
        
        //write it out to syslog
        syslog(LOG_ERR, "%s\n", sysLogMsg.UTF8String);
    }
    
    //set title
    [notification setTitle:title];
    
    //set subtitle
    [notification setSubtitle:details];
    
    //set id
    notification.identifier = [[NSUUID UUID] UUIDString];
    
    //set notification
    [[NSUserNotificationCenter defaultUserNotificationCenter] setDelegate:self];
    
    //deliver notification
    [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
    
    //save displayed activation alerts
    if(YES == [DEVICE_ACTIVE isEqual:event[EVENT_DEVICE_STATUS]])
    {
        //save
        self.activationAlerts[notification.identifier] = event;
    }
    
    //for 'went inactive' notification automatically close
    //  ->unless there still is an active alert on the screen
    if(YES == [DEVICE_INACTIVE isEqual:event[EVENT_DEVICE_STATUS]])
    {
        //any active alerts still visible?
        // ->note: we make to check if the type matches
        for(NSUUID* key in self.activationAlerts.allKeys)
        {
            //same type?
            if(event[EVENT_DEVICE] == self.activationAlerts[key][EVENT_DEVICE])
            {
                //got match
                matchingActivationAlert = YES;
                
                //no need to check more
                break;
            }
        }
        
        //go match
        // ->close if not still visible
        if(YES != matchingActivationAlert)
        {
            //dbg msg
            #ifdef DEBUG
            logMsg(LOG_DEBUG, @"automatically closing deactivation alert");
            #endif
            
            //delay, then close
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                
                //close
                [NSUserNotificationCenter.defaultUserNotificationCenter removeDeliveredNotification:notification];
                
            });
        }
    }
    
//bail
bail:
    
    return;
}

//always present notifications
-(BOOL)userNotificationCenter:(NSUserNotificationCenter *)center shouldPresentNotification:(NSUserNotification *)notification
{
    return YES;
}

//automatically invoked when user interacts w/ the notification popup
// ->handle rule creation, blocking/killing proc, etc
-(void)userNotificationCenter:(NSUserNotificationCenter *)center didActivateNotification:(NSUserNotification *)notification
{
    //xpc connection
    __block NSXPCConnection* xpcConnection = nil;
    
    //process id
    NSNumber* processID = nil;
    
    //device type
    NSNumber* deviceType = nil;
    
    //preferences
    NSDictionary* preferences = nil;
    
    //log msg
    NSMutableString* sysLogMsg = nil;
    
    //always (manually) load preferences
    preferences = [NSDictionary dictionaryWithContentsOfFile:[APP_PREFERENCES stringByExpandingTildeInPath]];
    
    //alloc log msg
    sysLogMsg = [NSMutableString string];
    
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"user responded to notification: %@", notification]);
    #endif
    
    //ignore if this notification was already seen
    // ->need this logic, since have to determine if 'allow' was invoke indirectly
    if(nil != self.lastNotification)
    {
        //same?
        if(YES == [self.lastNotification isEqualToString:notification.identifier])
        {
            //update
            self.lastNotification = notification.identifier;
            
            //ignore
            goto bail;
        }
    }
    
    //when it's a deactivation alert
    // ->remove all activation alerts that match the same type
    if(ALERT_INACTIVE.intValue == [notification.userInfo[EVENT_ALERT_TYPE] intValue])
    {
        //remove any active alerts
        // ->note: we make to check if the type matches
        for(NSUUID* key in self.activationAlerts.allKeys)
        {
            //check stored activation alert type
            // ->audio
            if(YES == [self.activationAlerts[key][EVENT_DEVICE] isKindOfClass:NSClassFromString(@"AVCaptureHALDevice")])
            {
                //set device
                deviceType = SOURCE_AUDIO;
            }
            //check stored activation alert type
            // ->video
            else
            {
                //set device
                deviceType = SOURCE_VIDEO;
            }
            
            //same type?
            if( [notification.userInfo[EVENT_DEVICE] intValue] == deviceType.intValue)
            {
                //remove
                [self.activationAlerts removeObjectForKey:key];
            }
        }
    }

    //update
    self.lastNotification = notification.identifier;
    
    //for alerts without an action
    // ->don't need to do anything!
    if(YES != notification.hasActionButton)
    {
        //dbg msg
        #ifdef DEBUG
        logMsg(LOG_DEBUG, @"popup without an action, no need to do anything");
        #endif
        
        //bail
        goto bail;
    }
    
    //log user's response?
    if(YES == [preferences[PREF_LOG_ACTIVITY] boolValue])
    {
        //init msg
        [sysLogMsg appendString:@"OVERSIGHT: "];
        
        //user clicked 'block'
        if(notification.activationType == NSUserNotificationActivationTypeActionButtonClicked)
        {
            //add
            [sysLogMsg appendFormat:@"user clicked 'block' for %@", notification.userInfo];
        }
        //user clicked 'allow'
        else
        {
            //add
            [sysLogMsg appendFormat:@"user clicked 'allow' for %@", notification.userInfo];
        }
        
        //write it out to syslog
        syslog(LOG_ERR, "%s\n", sysLogMsg.UTF8String);
    }
    
    //check if user clicked 'allow' via user info (since OS doesn't directly deliver this)
    // ->show a popup w/ option to remember ('whitelist') the application
    //   don't do this for 'block' since that kills the app, so obv, that'd be bad to *always* do!
    if(NSUserNotificationActivationTypeAdditionalActionClicked == [notification.userInfo[@"activationType"] integerValue])
    {
        //dbg msg
        #ifdef DEBUG
        logMsg(LOG_DEBUG, @"user clicked 'allow'");
        #endif
        
        //can't remember process that we didn't find the path for
        if(YES == [notification.userInfo[EVENT_PROCESS_PATH] isEqualToString:PROCESS_UNKNOWN])
        {
            //dbg msg
            #ifdef DEBUG
            logMsg(LOG_DEBUG, @"don't have a process path, so not displaying whitelisting popup");
            #endif

            //bail
            goto bail;
        }
     
        //alloc/init settings window
        if(nil == self.rememberWindowController)
        {
            //alloc/init
            rememberWindowController = [[RememberWindowController alloc] initWithWindowNibName:@"RememberPopup"];
        }
        
        //center window
        [[self.rememberWindowController window] center];
        
        //show it
        [self.rememberWindowController showWindow:self];
        
        //manually configure
        // ->invoke here as the outlets will be set
        [self.rememberWindowController configure:notification avMonitor:self];
        
        //make it key window
        [self.rememberWindowController.window makeKeyAndOrderFront:self];
        
        //make window front
        [NSApp activateIgnoringOtherApps:YES];
    }
    
    //when user clicks 'block'
    // ->kill the process to block it
    else if(NSUserNotificationActivationTypeActionButtonClicked == notification.activationType)
    {
        //dbg msg
        #ifdef DEBUG
        logMsg(LOG_DEBUG, @"user clicked 'block'");
        #endif
        
        //extract process id
        processID = notification.userInfo[EVENT_PROCESS_ID];
        if(nil == processID)
        {
            //err msg
            logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to extract process id from notification, %@", notification.userInfo]);
            
            //bail
            goto bail;
        }
        
        //alloc XPC connection
        xpcConnection = [[NSXPCConnection alloc] initWithServiceName:@"com.objective-see.OverSightXPC"];
        
        //set remote object interface
        xpcConnection.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:@protocol(XPCProtocol)];
        
        //resume
        [xpcConnection resume];
        
        //dbg msg
        #ifdef DEBUG
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"invoking XPC method to kill: %@", processID]);
        #endif
        
        //invoke XPC method 'killProcess' to terminate
        [[xpcConnection remoteObjectProxy] killProcess:processID reply:^(BOOL wasKilled)
         {
             //check for err
             if(YES != wasKilled)
             {
                 //err msg
                 logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to kill/block: %@", processID]);
             }
             
             //close connection
             [xpcConnection invalidate];
             
             //nil out
             xpcConnection = nil;
         }];

    }//user clicked 'block'
    
//bail
bail:
         
    return;
}

//manually monitor delivered notifications to see if user closes alert
// ->can't detect 'allow' otherwise :/ (see: http://stackoverflow.com/questions/21110714/mac-os-x-nsusernotificationcenter-notification-get-dismiss-event-callback)
-(void)userNotificationCenter:(NSUserNotificationCenter *)center didDeliverNotification:(NSUserNotification *)notification
{
    //flag
    __block BOOL notificationStillPresent;
    
    //user dictionary
    __block NSMutableDictionary* userInfo = nil;

    //monitor in background to see if alert was dismissed
    // ->invokes normal 'didActivateNotification' callback when alert is dimsissed
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
    ^{
            //monitor all delivered notifications until it goes away
            do {
                
                //reset
                notificationStillPresent = NO;
               
                //check all delivered notifications
                for (NSUserNotification *nox in [[NSUserNotificationCenter defaultUserNotificationCenter] deliveredNotifications])
                {
                    //check
                    if(YES == [nox.identifier isEqualToString:notification.identifier])
                    {
                        //found!
                        notificationStillPresent = YES;
                        
                        //exit loop
                        break;
                    }
                }
                
                //nap if notification is still there
                if(YES == notificationStillPresent)
                {
                    //nap
                    [NSThread sleepForTimeInterval:0.25f];
                }
                
            //keep monitoring until its gone
            } while(YES == notificationStillPresent);
        
            //alert was dismissed
            // ->invoke 'didActivateNotification' to process if it was an 'allow/block' alert
            dispatch_async(dispatch_get_main_queue(),
            ^{
                    //add extra info for activation alerts
                    // ->will allow callback to identify we delivered via this mechanism
                    if(YES == notification.hasActionButton)
                    {
                        //grab user info dictionary
                        userInfo = [notification.userInfo mutableCopy];
                    
                        //add activation type
                        userInfo[@"activationType"] = [NSNumber numberWithInteger:NSUserNotificationActivationTypeAdditionalActionClicked];
                    
                        //update
                        notification.userInfo =  userInfo;
                    }
                
                    //deliver
                    [self userNotificationCenter:center didActivateNotification:notification];
            });
        });
    
    return;
}

//monitor for new procs (video only at the moment)
// ->runs until video is no longer in use (set elsewhere)
-(void)monitor4Procs
{
    //xpc connection
    NSXPCConnection* xpcConnection = nil;
    
    //wait semaphore
    dispatch_semaphore_t waitSema = nil;
    
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, @"[MONITOR THREAD] video is active, so polling for new procs");
    #endif
    
    //alloc XPC connection
    xpcConnection = [[NSXPCConnection alloc] initWithServiceName:@"com.objective-see.OverSightXPC"];
    
    //set remote object interface
    xpcConnection.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:@protocol(XPCProtocol)];
    
    //set classes
    // ->arrays/numbers ok to vend
    [xpcConnection.remoteObjectInterface setClasses: [NSSet setWithObjects: [NSMutableArray class], [NSNumber class], nil]
                                        forSelector: @selector(getVideoProcs:) argumentIndex: 0 ofReply: YES];
    //resume
    [xpcConnection resume];
    
    //poll while video is active
    while(YES == self.videoActive)
    {
        //init wait semaphore
        waitSema = dispatch_semaphore_create(0);
        
        //dbg msg
        #ifdef DEBUG
        logMsg(LOG_DEBUG, @"[MONITOR THREAD] (re)Asking XPC for (new) video procs");
        #endif
        
        //invoke XPC service to get (new) video procs
        // ->will generate user notifications for any new processes
        [[xpcConnection remoteObjectProxy] getVideoProcs:^(NSMutableArray* videoProcesses)
         {
             //dbg msg
             #ifdef DEBUG
             logMsg(LOG_DEBUG, [NSString stringWithFormat:@"[MONITOR THREAD] found %lu new video procs: %@", (unsigned long)videoProcesses.count, videoProcesses]);
            #endif
             
             //generate a notification for each process
             // ->double check video is still active though...
             for(NSNumber* processID in videoProcesses)
             {
                 //check video
                 if(YES != self.videoActive)
                 {
                     //exit loop
                     break;
                 }
                 
                 //generate notification
                 [self generateNotification:[@{EVENT_TIMESTAMP:[NSDate date], EVENT_DEVICE:self.camera, EVENT_DEVICE_STATUS:DEVICE_ACTIVE, EVENT_PROCESS_ID:processID} mutableCopy]];
             }
             
             //signal sema
             dispatch_semaphore_signal(waitSema);
             
         }];
    
        //wait until XPC is done
        // ->XPC reply block will signal semaphore
        dispatch_semaphore_wait(waitSema, DISPATCH_TIME_FOREVER);

        //nap
        [NSThread sleepForTimeInterval:5.0f];
        
    }//run until video (camera) is off
    
//bail
bail:

    //close connection
    [xpcConnection invalidate];
    
    //nil out
    xpcConnection = nil;
    
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, @"[MONITOR THREAD] exiting polling/monitor thread since camera is off");
    #endif
    
    return;
}

@end
