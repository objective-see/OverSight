//
//  AVMonitor.m
//  Application
//
//  Created by Patrick Wardle on 4/30/21.
//  Copyright © 2021 Objective-See. All rights reserved.
//

@import OSLog;
@import AVFoundation;

#import "consts.h"
#import "Client.h"
#import "AVMonitor.h"
#import "utilities.h"
#import "AppDelegate.h"

/* GLOBALS */

//log handle
extern os_log_t logHandle;

@implementation AVMonitor

//init
-(id)init
{
    //action: ok
    UNNotificationAction *ok = nil;
    
    //action: allow
    UNNotificationAction *allow = nil;
    
    //action: allow
    UNNotificationAction *allowAlways = nil;
    
    //action: block
    UNNotificationAction *block = nil;
    
    //close category
    UNNotificationCategory* closeCategory = nil;
    
    //action category
    UNNotificationCategory* actionCategory = nil;
    
    //super
    self = [super init];
    if(nil != self)
    {
        //init log monitor
        self.logMonitor = [[LogMonitor alloc] init];
        
        //init audio attributions
        self.audioAttributions = [NSMutableArray array];
        
        //init camera attributions
        self.cameraAttributions = [NSMutableArray array];
        
        //init audio listeners
        self.audioListeners = [NSMutableDictionary dictionary];
        
        //init video listeners
        self.cameraListeners = [NSMutableDictionary dictionary];
        
        //set up delegate
        UNUserNotificationCenter.currentNotificationCenter.delegate = self;
        
        //init ok action
        ok = [UNNotificationAction actionWithIdentifier:@"Ok" title:@"Ok" options:UNNotificationActionOptionNone];
        
        //init close category
        closeCategory = [UNNotificationCategory categoryWithIdentifier:CATEGORY_CLOSE actions:@[ok] intentIdentifiers:@[] options:0];
        
        //init allow action
        allow = [UNNotificationAction actionWithIdentifier:@"Allow" title:@"Allow (Once)" options:UNNotificationActionOptionNone];
        
        //init allow action
        allowAlways = [UNNotificationAction actionWithIdentifier:@"AllowAlways" title:@"Allow (Always)" options:UNNotificationActionOptionNone];
        
        //init block action
        block = [UNNotificationAction actionWithIdentifier:@"Block" title:@"Block" options:UNNotificationActionOptionNone];
        
        //init category
        actionCategory = [UNNotificationCategory categoryWithIdentifier:CATEGORY_ACTION actions:@[allow, allowAlways, block] intentIdentifiers:@[] options:UNNotificationCategoryOptionCustomDismissAction];
        
        //set categories
        [UNUserNotificationCenter.currentNotificationCenter setNotificationCategories:[NSSet setWithObjects:closeCategory, actionCategory, nil]];
        
        //per device events
        self.deviceEvents = [NSMutableDictionary dictionary];
        
        //init audio event queue
        self.audioEventQueue = dispatch_queue_create("audio.event.timer", 0);
        
        //init camera event queue
        self.cameraEventQueue = dispatch_queue_create("camera.event.timer", 0);
        
        //enumerate active devices
        // then update status menu (on main thread)
        dispatch_async(dispatch_get_main_queue(), ^{
            
            //update status menu
            [((AppDelegate*)[[NSApplication sharedApplication] delegate]).statusBarItemController setActiveDevices:[self enumerateActiveDevices]];
            
        });
        
        //find built-in mic
        self.builtInMic = [self findBuiltInMic];
        
        //dbg msg
        os_log_debug(logHandle, "built-in mic: %{public}@ (device ID: %d)", self.builtInMic.localizedName, [self getAVObjectID:self.builtInMic]);
        
        //find built-in camera
        self.builtInCamera = [self findBuiltInCamera];
        
        //dbg msg
        os_log_debug(logHandle, "built-in camera: %{public}@ (device ID: %d)", self.builtInCamera.localizedName, [self getAVObjectID:self.builtInCamera]);
        
    }
    
    return self;
}

//monitor AV
// also generate alerts as needed
-(void)start
{
    //dbg msg
    os_log_debug(logHandle, "starting AV monitoring");

    //start log monitor
    [self startLogMonitor];
    
    //watch all input audio (mic) devices
    for(AVCaptureDevice* audioDevice in [AVCaptureDevice devicesWithMediaType:AVMediaTypeAudio])
    {
       //start (device) monitor
       [self watchAudioDevice:audioDevice];
    }
       
    //watch all input video (cam) devices
    for(AVCaptureDevice* videoDevice in [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo])
    {
       //start (device) monitor
       [self watchVideoDevice:videoDevice];
    }
    
    return;
}

