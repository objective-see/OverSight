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

#import <CoreAudio/CoreAudio.h>
#import <CoreMedia/CoreMedia.h>
#import <Foundation/Foundation.h>
#import <CoreMediaIO/CMIOHardware.h>


/* GLOBALS */

//log handle
extern os_log_t logHandle;

@implementation AVMonitor

@synthesize clients;
@synthesize audioClients;

//init
// create XPC connection & set remote obj interface
-(id)init
{
    //action: allow
    UNNotificationAction *allow = nil;
    
    //action: allow
    UNNotificationAction *allowAlways = nil;
    
    //action: block
    UNNotificationAction *block = nil;
    
    //category
    UNNotificationCategory* category = nil;
    
    //super
    self = [super init];
    if(nil != self)
    {
        //init video log monitor
        self.videoLogMonitor = [[LogMonitor alloc] init];
        
        //init audio log monitor
        self.audioLogMonitor = [[LogMonitor alloc] init];
        
        //init video clients
        self.clients = [NSMutableArray array];
        
        //init audio clients
        self.audioClients = [NSMutableArray array];
        
        //set up delegate
        UNUserNotificationCenter.currentNotificationCenter.delegate = self;
        
        //ask for notificaitons
        [UNUserNotificationCenter.currentNotificationCenter requestAuthorizationWithOptions:(UNAuthorizationOptionAlert) completionHandler:^(BOOL granted, NSError * _Nullable error)
        {
            //dbg msg
            os_log_debug(logHandle, "permission to display notifications granted? %d (error: %@)", granted, error);
            
            //not granted/error
            if( (nil != error) ||
                (YES != granted) )
            {
                //main thread?
                if(YES == NSThread.isMainThread)
                {
                    //show alert
                    showAlert(@"ERROR: OverSight not authorized to display notifications!", @"Please authorize via the \"Notifications\" pane (in System Preferences).");
                }
                //bg thread
                // show alert on main thread
                else
                {
                    //on main thread
                    dispatch_async(dispatch_get_main_queue(),
                    ^{
                        //show alert
                        showAlert(@"ERROR: OverSight not authorized to display notifications!", @"Please authorize via the \"Notifications\" pane (in System Preferences).");
                    });
                }
            }
        }];
        
        //init allow action
        allow = [UNNotificationAction actionWithIdentifier:@"Allow" title:@"Allow (Once)" options:UNNotificationActionOptionNone];
        
        //init allow action
        allowAlways = [UNNotificationAction actionWithIdentifier:@"AllowAlways" title:@"Allow (Always)" options:UNNotificationActionOptionNone];
        
        //init block action
        block = [UNNotificationAction actionWithIdentifier:@"Block" title:@"Block" options:UNNotificationActionOptionNone];
        
        //init category
        category = [UNNotificationCategory categoryWithIdentifier:@BUNDLE_ID actions:@[allow, allowAlways, block] intentIdentifiers:@[] options:UNNotificationCategoryOptionCustomDismissAction];
        
        //set categories
        [UNUserNotificationCenter.currentNotificationCenter setNotificationCategories:[NSSet setWithObject:category]];
        
        //any active cameras
        // only call on intel, since broken on M1 :/
        if(YES != AppleSilicon())
        {
            self.cameraState = [self isACameraOn];
        }
    }
    
    return self;
}

//monitor AV
// also generate alerts as needed
-(void)start
{
    //dbg msg
    os_log_debug(logHandle, "starting AV monitoring");
    
    //invoke appropriate architecute monitoring logic
    (YES == AppleSilicon()) ? [self monitorM1] : [self monitorIntel];
    
    //monitor audio
    [self startAudioMonitor];
    
    return;
}

