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

//TODO: make instance methods?!

//grab first apple camera
AVCaptureDevice* findAppleCamera()
{
    //apple camera
    // ->likely FaceTime camera
    AVCaptureDevice* appleCamera = nil;
    
    //list of cameras
    NSArray *cameras = nil;
    
    //get cameras
    cameras = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for(AVCaptureDevice* camera in cameras)
    {
        //check if apple
        if(YES == [camera.manufacturer isEqualToString:@"Apple Inc."])
        {
            //save
            appleCamera = camera;
            
            //exit loop
            break;
        }
    }
    
    return appleCamera;
}

//grab built-in mic
AVCaptureDevice* findAppleMic()
{
    //built-in mic
    AVCaptureDevice* appleMic = nil;
    
    //list of mics
    NSArray *mics = nil;
    
    //get mics
    mics = [AVCaptureDevice devicesWithMediaType:AVMediaTypeAudio];
    for(AVCaptureDevice* mic in mics)
    {
        //check if apple
        // ->also check input source
        if( (YES == [mic.manufacturer isEqualToString:@"Apple Inc."]) &&
            (YES == [[[mic activeInputSource] inputSourceID] isEqualToString:@"imic"]) )
        {
            //save
            appleMic = mic;
            
            //exit loop
            break;
        }
        
    }
    
    return appleMic;
}


@implementation AVMonitor

@synthesize mic;
@synthesize camera;
@synthesize audioActive;
@synthesize videoActive;
@synthesize videoMonitorThread;

//init
-(id)init
{
    //init super
    self = [super init];
    if(nil != self)
    {
        
    }
    
    return self;
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
    logMsg(LOG_DEBUG, @"telling XPC service to begin base-lining mach messages");
    
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
    self.camera = findAppleCamera();
    
    //find built in mic
    self.mic = findAppleMic();
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"found mic: %@", self.mic]);
    
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
        // ->start monitoring thread
        if(YES == self.videoActive)
        {
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
            logMsg(LOG_DEBUG, @"failed to watch for video events");
            
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
        
        //save camera/status into device array
        [devices addObject:@{EVENT_DEVICE:self.mic, EVENT_DEVICE_STATUS:@(self.audioActive)}];
        
        //register for audio events
        if(YES != [self watchAudio:connectionID])
        {
            //err msg
            logMsg(LOG_DEBUG, @"failed to watch for audio events");
            
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
    
    //init dictionary
    event = [NSMutableDictionary dictionary];
    
    //sync
    @synchronized (self)
    {
    
    //set status
    [self setVideoDevStatus:deviceID];
        
    //send msg to status menu
    // ->update menu to show (all) devices & their status
    [((AppDelegate*)[[NSApplication sharedApplication] delegate]).statusBarMenuController updateStatusItemMenu:@[@{EVENT_DEVICE:self.camera, EVENT_DEVICE_STATUS:@(self.videoActive)},@{EVENT_DEVICE:self.mic, EVENT_DEVICE_STATUS:@(self.audioActive)}]];

    //add device
    event[EVENT_DEVICE] = self.camera;
    
    //set device status
    event[EVENT_DEVICE_STATUS] = [NSNumber numberWithInt:self.videoActive];
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"got video change notification; is running? %x", self.videoActive]);
    
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
        logMsg(LOG_DEBUG, @"querying XPC to get video process(s)");
        
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
             logMsg(LOG_DEBUG, [NSString stringWithFormat:@"video procs from XPC: %@", videoProcesses]);
             
             //generate notification for each process
             for(NSNumber* processID in videoProcesses)
             {
                 //set pid
                 event[EVENT_PROCESS_ID] = processID;
                 
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
            //alloc
            videoMonitorThread = [[NSThread alloc] initWithTarget:self selector:@selector(monitor4Procs) object:nil];
            
            //start
            [self.videoMonitorThread start];
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
        //TODO: add
        
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
    
    //init dictionary
    event = [NSMutableDictionary dictionary];
    
    //sync
    @synchronized (self)
    {
        
    //set status
    [self setAudioDevStatus:deviceID];
        
    //send msg to status menu
    // ->update menu to show (all) devices & their status
    [((AppDelegate*)[[NSApplication sharedApplication] delegate]).statusBarMenuController updateStatusItemMenu:@[@{EVENT_DEVICE:self.mic, EVENT_DEVICE_STATUS:@(self.audioActive)},@{EVENT_DEVICE:self.camera, EVENT_DEVICE_STATUS:@(self.videoActive)}]];

    //add device
    event[EVENT_DEVICE] = self.mic;
    
    //set device status
    event[EVENT_DEVICE_STATUS] = [NSNumber numberWithInt:self.audioActive];
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"got audio change notification; is running? %x", self.audioActive]);
    
    //generate notification
    [self generateNotification:event];
        
    }
    
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
    
    
    OSStatus ret = AudioObjectAddPropertyListenerBlock(deviceID, &propertyStruct, dispatch_get_main_queue(), listenerBlock);
    if (ret)
    {
        abort(); // FIXME
    }
    
    
    //happy
    bRegistered = YES;
    
    //bail
bail:
    
    return bRegistered;
    
}

