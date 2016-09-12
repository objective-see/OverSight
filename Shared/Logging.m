//
//  Logging.m
//  WhatsYourSign
//
//  Created by Patrick Wardle on 7/7/16.
//  Copyright (c) 2016 Objective-See. All rights reserved.
//

#import "Consts.h"
#import "Logging.h"
#import "Utilities.h"

//log a msg
void logMsg(int level, NSString* msg)
{
    //log prefix
    NSMutableString* logPrefix = nil;
    
    //alloc/init
    logPrefix = [NSMutableString stringWithString:@"OBJECTIVE-SEE OVERSIGHT"];
    
    //if its error, add error to prefix
    if(LOG_ERR == level)
    {
        //add
        [logPrefix appendString:@" ERROR"];
    }
    
    //debug mode logic
    #ifdef DEBUG
    
    //in debug mode promote debug msgs to LOG_NOTICE
    // ->OS X only shows LOG_NOTICE and above
    if(LOG_DEBUG == level)
    {
        //promote
        level = LOG_NOTICE;
    }
    
    #endif
    
    //log to syslog
    syslog(level, "%s: %s\n", [logPrefix UTF8String], [msg UTF8String]);
    
    //TODO: remove
    NSLog(@"%s: %s", [logPrefix UTF8String], [msg UTF8String]);
    
    return;
}