//log monitor
-(void)startLogMonitor
{
    //dbg msg
    os_log_debug(logHandle, "starting log monitor for AV events via w/ 'com.apple.SystemStatus'");

    //start logging
    [self.logMonitor start:[NSPredicate predicateWithFormat:@"subsystem=='com.apple.SystemStatus'"] level:Log_Level_Default callback:^(OSLogEvent* logEvent) {
    
        //flags
        BOOL audioAttributionsList = NO;
        BOOL cameraAttributionsList = NO;
        
        //new audio attributions
        NSMutableArray* newAudioAttributions = nil;
    
        //new camera attributions
        NSMutableArray* newCameraAttributions = nil;
                
        //dbg msg
        os_log_debug(logHandle, "log message from 'com.apple.SystemStatus'");
        
        //only interested on "Server data changed..." msgs
        if(YES != [logEvent.composedMessage containsString:@"Server data changed for media domain"])
        {
            return;
        }
        
        //dbg msg
        //os_log_debug(logHandle, "new (video) client msg: %{public}@", logEvent.composedMessage);
        
        //split on newlines
        // ...and then parse out audio/camera attributions
        for(NSString* __strong line in [logEvent.composedMessage componentsSeparatedByString:@"\n"])
        {
            //pid
            NSNumber* pid = 0;
            
            //trim
            line = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            
            //audioAttributions list?
            if(YES == [line hasPrefix:@"audioAttributions = "])
            {
                //set flag
                audioAttributionsList = YES;
                
                //init
                newAudioAttributions = [NSMutableArray array];
                
                //unset (other) list
                cameraAttributionsList = NO;
                
                //next
                continue;
            }
            
            //cameraAttributions list?
            if(YES == [line hasPrefix:@"cameraAttributions = "])
            {
                //set flag
                cameraAttributionsList = YES;
                
                //init
                newCameraAttributions = [NSMutableArray array];
                
                //unset (other) list
                audioAttributionsList = NO;
                
                //next
                continue;
            }
            
            //audit token of item?
            if(YES == [line containsString:@"<BSAuditToken:"])
            {
                //pid extraction regex
                NSRegularExpression* regex = nil;
                
                //match
                NSTextCheckingResult* match = nil;
                
                //init regex
                regex = [NSRegularExpression regularExpressionWithPattern:@"(?<=PID: )[0-9]*" options:0 error:nil];
                
                //match/extract pid
                match = [regex firstMatchInString:line options:0 range:NSMakeRange(0, line.length)];
                if( (nil == match) ||
                    (NSNotFound == match.range.location))
                {
                    //ignore
                    continue;
                }
                
                //extract pid
                pid = @([[line substringWithRange:[match rangeAtIndex:0]] intValue]);
                
                //in audio list?
                if(YES == audioAttributionsList)
                {
                    //add
                    [newAudioAttributions addObject:[NSNumber numberWithInt:[pid intValue]]];
                }
                //in camera list?
                else if(YES == cameraAttributionsList)
                {
                    //add
                    [newCameraAttributions addObject:[NSNumber numberWithInt:[pid intValue]]];
                }

                //next
                continue;
            }
        }
        
        //sync to process
        @synchronized (self) {
            
            //process attibutions
            [self processAttributions:newAudioAttributions newCameraAttributions:newCameraAttributions];
        }
        
        //(re)enumerate active devices
        // delayed need as device deactiavation
        // then update status menu (on main thread)
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^
        {
            //update on on main thread
            dispatch_async(dispatch_get_main_queue(), ^{
            
                //update status menu
                [((AppDelegate*)[[NSApplication sharedApplication] delegate]).statusBarItemController setActiveDevices:[self enumerateActiveDevices]];
                
            });
            
        }); //dispatch for delay
    }];

    return;
}