//on M1 systems
// monitor for video events via 'appleh13camerad'
-(void)monitorM1
{
    //dbg msg
    os_log_debug(logHandle, "CPU architecuture: M1, will leverage 'appleh13camerad'");
    
    //start logging
    [self.videoLogMonitor start:[NSPredicate predicateWithFormat:@"process == 'appleh13camerad'"] level:Log_Level_Default callback:^(OSLogEvent* event) {
    
        //new client
        // add to list
        if( (YES == [event.composedMessage hasPrefix:@"TCC access already allowed for pid"]) ||
            (YES == [event.composedMessage hasPrefix:@"TCC preflight access returned allowed for pid"]) )
        {
            //client
            Client* client = nil;
            
            //pid
            NSNumber* pid = nil;
            
            //dbg msg
            os_log_debug(logHandle, "new client msg: %{public}@", event.composedMessage);
            
            //extract pid
            pid = @([event.composedMessage componentsSeparatedByString:@" "].lastObject.intValue);
            if(nil != pid)
            {
                //init client
                client = [[Client alloc] init];
                client.pid = pid;
                client.path = getProcessPath(pid.intValue);
                client.name = getProcessName(client.path);
                
                //dbg msg
                os_log_debug(logHandle, "new client: %{public}@", client);
                
                //camera already on?
                // show notifcation for new client
                if(NSControlStateValueOn == self.cameraState)
                {
                    //show notification
                    [self generateNotification:Device_Camera state:NSControlStateValueOn client:client];
                    
                    //execute action
                    [self executeUserAction:Device_Camera state:NSControlStateValueOn client:nil];
                }
                
                //will handle when "on" camera msg is delivered
                else
                {
                    //add client
                    [self.clients addObject:client];
                }
            }
        }
        
        //camera on
        // show alert!
        else if(YES == [event.composedMessage isEqualToString:@"StartStream : StartStream: Powering ON camera"])
        {
            //client
            Client* client = nil;
            
            //dbg msg
            os_log_debug(logHandle, "camera on msg: %{public}@", event.composedMessage);
            
            //set state
            self.cameraState = NSControlStateValueOn;
            
            //last client should be responsible one
            client = self.clients.lastObject;
            
            //show notification
            [self generateNotification:Device_Camera state:NSControlStateValueOn client:client];
            
            //remove
            [self.clients removeLastObject];
            
            //execute action
            [self executeUserAction:Device_Camera state:NSControlStateValueOn client:client];
        }
        
        //dead client
        // remove from list
        else if(YES == [event.composedMessage hasPrefix:@"Removing client: pid"])
        {
            //pid
            NSNumber* pid = 0;
            
            //dbg msg
            os_log_debug(logHandle, "removed client msg: %{public}@", event.composedMessage);
            
            //extract pid
            pid = @([event.composedMessage componentsSeparatedByString:@" "].lastObject.intValue);
            if(nil != pid)
            {
                //sync
                @synchronized (self) {
                    
                //find and remove client
                for(NSInteger i = self.clients.count - 1; i >= 0; i--)
                {
                    if(pid != ((Client*)self.clients[i]).pid) continue;
                    
                    //remove
                    [self.clients removeObjectAtIndex:i];
                        
                    //dbg msg
                    os_log_debug(logHandle, "removed client at index %ld", (long)i);
                }
                    
                }//sync
            }
        }
        
        //camera off
        // show inactive notification
        else if(YES == [event.composedMessage hasPrefix:@"StopStream : Powering OFF camera"])
        {
            //dbg msg
            os_log_debug(logHandle, "camera off msg: %{public}@", event.composedMessage);
            
            //set state
            self.cameraState = NSControlStateValueOff;
            
            //show inactive notifcations?
            if(YES != [NSUserDefaults.standardUserDefaults boolForKey:PREF_DISABLE_INACTIVE])
            {
                //show notification
                [self generateNotification:Device_Camera state:NSControlStateValueOff client:nil];
                
                //execute action
                [self executeUserAction:Device_Camera state:NSControlStateValueOff client:nil];
            }
            else
            {
                //dbg msg
                os_log_debug(logHandle, "user has set preference to ingore 'inactive' notifications");
            }
        }
    
    }];

    return;
}