//build and display notification
-(void)generateNotification:(NSDictionary*)event
{
    //notification
    NSUserNotification* notification = nil;
    
    //title
    NSMutableString* title = nil;
    
    //details
    NSMutableString* details = nil;
    
    //process name
    NSString* processName = nil;
    
    //log msg
    NSMutableString* logMsg = nil;
    
    //alloc notificaiton
    notification = [[NSUserNotification alloc] init];
    
    //alloc title
    title = [NSMutableString string];
    
    //alloc details
    details = [NSMutableString string];
    
    //alloc log msg
    logMsg = [NSMutableString string];
    
    //set title
    // ->audio device
    if(YES == [event[EVENT_DEVICE] isKindOfClass:NSClassFromString(@"AVCaptureHALDevice")])
    {
        //add
        [title appendString:@"Audio Device"];
    }
    //add source
    // ->video device
    else
    {
        //add
        [title appendString:@"Video Device"];
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
    
    //customize buttons
    // ->for mic or inactive events, just say 'ok'
    if( (YES == [event[EVENT_DEVICE] isKindOfClass:NSClassFromString(@"AVCaptureHALDevice")]) ||
        (YES == [DEVICE_INACTIVE isEqual:event[EVENT_DEVICE_STATUS]]) )
    {
        //set other button title
        notification.otherButtonTitle = @"ok";
        
        //remove action button
        notification.hasActionButton = NO;
    }
    
    //customize buttons
    // ->for activatated video; allow/block
    else
    {
        //set other button title
        notification.otherButtonTitle = @"allow";
        
        //set action title
        notification.actionButtonTitle = @"block";
        
        //get process name
        // TODO: see 'determineName' in BB (to get name from bundle, etc)
        processName = [getProcessPath([event[EVENT_PROCESS_ID] intValue]) lastPathComponent];
        
        //set pid in user info
        // ->allows code to try kill proc (later) if user clicks 'block'
        notification.userInfo = @{EVENT_PROCESS_ID:event[EVENT_PROCESS_ID]};
        
        //set details
        // ->name of process using it / icon too?
        [notification setInformativeText:[NSString stringWithFormat:@"%@ (%@)", processName, event[EVENT_PROCESS_ID]]];
    }

    //log event?
    // TODO: test will final apps/prefs
    if(YES == [[NSUserDefaults standardUserDefaults] boolForKey:LOG_ACTIVITY])
    {
        //init msg
        [logMsg appendString:@"OVERSIGHT: "];
        
        //no process?
        // ->just add title / details
        if(nil == processName)
        {
            //add
            [logMsg appendFormat:@"%@ (%@)", title, details];
        }
        
        //process
        // ->add title / details / process
        else
        {
            //add
            [logMsg appendFormat:@"%@ (%@, %@)", title, details, processName];
        }
        
        //write it out to syslog
        syslog(LOG_ERR, "%s\n", logMsg.UTF8String);
    }
    
    //icon issues
    //http://stackoverflow.com/questions/11856766/osx-notification-center-icon
    
    //contentImage for process icon?
    
    //custom icon?
    //http://stackoverflow.com/questions/24923979/nsusernotification-customisable-app-icon
    
    //icon set automatically?
    //[notification set]
    
    //set title
    [notification setTitle:title];
    
    //set subtitle
    [notification setSubtitle:((AVCaptureDevice*)event[EVENT_DEVICE]).localizedName];
    
    //set details
    // ->name of process using it / icon too?
    //[notification setInformativeText:@"some process (1337)"];
    
    //set notification
    [[NSUserNotificationCenter defaultUserNotificationCenter] setDelegate:self];
    
    //deliver notification
    [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
    
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
// ->only action we care about, is killing the process if they click 'block'
-(void)userNotificationCenter:(NSUserNotificationCenter *)center didActivateNotification:(NSUserNotification *)notification
{
    //xpc connection
    __block NSXPCConnection* xpcConnection = nil;
    
    //process id
    NSNumber* processID = nil;
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"use responded to notification: %@", notification]);
    
    //for video
    // ->kill process if user clicked 'block'
    if( (YES == [notification.actionButtonTitle isEqualToString:@"block"]) &&
        (notification.activationType == NSUserNotificationActivationTypeActionButtonClicked))
    {
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
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"invoking XPC method to kill: %@", processID]);
        
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


//monitor for new procs (video only at the moment)
// ->runs until video is no longer in use (set elsewhere)
-(void)monitor4Procs
{
    //xpc connection
    NSXPCConnection* xpcConnection = nil;
    
    //wait semaphore
    dispatch_semaphore_t waitSema = nil;
    
    //dbg msg
    logMsg(LOG_DEBUG, @"video is active, so polling for new procs");
    
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
        logMsg(LOG_DEBUG, @"asking XPC for (new) video procs");
        
        //invoke XPC service to get (new) video procs
        // ->will generate user notifications for any new processes
        [[xpcConnection remoteObjectProxy] getVideoProcs:^(NSMutableArray* videoProcesses)
         {
             //dbg msg
             logMsg(LOG_DEBUG, [NSString stringWithFormat:@"new video procs: %@", videoProcesses]);
             
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
                 [self generateNotification:@{EVENT_DEVICE:self.camera, EVENT_DEVICE_STATUS:DEVICE_ACTIVE, EVENT_PROCESS_ID:processID}];
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
    logMsg(LOG_DEBUG, @"exiting monitor thread");
    
    return;
}

@end