//process attributions
// will generate (any needed) events to trigger alerts to user
-(void)processAttributions:(NSMutableArray*)newAudioAttributions newCameraAttributions:(NSMutableArray*)newCameraAttributions
{
    //audio differences
    NSOrderedCollectionDifference* audioDifferences = nil;
    
    //camera differences
    NSOrderedCollectionDifference* cameraDifferences = nil;
    
    //client
    __block Client* client = nil;
    
    //event
    __block Event* event = nil;
    
    //diff audio differences
    if(nil != newAudioAttributions)
    {
        //diff
        audioDifferences = [newAudioAttributions differenceFromArray:self.audioAttributions];
    }
    
    //diff camera differences
    if(nil != newCameraAttributions)
    {
        //diff
        cameraDifferences = [newCameraAttributions differenceFromArray:self.cameraAttributions];
    }
    
    /* audio event logic */
    
    //new audio event?
    // handle (lookup mic, send event)
    if(YES == audioDifferences.hasChanges)
    {
        //cancel prev timer
        if(nil != self.audioEventTimer)
        {
            //cancel
            dispatch_cancel(self.audioEventTimer);
            self.audioEventTimer = nil;
        }
        
        //re-init timer
        self.audioEventTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, self.audioEventQueue);
        dispatch_source_set_timer(self.audioEventTimer, dispatch_walltime(NULL, 1.0 * NSEC_PER_SEC), DISPATCH_TIME_FOREVER, 0.1 * NSEC_PER_SEC);
        
        //set handler
        dispatch_source_set_event_handler(self.audioEventTimer, ^{
            
            //active mic
            AVCaptureDevice* activeMic = nil;
            
            //canel timer
            dispatch_cancel(self.audioEventTimer);
            self.audioEventTimer = nil;
            
            //audio off?
            // sent event
            if(0 == audioDifferences.insertions.count)
            {
                //dbg msg
                os_log_debug(logHandle, "audio event: off");
                
                //init event
                // process (client) and device are nil
                event = [[Event alloc] init:nil device:nil deviceType:Device_Microphone state:NSControlStateValueOff];
                
                //handle event
                [self handleEvent:event];
            }
            
            //audio on?
            // send event
            else
            {
                //dbg msg
                os_log_debug(logHandle, "audio event: on");
                
                //send event for each process (attribution)
                for(NSOrderedCollectionChange* audioAttribution in audioDifferences.insertions)
                {
                    //init client from attribution
                    client = [[Client alloc] init];
                    client.pid = audioAttribution.object;
                    client.path = valueForStringItem(getProcessPath(client.pid.intValue));
                    client.name = valueForStringItem(getProcessName(client.path));
                    
                    //look for active mic
                    for(AVCaptureDevice* microphone in [AVCaptureDevice devicesWithMediaType:AVMediaTypeAudio])
                    {
                        //off? skip
                        if(NSControlStateValueOn != [self getMicState:microphone])
                        {
                            //skip
                            continue;
                        }
                        
                        //dbg msg
                        os_log_debug(logHandle, "device: %{public}@/%{public}@ is on", microphone.manufacturer, microphone.localizedName);
                        
                        //save
                        activeMic = microphone;
                        
                        //init event
                        // with client and (active) mic
                        event = [[Event alloc] init:client device:activeMic deviceType:Device_Microphone state:NSControlStateValueOn];
                        
                        //handle event
                        [self handleEvent:event];
                    }
                    
                    //no mic found? (e.g. headphones as input)
                    // show (limited) alert
                    if(nil == activeMic)
                    {
                        //init event
                        // devivce is nil
                        event = [[Event alloc] init:client device:nil deviceType:Device_Microphone state:NSControlStateValueOn];
                        
                        //handle event
                        [self handleEvent:event];
                    }
                }
            }
        });
        
        //start audio event timer
        dispatch_resume(self.audioEventTimer);
        
    } //audio event
    
    /* camera event logic */

    //new camera event?
    // handle (lookup camera, send event)
    if(YES == cameraDifferences.hasChanges)
    {
        //cancel prev timer
        if(nil != self.cameraEventTimer)
        {
            //cancel
            dispatch_cancel(self.cameraEventTimer);
            self.cameraEventTimer = nil;
        }
        
        //re-init timer
        self.cameraEventTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, self.cameraEventQueue);
        dispatch_source_set_timer(self.cameraEventTimer, dispatch_walltime(NULL, 1.0 * NSEC_PER_SEC), DISPATCH_TIME_FOREVER, 0.1 * NSEC_PER_SEC);
        
        //set handler
        dispatch_source_set_event_handler(self.cameraEventTimer, ^{
            
            //active camera
            AVCaptureDevice* activeCamera = nil;
            
            //canel timer
            dispatch_cancel(self.cameraEventTimer);
            self.cameraEventTimer = nil;
            
            //camera off?
            // sent event
            if(0 == cameraDifferences.insertions.count)
            {
                //dbg msg
                os_log_debug(logHandle, "camera event: off");
                
                //init event
                // process (client) and device are nil
                event = [[Event alloc] init:nil device:nil deviceType:Device_Camera state:NSControlStateValueOff];
                
                //handle event
                [self handleEvent:event];
            }
            
            //camera on?
            // send event
            else
            {
                //dbg msg
                os_log_debug(logHandle, "camera event: on");
                
                //send event for each process (attribution)
                for(NSOrderedCollectionChange* cameraAttribution in cameraDifferences.insertions)
                {
                    //init client from attribution
                    client = [[Client alloc] init];
                    client.pid = cameraAttribution.object;
                    client.path = valueForStringItem(getProcessPath(client.pid.intValue));
                    client.name = valueForStringItem(getProcessName(client.path));
                    
                    //look for active camera
                    for(AVCaptureDevice* camera in [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo])
                    {
                        //off? skip
                        if(NSControlStateValueOn != [self getCameraState:camera])
                        {
                            //skip
                            continue;
                        }
                        
                        //virtual
                        // TODO: is there a better way to determine this?
                        if(YES == [camera.localizedName containsString:@"Virtual"])
                        {
                            //skip
                            continue;
                        }
                        
                        //dbg msg
                        os_log_debug(logHandle, "camera device: %{public}@/%{public}@ is on", camera.manufacturer, camera.localizedName);
                        
                        //save
                        activeCamera = camera;
                        
                        //init event
                        // with client and (active) camera
                        event = [[Event alloc] init:client device:activeCamera deviceType:Device_Camera state:NSControlStateValueOn];
                        
                        //handle event
                        [self handleEvent:event];
                    }
                    
                    //no camera found?
                    // show (limited) alert
                    if(nil == activeCamera)
                    {
                        //init event
                        // devivce is nil
                        event = [[Event alloc] init:client device:nil deviceType:Device_Camera state:NSControlStateValueOn];
                        
                        //handle event
                        [self handleEvent:event];
                    }
                }
            }
        });
        
        //start audio timer
        dispatch_resume(self.cameraEventTimer);
        
    } //camera event
     
    //update audio attributions
    self.audioAttributions = [newAudioAttributions copy];
        
    //update camera attributions
    self.cameraAttributions = [newCameraAttributions copy];
    
    return;
}

