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
    execTask(XATTR, @[@"-cr", appPathDest], YES);
    
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
    
    //create app support directory
    if(YES != [self createAppSupport:user])
    {
        //err msg
        logMsg(LOG_ERR, @"failed to create app support directory for current user");
        
        //bail
        goto bail;
    }
    
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, @"created app support directory");
    #endif
    

    //call into login item to install itself
    // ->runs as logged in user, so can access user's login items, etc
    execTask(SUDO, @[@"-u", user, loginItem, [NSString stringWithUTF8String:CMD_INSTALL]], YES);
    
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

//start login item
// ->exec as logged in user, since might be called via 'sudo' (cmdline install)
-(BOOL)start
{
    //flag
    BOOL bStarted = NO;
    
    //logged in user
    NSString* user = nil;
    
    //path to login item
    NSString* loginItem = nil;
    
    //get user
    user = loggedinUser();
    if(nil == user)
    {
        //err msg
        logMsg(LOG_ERR, @"failed to determine logged-in user");
        
        //bail
        goto bail;
    }
    
    //init path
    loginItem = [[APPS_FOLDER stringByAppendingPathComponent:APP_NAME] stringByAppendingPathComponent:@"Contents/Library/LoginItems/OverSight Helper.app/Contents/MacOS/OverSight Helper"];
    
    //start it!
    // ->don't wait, as it won't exit
    execTask(SUDO, @[@"-u", user, loginItem], NO);
    
    //happy
    bStarted = YES;
    
//bail
bail:
    
    return bStarted;
}

//stop
-(void)stop
{
    //kill helper app
    execTask(PKILL, @[APP_HELPER], YES);
    
    //kill xpc
    execTask(PKILL, @[APP_HELPER_XPC], YES);

    return;
}

//uninstall
// ->delete app, remove login item, etc
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
    loginItem = [[APPS_FOLDER stringByAppendingPathComponent:APP_NAME] stringByAppendingPathComponent:@"Contents/Library/LoginItems/OverSight Helper.app/Contents/MacOS/OverSight Helper"];
    
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
        execTask(SUDO, @[@"-u", user, loginItem, [NSString stringWithUTF8String:CMD_UNINSTALL]], YES);
        
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
            if(YES != [self removeAppSupport:user])
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

//create directory app support
// ->store whitelist file, log file, etc
-(BOOL)createAppSupport:(NSString*)user
{
    //flag
    BOOL createdDirectory = NO;
    
    //directory
    NSString* appSupportDirectory = nil;
    
    //user's directory permissions
    // ->used to match any created directories
    NSDictionary* userDirAttributes = nil;
    
    //build path
    appSupportDirectory = [NSString pathWithComponents:@[@"/Users/", user, APP_SUPPORT_DIRECTORY]];
    
    //create if not present
    if(YES != [[NSFileManager defaultManager] fileExistsAtPath:appSupportDirectory])
    {
        //create it
        if(YES != [[NSFileManager defaultManager] createDirectoryAtPath:appSupportDirectory withIntermediateDirectories:YES attributes:nil error:NULL])
        {
            //err msg
            logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to create app support directory (%@)", appSupportDirectory]);
            
            //bail
            goto bail;
        }
    }
    
    //get permissions of one directory up
    // -> ~/Library
    userDirAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[@"/Users/" stringByAppendingPathComponent:user] error:nil];
    
    //assuming required attributes were found
    // ->make sure ~/Library/Application Support/Objective-See is owned by user
    if( (nil != userDirAttributes) &&
        (nil != userDirAttributes[@"NSFileGroupOwnerAccountID"]) &&
        (nil != userDirAttributes[@"NSFileOwnerAccountID"]) )
    {
        //match newly created directory w/ user
        setFileOwner([appSupportDirectory stringByDeletingLastPathComponent], userDirAttributes[@"NSFileGroupOwnerAccountID"], userDirAttributes[@"NSFileOwnerAccountID"], YES);
    }

    //happy
    createdDirectory = YES;
    
//bail
bail:
    
    return createdDirectory;
}

//remove ~/Library/Application Support/Objective-See/OverSight
// and also  ~/Library/Application Support/Objective-See/ if nothing else is in there (no other products)
-(BOOL)removeAppSupport:(NSString*)user
{
    //flag
    BOOL removedDirectory = NO;
    
    //directory
    NSString* appSupportDirectory = nil;
    
    //error
    NSError* error = nil;
    
    //build path
    appSupportDirectory = [NSString pathWithComponents:@[@"/Users/", user, APP_SUPPORT_DIRECTORY]];
    
    //delete OverSight's app support directory
    if(YES != [[NSFileManager defaultManager] removeItemAtPath:appSupportDirectory error:&error])
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to delete OverSight's app support directory %@ (%@)", appSupportDirectory, error]);
        
        //bail
        goto bail;
    }
    
    //anything left in ~/Library/Application Support/Objective-See/?
    // ->nope: delete it
    if(0 == [[[NSFileManager defaultManager] contentsOfDirectoryAtPath:[appSupportDirectory stringByDeletingLastPathComponent] error:nil] count])
    {
        if(YES != [[NSFileManager defaultManager] removeItemAtPath:[appSupportDirectory stringByDeletingLastPathComponent] error:&error])
        {
            //err msg
            logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to delete Objective-See's app support directory %@ (%@)", [appSupportDirectory stringByDeletingLastPathComponent], error]);
            
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

