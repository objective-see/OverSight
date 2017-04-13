//
//  Logging.m
//  OverSight
//
//  Created by Patrick Wardle on 7/7/16.
//  Copyright (c) 2016 Objective-See. All rights reserved.
//

#import "Consts.h"
#import "Logging.h"
#import "Utilities.h"

//global log file handle
NSFileHandle* logFileHandle = nil;

//log a msg
// ->default to syslog, and if an err msg, to disk
void logMsg(int level, NSString* msg)
{
    //flag for logging
    BOOL shouldLog = NO;
    
    //log prefix
    NSMutableString* logPrefix = nil;
    
    //first grab logging flag
    shouldLog = (LOG_TO_FILE == (level & LOG_TO_FILE));
    
    //then remove it
    // ->make sure syslog is happy
    level &= ~LOG_TO_FILE;
    
    //alloc/init
    // ->always start w/ 'OVERSIGHT' + pid
    logPrefix = [NSMutableString stringWithFormat:@"OVERSIGHT(%d)", getpid()];
    
    //if its error, add error to prefix
    if(LOG_ERR == level)
    {
        //add
        [logPrefix appendString:@" ERROR"];
    }
    
    //debug mode logic
    #ifdef DEBUG
    
    //in debug mode. promote debug msgs to LOG_NOTICE
    // ->OS X/macOS only shows LOG_NOTICE and above in the system log
    if(LOG_DEBUG == level)
    {
        //promote
        level = LOG_NOTICE;
    }
    
    #endif
    
    //log to syslog
    syslog(level, "%s: %s", [logPrefix UTF8String], [msg UTF8String]);
    
    //when a message is to be logged to file
    // ->log it to file and syslog, when logging is enabled
    if(YES == shouldLog)
    {
        //but only when logging is enabled
        if(nil != logFileHandle)
        {
            //log
            log2File(msg);
            
            //promote to notice for syslog
            if(LOG_DEBUG == level)
            {
                //promote
                level = LOG_NOTICE;
            }
            
            //also syslog
            // ->should result in 1 log msg, (in release), as all LOG_TO_FILE are at LOG_DEBUG level
            syslog(level, "%s: %s", [logPrefix UTF8String], [msg UTF8String]);
        }
    }
    
    return;
}

//get path to log file
NSString* logFilePath()
{
    //path to log directory
    NSString* logDirectory = nil;
    
    //path to log file
    NSString* logFile = nil;
    
    //get log file directory
    logDirectory = [[@"~" stringByAppendingPathComponent:APP_SUPPORT_DIRECTORY] stringByExpandingTildeInPath];
    
    //build path
    logFile = [logDirectory stringByAppendingPathComponent:LOG_FILE_NAME];
    
    return logFile;
}

//log to file
void log2File(NSString* msg)
{
    //append timestamp
    // ->write msg out to disk
    [logFileHandle writeData:[[NSString stringWithFormat:@"%@: %@\n", [NSDate date], msg] dataUsingEncoding:NSUTF8StringEncoding]];
    
    return;
}

//de-init logging
void deinitLogging()
{
    //close file handle
    [logFileHandle closeFile];
    
    //nil out
    logFileHandle = nil;
    
    return;
}

//prep/open log file
BOOL initLogging()
{
    //ret var
    BOOL bRet = NO;
    
    //log file path
    NSString* logPath = nil;
    
    //get path to log file
    logPath = logFilePath();
    
    //first time
    // ->create log file
    if(YES != [[NSFileManager defaultManager] fileExistsAtPath:logPath])
    {
        //create
        [[NSFileManager defaultManager] createFileAtPath:logPath contents:nil attributes:nil];
    }
    
    //get file handle
    logFileHandle = [NSFileHandle fileHandleForWritingAtPath:logPath];
    if(nil == logFileHandle)
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to get log file handle to %@", logPath]);
        
        //bail
        goto bail;
    }
    
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"opened log file; %@", logPath]);
    #endif
    
    //seek to end
    [logFileHandle seekToEndOfFile];
    
    //happy
    bRet = YES;
    
//bail
bail:
    
    return bRet;
}
