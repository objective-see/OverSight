//
//  OverSightXPC.m
//  OverSightXPC
//
//  Created by Patrick Wardle on 8/16/16.
//  Copyright (c) 2016 Objective-See. All rights reserved.
//

#import "Logging.h"
#import "Enumerator.h"
#import "OverSightXPC.h"


#import "../Shared/Utilities.h"



@implementation OverSightXPC

//TODO: method to set flag, that's sync'd~!?

@synthesize machSenders;
@synthesize videoActive;

//do any initializations
// ->for now, just kick off enumerator
-(void)initialize:(void (^)(void))reply
{
    //start enumerating
    // ->will forever baseline current mach msg procs
    [NSThread detachNewThreadSelector:@selector(start) toTarget:[Enumerator sharedManager] withObject:nil];
    
    //reply
    reply();
    
    return;
}

//call into emumerate to get (new) video proc
-(void)getVideoProcs:(void (^)(NSMutableArray *))reply
{
    //reply w/ video procs
    reply([[Enumerator sharedManager] enumVideoProcs]);
    
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

//kill a process
-(void)killProcess:(NSNumber*)processID reply:(void (^)(BOOL))reply
{
    //flag
    BOOL wasKilled = NO;
    
    //terminate
    if(-1 == kill(processID.intValue, SIGKILL))
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to kill %@, with %d", processID, errno]);
        
        //bail
        goto bail;
    }
    
    //happy
    wasKilled = YES;
    
//bail
bail:
    
    //reply
    reply(wasKilled);
    
    return;

}


@end