//register for audio changes
-(BOOL)watchAudioDevice:(AVCaptureDevice*)device
{
    //ret var
    BOOL bRegistered = NO;
    
    //status var
    OSStatus status = -1;
    
    //device ID
    AudioObjectID deviceID = 0;
    
    //property struct
    AudioObjectPropertyAddress propertyStruct = {0};
    
    //init property struct's selector
    propertyStruct.mSelector = kAudioDevicePropertyDeviceIsRunningSomewhere;
    
    //init property struct's scope
    propertyStruct.mScope = kAudioObjectPropertyScopeGlobal;
    
    //init property struct's element
    propertyStruct.mElement = kAudioObjectPropertyElementMaster;
    
    //get device ID
    deviceID = [self getAVObjectID:device];
    
    //block
    // invoked when audio changes
    AudioObjectPropertyListenerBlock listenerBlock = ^(UInt32 inNumberAddresses, const AudioObjectPropertyAddress *inAddresses)
    {
        //state
        NSInteger state = -1;
    
        //get state
        state = [self getMicState:device];
        
        //dbg msg
        os_log_debug(logHandle, "Mic: %{public}@ changed state to %ld", device.localizedName, (long)state);
        
        //save last mic off
        if(NSControlStateValueOff == state)
        {
            //save
            self.lastMicOff = device;
        }
    };
    
    //add property listener for audio changes
    status = AudioObjectAddPropertyListenerBlock(deviceID, &propertyStruct, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), listenerBlock);
    if(noErr != status)
    {
        //err msg
        os_log_error(logHandle, "ERROR: AudioObjectAddPropertyListenerBlock() failed with %d", status);
        
        //bail
        goto bail;
    }
    
    //save
    self.audioListeners[device.uniqueID] = listenerBlock;
    
    //dbg msg
    os_log_debug(logHandle, "monitoring %{public}@ for audio changes", device.localizedName);

    //happy
    bRegistered = YES;
    
bail:
    
    return bRegistered;
}

//register for video changes
-(BOOL)watchVideoDevice:(AVCaptureDevice*)device
{
    //ret var
    BOOL bRegistered = NO;
    
    //status var
    OSStatus status = -1;
    
    //device id
    CMIOObjectID deviceID = 0;
    
    //property struct
    CMIOObjectPropertyAddress propertyStruct = {0};
    
    //init property struct's selector
    propertyStruct.mSelector = kAudioDevicePropertyDeviceIsRunningSomewhere;
    
    //init property struct's scope
    propertyStruct.mScope = kAudioObjectPropertyScopeGlobal;
    
    //init property struct's element
    propertyStruct.mElement = kAudioObjectPropertyElementMaster;
    
    //get device ID
    deviceID = [self getAVObjectID:device];
    
    //block
    // invoked when video changes
    CMIOObjectPropertyListenerBlock listenerBlock = ^(UInt32 inNumberAddresses, const CMIOObjectPropertyAddress addresses[])
    {
        //state
        NSInteger state = -1;
    
        //get state
        state = [self getCameraState:device];
        
        //dbg msg
        os_log_debug(logHandle, "Camera: %{public}@ changed state to %ld", device.localizedName, (long)state);
        
        //save last camera off
        if(NSControlStateValueOff == state)
        {
            //save
            self.lastCameraOff = device;
        }
    };
    
    //register (add) property block listener
    status = CMIOObjectAddPropertyListenerBlock(deviceID, &propertyStruct, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), listenerBlock);
    if(noErr != status)
    {
        //err msg
        os_log_error(logHandle, "ERROR: CMIOObjectAddPropertyListenerBlock() failed with %d", status);
        
        //bail
        goto bail;
    }
    
    //save
    self.cameraListeners[device.uniqueID] = listenerBlock;
    
    //dbg msg
    os_log_debug(logHandle, "monitoring %{public}@ for video changes", device.localizedName);
    
    //happy
    bRegistered = YES;
    
bail:
    
    return bRegistered;
}

//enumerate active devices
-(NSMutableArray*)enumerateActiveDevices
{
    //active device
    NSMutableArray* activeDevices = nil;
    
    //init
    activeDevices = [NSMutableArray array];
    
    //look for active cameras
    for(AVCaptureDevice* camera in [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo])
    {
        //skip virtual devices (e.g. OBS virtual camera)
        // TODO: is there a better way to determine this?
        if(YES == [camera.localizedName containsString:@"Virtual"])
        {
            //skip
            continue;
        }
        
        //save those that are one
        if(NSControlStateValueOn == [self getCameraState:camera])
        {
            //save
            [activeDevices addObject:camera];
        }
    }
    
    //look for active mic
    for(AVCaptureDevice* microphone in [AVCaptureDevice devicesWithMediaType:AVMediaTypeAudio])
    {
        //save those that are one
        if(NSControlStateValueOn == [self getMicState:microphone])
        {
            //save
            [activeDevices addObject:microphone];
        }
    }
    
    return activeDevices;
}

