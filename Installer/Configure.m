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
    
    //install extension
    if(ACTION_INSTALL_FLAG == parameter)
    {
        //dbg msg
        logMsg(LOG_DEBUG, @"installing...");
        
        //if already installed though
        // ->uninstall everything first
        if(YES == [self isInstalled])
        {
            //dbg msg
            logMsg(LOG_DEBUG, @"already installed, so uninstalling...");
            
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
            //bail
            goto bail;
        }
        
        //dbg msg
        logMsg(LOG_DEBUG, @"installed!");
    }
    //uninstall extension
    else if(ACTION_UNINSTALL_FLAG == parameter)
    {
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
// ->simply checks if extension binary exists
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

    //always set group/owner to root/wheel
    setFileOwner(appPathDest, @0, @0, YES);
    
    //no error
    wasInstalled = YES;
    
//bail
bail:
    
    return wasInstalled;
}

//uninstall
// a) remove it (pluginkit -r <path 2 ext>)
// b) delete binary & folder; /Library/WhatsYourSign
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

