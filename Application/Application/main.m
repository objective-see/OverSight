//
//  file: main.m
//  project: OverSight (login item)
//  description: main; 'nuff said
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

//FOR LOGGING:
// % log stream --level debug --predicate="subsystem='com.objective-see.oversight'"

@import Cocoa;
@import OSLog;

@import Sentry;

#import "consts.h"
#import "utilities.h"

/* GLOBALS */

//log handle
os_log_t logHandle = nil;

//main interface
// sanity checks, then kick off app
int main(int argc, const char * argv[])
{
    //status
    int status = 0;
    
    //(v1.0) allowed items
    NSArray* allowedItems = nil;
    
    //init log
    logHandle = os_log_create(BUNDLE_ID, "application");
    
    //dbg msg(s)
    os_log_debug(logHandle, "started: %{public}@ (pid: %d / uid: %d)", NSProcessInfo.processInfo.arguments.firstObject, getpid(), getuid());
    os_log_debug(logHandle, "arguments: %{public}@", NSProcessInfo.processInfo.arguments);
    
    //init crash reporting
    [SentrySDK startWithConfigureOptions:^(SentryOptions *options) {
        options.dsn = SENTRY_DSN;
        options.debug = YES;
    }];
    
    //upgrade allowed items?
    // convert into 'NSUserDefaults' and then exit
    if(YES == [NSProcessInfo.processInfo.arguments containsObject:CMD_UPGRADE])
    {
        //dbg msg
        os_log_debug(logHandle, "upgrading allowed items (from: %@)", NSProcessInfo.processInfo.arguments.lastObject);
        
        //load rules
        allowedItems = [NSArray arrayWithContentsOfFile:NSProcessInfo.processInfo.arguments.lastObject];
        if(0 != allowedItems.count)
        {
            //set & snyc
            [NSUserDefaults.standardUserDefaults setValue:allowedItems forKey:PREFS_ALLOWED_ITEMS];
            [NSUserDefaults.standardUserDefaults synchronize];
        }
        
        //done
        goto bail;
    }

    //initial launch?
    // set defaults/handle login item persistence
    if(YES == [NSProcessInfo.processInfo.arguments containsObject:INITIAL_LAUNCH])
    {
        // autostart mode
        // not specified? set to true
        if(nil == [NSUserDefaults.standardUserDefaults objectForKey:PREF_AUTOSTART_MODE])
        {
            //set & snyc
            [NSUserDefaults.standardUserDefaults setBool:YES forKey:PREF_AUTOSTART_MODE];
            [NSUserDefaults.standardUserDefaults synchronize];
        }
        
        //autostart mode enabled?
        // since this is initial launch, check that login item is set
        if(YES == [NSUserDefaults.standardUserDefaults boolForKey:PREF_AUTOSTART_MODE])
        {
            //dbg msg
            os_log_debug(logHandle, "first launch + auto-start is set ...will ensure app is persisted as login item");
            
            //persist
            toggleLoginItem([NSURL fileURLWithPath:NSBundle.mainBundle.bundlePath], NSControlStateValueOn);
        }
    }
    
    //launch app normally
    status = NSApplicationMain(argc, argv);
    
bail:
    
    return status;
}