//get built-in mic
// looks for Apple device that's 'BuiltInMicrophoneDevice'
-(AVCaptureDevice*)findBuiltInMic
{
    //mic
    AVCaptureDevice* builtInMic = 0;
    
    //built in mic appears as "BuiltInMicrophoneDevice"
    for(AVCaptureDevice* currentMic in [AVCaptureDevice devicesWithMediaType:AVMediaTypeAudio])
    {
        //dbg msg
        os_log_debug(logHandle, "device: %{public}@/%{public}@", currentMic.manufacturer, currentMic.localizedName);
        
        //is "BuiltInMicrophoneDevice" ?
        if( (YES == [currentMic.manufacturer isEqualToString:@"Apple Inc."]) &&
            (YES == [currentMic.uniqueID isEqualToString:@"BuiltInMicrophoneDevice"]) )
        {
            //found
            builtInMic = currentMic;
            break;
        }
    }
    
    //not found?
    // grab default
    if(0 == builtInMic)
    {
        //get mic / id
        builtInMic = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
        
        //dbg msg
        os_log_debug(logHandle, "Apple Mic not found, defaulting to default device: %{public}@/%{public}@)", builtInMic.manufacturer, builtInMic.localizedName);
    }
    
    return builtInMic;
}

//get built-in camera
-(AVCaptureDevice*)findBuiltInCamera
{
    //camera
    AVCaptureDevice* builtInCamera = 0;
    
    //built in mic appears as "BuiltInMicrophoneDevice"
    for(AVCaptureDevice* currentCamera in [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo])
    {
        //dbg msg
        os_log_debug(logHandle, "device: %{public}@/%{public}@", currentCamera.manufacturer, currentCamera.localizedName);
        
        //check if apple && 'FaceTime HD Camera'
        if( (YES == [currentCamera.manufacturer isEqualToString:@"Apple Inc."]) &&
            (YES == [currentCamera.uniqueID isEqualToString:@"FaceTime HD Camera"]) )
        {
            //found
            builtInCamera = currentCamera;
            break;
        }
    }
    
    //not found?
    // grab default
    if(0 == builtInCamera)
    {
        //get mic / id
        builtInCamera = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
        
        //dbg msg
        os_log_debug(logHandle, "Apple Camera not found, defaulting to default device: %{public}@/%{public}@)", builtInCamera.manufacturer, builtInCamera.localizedName);
    }
    
    return builtInCamera;
}

//get av object's ID
-(UInt32)getAVObjectID:(AVCaptureDevice*)device
{
    //object id
    UInt32 objectID = 0;
    
    //selector for getting device id
    SEL methodSelector = nil;

    //init selector
    methodSelector = NSSelectorFromString(@"connectionID");
    
    //sanity check
    if(YES != [device respondsToSelector:methodSelector])
    {
        //bail
        goto bail;
    }
    
    //ignore warning
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Wpointer-to-int-cast"
    #pragma clang diagnostic ignored "-Warc-performSelector-leaks"

    //grab connection ID
    objectID = (UInt32)[device performSelector:methodSelector withObject:nil];
    
    //restore
    #pragma clang diagnostic pop
    
bail:
    
    return objectID;
}


//determine if audio device is active
-(UInt32)getMicState:(AVCaptureDevice*)device;
{
    //status var
    OSStatus status = -1;
    
    //device ID
    AudioObjectID deviceID = 0;
    
    //running flag
    UInt32 isRunning = 0;
    
    //size of query flag
    UInt32 propertySize = 0;
    
    //get device ID
    deviceID = [self getAVObjectID:device];
    
    //init size
    propertySize = sizeof(isRunning);
    
    //query to get 'kAudioDevicePropertyDeviceIsRunningSomewhere' status
    status = AudioDeviceGetProperty(deviceID, 0, false, kAudioDevicePropertyDeviceIsRunningSomewhere, &propertySize, &isRunning);
    if(noErr != status)
    {
        //err msg
        os_log_error(logHandle, "ERROR: getting status of audio device failed with %d", status);
        
        //set error
        isRunning = -1;
        
        //bail
        goto bail;
    }
    
bail:
    
    return isRunning;
}

//check if a specified video is active
// note: on M1 this sometimes always says 'on' (smh apple)
-(UInt32)getCameraState:(AVCaptureDevice*)device
{
    //status var
    OSStatus status = -1;
    
    //device ID
    CMIODeviceID deviceID = 0;
    
    //running flag
    UInt32 isRunning = 0;
    
    //size of query flag
    UInt32 propertySize = 0;
    
    //property address struct
    CMIOObjectPropertyAddress propertyStruct = {0};
    
    //get device ID
    deviceID = [self getAVObjectID:device];
    
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
        os_log_error(logHandle, "ERROR: failed to get camera status (error: %#x)", status);
        
        //set error
        isRunning = -1;
        
        //bail
        goto bail;
    }

bail:
    
    return isRunning;
}

