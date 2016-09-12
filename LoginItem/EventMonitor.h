//
//  ProcessMonitor.h
//  BlockBlock
//
//  Created by Patrick Wardle on 10/19/14.
//  Copyright (c) 2015 Objective-See. All rights reserved.
//
#import <Foundation/Foundation.h>

//#import "OrderedDictionary.h"

/*
//custom struct
// format of data that's broadcast from kext
struct processStartEvent
{
    //process pid
    // ->id's all chunks
    pid_t pid;

    //process uid
    uid_t uid;
    
    //process ppid
    pid_t ppid;
    
    //process path
    char path[0];
};
*/



@interface EventMonitor : NSObject
{
    
}

/* PROPERTIES */

//process list
//@property(nonatomic, retain)OrderedDictionary* processList;

//dictionary of partial events
//@property(nonatomic, retain)NSMutableDictionary* partialProcessEvents;


/* METHODS */

//kicks off thread to monitor
-(BOOL)monitor;

//thread function
// ->recv() process creation notification events from kext
-(void)recvProcNotifications;

@end
