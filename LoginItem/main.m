//
//  main.m
//  Test Application Helper
//
//  Created by Patrick Wardle on 9/10/16.
//  Copyright (c) 2016 Objective-See. All rights reserved.
//

#import "main.h"
#import "Logging.h"
#import "Utilities.h"
#import "../Shared/XPCProtocol.h"

//go go go
// ->either install/uninstall, or just launch normally
int main(int argc, const char * argv[])
{
    //return var
    int iReturn = 0;
    
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"starting login item (args: %@/user: %@)", [[NSProcessInfo processInfo] arguments], NSUserName()]);
    #endif
    
    //check for uninstall/install flags, and process to remove from whitelist
    if(2 == argc)
    {
        //install
        if(0 == strcmp(argv[1], CMD_INSTALL))
        {
            //dbg msg
            #ifdef DEBUG
            logMsg(LOG_DEBUG, @"running install logic");
            #endif
            
            //drop user privs
            setuid(getuid());

            //install
            toggleLoginItem([NSURL fileURLWithPath:[[NSBundle mainBundle] bundlePath]], ACTION_INSTALL_FLAG);
            
            //dbg msg
            #ifdef DEBUG
            logMsg(LOG_DEBUG, @"installed login item");
            #endif
            
            //create default prefs
            [@{PREF_LOG_ACTIVITY:@YES, PREF_START_AT_LOGIN:@YES, PREF_RUN_HEADLESS:@NO, PREF_CHECK_4_UPDATES:@YES} writeToFile:[APP_PREFERENCES stringByExpandingTildeInPath] atomically:NO];
            
            //dbg msg
            #ifdef DEBUG
            logMsg(LOG_DEBUG, [NSString stringWithFormat:@"created preferences at: %@", [APP_PREFERENCES stringByExpandingTildeInPath]]);
            #endif
            
            //bail
            goto bail;
        }
        //uninstall
        else if(0 == strcmp(argv[1], CMD_UNINSTALL))
        {
            //dbg msg
            #ifdef DEBUG
            logMsg(LOG_DEBUG, @"running uninstall logic");
            #endif
            
            //drop user privs
            setuid(getuid());
            
            //uninstall
            if(YES == toggleLoginItem([NSURL fileURLWithPath:[[NSBundle mainBundle] bundlePath]], ACTION_UNINSTALL_FLAG))
            {
                //err msg
                logMsg(LOG_ERR, @"failed to remove login item");
                
                //set error
                iReturn = -1;
                
                //bail
                goto bail;
            }
            
            //dbg msg
            #ifdef DEBUG
            logMsg(LOG_DEBUG, @"removed login item");
            #endif
            
            //delete prefs
            [[NSFileManager defaultManager] removeItemAtPath:[APP_PREFERENCES stringByExpandingTildeInPath] error:nil];
            
            //dbg msg
            #ifdef DEBUG
            logMsg(LOG_DEBUG, [NSString stringWithFormat:@"removed preferences from: %@", [APP_PREFERENCES stringByExpandingTildeInPath]]);
            #endif
            
            //bail
            goto bail;
        }
    }
    
    //unwhitelist path/device
    else if(3 == argc)
    {
        //dbg msg
        #ifdef DEBUG
        logMsg(LOG_DEBUG, @"running 'un-whitelist me' logic");
        #endif

        //remove from whitelist file
        unWhiteList([NSString stringWithUTF8String:argv[1]], [NSNumber numberWithInt:atoi(argv[2])]);
        
        //don't bail
        // ->let it start (as it was killed)
    }
    
    //launch app normally
    iReturn = NSApplicationMain(argc, argv);
    
//bail
bail:
    
    return iReturn;
}

//send XPC message to remove process from whitelist file
void unWhiteList(NSString* process, NSNumber* device)
{
    //xpc connection
    __block NSXPCConnection* xpcConnection = nil;

    //init XPC
    xpcConnection = [[NSXPCConnection alloc] initWithServiceName:@"com.objective-see.OverSightXPC"];
    
    //set remote object interface
    xpcConnection.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:@protocol(XPCProtocol)];
    
    //resume
    [xpcConnection resume];
    
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"sending XPC message to remove %@/%@ from whitelist file", process, device]);
    #endif
    
    //invoke XPC method 'whitelistProcess' to add process to white list
    [[xpcConnection remoteObjectProxy] unWhitelistProcess:process device:device reply:^(BOOL wasRemoved)
     {
        //dbg msg
        #ifdef DEBUG
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"got XPC response: %d", wasRemoved]);
        #endif
         
        //err msg on failure
        if(YES != wasRemoved)
        {
            //err msg
            logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to remove %@ from whitelist", process]);
        }

        //close connection
        [xpcConnection invalidate];

        //nil out
        xpcConnection = nil;
         
     }];
    
    return;
}
