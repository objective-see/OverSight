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

/* GLOBALS */

//log handle
extern os_log_t logHandle;

@implementation AVMonitor

@synthesize videoClients;
@synthesize audioClients;
@synthesize lastMicEvent;

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
        //init camera state
        self.cameraState = -1;
        
        //init video log monitor
        self.videoLogMonitor = [[LogMonitor alloc] init];
        
        //init audio log monitor
        self.audioLogMonitor = [[LogMonitor alloc] init];
        
        //init video clients
        self.videoClients = [NSMutableArray array];
        
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
    (YES == AppleSilicon()) ? [self startVideoMonitorM1] : [self startVideoMonitorIntel];
    
    //monitor audio
    [self startAudioMonitor];
    
    return;
}

//on M1 systems
// monitor for video events via 'appleh13camerad'
-(void)startVideoMonitorM1
{
    //dbg msg
    os_log_debug(logHandle, "CPU architecuture: M1, will leverage 'appleh13camerad'");
    
    //start logging
    [self.videoLogMonitor start:[NSPredicate predicateWithFormat:@"process == 'appleh13camerad'"] level:Log_Level_Default callback:^(OSLogEvent* logEvent) {
    
        //new client
        // add to list
        if( (YES == [logEvent.composedMessage hasPrefix:@"TCC access already allowed for pid"]) ||
            (YES == [logEvent.composedMessage hasPrefix:@"TCC preflight access returned allowed for pid"]) )
        {
            //event
            Event* event = nil;
            
            //client
            Client* client = nil;
            
            //pid
            NSNumber* pid = nil;
            
            //dbg msg
            os_log_debug(logHandle, "new (video) client msg: %{public}@", logEvent.composedMessage);
            
            //extract pid
            pid = @([logEvent.composedMessage componentsSeparatedByString:@" "].lastObject.intValue);
            if(nil != pid)
            {
                //init client
                client = [[Client alloc] init];
                client.pid = pid;
                client.path = getProcessPath(pid.intValue);
                client.name = getProcessName(client.path);
                
                //dbg msg
                os_log_debug(logHandle, "new (video) client: %{public}@", client);
                
                //init event
                event = [[Event alloc] init:client device:Device_Camera state:self.cameraState];
                
                //camera already on?
                // handle event for new client
                if(NSControlStateValueOn == self.cameraState)
                {
                    //handle event
                    [self handleEvent:event];
                }
                
                //will handle when "on" camera msg is delivered
                else
                {
                    //add client
                    [self.videoClients addObject:client];
                }
            }
        }
        
        //camera on
        // show alert!
        else if(YES == [logEvent.composedMessage isEqualToString:@"StartStream: Powering ON camera"])
        {
            //event
            Event* event = nil;
            
            //client
            Client* client = nil;
            
            //dbg msg
            os_log_debug(logHandle, "camera on msg: %{public}@", logEvent.composedMessage);
            
            //set state
            self.cameraState = NSControlStateValueOn;
            
            //last client should be responsible one
            client = self.videoClients.lastObject;
            
            //init event
            event = [[Event alloc] init:client device:Device_Camera state:self.cameraState];
            
            //handle event
            [self handleEvent:event];
        }
        
        //dead client
        // remove from list
        else if(YES == [logEvent.composedMessage hasPrefix:@"Removing client: pid"])
        {
            //pid
            NSNumber* pid = 0;
            
            //dbg msg
            os_log_debug(logHandle, "removed client msg: %{public}@", logEvent.composedMessage);
            
            //extract pid
            pid = @([logEvent.composedMessage componentsSeparatedByString:@" "].lastObject.intValue);
            if(nil != pid)
            {
                //sync
                @synchronized (self) {
                    
                //find and remove client
                for(NSInteger i = self.videoClients.count - 1; i >= 0; i--)
                {
                    //pid doesn't match?
                    if(pid != ((Client*)self.videoClients[i]).pid) continue;
                    
                    //remove
                    [self.videoClients removeObjectAtIndex:i];
                        
                    //dbg msg
                    os_log_debug(logHandle, "removed client at index %ld", (long)i);
                }
                    
                }//sync
            }
        }
        
        //camera off
        // show inactive notification
        else if(YES == [logEvent.composedMessage hasPrefix:@"StopStream : Powering OFF camera"])
        {
            //event
            Event* event = nil;
            
            //dbg msg
            os_log_debug(logHandle, "camera off msg: %{public}@", logEvent.composedMessage);
            
            //set state
            self.cameraState = NSControlStateValueOff;
            
            //init event
            event = [[Event alloc] init:nil device:Device_Camera state:self.cameraState];
            
            //handle event
            [self handleEvent:event];
            
            //sync
            @synchronized (self) {
                    
                //remove
                [self.videoClients removeAllObjects];
                
                //dbg msg
                os_log_debug(logHandle, "removed all (video) clients");
             
            }//sync
        }
    
    }];

    return;
}

