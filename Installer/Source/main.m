//
//  file: main.m
//  project: OverSight (config app)
//  description: main interface, for config
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

@import Cocoa;
@import OSLog;
@import Sentry;

#import "main.h"
#import "consts.h"
#import "utilities.h"
#import "Configure.h"

/* GLOBALS */

//log handle
os_log_t logHandle = nil;

//main interface
int main(int argc, char *argv[])
{
    //status
    int status = -1;
    
    //init log
    logHandle = os_log_create(BUNDLE_ID, "installer");
    
    //init crash reporting
    [SentrySDK startWithConfigureOptions:^(SentryOptions *options) {
        options.dsn = SENTRY_DSN;
        options.debug = YES;
    }];
    
    //user gotta be admin
    if(YES != hasAdminPrivileges())
    {
        //show alert
        showAlert(@"ERROR: Insuffient Privileges.", @"OverSight can only be installed / run on accounts with administrative privileges", @"Exit");
        
        //bail
        goto bail;
    }
    
    //cmdline install?
    if(YES == [NSProcessInfo.processInfo.arguments containsObject:CMD_INSTALL])
    {
        //dbg msg
        os_log_debug(logHandle, "performing commandline install");
        
        //install
        if(YES != cmdlineInterface(ACTION_INSTALL_FLAG))
        {
            //err msg
            printf("\n%s ERROR: install failed\n\n", PRODUCT_NAME.uppercaseString.UTF8String);
            
            //bail
            goto bail;
        }
        
        //dbg msg
        printf("%s: install ok!\n\n", PRODUCT_NAME.uppercaseString.UTF8String);
        
        //happy
        status = 0;
        
        //done
        goto bail;
    }
    
    //cmdline uninstall?
    else if(YES == [[[NSProcessInfo processInfo] arguments] containsObject:CMD_UNINSTALL])
    {
        //dbg msg
        os_log_debug(logHandle, "performing commandline uninstall");
        
        //install
        if(YES != cmdlineInterface(ACTION_UNINSTALL_FLAG))
        {
            //err msg
            printf("\n%s ERROR: uninstall failed\n\n", PRODUCT_NAME.uppercaseString.UTF8String);
            
            //bail
            goto bail;
        }
        
        //dbg msg
        printf("%s: uninstall ok!\n\n", PRODUCT_NAME.uppercaseString.UTF8String);
        
        //happy
        status = 0;
        
        //done
        goto bail;
    }
    
    //default run mode
    // just kick off main app logic
    status = NSApplicationMain(argc, (const char **)argv);
    
bail:
    
    return status;
}

//cmdline interface
// install or uninstall
BOOL cmdlineInterface(int action)
{
    //flag
    BOOL wasConfigured = NO;
    
    //configure obj
    Configure* configure = nil;
    
    //ignore SIGPIPE
    signal(SIGPIPE, SIG_IGN);
    
    //alloc/init
    configure = [[Configure alloc] init];
    
    //first check root
    if(0 != geteuid())
    {
        //err msg
        printf("\n%s ERROR: cmdline interface actions require root!\n\n", PRODUCT_NAME.uppercaseString.UTF8String);
        
        //bail
        goto bail;
    }
    
    //configure
    wasConfigured = [configure configure:action];
    if(YES != wasConfigured)
    {
        //bail
        goto bail;
    }
    
    
    //happy
    wasConfigured = YES;
    
bail:
    
    //cleanup
    if(nil != configure)
    {
        //cleanup
        [configure removeHelper];
    }
    
    return wasConfigured;
}