//TODO: log info mode ...more info?
//on Intel systems
// monitor for video events via 'VDCAssistant'
-(void)monitorIntel
{
    //dbg msg
    os_log_debug(logHandle, "CPU architecuture: Intel ...will leverage 'VDCAssistant'");
    
    //msg count
    // used to validate client pid to client id
    __block unsigned long long msgCount = 0;
        
    //start logging
    [self.videoLogMonitor start:[NSPredicate predicateWithFormat:@"process == 'VDCAssistant'"] level:Log_Level_Default callback:^(OSLogEvent* event) {
    
        //inc
        msgCount++;
        
        //new client
        // add to list
        if(YES == [event.composedMessage hasPrefix:@"Client Connect for PID"])
        {
            //client
            Client* client = nil;
            
            //pid
            NSNumber* pid = nil;
            
            //dbg msg
            os_log_debug(logHandle, "new client msg: %{public}@", event.composedMessage);
            
            //extract pid
            pid = @([event.composedMessage componentsSeparatedByString:@" "].lastObject.intValue);
            if(nil != pid)
            {
                //init client
                client = [[Client alloc] init];
                client.msgCount = msgCount;
                client.pid = pid;
                client.path = getProcessPath(pid.intValue);
                client.name = getProcessName(client.path);
                
                //dbg msg
                os_log_debug(logHandle, "new client: %{public}@", client);
                
                //add client
                [self.clients addObject:client];
            }
        }
        //client w/ id msg
        // update (last) client, with client id
        else if(YES == [event.composedMessage containsString:@"GetDevicesState for client"])
        {
            //client
            Client* client = nil;
            
            //client id
            NSNumber* clientID = nil;
            
            //dbg msg
            os_log_debug(logHandle, "new client id msg : %{public}@", event.composedMessage);
            
            //extract client id
            clientID = @([event.composedMessage componentsSeparatedByString:@" "].lastObject.intValue);
            if(0 != clientID)
            {
                //get last client
                // check that it the one in the *last* msg
                client = self.clients.lastObject;
                if(client.msgCount == msgCount-1)
                {
                    //add id
                    client.clientID = clientID;
                }
            }
        }
        
        //camera on (for client)
        // show notification
        else if(YES == [event.composedMessage containsString:@"StartStream for client"])
        {
            //client
            Client* client = nil;
            
            //client id
            NSNumber* clientID = nil;
            
            //dbg msg
            os_log_debug(logHandle, "camera on msg: %{public}@", event.composedMessage);
            
            //set state
            self.cameraState = NSControlStateValueOn;
            
            //extract client id
            clientID = @([event.composedMessage componentsSeparatedByString:@" "].lastObject.intValue);
            if(0 != clientID)
            {
                //find client w/ matching id
                for(Client* candidateClient in self.clients)
                {
                    //match?
                    if(candidateClient.clientID == clientID)
                    {
                        //save
                        client = candidateClient;
                        
                        //done
                        break;
                    }
                }
                
                //nil, but last client is FaceTime?
                // use that, as FaceTime is "special"
                if(nil == client)
                {
                    //facetime check?
                    if( (YES == [((Client*)self.clients.lastObject).path isEqualToString:FACE_TIME]) &&
                        (YES == [NSWorkspace.sharedWorkspace.frontmostApplication.executableURL.path isEqualToString:FACE_TIME]) )
                    {
                        //set
                        client = self.clients.lastObject;
                    }
                }
            }
            
            //show notification
            // ok if client is (still) nil...
            [self generateNotification:Device_Camera state:NSControlStateValueOn client:client];
            
            //execute action
            [self executeUserAction:Device_Camera state:NSControlStateValueOn client:client];
        }
        
        //dead client
        // remove from list
        // e.x. "ClientDied 1111 [PID: 2222]"
        else if( (YES == [event.composedMessage hasPrefix:@"ClientDied "]) &&
                 (YES == [event.composedMessage hasSuffix:@"]"]) )
        {
            //message (trimmed)
            NSString* message = nil;
            
            //pid
            NSNumber* pid = 0;
            
            //dbg msg
            os_log_debug(logHandle, "dead client msg: %{public}@", event.composedMessage);
            
            //init message
            // trim off last ']'
            message = [event.composedMessage substringToIndex:event.composedMessage.length - 1];
            
            //extract pid
            pid = @([message componentsSeparatedByString:@" "].lastObject.intValue);
            if(nil != pid)
            {
                //sync
                @synchronized (self) {
                
                for(NSInteger i = self.clients.count - 1; i >= 0; i--)
                {
                    //no match?
                    if(pid != ((Client*)self.clients[i]).pid)
                    {
                        //skip
                        continue;
                    }
                    
                    //remove
                    [self.clients removeObjectAtIndex:i];
                        
                    //dbg msg
                    os_log_debug(logHandle, "removed client at index %ld", (long)i);
                }
                    
                } //sync
            }
        }
        
        //camera off
        else if(YES == [event.composedMessage containsString:@"Post event kCameraStreamStop"])
        {
            //dbg msg
            os_log_debug(logHandle, "camera off msg: %{public}@", event.composedMessage);
            
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                
                //all camera's off?
                if(YES != [self isACameraOn])
                {
                    //set state
                    self.cameraState = NSControlStateValueOff;
                    
                    //show inactive notifcations?
                    if(YES != [NSUserDefaults.standardUserDefaults boolForKey:PREF_DISABLE_INACTIVE])
                    {
                        //show notification
                        [self generateNotification:Device_Camera state:NSControlStateValueOff client:nil];
                        
                        //execute action
                        [self executeUserAction:Device_Camera state:NSControlStateValueOff client:nil];
                    }
                    else
                    {
                        //dbg msg
                        os_log_debug(logHandle, "user has set preference to ingore 'inactive' notifications");
                    }
                }
            });
        }
    }];
    
    return;
}

