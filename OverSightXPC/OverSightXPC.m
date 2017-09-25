//
//  OverSightXPC.m
//  OverSightXPC
//
//  Created by Patrick Wardle on 8/16/16.
//  Copyright (c) 2016 Objective-See. All rights reserved.
//

#import "Consts.h"
#import "Logging.h"
#import "Utilities.h"
#import "Enumerator.h"
#import "OverSightXPC.h"

@implementation OverSightXPC

@synthesize machSenders;
@synthesize videoActive;

//do any initializations
// ->for now, just kick off enumerator
-(void)initialize:(void (^)(void))reply
{
    //start enumerating
    // will forever baseline current mach msg procs
    [NSThread detachNewThreadSelector:@selector(start) toTarget:[Enumerator sharedManager] withObject:nil];
    
    //reply
    reply();
    
    return;
}

//heartbeat
// need as otherwise kernel might kill XPC
-(void)heartBeat:(void (^)(BOOL))reply
{
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, @"heartbeat request");
    #endif
    
    //nap
    [NSThread sleepForTimeInterval:3.0f];
    
    reply(YES);
    
    return;
}

//call into emumerate to get (new) video proc
-(void)getVideoProcs:(BOOL)polling reply:(void (^)(NSMutableArray *))reply
{
    //reply w/ video procs
    reply([[Enumerator sharedManager] enumVideoProcs:polling]);
    
    return;
}

//call into emumerate to get (new) audio proc
-(void)getAudioProcs:(void (^)(NSMutableArray *))reply
{
    //reply w/ video procs
    reply([[Enumerator sharedManager] enumAudioProcs]);
    
    return;
}

//update status video
// ->allows enumerator to stop baselining (when active), etc
-(void)updateVideoStatus:(unsigned int)status reply:(void (^)(void))reply
{
    //set status
    [[Enumerator sharedManager] updateVideoStatus:status];
    
    //reply
    reply();
    
    return;
}

//update status audio
// ->allows enumerator to stop baselining (when active), etc
-(void)updateAudioStatus:(unsigned int)status reply:(void (^)(void))reply
{
    //set status
    [[Enumerator sharedManager] updateAudioStatus:status];

    //reply
    reply();
    
    return;
}

//whitelist a process
-(void)whitelistProcess:(NSString*)processPath device:(NSNumber*)device reply:(void (^)(BOOL))reply
{
    //flag
    BOOL wasAdded = NO;
    
    //path to whitelist
    NSString* path = nil;
    
    //whitelist
    NSMutableArray* whiteList = nil;
    
    //init path to whitelist
    path = [[[@"~" stringByAppendingPathComponent:APP_SUPPORT_DIRECTORY] stringByExpandingTildeInPath] stringByAppendingPathComponent:FILE_WHITELIST];
    
    //load whitelist
    whiteList = [NSMutableArray arrayWithContentsOfFile:path];
    
    //failed to load
    // ->might not exist yet, so alloc
    if(nil == whiteList)
    {
        //alloc
        whiteList = [NSMutableArray array];
    }
    
    //add
    [whiteList addObject:@{EVENT_PROCESS_PATH:processPath, EVENT_DEVICE:device}];
    
    //save to disk
    if(YES != [whiteList writeToFile:path atomically:YES])
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"XPC: failed to save %@ -> %@", processPath, path]);
        
        //bail
        goto bail;
    }
    
    //happy
    wasAdded = YES;
    
bail:
    
    //reply
    reply(wasAdded);
    
    return;
}

//remove a process from the whitelist file
-(void)unWhitelistProcess:(NSString*)processPath device:(NSNumber*)device reply:(void (^)(BOOL))reply
{
    //flag
    BOOL wasRemoved = NO;
    
    //path to whitelist
    NSString* path = nil;
    
    //whitelist
    NSMutableArray* whiteList = nil;
    
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"got request to unwhitelist %@/%@", processPath, device]);
    #endif
    
    //init path to whitelist
    path = [[[@"~" stringByAppendingPathComponent:APP_SUPPORT_DIRECTORY] stringByExpandingTildeInPath] stringByAppendingPathComponent:FILE_WHITELIST];
    
    //load whitelist
    whiteList = [NSMutableArray arrayWithContentsOfFile:path];
    if(nil == whiteList)
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"XPC: failed to load whitelist from %@", path]);
        
        //bail
        goto bail;
    }
    
    //find/remove item from whitelist
    for(NSDictionary* item in whiteList)
    {
        //match path and device?
        if( (YES == [item[EVENT_PROCESS_PATH] isEqualToString:processPath]) &&
            ([item[EVENT_DEVICE] intValue] == device.intValue) )
        {
            //dbg msg
            #ifdef DEBUG
            logMsg(LOG_DEBUG, @"found match in whitelist, will remove!");
            #endif
            
            //remove
            // ->ok, since we aren't going to iterate any more
            [whiteList removeObject:item];
            
            //save to disk
            if(YES != [whiteList writeToFile:path atomically:YES])
            {
                //err msg
                logMsg(LOG_ERR, [NSString stringWithFormat:@"XPC: failed to save updated whitelist to %@", path]);
                
                //bail
                goto bail;
            }
            
            //happy
            wasRemoved = YES;
            
            //done
            goto bail;
        }
    }
    
bail:
    
    //reply
    reply(wasRemoved);
    
    return;
}

//kill a process
-(void)killProcess:(NSNumber*)processID reply:(void (^)(BOOL))reply
{
    //flag
    BOOL wasKilled = NO;
    
    //terminate
    if(-1 == kill(processID.intValue, SIGKILL))
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"XPC: failed to kill %@, with %d", processID, errno]);
        
        //bail
        goto bail;
    }
    
    //happy
    wasKilled = YES;
    
bail:
    
    //reply
    reply(wasKilled);
    
    return;
}

//exit
-(void)exit
{
    //bye
    exit(0);
}

@end
