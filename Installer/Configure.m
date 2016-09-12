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
    return [[NSFileManager defaultManager] fileExistsAtPath:[[EXTENSION_FOLDER stringByExpandingTildeInPath] stringByAppendingPathComponent:EXTENSION_NAME]];
}


//install
// a) create and copy extension to ~/Library/WhatsYourSign
// b) add extension: 'pluginkit -a /path/2/WhatsYourSign.appex'
// c) enable extension: 'pluginkit -e use -i com.objective-see.WhatsYourSignExt.FinderSync'
-(BOOL)install
{
    //return/status var
    BOOL wasInstalled = NO;
    
    //error
    NSError* error = nil;
    
    //path to finder sync (src)
    NSString* extensionPathSrc = nil;
    
    //path to finder sync (dest)
    NSString* extensionPathDest = nil;
    
    //results from 'pluginkit' cmd
    NSData* results = nil;
       
    //set src path
    // ->orginally stored in installer app's /Resource bundle
    extensionPathSrc = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:EXTENSION_NAME];
    
    //set dest path
    extensionPathDest = [[EXTENSION_FOLDER stringByExpandingTildeInPath] stringByAppendingPathComponent:EXTENSION_NAME];
    
    //check if extension folder needs to be created
    if(YES != [[NSFileManager defaultManager] fileExistsAtPath:[EXTENSION_FOLDER stringByExpandingTildeInPath]])
    {
        //create it
        if(YES != [[NSFileManager defaultManager] createDirectoryAtPath:[EXTENSION_FOLDER stringByExpandingTildeInPath] withIntermediateDirectories:YES attributes:nil error:&error])
        {
            //err msg
            logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to create extension's directory %@ (%@)", EXTENSION_FOLDER, error]);
            
            //bail
            goto bail;
        }
    }
    
    //move extension into persistent location
    // ->'/Library/WhatsYourSign/' + extension name
    if(YES != [[NSFileManager defaultManager] copyItemAtPath:extensionPathSrc toPath:extensionPathDest error:&error])
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to copy %@ -> %@ (%@)", extensionPathSrc, extensionPathDest, error]);
        
        //bail
        goto bail;
    }

    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"copied %@ -> %@", extensionPathSrc, extensionPathDest]);
    
    //install extension via 'pluginkit -a <path 2 ext>
    results = execTask(PLUGIN_KIT, @[@"-a", extensionPathDest]);
    if(0 != results.length)
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"pluginkit failed to install extension (%@)", [[NSString alloc] initWithData:results encoding:NSUTF8StringEncoding]]);
        
        //bail
        goto bail;
    }

    //nap
    // ->VM sometimes didn't enable
    [NSThread sleepForTimeInterval:0.5];
        
    //enable extension via 'pluginkit -e use -i <ext bundle id>
    results = execTask(PLUGIN_KIT, @[@"-e", @"use", @"-i", EXTENSION_BUNDLE_ID]);
    if(0 != results.length)
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"pluginkit failed to enable extension (%@)", [[NSString alloc] initWithData:results encoding:NSUTF8StringEncoding]]);
        
        //bail
        goto bail;
    }

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
    NSString* extensionPath = nil;
    
    //error
    NSError* error = nil;

    //init path
    extensionPath = [[EXTENSION_FOLDER stringByExpandingTildeInPath] stringByAppendingPathComponent:EXTENSION_NAME];
  
    //this always seem to 'fail' with 'remove: no plugin at <path/2/FinderSync.appex>'
    // ->but yet works, so just ignore any return from this invocation of execTask()
    execTask(PLUGIN_KIT, @[@"-r", extensionPath]);

    //delete folder
    if(YES != [[NSFileManager defaultManager] removeItemAtPath:[EXTENSION_FOLDER stringByExpandingTildeInPath] error:&error])
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to delete extension directory %@ (%@)", EXTENSION_FOLDER, error]);
        
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