//start monitor audio
-(void)startAudioMonitor
{
    //dbg msg
    os_log_debug(logHandle, "starting audio monitor");
    
    //msg count
    // used to correlate msgs
    __block unsigned long long msgCount = 0;
    
    //pid extraction regex
    NSRegularExpression* regex = nil;
    
    //init regex
    regex = [NSRegularExpression regularExpressionWithPattern:@"pid:(\\d*)," options:0 error:nil];
        
    //start logging
    // looking for tccd access msgs from coreaudio
    [self.audioLogMonitor start:[NSPredicate predicateWithFormat:@"process == 'coreaudiod' && subsystem == 'com.apple.TCC' && category == 'access'"] level:Log_Level_Info callback:^(OSLogEvent* event) {
        
        //inc
        msgCount++;
        
        //tcc request
        if(YES == [event.composedMessage containsString:@"function=TCCAccessRequest, service=kTCCServiceMicrophone"])
        {
            //client
            Client* client = nil;
            
            //pid
            NSNumber* pid = nil;
            
            //match
            NSTextCheckingResult* match = nil;
            
            //dbg msg
            os_log_debug(logHandle, "new tcc access msg: %{public}@", event.composedMessage);
            
            //match/extract pid
            match = [regex firstMatchInString:event.composedMessage options:0 range:NSMakeRange(0, event.composedMessage.length)];
            
            //no match?
            if( (nil == match) ||
                (NSNotFound == match.range.location) ||
                (match.numberOfRanges < 2) )
            {
                //ignore
                return;
            }
            
            //extract pid
            pid = @([[event.composedMessage substringWithRange:[match rangeAtIndex:1]] intValue]);
            if(nil == pid)
            {
                //ignore
                return;
            }
            
            //init client
            client = [[Client alloc] init];
            client.msgCount = msgCount;
            client.pid = pid;
            client.path = getProcessPath(pid.intValue);
            client.name = getProcessName(client.path);
            
            //dbg msg
            os_log_debug(logHandle, "new client: %{public}@", client);
            
            //add client
            [self.audioClients addObject:client];
        }
        
        //auth ok msg
        else if(YES == [event.composedMessage containsString:@"RECV: synchronous reply"])
        {
            //client
            __block Client* client = nil;
            
            //(split) response
            NSArray* response = nil;
            
            //dbg msg
            os_log_debug(logHandle, "new client tccd response : %{public}@", event.composedMessage);
            
            //response
            response = [event.composedMessage componentsSeparatedByString:@"\n"];
            if( (response.count < 2) ||
                (YES != [response[1] hasSuffix:@"2"]) ||
                (YES != [response[1] containsString:@"auth_value"]) )
            {
                //ignore
                return;
            }
                
            //get last client
            // check that it the one in the *last* msg
            client = self.audioClients.lastObject;
            if(client.msgCount != msgCount-1)
            {
                //ignore
                return;
            }
            
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                
                //make sure mic is on
                if(YES != [self isMicOn])
                {
                    //dbg msg
                    os_log_debug(logHandle, "mic is not on...");
                    
                    //ignore
                    return;
                }
            
                //more than one client?
                // only use candiate client if it's the foreground
                if( (0 != self.audioClients.count) &&
                    (YES != [NSWorkspace.sharedWorkspace.frontmostApplication.executableURL.path isEqualToString:client.path]) )
                {
                    //reset
                    client = nil;
                }
                    
                //show notification
                [self generateNotification:Device_Microphone state:NSControlStateValueOn client:client];
                    
                //execute action
                [self executeUserAction:Device_Microphone state:NSControlStateValueOn client:nil];
                
                
            });
            
            
        }
    }];
    
    return;
}