//on Intel systems
// monitor for video events via 'VDCAssistant'
-(void)startVideoMonitorIntel
{
    //dbg msg
    os_log_debug(logHandle, "CPU architecuture: Intel ...will leverage 'VDCAssistant'");
    
    //msg count
    // used to validate client pid to client id
    __block unsigned long long msgCount = 0;
        
    //start logging
    [self.videoLogMonitor start:[NSPredicate predicateWithFormat:@"process == 'VDCAssistant'"] level:Log_Level_Default callback:^(OSLogEvent* logEvent) {
    
        //inc
        msgCount++;
        
        //new client
        // add to list
        if(YES == [logEvent.composedMessage hasPrefix:@"Client Connect for PID"])
        {
            //client
            Client* client = nil;
            
            //pid
            NSNumber* pid = nil;
            
            //dbg msg
            os_log_debug(logHandle, "new client msg: %{public}@", logEvent.composedMessage);
            
            //extract pid
            pid = @([logEvent.composedMessage componentsSeparatedByString:@" "].lastObject.intValue);
            if(nil != pid)
            {
                //init client
                client = [[Client alloc] init];
                client.msgCount = msgCount;
                client.pid = pid;
                client.path = getProcessPath(pid.intValue);
                client.name = getProcessName(client.path);
                
                //dbg msg
                os_log_debug(logHandle, "new (video) client: %{public}@", client);
                
                //add client
                [self.videoClients addObject:client];
            }
        }
        //client w/ id msg
        // update (last) client, with client id
        else if(YES == [logEvent.composedMessage containsString:@"GetDevicesState for client"])
        {
            //client
            Client* client = nil;
            
            //client id
            NSNumber* clientID = nil;
            
            //dbg msg
            os_log_debug(logHandle, "new client id msg : %{public}@", logEvent.composedMessage);
            
            //extract client id
            clientID = @([logEvent.composedMessage componentsSeparatedByString:@" "].lastObject.intValue);
            if(0 != clientID)
            {
                //get last client
                // check that it the one in the *last* msg
                client = self.videoClients.lastObject;
                if(client.msgCount == msgCount-1)
                {
                    //add id
                    client.clientID = clientID;
                }
            }
        }
        
        //camera on (for client)
        // show notification
        else if(YES == [logEvent.composedMessage containsString:@"StartStream for client"])
        {
            //event
            Event* event = nil;
            
            //client
            Client* client = nil;
            
            //client id
            NSNumber* clientID = nil;
            
            //dbg msg
            os_log_debug(logHandle, "camera on msg: %{public}@", logEvent.composedMessage);
            
            //set state
            self.cameraState = NSControlStateValueOn;
            
            //extract client id
            clientID = @([logEvent.composedMessage componentsSeparatedByString:@" "].lastObject.intValue);
            if(0 != clientID)
            {
                //find client w/ matching id
                for(Client* candidateClient in self.videoClients)
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
                    if( (YES == [((Client*)self.videoClients.lastObject).path isEqualToString:FACE_TIME]) &&
                        (YES == [NSWorkspace.sharedWorkspace.frontmostApplication.executableURL.path isEqualToString:FACE_TIME]) )
                    {
                        //set
                        client = self.videoClients.lastObject;
                    }
                }
            }
            
            //init event
            event = [[Event alloc] init:client device:Device_Camera state:self.cameraState];
            
            //handle event
            [self handleEvent:event];
        }
        
        //dead client
        // remove from list
        // e.x. "ClientDied 1111 [PID: 2222]"
        else if( (YES == [logEvent.composedMessage hasPrefix:@"ClientDied "]) &&
                 (YES == [logEvent.composedMessage hasSuffix:@"]"]) )
        {
            //message (trimmed)
            NSString* message = nil;
            
            //pid
            NSNumber* pid = 0;
            
            //dbg msg
            os_log_debug(logHandle, "dead client msg: %{public}@", logEvent.composedMessage);
            
            //init message
            // trim off last ']'
            message = [logEvent.composedMessage substringToIndex:logEvent.composedMessage.length - 1];
            
            //extract pid
            pid = @([message componentsSeparatedByString:@" "].lastObject.intValue);
            if(nil != pid)
            {
                //sync
                @synchronized (self) {
                
                //iterate over and remove
                for(NSInteger i = self.videoClients.count - 1; i >= 0; i--)
                {
                    //no match?
                    if(pid != ((Client*)self.videoClients[i]).pid)
                    {
                        //skip
                        continue;
                    }
                    
                    //remove
                    [self.videoClients removeObjectAtIndex:i];
                        
                    //dbg msg
                    os_log_debug(logHandle, "removed client at index %ld", (long)i);
                }
                    
                } //sync
            }
        }
        
        //camera off
        else if(YES == [logEvent.composedMessage containsString:@"Post event kCameraStreamStop"])
        {
            //dbg msg
            os_log_debug(logHandle, "camera off msg: %{public}@", logEvent.composedMessage);
            
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                
                //event
                Event* event = nil;
                
                //all camera's off?
                if(YES != [self isACameraOn])
                {
                    //set state
                    self.cameraState = NSControlStateValueOff;
                    
                    //init event
                    event = [[Event alloc] init:nil device:Device_Camera state:self.cameraState];
                    
                    //handle event
                    [self handleEvent:event];
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
   
    //built in mic
    AudioObjectID builtInMic = 0;
    
    //msg count
    // used to correlate msgs
    __block unsigned long long msgCount = 0;
    
    //pid extraction regex
    NSRegularExpression* regex = nil;
    
    //init regex
    //macOS 10.16 (11)
    if(@available(macOS 10.16, *))
    {
        //init
        regex = [NSRegularExpression regularExpressionWithPattern:@"pid:(\\d*)," options:0 error:nil];
    }
    //macOS 10.15
    else
    {
        regex = [NSRegularExpression regularExpressionWithPattern:@"0x([a-fA-F0-9]){20,}" options:0 error:nil];
    }
    
    //find built-in mic
    builtInMic = [self findBuiltInMic];
    if(0 != builtInMic)
    {
        //start (device) monitor
        [self watchAudioDevice:builtInMic];
    }
    //error :/
    else
    {
        //err msg
        os_log_error(logHandle, "ERROR: failed to find built-in mic");
    }
    
    //start audio-related log monitoring
    // looking for tccd access msgs from coreaudio
    [self.audioLogMonitor start:[NSPredicate predicateWithFormat:@"process == 'coreaudiod' && subsystem == 'com.apple.TCC' && category == 'access'"] level:Log_Level_Info callback:^(OSLogEvent* logEvent) {
        
        //inc
        msgCount++;
        
        //macOS 10.16 (11)
        if(@available(macOS 10.16, *))
        {
            //tcc request
            if(YES == [logEvent.composedMessage containsString:@"function=TCCAccessRequest, service=kTCCServiceMicrophone"])
            {
                //client
                Client* client = nil;
                
                //pid
                NSNumber* pid = nil;
                
                //match
                NSTextCheckingResult* match = nil;
                
                //dbg msg
                os_log_debug(logHandle, "new tcc access msg: %{public}@", logEvent.composedMessage);
                
                //match/extract pid
                match = [regex firstMatchInString:logEvent.composedMessage options:0 range:NSMakeRange(0, logEvent.composedMessage.length)];
                
                //no match?
                if( (nil == match) ||
                    (NSNotFound == match.range.location) ||
                    (match.numberOfRanges < 2) )
                {
                    //ignore
                    return;
                }
                
                //extract pid
                pid = @([[logEvent.composedMessage substringWithRange:[match rangeAtIndex:1]] intValue]);
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
                os_log_debug(logHandle, "new (audio) client: %{public}@", client);
                
                //add client
                [self.audioClients addObject:client];
                
                //done
                return;
            }
        }
        //macOS 10.15
        else
        {
            //tcc request
            if( (YES == [logEvent.composedMessage containsString:@"TCCAccessRequest"]) &&
                (YES == [logEvent.composedMessage containsString:@"kTCCServiceMicrophone"]) )
            {
                //client
                Client* client = nil;
                
                //token
                NSString* token = nil;
                
                //pid substring
                NSString* substring = nil;
                
                //pid
                unsigned int pid = 0;
                
                //match
                NSTextCheckingResult* match = nil;
                
                //dbg msg
                os_log_debug(logHandle, "new tcc access msg: %{public}@", logEvent.composedMessage);
                
                //match/extract pid
                match = [regex firstMatchInString:logEvent.composedMessage options:0 range:NSMakeRange(0, logEvent.composedMessage.length)];
                
                //no match?
                if( (nil == match) ||
                    (NSNotFound == match.range.location) )
                {
                    //ignore
                    return;
                }
                
                //extract token
                token = [logEvent.composedMessage substringWithRange:[match rangeAtIndex:0]];
                if(token.length < 46) return;
                
                //extract pid
                substring = [token substringWithRange:NSMakeRange(42, 4)];
                
                //convert to int
                sscanf(substring.UTF8String, "%x", &pid);
                if(0 == pid) return;
    
                //init client
                client = [[Client alloc] init];
                client.msgCount = msgCount;
                client.pid = @(htons(pid));
                client.path = getProcessPath(client.pid.intValue);
                client.name = getProcessName(client.path);
                
                //dbg msg
                os_log_debug(logHandle, "new (audio) client: %{public}@", client);
                
                //add client
                [self.audioClients addObject:client];
                
                //done
                return;
            }
        }
       
        //tcc auth response
        // check that a) auth ok b) msg is right after new request
        //            c) mic is still on d) process is still alive
        // then trigger notification
        if( (YES == [logEvent.composedMessage containsString:@"RECV: synchronous reply"]) ||
            (YES == [logEvent.composedMessage containsString:@"Received synchronous reply"]) )
            
        {
            //client
            __block Client* client = nil;
            
            //flag
            BOOL isAuthorized = NO;
            
            //dbg msg
            os_log_debug(logHandle, "new client tccd response : %{public}@", logEvent.composedMessage);
            
            //look for:
            // "result" => <bool: xxx>: true
            for(NSString* response in [logEvent.composedMessage componentsSeparatedByString:@"\n"])
            {
                //no match?
                if( (YES != [response hasSuffix:@"true"]) ||
                    (YES != [response containsString:@"\"result\""]) )
                {
                    continue;
                }
            
                //match
                isAuthorized = YES;
                
                //done
                break;
            }
        
            //not auth'd?
            if(YES != isAuthorized) return;
            
            //auth, so get last client
            // check that it the one in the *last* msg
            client = self.audioClients.lastObject;
            if(client.msgCount != msgCount-1)
            {
                //ignore
                return;
            }
        
            //is mic (really) on?
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                
                //event
                Event* event = nil;
                
                //set mic state
                self.microphoneState = [self isMicOn];
                
                //make sure mic is on
                if(YES != self.microphoneState)
                {
                    //dbg msg
                    os_log_debug(logHandle, "mic is not on...");
                    
                    //ignore
                    return;
                }
                
                //make sure process is still alive
                if(YES != isProcessAlive(client.pid.intValue))
                {
                    //dbg msg
                    os_log_debug(logHandle, "%@ is no longer alive, so ignoring", client.name);
                    
                    //ignore
                    return;
                }
            
                //more than one client?
                // only use candiate client if:
                // a) it's the foreground and b) the last event was from a different client
                if(1 != self.audioClients.count)
                {
                    //dbg msg
                    os_log_debug(logHandle, "more than one audio client (total: %lu)", (unsigned long)self.audioClients.count);
                    
                    //not foreground?
                    if(YES != [NSWorkspace.sharedWorkspace.frontmostApplication.executableURL.path isEqualToString:client.path])
                    {
                        //reset
                        client = nil;
                    }
                    
                    //last event was same client?
                    else if( (self.lastMicEvent.client.pid == client.pid) &&
                             (YES == [self.lastMicEvent.client.path isEqualToString:client.path]) )
                    {
                        //reset
                        client = nil;
                    }
                }
               
                //init event
                event = [[Event alloc] init:client device:Device_Microphone state:self.microphoneState];
                    
                //handle event
                [self handleEvent:event];
            
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
    
    //device's connection id
    unsigned int connectionID = 0;
    
    //dbg msg
    os_log_debug(logHandle, "checking if any camera is active");
    
    //are any cameras currently on?
    for(AVCaptureDevice* currentCamera in [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo])
    {
        //dbg msg
        os_log_debug(logHandle, "device: %{public}@/%{public}@", currentCamera.manufacturer, currentCamera.localizedName);
        
        //get id
        connectionID = [self getAVObjectID:currentCamera];
        
        //get state
        // is (any) camera on?
        if(NSControlStateValueOn == [self getCameraStatus:connectionID])
        {
            //dbg msg
            os_log_debug(logHandle, "device: %{public}@/%{public}@, is on!", currentCamera.manufacturer, currentCamera.localizedName);
            
            //set
            cameraOn = YES;
            
            //done
            break;
        }
    }
    
bail:
    
    return cameraOn;
}

//get built-in mic
-(AudioObjectID)findBuiltInMic
{
    //mic
    AudioObjectID builtInMic = 0;
    
    //look for mic that belongs to apple
    for(AVCaptureDevice* currentMic in [AVCaptureDevice devicesWithMediaType:AVMediaTypeAudio])
    {
        //dbg msg
        os_log_debug(logHandle, "device: %{public}@/%{public}@", currentMic.manufacturer, currentMic.localizedName);
        
        //check if apple
        // also check input source
        if( (YES == [currentMic.manufacturer isEqualToString:@"Apple Inc."]) &&
            (YES == [[[currentMic activeInputSource] inputSourceID] isEqualToString:@"imic"]) )
        {
            //grab ID
            builtInMic = [self getAVObjectID:currentMic];
     
            //done
            break;
        }
    }
    
    //not found?
    // grab default
    if(0 == builtInMic)
    {
        //get mic / id
        builtInMic = [self getAVObjectID:[AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio]];
        
        //dbg msg
        os_log_debug(logHandle, "Apple mic not found, defaulting to default (id: %d)", builtInMic);
    }
    
    return builtInMic;
}

//get av object's ID
-(UInt32)getAVObjectID:(AVCaptureDevice*)audioObject
{
    //object id
    AudioObjectID objectID = 0;
    
    //selector for getting device id
    SEL methodSelector = nil;

    //init selector
    methodSelector = NSSelectorFromString(@"connectionID");
    
    //sanity check
    if(YES != [audioObject respondsToSelector:methodSelector])
    {
        //bail
        goto bail;
    }
    
    //ignore leak warning
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    
    //grab connection ID
    objectID = (unsigned int)[audioObject performSelector:methodSelector withObject:nil];
    
    //restore
    #pragma clang diagnostic pop
    
bail:
    
    return objectID;
}

//is built-in mic on?
-(BOOL)isMicOn
{
    //flag
    BOOL isMicOn = NO;
    
    //mic's ID
    AudioObjectID builtInMic = 0;
    
    //dbg msg
    os_log_debug(logHandle, "checking if built-in mic is active");
    
    //find mic
    builtInMic = [self findBuiltInMic];
    if( (0 != builtInMic) &&
        (NSControlStateValueOn == [self getMicState:builtInMic]) )
    {
        //dbg msg
        os_log_debug(logHandle, "built-in mic is on");
        
        //set
        isMicOn = YES;
    }

    return isMicOn;
}
    
//register for audio notifcations
// ...only care about mic deactivation events
-(BOOL)watchAudioDevice:(AudioObjectID)builtInMic
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
    
    //weak self
    __unsafe_unretained typeof(self)weakSelf = self;
    
    //block
    // invoked when audio changes
    self.listenerBlock = ^(UInt32 inNumberAddresses, const AudioObjectPropertyAddress *inAddresses)
    {
        //state
        NSInteger state = -1;
        
        //event
        Event* event = nil;
        
        //get state
        state = [self getMicState:builtInMic];
        
        //dbg msg
        os_log_debug(logHandle, "built in mic changed state to %ld", (long)state);
        
        //init event
        event = [[Event alloc] init:nil device:Device_Microphone state:state];
        
        //mic off?
        if(NSControlStateValueOff == state)
        {
            //dbg msg
            os_log_debug(logHandle, "built in mic turned to off");
            
            //sync
            @synchronized (weakSelf) {
                    
                //remove
                [weakSelf.audioClients removeAllObjects];
                
                //dbg msg
                os_log_debug(logHandle, "removed all (audio) clients");
             
            }//sync
            
            //handle event
            [weakSelf handleEvent:event];
        }
    };
    
    //add property listener for audio changes
    status = AudioObjectAddPropertyListenerBlock(builtInMic, &propertyStruct, dispatch_get_main_queue(), self.listenerBlock);
    if(noErr != status)
    {
        //err msg
        os_log_error(logHandle, "ERROR: AudioObjectAddPropertyListenerBlock() failed with %d", status);
        
        //bail
        goto bail;
    }
    
    //dbg msg
    os_log_debug(logHandle, "monitoring %d for audio changes", builtInMic);

    //happy
    bRegistered = YES;
    
bail:
    
    return bRegistered;
}

//stop audio monitor
-(void)stopAudioMonitor
{
    //status
    OSStatus status = -1;
    
    //built in mic
    AudioObjectID builtInMic = 0;
    
    //property struct
    AudioObjectPropertyAddress propertyStruct = {0};
    
    //dbg msg
    os_log_debug(logHandle, "stopping audio (device) monitor");
    
    //init property struct's selector
    propertyStruct.mSelector = kAudioDevicePropertyDeviceIsRunningSomewhere;
    
    //init property struct's scope
    propertyStruct.mScope = kAudioObjectPropertyScopeGlobal;
    
    //init property struct's element
    propertyStruct.mElement = kAudioObjectPropertyElementMaster;
    
    //find built-in mic
    builtInMic = [self findBuiltInMic];
    if(0 != builtInMic)
    {
        //remove
        status = AudioObjectRemovePropertyListenerBlock(builtInMic, &propertyStruct, dispatch_get_main_queue(), self.listenerBlock);
        if(noErr != status)
        {
            //err msg
            os_log_error(logHandle, "ERROR: 'AudioObjectRemovePropertyListenerBlock' failed with %d", status);
        }
    }
    
bail:
    
    return;
    
}

//determine if audio device is active
-(UInt32)getMicState:(AudioObjectID)deviceID
{
    //status var
    OSStatus status = -1;
    
    //running flag
    UInt32 isRunning = 0;
    
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
    UInt32 isRunning = 0;
    
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

//should an event be shown?
-(NSUInteger)shouldShowNotification:(Event*)event
{
    //result
    NSUInteger result = NOTIFICATION_ERROR;
    
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
    
    //(new) mic event?
    // need extra logic, since macOS sometimes toggles / delivers 2x event, etc...
    if(Device_Microphone == event.device)
    {
        //from same client?
        // ignore if last event *just* occurred
        if( (self.lastMicEvent.client.pid == event.client.pid) &&
            ([[NSDate date] timeIntervalSinceDate:self.lastMicEvent.timestamp] < 0.5f) )
        {
            //set result
            result = NOTIFICATION_SPURIOUS;
            
            //dbg msg
            os_log_debug(logHandle, "ignoring mic event, as it happened <0.5s ");
            
            //bail
            goto bail;
        }
        
        //or, was a 2x off?
        if( (nil != self.lastMicEvent) &&
            (NSControlStateValueOff == event.state) &&
            (NSControlStateValueOff == self.lastMicEvent.state) )
        {
            //set result
            result = NOTIFICATION_SPURIOUS;
            
            //dbg msg
            os_log_debug(logHandle, "ignoring mic event, as it was a 2x off");
            
            //bail
            goto bail;
        }

        //update
        self.lastMicEvent = event;
    }
    
    //client provided?
    // check if its allowed
    if(nil != event.client)
    {
        //match is simply: device and path
        for(NSDictionary* allowedItem in [NSUserDefaults.standardUserDefaults objectForKey:PREFS_ALLOWED_ITEMS])
        {
            //match?
            if( ([allowedItem[EVENT_DEVICE] intValue] == event.device) &&
                (YES == [allowedItem[EVENT_PROCESS_PATH] isEqualToString:event.client.path]) )
            {
                //set result
                result = NOTIFICATION_SKIPPED;
                
                //dbg msg
                os_log_debug(logHandle, "%{public}@ is allowed to access %d, so no notification will be shown", event.client.path, event.device);
                
                //done
                goto bail;
            }
        }
    }
    
    //set result
    result = NOTIFICATION_DELIVER;
    
bail:
    
    return result;
}

//handle an event
// show alert / exec user action
-(void)handleEvent:(Event*)event
{
    //result
    NSUInteger result = NOTIFICATION_ERROR;
    
    //should show?
    result = [self shouldShowNotification:event];
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

    //set device
    (Device_Camera == event.device) ? [title appendString:@"Video Device"] : [title appendString:@"Audio Device"];
    
    //set status
    (NSControlStateValueOn == event.state) ? [title appendString:@" became active!"] : [title appendString:@" became inactive."];
    
    //set title
    content.title = title;
    
    //have client?
    // use as body
    if(nil != event.client)
    {
        //set body
        content.body = [NSString stringWithFormat:@"Process: %@ (%@)", getProcessName(event.client.path), event.client.pid];
        
        //set category
        content.categoryIdentifier = CATEGORY_ACTION;
        
        //set user info
        content.userInfo = @{EVENT_DEVICE:@(event.device), EVENT_PROCESS_ID:event.client.pid, EVENT_PROCESS_PATH:event.client.path};
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
    //stop video log monitoring
    [self.videoLogMonitor stop];
    
    //stop audio log monitoring
    [self.audioLogMonitor stop];
    
    //stop audio (device) monitor
    [self stopAudioMonitor];
    
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
