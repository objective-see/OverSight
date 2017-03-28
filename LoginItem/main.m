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
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"starting login item (args: %@/user: %@)", [[NSProcessInfo processInfo] arguments], NSUserName()]);
           
    //check for uninstall/install flags, and process to remove from whitelist
    if(2 == argc)
    {
        //install
        if(0 == strcmp(argv[1], CMD_INSTALL))
        {
            //dbg msg
            logMsg(LOG_DEBUG, @"running install logic");
            
            //drop user privs
            setuid(getuid());

            //install
            toggleLoginItem([NSURL fileURLWithPath:[[NSBundle mainBundle] bundlePath]], ACTION_INSTALL_FLAG);
            
            //dbg msg
            logMsg(LOG_DEBUG, @"installed login item");
            
            //create default prefs
            [@{PREF_LOG_ACTIVITY:@YES, PREF_START_AT_LOGIN:@YES, PREF_RUN_HEADLESS:@NO, PREF_CHECK_4_UPDATES:@YES} writeToFile:[APP_PREFERENCES stringByExpandingTildeInPath] atomically:NO];
            
            //dbg msg
            logMsg(LOG_DEBUG, [NSString stringWithFormat:@"created preferences at: %@", [APP_PREFERENCES stringByExpandingTildeInPath]]);
            
            //bail
            goto bail;
        }
        //uninstall
        else if(0 == strcmp(argv[1], CMD_UNINSTALL))
        {
            //dbg msg
            logMsg(LOG_DEBUG, @"running uninstall logic");
            
            //drop user privs
            setuid(getuid());
            
            //unistall
            toggleLoginItem([NSURL fileURLWithPath:[[NSBundle mainBundle] bundlePath]], ACTION_UNINSTALL_FLAG);
            
            //dbg msg
            logMsg(LOG_DEBUG, @"removed login item");
            
            //delete prefs
            [[NSFileManager defaultManager] removeItemAtPath:[APP_PREFERENCES stringByExpandingTildeInPath] error:nil];
            
            //dbg msg
            logMsg(LOG_DEBUG, [NSString stringWithFormat:@"removed preferences from: %@", [APP_PREFERENCES stringByExpandingTildeInPath]]);
            
            //bail
            goto bail;
        }
        
        //assume its a path to a process to remove from whitelist
        else
        {
            //dbg msg
            logMsg(LOG_DEBUG, @"running 'un-whitelist me' logic");
            
            //remove from whitelist file
            unWhiteList([NSString stringWithUTF8String:argv[1]]);
            
            //don't bail
            // ->let it start (as it was killed)
        }
    }
    
    //launch app normally
    iReturn = NSApplicationMain(argc, argv);
    
//bail
bail:
    
    return iReturn;
}

//send XPC message to remove process from whitelist file
void unWhiteList(NSString* process)
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
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"sending XPC message to remove %@ from whitelist file", process]);
    
    //invoke XPC method 'whitelistProcess' to add process to white list
    [[xpcConnection remoteObjectProxy] unWhitelistProcess:process reply:^(BOOL wasRemoved)
     {
         //dbg msg
         logMsg(LOG_DEBUG, [NSString stringWithFormat:@"got XPC response: %d", wasRemoved]);
         
         //err msg ono failure
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
