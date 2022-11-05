//
//  file: Configure.m
//  project: OverSight (config)
//  description: install/uninstall logic
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

@import OSLog;

#import "consts.h"
#import "Configure.h"
#import "utilities.h"

#import <IOKit/IOKitLib.h>
#import <Foundation/Foundation.h>
#import <Security/Authorization.h>
#import <ServiceManagement/ServiceManagement.h>

/* GLOBALS */

//log handle
extern os_log_t logHandle;

@implementation Configure

@synthesize gotHelp;
@synthesize xpcComms;

//invokes appropriate action
// either install || uninstall logic
-(BOOL)configure:(NSInteger)parameter
{
    //return var
    BOOL wasConfigured = NO;
    
    //uninstall flag
    BOOL uninstallFlag = UNINSTALL_FULL;
    
    //v1 installed?
    // init XPC helper
    if(YES == [self isV1Installed])
    {
        //dbg msg
        os_log_debug(logHandle, "V1 installed, will initialize XPC helper");
        
        //get help
        if(YES != [self initHelper])
        {
            //err msg
            os_log_error(logHandle, "ERROR: failed to init helper tool");
            
            //bail
            goto bail;
        }
    }
    //other, super quick
    // so nap just a sec to allow install/uninstall msg to show up
    else
    {
        //nap
        [NSThread sleepForTimeInterval:1.0f];
    }
    
    //install
    if(ACTION_INSTALL_FLAG == parameter)
    {
        //dbg msg
        os_log_debug(logHandle, "installing...");
        
        //already installed?
        // first uninstall (old version)
        if(YES == [self isInstalled])
        {
            //dbg msg
            os_log_debug(logHandle, "already installed, so this is an upgrade...");
            
            //existing install <2.0?
            // upgrade rules and set flag to perform full uninstall
            if(YES == [self isV1Installed])
            {
                //dbg msg
                os_log_debug(logHandle, "found previous version <2.0");
                
                //exec upgrade v1 -> v2 logic
                [self upgradeFromV1];
                
                //now set full uninstall flag
                uninstallFlag = UNINSTALL_FULL;
            }
            //otherwise,
            // set flag to perform partial uninstall
            else
            {
                //dbg msg
                os_log_debug(logHandle, "previous version is not v1.*, so only partially uninstall");
                
                //set flag
                uninstallFlag = UNINSTALL_PARTIAL;
            }
            
            //uninstall
            if(YES != [self uninstall:uninstallFlag])
            {
                //bail
                goto bail;
            }
            
            //dbg msg
            os_log_debug(logHandle, "uninstalled (type: %@)", (uninstallFlag == UNINSTALL_PARTIAL) ? @"partial" : @"full");
        }
        
        //install
        if(YES != [self install])
        {
            //bail
            goto bail;
        }
    
        //dbg msg
        os_log_debug(logHandle, "installed!");
    }	
    //uninstall
    else if(ACTION_UNINSTALL_FLAG == parameter)
    {
        //dbg msg
        os_log_debug(logHandle, "uninstalling...");
        
        //uninstall
        if(YES != [self uninstall:UNINSTALL_FULL])
        {
            //bail
            goto bail;
        }
        
        //dbg msg
        os_log_debug(logHandle, "uninstalled!");
    }

    //no errors
    wasConfigured = YES;
    
bail:
    
    return wasConfigured;
}

//determine if (already) installed
// just check if app exists
-(BOOL)isInstalled
{
    //check if extension exists
    return [[NSFileManager defaultManager] fileExistsAtPath:[APPS_FOLDER stringByAppendingPathComponent:APP_NAME]];
}

//old version installed?
// check for 'Objective-See' in user's application support directory
-(BOOL)isV1Installed
{
    //application support directory
    NSString* applicationSupport = nil;
    
    //get user's application support directory
    applicationSupport = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES).firstObject;
    
    //check for installed components
    return (YES == [[NSFileManager defaultManager] fileExistsAtPath:[NSString pathWithComponents:@[applicationSupport, @"Objective-See", PRODUCT_NAME]]]);
}

//upgrade logic for v1 -> v2+
// for now, just 'allowed item' upgrade
-(void)upgradeFromV1
{
    //app path
    NSString* application = nil;
    
    //application support directory
    NSString* applicationSupport = nil;
    
    //allowed items
    NSString* allowedItems = nil;
    
    //get app path from resources
    application = [NSBundle.mainBundle pathForResource:PRODUCT_NAME ofType:@"app"];
    
    //get user's application support directory
    applicationSupport = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES).firstObject;
    
    //build path to allowed items
    allowedItems = [NSString pathWithComponents:@[applicationSupport, @"Objective-See", PRODUCT_NAME, @"whitelist.plist"]];
    if(YES != [NSFileManager.defaultManager fileExistsAtPath:allowedItems])
    {
        //dbg msg
        os_log_debug(logHandle, "no allowed items found at: %@", allowedItems);
        
        //done
        goto bail;
    }
    
    //launch app to upgrade
    // storing in 'NSUserDefaults' so its gotta do it
    execTask(application, @[CMD_UPGRADE, allowedItems], YES, NO);
    
