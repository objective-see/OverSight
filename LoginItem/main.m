//
//  main.m
//  Test Application Helper
//
//  Created by Patrick Wardle on 9/10/16.
//  Copyright (c) 2016 Objective-See. All rights reserved.
//

#import "main.h"
#import "Utilities.h"

//go go go
// ->either install/uninstall, or just launch normally
int main(int argc, const char * argv[])
{
    //return var
    int iReturn = 0;
    
    //dbg msg
    logMsg(LOG_DEBUG, @"starting login item");

    //check for uninstall/install flags
    if(2 == argc)
    {
        //install
        if(0 == strcmp(argv[1], ACTION_INSTALL.UTF8String))
        {
            //drop user privs
            setuid(getuid());

            //install
            toggleLoginItem([NSURL fileURLWithPath:[[NSBundle mainBundle] bundlePath]], ACTION_INSTALL_FLAG);
            
            //create default prefs
            [@{PREF_LOG_ACTIVITY:@YES, PREF_START_AT_LOGIN:@YES, PREF_RUN_HEADLESS:@NO, PREF_CHECK_4_UPDATES:@YES} writeToFile:[APP_PREFERENCES stringByExpandingTildeInPath] atomically:NO];
            
            //bail
            goto bail;
        }
        //uninstall
        else if(0 == strcmp(argv[1], ACTION_UNINSTALL.UTF8String))
        {
            //drop user privs
            setuid(getuid());
            
            //unistall
            toggleLoginItem([NSURL fileURLWithPath:[[NSBundle mainBundle] bundlePath]], ACTION_UNINSTALL_FLAG);
            
            //delete prefs
            [[NSFileManager defaultManager] removeItemAtPath:[APP_PREFERENCES stringByExpandingTildeInPath] error:nil];
            
            //bail
            goto bail;
        }
    }
    
    //launch app normally
    iReturn = NSApplicationMain(argc, argv);
    
//bail
bail:
    
    return iReturn;
}