//should an event be shown?
-(NSUInteger)shouldShowNotification:(Event*)event
{
    //result
    NSUInteger result = NOTIFICATION_ERROR;

    //device ID
    NSNumber* deviceID = 0;
    
    //device's last event
    Event* deviceLastEvent = nil;
    
    //get device ID
    deviceID = [NSNumber numberWithInt:[self getAVObjectID:event.device]];
    
    //extract its last event
    deviceLastEvent = self.deviceEvents[deviceID];
    
    //inactive alerting off?
    // ignore if event is an inactive/off
    if( (NSControlStateValueOff == event.state) &&
        (YES == [NSUserDefaults.standardUserDefaults boolForKey:PREF_DISABLE_INACTIVE]))
    {
        //set result
        result = NOTIFICATION_SKIPPED;
        
        //dbg msg
        os_log_debug(logHandle, "disable inactive alerts set, so ignoring inactive/off event");
            
        //bail
        goto bail;
    }
    
    //no external devices mode?
    if(YES == [NSUserDefaults.standardUserDefaults boolForKey:PREF_NO_EXTERNAL_DEVICES_MODE])
    {
        //on?
        // we have the device directly
        if(NSControlStateValueOn == event.state)
        {
            //external device?
            // don't show notification
            if( (YES != [self.builtInMic.uniqueID isEqualToString:event.device.uniqueID]) &&
                (YES != [self.builtInCamera.uniqueID isEqualToString:event.device.uniqueID]) )
            {
                //set result
                result = NOTIFICATION_SKIPPED;
                
                //dbg msg
                os_log_debug(logHandle, "ingore external devices is set, so ignoring external device 'on' event");
                
                //bail
                goto bail;
            }
        }
        
        //off
        // check last device that turned off
        else
        {
            //mic
            // check last mic off device
            if( (Device_Microphone == event.deviceType) &&
                (nil != self.lastMicOff) &&
                (YES != [self.builtInMic.uniqueID isEqualToString:self.lastMicOff.uniqueID]) )
            {
                //set result
                result = NOTIFICATION_SKIPPED;
                
                //dbg msg
                os_log_debug(logHandle, "ingore external devices is set, so ignoring external mic 'off' event");
                
                //bail
                goto bail;
            }
            
            //camera
            // check last camera off device
            if( (Device_Camera == event.deviceType) &&
                (nil != self.lastCameraOff) &&
                (YES != [self.builtInCamera.uniqueID isEqualToString:self.lastCameraOff.uniqueID]) )
            {
                //set result
                result = NOTIFICATION_SKIPPED;
                
                //dbg msg
                os_log_debug(logHandle, "ingore external devices is set, so ignoring external camera 'off' event");
                
                //bail
                goto bail;
            }
        }
        
    } //PREF_NO_EXTERNAL_DEVICES_MODE
    
    //(new) mic event?
    // need extra logic, since macOS sometimes toggles / delivers 2x events :/
    if(Device_Microphone == event.deviceType)
    {
        //ignore if mic's last event was <0.5
        if([event.timestamp timeIntervalSinceDate:deviceLastEvent.timestamp] < 0.5f)
        {
            //set result
            result = NOTIFICATION_SPURIOUS;
            
            //dbg msg
            os_log_debug(logHandle, "ignoring mic event, as it happened <0.5s ago");
            
            //bail
            goto bail;
        }
        
        //ignore if mic's last event was same state
        if( (deviceLastEvent.state == event.state) &&
            ([event.timestamp timeIntervalSinceDate:deviceLastEvent.timestamp] < 2.0f) )
        {
            //set result
            result = NOTIFICATION_SPURIOUS;
            
            //dbg msg
            os_log_debug(logHandle, "ignoring mic event as it was same state as last (%ld), and happened <2.0s ago", (long)event.state);
            
            //bail
            goto bail;
        }
    }

    //client provided?
    // check if its allowed
    if(nil != event.client)
    {
        //match is simply: device and path
        for(NSDictionary* allowedItem in [NSUserDefaults.standardUserDefaults objectForKey:PREFS_ALLOWED_ITEMS])
        {
            //match?
            if( ([allowedItem[EVENT_DEVICE] intValue] == event.deviceType) &&
                (YES == [allowedItem[EVENT_PROCESS_PATH] isEqualToString:event.client.path]) )
            {
                //set result
                result = NOTIFICATION_SKIPPED;
                
                //dbg msg
                os_log_debug(logHandle, "%{public}@ is allowed to access %d, so no notification will be shown", event.client.path, event.deviceType);
                
                //done
                goto bail;
            }
        }
    }
    
    //set result
    result = NOTIFICATION_DELIVER;
    
bail:
    
    //(always) update last event
    self.deviceEvents[deviceID] = event;
    
    return result;
}

//handle an event
// show alert / exec user action
-(void)handleEvent:(Event*)event
{
    //result
    __block NSUInteger result = NOTIFICATION_ERROR;
    
    //should show?
    @synchronized (self) {
        
       //show?
       result = [self shouldShowNotification:event];
    }
    
    //deliver/show user?
    if(NOTIFICATION_DELIVER == result)
    {
        //deliver
        [self showNotification:event];
    }
    
    //should (also) exec user action?
    if( (NOTIFICATION_ERROR != result) &&
        (NOTIFICATION_SPURIOUS != result) )
    {
        //exec
        [self executeUserAction:event];
    }
    
bail:
    
    return;
}