bail:
    
    return;
}

//init helper tool
// install and establish XPC connection
-(BOOL)initHelper
{
    //bail if we're already G2G
    if(YES == self.gotHelp)
    {
        //all set
        goto bail;
    }
    
    //install
    if(YES != [self blessHelper])
    {
        //err msg
        os_log_error(logHandle, "ERROR: failed to install helper tool");
        
        //bail
        goto bail;
    }
    
    //init XPC comms
    xpcComms = [[HelperComms alloc] init];
    if(nil == xpcComms)
    {
        //err msg
        os_log_error(logHandle, "ERROR: failed to connect to helper tool");
        
        //bail
        goto bail;
    }
    
    //happy
    self.gotHelp = YES;
    
bail:
    
    return self.gotHelp;
}

//install helper tool
// sets 'wasBlessed' iVar
-(BOOL)blessHelper
{
    //flag
    BOOL wasBlessed = NO;
    
    //auth ref
    AuthorizationRef authRef = NULL;
    
    //error
    CFErrorRef error = NULL;
    
    //auth item
    AuthorizationItem authItem = {};
    
    //auth rights
    AuthorizationRights authRights = {};
    
    //auth flags
    AuthorizationFlags authFlags = 0;
    
    //create auth
    if(errAuthorizationSuccess != AuthorizationCreate(NULL, kAuthorizationEmptyEnvironment, kAuthorizationFlagDefaults, &authRef))
    {
        //err msg
        os_log_error(logHandle, "ERROR: failed to create authorization");
        
        //bail
        goto bail;
    }
    
    //init auth item
    memset(&authItem, 0x0, sizeof(authItem));
    
    //set name
    authItem.name = kSMRightBlessPrivilegedHelper;
    
    //set auth count
    authRights.count = 1;
    
    //set auth items
    authRights.items = &authItem;
    
    //init flags
    authFlags = kAuthorizationFlagDefaults | kAuthorizationFlagInteractionAllowed | kAuthorizationFlagPreAuthorize | kAuthorizationFlagExtendRights;
    
    //get auth rights
    if(errAuthorizationSuccess != AuthorizationCopyRights(authRef, &authRights, kAuthorizationEmptyEnvironment, authFlags, NULL))
    {
        //err msg
        os_log_error(logHandle, "ERROR: failed to copy authorization rights");
        
        //bail
        goto bail;
    }
    
    //bless
    if(YES != (BOOL)SMJobBless(kSMDomainSystemLaunchd, (__bridge CFStringRef)(CONFIG_HELPER_ID), authRef, &error))
    {
        //err msg
        os_log_error(logHandle, "ERROR: failed to bless job (%@)", ((__bridge NSError*)error));
        
        //bail
        goto bail;
    }
    
    //happy
    wasBlessed = YES;
    
bail:
    
    //free auth ref
    if(NULL != authRef)
    {
        //free
        AuthorizationFree(authRef, kAuthorizationFlagDefaults);
        
        //unset
        authRef = NULL;
    }
    
    //free error
    if(NULL != error)
    {
        //release
        CFRelease(error);
        
        //unset
        error = NULL;
    }
    
    return wasBlessed;
}

//remove helper (daemon)
-(BOOL)removeHelper
{
    //return/status var
    __block BOOL wasRemoved = NO;
    
    //if needed
    // tell helper to remove itself
    if(YES == self.gotHelp)
    {
        //cleanup
        wasRemoved = [self.xpcComms cleanup];
        
        //unset var
        if(YES == wasRemoved)
        {
            //unset
            self.gotHelp = NO;
        }
    }
    //didn't need to remove
    // just set ret var to 'ok'
    else
    {
        //set
        wasRemoved = YES;
    }
    
    return wasRemoved;
}

