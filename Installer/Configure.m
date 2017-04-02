//
//  Configure.m
//  OverSight
//
//  Created by Patrick Wardle on 9/01/16.
//  Copyright (c) 2016 Objective-See. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <ServiceManagement/ServiceManagement.h>

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
        #ifdef DEBUG
        logMsg(LOG_DEBUG, @"installing...");
        #endif
        
        //if already installed though
        // ->uninstall everything first
        if(YES == [self isInstalled])
        {
            //dbg msg
            #ifdef DEBUG
            logMsg(LOG_DEBUG, @"already installed, so stopping/uninstalling...");
            #endif
            
            //stop
            // ->kill login item/XPC service
            [self stop];
            
            //uninstall
            // ->but do partial (leave whitelist)
            if(YES != [self uninstall:UNINSTALL_PARIAL])
            {
                //bail
                goto bail;
            }
            
            //dbg msg
            #ifdef DEBUG
            logMsg(LOG_DEBUG, @"uninstalled");
            #endif
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
        #ifdef DEBUG
        logMsg(LOG_DEBUG, @"installed, now will start");
        #endif
        
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
        #ifdef DEBUG
        logMsg(LOG_DEBUG, @"stopping login item");
        #endif
        
        //stop
        // ->kill login item/XPC service
        [self stop];
         
        //dbg msg
        #ifdef DEBUG
        logMsg(LOG_DEBUG, @"uninstalling...");
        #endif
        
        //uninstall
        if(YES != [self uninstall:UNINSTALL_FULL])
        {
            //bail
            goto bail;
        }
        
        //dbg msg
        #ifdef DEBUG
        logMsg(LOG_DEBUG, @"uninstalled!");
        #endif
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
    
    //path to login item
    NSString* loginItem = nil;
    
    //logged in user
    NSString* user = nil;
    
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
    #ifdef DEBUG
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"copied %@ -> %@", appPathSrc, appPathDest]);
    #endif
    
    //remove xattrs
    // ->otherwise app translocation causes issues
    execTask(XATTR, @[@"-cr", appPathDest]);
    
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, @"removed xattr");
    #endif
    
    //init path to login item
    loginItem = [appPathDest stringByAppendingPathComponent:@"Contents/Library/LoginItems/OverSight Helper.app/Contents/MacOS/OverSight Helper"];
    
    //get user
    user = loggedinUser();
    if(nil == user)
    {
        //err msg
        logMsg(LOG_ERR, @"failed to determine logged-in user");
        
        //bail
        goto bail;
    }

    //call into login item to install itself
    // ->runs as logged in user, so can access user's login items, etc
    execTask(SUDO, @[@"-u", user, loginItem, [NSString stringWithUTF8String:CMD_INSTALL]]);
    
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"persisted %@", loginItem]);
    #endif
    
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
    
    //task
    NSTask* task = nil;
    
    //init path
    loginItem = [[APPS_FOLDER stringByAppendingPathComponent:APP_NAME] stringByAppendingPathComponent:@"Contents/Library/LoginItems/OverSight Helper.app/Contents/MacOS/OverSight Helper"];
    
    //alloc task
    task = [[NSTask alloc] init];
    
    //set path
    [task setLaunchPath:loginItem];
    
    //wrap task launch
    @try
    {
        //launch
        [task launch];
    }
    @catch(NSException* exception)
    {
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
-(BOOL)uninstall:(NSUInteger)type
{
    //return/status var
    BOOL wasUninstalled = NO;
    
    //status var
    // ->since want to try all uninstall steps, but record if any fail
    BOOL bAnyErrors = NO;
    
    //path to login item
    NSString* loginItem = nil;
    
    //path to installed app
    NSString* installedAppPath = nil;
    
    //error
    NSError* error = nil;
    
    //logged in user
    NSString* user = nil;
    
    //init path to login item
    loginItem = [[[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:APP_NAME] stringByAppendingPathComponent:@"Contents/Library/LoginItems/OverSight Helper.app/Contents/MacOS/OverSight Helper"];
    
    //init path to installed app
    installedAppPath = [APPS_FOLDER stringByAppendingPathComponent:APP_NAME];
    
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, @"uninstalling login item");
    #endif
    
    //get user
    user = loggedinUser();
    if(nil == user)
    {
        //err msg
        logMsg(LOG_ERR, @"failed to determine logged-in user");
        
        //set flag
        bAnyErrors = YES;
        
        //keep uninstalling...
    }
    
    //unistall login item
    else
    {
        //dbg msg
        #ifdef DEBUG
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"telling login item %@, to uninstall itself", loginItem]);
        #endif
        
        //call into login item to uninstall itself
        // ->runs as logged in user, so can access user's login items, etc
        execTask(SUDO, @[@"-u", user, loginItem, [NSString stringWithUTF8String:CMD_UNINSTALL]]);
        
        //dbg msg
        #ifdef DEBUG
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"unpersisted %@", loginItem]);
        #endif
    }
    
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, @"deleting app");
    #endif

    //delete folder
    if(YES != [[NSFileManager defaultManager] removeItemAtPath:installedAppPath error:&error])
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to delete app %@ (%@)", installedAppPath, error]);
        
        //set flag
        bAnyErrors = YES;
        
        //keep uninstalling...
    }
    
    //full uninstall?
    // ->remove app support directory too
    if(UNINSTALL_FULL == type)
    {
        //dbg msg
        #ifdef DEBUG
        logMsg(LOG_DEBUG, @"full uninstall, so also deleting app support directory");
        #endif
        
        //delete app support folder
        if(YES == [[NSFileManager defaultManager] fileExistsAtPath:[APP_SUPPORT_DIRECTORY stringByExpandingTildeInPath]])
        {
            //delete
            if(YES != [self removeAppSupport])
            {
                //err msg
                logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to delete app support directory %@", APP_SUPPORT_DIRECTORY]);
                
                //set flag
                bAnyErrors = YES;
                
                //keep uninstalling...
            }
        }
    }
    
    //only success when there were no errors
    if(YES != bAnyErrors)
    {
        //happy
        wasUninstalled = YES;
    }

    return wasUninstalled;
}

//remove ~/Library/Application Support/Objective-See/OverSight
// and also  ~/Library/Application Support/Objective-See/ if nothing else is in there (no other products)
-(BOOL)removeAppSupport
{
    //flag
    BOOL removedDirectory = NO;
    
    //error
    NSError* error = nil;
    
    //delete OverSight directory
    if(YES != [[NSFileManager defaultManager] removeItemAtPath:[APP_SUPPORT_DIRECTORY stringByExpandingTildeInPath] error:&error])
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to delete OverSight's app support directory %@ (%@)", APP_SUPPORT_DIRECTORY, error]);
        
        //bail
        goto bail;
    }
    
    //anything left in ~/Library/Application Support/Objective-See/?
    // ->nope: delete it
    if(0 == [[[NSFileManager defaultManager] contentsOfDirectoryAtPath:[[APP_SUPPORT_DIRECTORY stringByExpandingTildeInPath] stringByDeletingLastPathComponent] error:nil] count])
    {
        if(YES != [[NSFileManager defaultManager] removeItemAtPath:[[APP_SUPPORT_DIRECTORY stringByExpandingTildeInPath] stringByDeletingLastPathComponent] error:&error])
        {
            //err msg
            logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to delete Objective-See's app support directory %@ (%@)", [APP_SUPPORT_DIRECTORY stringByDeletingLastPathComponent], error]);
            
            //bail
            goto bail;
        }
    }
    
    //happy
    removedDirectory = YES;
    
//bail
bail:
    
    return removedDirectory;
}


@end