//build and display notification
-(void)showNotification:(Event*)event
{
    //notification content
    UNMutableNotificationContent* content = nil;
    
    //notificaito0n request
    UNNotificationRequest* request = nil;
    
    //alloc content
    content = [[UNMutableNotificationContent alloc] init];
    
    //title
    NSMutableString* title = nil;
    
    //set (default) category
    content.categoryIdentifier = CATEGORY_CLOSE;
    
    //alloc title
    title = [NSMutableString string];

    //set device type
    (Device_Camera == event.deviceType) ? [title appendString:@"📸"] : [title appendFormat:@"🎙️"];
    
    //set status
    (NSControlStateValueOn == event.state) ? [title appendString:@" Became Active!"] : [title appendString:@" Became Inactive."];
    
    //set title
    content.title = title;
    
    //sub-title
    // device name
    if(nil != event.device)
    {
        //set
        content.subtitle = [NSString stringWithFormat:@"%@", event.device.localizedName];
    }
    
    //have client?
    // use as body
    if(nil != event.client)
    {
        //set body
        content.body = [NSString stringWithFormat:@"\r\nProcess: %@ (%@)", event.client.name, (0 != event.client.pid.intValue) ? event.client.pid : @"pid: unknown"];
        
        //set category
        content.categoryIdentifier = CATEGORY_ACTION;
        
        //set user info
        content.userInfo = @{EVENT_DEVICE:@(event.deviceType), EVENT_PROCESS_ID:event.client.pid, EVENT_PROCESS_PATH:event.client.path};
    }
    else if(nil != event.device)
    {
        //set body
        content.body = [NSString stringWithFormat:@"Device: %@", event.device.localizedName];
    }
    
    //init request
    request = [UNNotificationRequest requestWithIdentifier:NSUUID.UUID.UUIDString content:content trigger:NULL];
    
    //send notification
    [UNUserNotificationCenter.currentNotificationCenter addNotificationRequest:request withCompletionHandler:^(NSError *_Nullable error)
    {
        //error?
        if(nil != error)
        {
            //err msg
            os_log_error(logHandle, "ERROR failed to deliver notification (error: %@)", error);
        }
    }];

bail:

    return;
}

//execute user action
-(BOOL)executeUserAction:(Event*)event
{
    //flag
    BOOL wasExecuted = NO;
    
    //path to action
    NSString* action = nil;
    
    //args
    NSMutableArray* args = nil;
    
    //execute user-specified action?
    if(YES != [NSUserDefaults.standardUserDefaults boolForKey:PREF_EXECUTE_ACTION])
    {
        //bail
        goto bail;
    }

    //dbg msg
    os_log_debug(logHandle, "executing user action");
    
    //grab action
    action = [NSUserDefaults.standardUserDefaults objectForKey:PREF_EXECUTE_PATH];
    if(YES != [NSFileManager.defaultManager fileExistsAtPath:action])
    {
        //err msg
        os_log_error(logHandle, "ERROR: action %{public}@, does not exist", action);
        
        //bail
        goto bail;
    }
    
    //pass args?
    if(YES == [NSUserDefaults.standardUserDefaults boolForKey:PREF_EXECUTE_ACTION_ARGS])
    {
        //alloc
        args = [NSMutableArray array];
        
        //add device
        [args addObject:@"-device"];
        (Device_Camera == event.device) ? [args addObject:@"camera"] : [args addObject:@"microphone"];
        
        //add event
        [args addObject:@"-event"];
        (NSControlStateValueOn == event.state) ? [args addObject:@"on"] : [args addObject:@"off"];
        
        //add process
        if(nil != event.client)
        {
            //add
            [args addObject:@"-process"];
            [args addObject:event.client.pid.stringValue];
        }
    }
    
    //exec user specified action
    execTask(action, args, NO, NO);
    
bail:
    
    return wasExecuted;
}

//stop monitor
-(void)stop
{
    //dbg msg
    os_log_debug(logHandle, "stopping log monitor");

    //stop log monitoring
    [self.logMonitor stop];
    
    //dbg msg
    os_log_debug(logHandle, "stopping audio monitor(s)");
    
    //watch all input audio (mic) devices
    for(AVCaptureDevice* audioDevice in [AVCaptureDevice devicesWithMediaType:AVMediaTypeAudio])
    {
       //stop (device) monitor
       [self unwatchAudioDevice:audioDevice];
    }
       
    //dbg msg
    os_log_debug(logHandle, "stopping video monitor(s)");
    
    //watch all input video (cam) devices
    for(AVCaptureDevice* videoDevice in [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo])
    {
       //start (device) monitor
       [self unwatchVideoDevice:videoDevice];
    }
    
    //dbg msg
    os_log_debug(logHandle, "all stopped...");
    
    return;
}

//stop audio monitor
-(void)unwatchAudioDevice:(AVCaptureDevice*)device
{
    //status
    OSStatus status = -1;
    
    //device ID
    AudioObjectID deviceID = 0;

    //property struct
    AudioObjectPropertyAddress propertyStruct = {0};
    
    //get device ID
    deviceID = [self getAVObjectID:device];
    
    //init property struct's selector
    propertyStruct.mSelector = kAudioDevicePropertyDeviceIsRunningSomewhere;
    
    //init property struct's scope
    propertyStruct.mScope = kAudioObjectPropertyScopeGlobal;
    
    //init property struct's element
    propertyStruct.mElement = kAudioObjectPropertyElementMaster;
    
    //remove
    status = AudioObjectRemovePropertyListenerBlock(deviceID, &propertyStruct, dispatch_get_main_queue(), self.audioListeners[device.uniqueID]);
    if(noErr != status)
    {
        //err msg
        os_log_error(logHandle, "ERROR: 'AudioObjectRemovePropertyListenerBlock' failed with %d", status);
        
        //bail
        goto bail;
    }
    
    //unset listener block
    self.audioListeners[device.uniqueID] = nil;
    
bail:
    
    return;
}