//install
// copy app/install as login item
-(BOOL)install
{
    //return/status var
    BOOL wasInstalled = NO;
    
    //app source
    NSString* applicationSrc = nil;
    
    //path to app
    NSString* applicationDest = nil;
    
    //error
    NSError* error = nil;
    
    //init app src (from resources)
    applicationSrc = [NSBundle.mainBundle pathForResource:PRODUCT_NAME ofType:@"app"];

    //init app dest
    applicationDest = [@"/Applications" stringByAppendingPathComponent:APP_NAME];
    
    //copy
    if(YES != [NSFileManager.defaultManager copyItemAtPath:applicationSrc toPath:applicationDest error:&error])
    {
        //err msg
        os_log_error(logHandle, "ERROR: failed to copy %{public}@ -> %{public}@ (error: %@)", applicationSrc, applicationDest, error);
        
        //bail
        goto bail;
    }
    
    //dbg msg
    os_log_debug(logHandle, "copied %{public}@ -> %{public}@", applicationSrc, applicationDest);
    
    //remove xattrs
    // otherwise app translocation may causes issues
    execTask(XATTR, @[@"-rc", applicationDest], YES, NO);
    
    //dbg msg
    os_log_debug(logHandle, "removed %{public}@'s xattrs", applicationDest);
    
    //happy
    wasInstalled = YES;
    
bail:
    
    return wasInstalled;
}

//uninstall
-(BOOL)uninstall:(BOOL)full
{
    //return/status var
    __block BOOL wasUninstalled = NO;
    
    //flag
    BOOL v1Uninstall = NO;
    
    //path to app
    NSString* application = nil;
    
    //application support directory
    NSString* applicationSupport = nil;
    
    //path to preferences dir
    NSString* prefsDirectory = nil;
    
    //preferences file
    NSString* preferences = nil;
    
    //path to login item
    NSURL* loginItem = nil;

    //error
    NSError* error = nil;

    //set flag
    v1Uninstall = [self isV1Installed];
    
    //init path
    application = [@"/Applications" stringByAppendingPathComponent:APP_NAME];
    
    //dbg msg
    os_log_debug(logHandle, "uninstalling %{public}@", application);
    
    //full?
    // first uninstall app as login item
    if(YES == full)
    {
        //v1 had different login item name
        if(YES == v1Uninstall)
        {
            //init path
            loginItem = [NSURL fileURLWithPath:[application stringByAppendingPathComponent:@"/Contents/Library/LoginItems/OverSight Helper.app"]];
        }
        //otherwise, just path to app
        else
        {
            //init path
            loginItem = [NSURL fileURLWithPath:application];
        }
        
        //uninstall login item
        if(YES != toggleLoginItem(loginItem, ACTION_UNINSTALL_FLAG))
        {
            //err msg
            // ...though not fatal
            os_log_error(logHandle, "failed to uninstall login item");
        }
        else
        {
            //dbg msg
            os_log_debug(logHandle, "uninstalled %{public}@ as login item", loginItem.path);
        }
    }

    //v1.0 uninstall?
    // uninstall via XPC
    if(YES == [self isV1Installed])
    {
        //get user's application support directory
        applicationSupport = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES).firstObject;
        
        //init prefs directory
        prefsDirectory = [NSString pathWithComponents:@[applicationSupport, @"Objective-See", PRODUCT_NAME]];
        
        //dbg msg
        os_log_debug(logHandle, "v1 installed, so uninstalling via XPC helper");
        
        //uninstall
        wasUninstalled = [xpcComms uninstall:prefsDirectory];
        
        //up one level
        prefsDirectory = [prefsDirectory stringByDeletingLastPathComponent];
        
        //no other items
        // delete obj-see directory
        if(0 == [NSFileManager.defaultManager contentsOfDirectoryAtPath:prefsDirectory error:nil].count)
        {
            //dbg msg
            os_log_debug(logHandle, "no files found in %{public}@, will remove", prefsDirectory);
            
            //remove
            [NSFileManager.defaultManager removeItemAtPath:prefsDirectory error:nil];
        }
        
        //done
        goto bail;
    }
    
    //full?
    // delete preferences
    if(YES == full)
    {
        //init prefs file
        preferences = [NSHomeDirectory() stringByAppendingPathComponent:PREFERENCES];
        
        //dbg msg
        os_log_debug(logHandle, "deleting preferences");
    
        //delete preferences file
        // and if this fails, reset
        if(YES != [NSFileManager.defaultManager removeItemAtPath:preferences error:nil])
        {
            //dbg msg
            os_log_debug(logHandle, "deleting failed, will reset preferences");
            
            //reset
            [NSUserDefaults.standardUserDefaults removePersistentDomainForName:@BUNDLE_ID];
        }
    }
    
    //always remove application
    if(YES != [NSFileManager.defaultManager removeItemAtPath:application error:&error])
    {
        //err msg
        os_log_error(logHandle, "ERROR: failed to remove %{public}@ (error: %@)", application, error);
        
        //bail
        goto bail;
    }
        
    //dbg msg
    os_log_debug(logHandle, "deleted %{public}@", application);
    
    //kill it
    execTask(KILL_ALL, @[@"OverSight"], NO, NO);
    
    //happy
    wasUninstalled = YES;
    
bail:
    
    return wasUninstalled;
}

@end
