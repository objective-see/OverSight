//
//  Configure.m
//  OverSight
//
//  Created by Patrick Wardle on 9/01/16.
//  Copyright (c) 2016 Objective-See. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "Consts.h"
#import "Logging.h"
#import "Utilities.h"
#import "Configure.h"


@implementation Configure

//invokes appropriate install || uninstall logic
-(BOOL)configure:(NSUInteger)parameter
{
    //return var
    BOOL wasConfigured = NO;
    
    //install
    // ->starts on success
    if(ACTION_INSTALL_FLAG == parameter)
    {
        //dbg msg
        logMsg(LOG_DEBUG, @"installing...");
        
        //if already installed though
        // ->uninstall everything first
        if(YES == [self isInstalled])
        {
            //dbg msg
            logMsg(LOG_DEBUG, @"already installed, so stopping/uninstalling...");
            
            //stop
            // ->kill login item/XPC service
            [self stop];
            
            //uninstall
            if(YES != [self uninstall])
            {
                //bail
                goto bail;
            }
            
            //dbg msg
            logMsg(LOG_DEBUG, @"uninstalled");
        }
        
        //install
        if(YES != [self install])
        {
            //err msg
            logMsg(LOG_ERR, @"installation failed");
            
            //bail
            goto bail;
        }
        
        //dbg msg
        logMsg(LOG_DEBUG, @"installed, now will start");
        
        //start login item
        if(YES != [self start])
        {
            //err msg
            logMsg(LOG_ERR, @"starting failed");
            
            //bail
            goto bail;
        }
    }
    //uninstall
    // ->stops login item (also w/ stop XPC service)
    else if(ACTION_UNINSTALL_FLAG == parameter)
    {
        //dbg msg
        logMsg(LOG_DEBUG, @"stopping login item");
        
        //stop
        // ->kill login item/XPC service
        [self stop];
         
        //dbg msg
        logMsg(LOG_DEBUG, @"uninstalling...");
        
        //uninstall
        if(YES != [self uninstall])
        {
            //bail
            goto bail;
        }
        
        //dbg msg
        logMsg(LOG_DEBUG, @"uninstalled!");
    }

    //no errors
    wasConfigured = YES;
    
//bail
bail:
    
    return wasConfigured;
}

//determine if installed
// ->simply checks if application exists in /Applications
-(BOOL)isInstalled
{
    //check if extension exists
    return [[NSFileManager defaultManager] fileExistsAtPath:[APPS_FOLDER stringByAppendingPathComponent:APP_NAME]];
}

//install
// a) copy to /Applications
// b) chown/chmod XPC component
-(BOOL)install
{
    //return/status var
    BOOL wasInstalled = NO;
    
    //error
    NSError* error = nil;
    
    //path to app (src)
    NSString* appPathSrc = nil;
    
    //path to app (dest)
    NSString* appPathDest = nil;
    
    //path to XPC service
    NSString* xpcServicePath = nil;
    
    //set src path
    // ->orginally stored in installer app's /Resource bundle
    appPathSrc = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:APP_NAME];
    
    //set dest path
    appPathDest = [APPS_FOLDER stringByAppendingPathComponent:APP_NAME];
    
    //move app into /Applications
    if(YES != [[NSFileManager defaultManager] copyItemAtPath:appPathSrc toPath:appPathDest error:&error])
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to copy %@ -> %@ (%@)", appPathSrc, appPathDest, error]);
        
        //bail
        goto bail;
    }

    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"copied %@ -> %@", appPathSrc, appPathDest]);
    
    //init path to XPC service
    xpcServicePath = [appPathDest stringByAppendingPathComponent:@"Contents/Library/LoginItems/OverSight Helper.app/Contents/XPCServices/OverSightXPC.xpc"];

    //set XPC service to be owned; root:wheel
    if(YES != setFileOwner(xpcServicePath, @0, @0, YES))
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to set file owner to root:wheel on %@", xpcServicePath]);
        
        //bail
        goto bail;
    }
    
    //set XPC service binary to setuid
    if(YES != setFilePermissions(xpcServicePath, 06755, YES))
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to set file permissions to 06755 on %@", xpcServicePath]);
        
        //bail
        goto bail;
    }
    
    //no error
    wasInstalled = YES;
    
//bail
bail:
    
    return wasInstalled;
}

//start
// ->just the login item
-(BOOL)start
{
    //flag
    BOOL bStarted = NO;
    
    //path to login item
    NSString* loginItem = nil;
    
    //init path
    loginItem = [[APPS_FOLDER stringByAppendingPathComponent:APP_NAME] stringByAppendingPathComponent:@"Contents/Library/LoginItems/OverSight Helper.app"];

    //launch it!
    if(YES != [[NSWorkspace sharedWorkspace] launchApplication:loginItem])
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to start login item, %@", loginItem]);
        
        //bail
        goto bail;
    }
    
    //happy
    bStarted = YES;
    
//bail
bail:
    
    return bStarted;
}

//stop
-(void)stop
{
    //kill it
    // pkill doesn't provide error info, so...
    execTask(PKILL, @[APP_HELPER_NAME]);

    return;
}

//uninstall
// ->delete app
-(BOOL)uninstall
{
    //return/status var
    BOOL wasUninstalled = NO;
    
    //status var
    // ->since want to try all uninstall steps, but record if any fail
    BOOL bAnyErrors = NO;
    
    //path to finder sync
    NSString* appPath = nil;
    
    //error
    NSError* error = nil;

    //init path
    appPath = [APPS_FOLDER stringByAppendingPathComponent:APP_NAME];
  
    //delete folder
    if(YES != [[NSFileManager defaultManager] removeItemAtPath:appPath error:&error])
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to delete app %@ (%@)", appPath, error]);
        
        //set flag
        bAnyErrors = YES;
        
        //keep uninstalling...
    }
    
    //only success when there were no errors
    if(YES != bAnyErrors)
    {
        //happy
        wasUninstalled = YES;
    }

    return wasUninstalled;
}

@end