//stop video monitor
-(void)unwatchVideoDevice:(AVCaptureDevice*)device
{
    //status
    OSStatus status = -1;
    
    //device id
    CMIOObjectID deviceID = 0;
    
    //property struct
    CMIOObjectPropertyAddress propertyStruct = {0};
    
    //get device ID
    deviceID = [self getAVObjectID:device];
    
    //init property struct's selector
    propertyStruct.mSelector = kAudioDevicePropertyDeviceIsRunningSomewhere;
    
    //init property struct's scope
    propertyStruct.mScope = kAudioObjectPropertyScopeGlobal;
    
    //init property struct's element
    propertyStruct.mElement = kAudioObjectPropertyElementMaster;
    
    //remove
    status = CMIOObjectRemovePropertyListenerBlock(deviceID, &propertyStruct, dispatch_get_main_queue(), self.cameraListeners[device.uniqueID]);
    if(noErr != status)
    {
        //err msg
        os_log_error(logHandle, "ERROR: 'AudioObjectRemovePropertyListenerBlock' failed with %d", status);
        
        //bail
        goto bail;
    }
    
    //unset listener block
    self.cameraListeners[device.uniqueID] = nil;
    
bail:
    
    return;
    
}

# pragma mark UNNotificationCenter Delegate Methods

- (void)userNotificationCenter:(UNUserNotificationCenter *)center willPresentNotification:(UNNotification *)notification withCompletionHandler:(void (^)(UNNotificationPresentationOptions options))completionHandler {
    
    completionHandler(UNNotificationPresentationOptionAlert);
    
    return;
}

//handle user response to notification
-(void)userNotificationCenter:(UNUserNotificationCenter *)center didReceiveNotificationResponse:(UNNotificationResponse *)response withCompletionHandler:(void (^)(void))completionHandler {
    
    //allowed items
    NSMutableArray* allowedItems = nil;
    
    //device
    NSNumber* device = nil;
    
    //process path
    NSString* processPath = nil;
    
    //process name
    NSString* processName = nil;
    
    //process id
    NSNumber* processID = nil;
    
    //error
    int error = 0;
    
    //dbg msg
    //os_log_debug(logHandle, "user response to notification: %{public}@", response);
    
    //extract device
    device = response.notification.request.content.userInfo[EVENT_DEVICE];
    
    //extact process path
    processPath = response.notification.request.content.userInfo[EVENT_PROCESS_PATH];
    
    //extract process id
    processID = response.notification.request.content.userInfo[EVENT_PROCESS_ID];
    
    //get process name
    processName = valueForStringItem(getProcessName(processPath));
    
    //close?
    // nothing to do
    if(YES == [response.notification.request.content.categoryIdentifier isEqualToString:CATEGORY_CLOSE])
    {
        //dbg msg
        os_log_debug(logHandle, "user clicked 'Ok'");
        
        //done
        goto bail;
    }
        
    //allow?
    // really nothing to do
    else if(YES == [response.actionIdentifier isEqualToString:@"Allow"])
    {
        //dbg msg
        os_log_debug(logHandle, "user clicked 'Allow'");
        
        //done
        goto bail;
    }
    
    //always allow?
    // added to 'allowed' items
    if(YES == [response.actionIdentifier isEqualToString:@"AllowAlways"])
    {
        //dbg msg
        os_log_debug(logHandle, "user clicked 'Allow Always'");
        
        //load allowed items
        allowedItems = [[NSUserDefaults.standardUserDefaults objectForKey:PREFS_ALLOWED_ITEMS] mutableCopy];
        if(nil == allowedItems)
        {
            //alloc
            allowedItems = [NSMutableArray array];
        }
        
        //add item
        [allowedItems addObject:@{EVENT_PROCESS_PATH:processPath, EVENT_DEVICE:device}];
        
        //save & sync
        [NSUserDefaults.standardUserDefaults setObject:allowedItems forKey:PREFS_ALLOWED_ITEMS];
        [NSUserDefaults.standardUserDefaults synchronize];
        
        //dbg msg
        os_log_debug(logHandle, "added %{public}@ to list of allowed items", processPath);
        
        //broadcast
        [[NSNotificationCenter defaultCenter] postNotificationName:RULES_CHANGED object:nil userInfo:nil];
        
        //done
        goto bail;
    }
    
    //block?
    // kill process
    if(YES == [response.actionIdentifier isEqualToString:@"Block"])
    {
        //dbg msg
        os_log_debug(logHandle, "user clicked 'Block'");
        
        //kill
        error = kill(processID.intValue, SIGKILL);
        if(0 != error)
        {
            //err msg
            os_log_error(logHandle, "ERROR: failed to kill %@ (%@)", processName, processID);
    
            //show an alert
            showAlert([NSString stringWithFormat:@"ERROR: failed to terminate %@ (%@)", processName, processID], [NSString stringWithFormat:@"system error code: %d", error], @"OK");
            
            //bail
            goto bail;
        }
        
        //dbg msg
        os_log_debug(logHandle, "killed %@ (%@)", processName, processID);
    }
   
bail:
    
    //gotta call
    completionHandler();
    
    return;
}

@end