//is (any) camera on?
-(BOOL)isACameraOn
{
    //flag
    BOOL cameraOn = NO;
    
    //selector for getting device id
    SEL methodSelector = nil;
    
    //device's connection id
    unsigned int connectionID = 0;
    
    //dbg msg
    os_log_debug(logHandle, "checking if any camera is active");
    
    //init selector
    methodSelector = NSSelectorFromString(@"connectionID");
            
    //are any cameras currently on?
    for(AVCaptureDevice* currentCamera in [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo])
    {
        //dbg msg
        os_log_debug(logHandle, "device: %@/%@", currentCamera.manufacturer, currentCamera.localizedName);
        
        //sanity check
        // make sure is has private 'connectionID' iVar
        if(YES != [currentCamera respondsToSelector:methodSelector])
        {
            //skip
            continue;
        }
        
        //ignore leak warning
        // we know what we're doing via this 'performSelector'
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        
        //grab connection ID
        connectionID = (unsigned int)[currentCamera performSelector:methodSelector withObject:nil];
        
        //restore
        #pragma clang diagnostic pop
        
        //get state
        // is (any) camera on?
        if(NSControlStateValueOn == [self getCameraStatus:connectionID])
        {
            //dbg msg
            os_log_debug(logHandle, "device: %@/%@, is on!", currentCamera.manufacturer, currentCamera.localizedName);
            
            //set
            cameraOn = YES;
            
            //done
            break;
        }
    }
    
bail:
    
    return cameraOn;
}

//is (any) camera on?
-(BOOL)isMicOn
{
    //flag
    BOOL isMicOn = NO;
    
    //selector for getting device id
    SEL methodSelector = nil;
    
    //device's connection id
    unsigned int connectionID = 0;
    
    //dbg msg
    os_log_debug(logHandle, "checking if built-in mic is active");
    
    //init selector
    methodSelector = NSSelectorFromString(@"connectionID");
 
    //look for mic that belongs to apple
    for(AVCaptureDevice* currentMic in [AVCaptureDevice devicesWithMediaType:AVMediaTypeAudio])
    {
        //dbg msg
        os_log_debug(logHandle, "device: %@/%@", currentMic.manufacturer, currentMic.localizedName);
        
        //sanity check
        // make sure is has private 'connectionID' iVar
        if(YES != [currentMic respondsToSelector:methodSelector])
        {
            //skip
            continue;
        }
        
        //check if apple
        // also check input source
        if( (YES == [currentMic.manufacturer isEqualToString:@"Apple Inc."]) &&
            (YES == [[[currentMic activeInputSource] inputSourceID] isEqualToString:@"imic"]) )
        {
            //ignore leak warning
            // ->we know what we're doing via this 'performSelector'
            #pragma clang diagnostic push
            #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            
            //grab connection ID
            connectionID = (unsigned int)[currentMic performSelector:NSSelectorFromString(@"connectionID") withObject:nil];
            
            //restore
            #pragma clang diagnostic pop
            
            //get state
            // is mic on?
            if(NSControlStateValueOn == [self getMicState:connectionID])
            {
                //dbg msg
                os_log_debug(logHandle, "device: %@/%@, is on!", currentMic.manufacturer, currentMic.localizedName);
                
                //set
                isMicOn = YES;
                
                //done
                break;
            }
        }
    }
    
    return isMicOn;
}
    
//determine if audio device is active
-(UInt32)getMicState:(AudioObjectID)deviceID
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
// note: on M1 this always says 'on' (smh apple)
-(UInt32)getCameraStatus:(CMIODeviceID)deviceID
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
        os_log_error(logHandle, "ERROR: failed to get camera status (error: %#x)", status);
        
        //set error
        isRunning = -1;
        
        //bail
        goto bail;
    }
    
    //dbg msg
    os_log_debug(logHandle, "isRunning: %d", isRunning);

bail:
    
    return isRunning;
}

//build and display notification
-(void)generateNotification:(AVDevice)device state:(NSControlStateValue)state client:(Client*)client
{
    //notification content
    UNMutableNotificationContent* content = nil;
    
    //notificaito0n request
    UNNotificationRequest* request = nil;
    
    //alloc content
    content = [[UNMutableNotificationContent alloc] init];
    
    //title
    NSMutableString* title = nil;
    
    //client?
    // check if allowed
    if(nil != client)
    {
        //match is simply: device and path
        for(NSDictionary* allowedItem in [NSUserDefaults.standardUserDefaults objectForKey:PREFS_ALLOWED_ITEMS])
        {
            //match?
            if( (allowedItem[EVENT_DEVICE] == (NSNumber*)@(device)) &&
                (YES == [allowedItem[EVENT_PROCESS_PATH] isEqualToString:client.path]) )
            {
                //dbg msg
                os_log_debug(logHandle, "%{public}@ is allowed to access %d, so no notification will be shown", client.path, device);
                
                //done
                goto bail;
            }
        }
    }
    
    //alloc title
    title = [NSMutableString string];

    //set device
    (Device_Camera == device) ? [title appendString:@"Video Device"] : [title appendString:@"Audio Device"];
    
    //set status
    (NSControlStateValueOn == state) ? [title appendString:@" became active!"] : [title appendString:@" became inactive."];
    
    //set title
    content.title = title;
    
    //have client?
    // use as body
    if(nil != client)
    {
        //set body
        content.body = [NSString stringWithFormat:@"Process: %@ (%@)", getProcessName(client.path), client.pid];
        
        //set category
        content.categoryIdentifier = @BUNDLE_ID;
        
        //set user info
        content.userInfo = @{EVENT_DEVICE:@(Device_Camera), EVENT_PROCESS_ID:client.pid, EVENT_PROCESS_PATH:client.path};
    }
    
    //init request
    request = [UNNotificationRequest requestWithIdentifier:NSUUID.UUID.UUIDString content:content trigger:NULL];
    
    //send notification
    [[UNUserNotificationCenter currentNotificationCenter] addNotificationRequest:request withCompletionHandler:^(NSError *_Nullable error)
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
-(BOOL)executeUserAction:(AVDevice)device state:(NSControlStateValue)state client:(Client*)client
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
        //dbg msg
        os_log_debug(logHandle, "'execute action' is disabled");
        
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
        os_log_error(logHandle, "ERROR: %{public}@ is not a valid action", action);
        
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
        (Device_Camera == device) ? [args addObject:@"camera"] : [args addObject:@"microphone"];
        
        //add event
        [args addObject:@"-event"];
        (NSControlStateValueOn == state) ? [args addObject:@"on"] : [args addObject:@"off"];
        
        //add process
        if(nil != client)
        {
            //add
            [args addObject:@"-process"];
            [args addObject:client.pid.stringValue];
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
    //stop video log monitoring
    [self.videoLogMonitor stop];
    
    //stop audio log monitoring
    [self.audioLogMonitor stop];
    
    return;
}

# pragma mark UNNotificationCenter Delegate Methods

//handle user response to notification
- (void)userNotificationCenter:(UNUserNotificationCenter *)center didReceiveNotificationResponse:(UNNotificationResponse *)response withCompletionHandler:(void (^)(void))completionHandler {
    
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
    os_log_debug(logHandle, "user response to notification: %{public}@", response);
    
    //extract device
    device = response.notification.request.content.userInfo[EVENT_DEVICE];
    
    //extact process path
    processPath = response.notification.request.content.userInfo[EVENT_PROCESS_PATH];
    
    //extract process id
    processID = response.notification.request.content.userInfo[EVENT_PROCESS_ID];
    
    //get process name
    processName = getProcessName(processPath);
        
    //allow?
    // really nothing to do
    if(YES == [response.actionIdentifier isEqualToString:@"Allow"])
    {
        //dbg msg
        os_log_debug(logHandle, "user clicked 'Allow'");
    }
    
    //always allow?
    // added to 'allowed' items
    else if(YES == [response.actionIdentifier isEqualToString:@"AllowAlways"])
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
    }
    
    //block?
    // kill process
    else if(YES == [response.actionIdentifier isEqualToString:@"Block"])
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
            showAlert([NSString stringWithFormat:@"ERROR: failed to block %@ (%@)", processName, processID], [NSString stringWithFormat:@"system error code: %d", error]);
            
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
