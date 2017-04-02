//
//  RememberWindowController.m
//  OverSight
//
//  Created by Patrick Wardle on 7/15/16.
//  Copyright (c) 2016 Objective-See. All rights reserved.
//

#import "Consts.h"
#import "Logging.h"
#import "AVMonitor.h"
#import "Utilities.h"
#import "../Shared/XPCProtocol.h"
#import "RemeberWindowController.h"


@implementation RememberWindowController

@synthesize avMonitor;
@synthesize processPath;

//@synthesize versionLabel;

//automatically called when nib is loaded
// ->center window
-(void)awakeFromNib
{
    //center
    [self.window center];
}

//automatically invoked when window is loaded
// ->set to white
-(void)windowDidLoad
{
    //super
    [super windowDidLoad];
    
    //make white
    [self.window setBackgroundColor: NSColor.whiteColor];
    
    //set version sting
    //[self.versionLabel setStringValue:[NSString stringWithFormat:@"version: %@", getAppVersion()]];

    return;
}

/*
//automatically invoked when window is closing
// ->make ourselves unmodal
-(void)windowWillClose:(NSNotification *)notification
{
    //make un-modal
    [[NSApplication sharedApplication] stopModal];
    
    return;
}
*/

//save stuff into iVars
// ->configure window w/ dynamic text
-(void)configure:(NSUserNotification*)notification avMonitor:(AVMonitor*)monitor;
{
    //process ID
    NSNumber* processID = nil;
    
    //process name
    NSString* processName = nil;
    
    //device type
    NSString* deviceType = nil;
    
    //save monitor into iVar
    self.avMonitor = monitor;
    
    //grab process id
    processID = notification.userInfo[EVENT_PROCESS_ID];
    
    //grab process name
    processName = notification.userInfo[EVENT_PROCESS_NAME];
    
    //grab process path
    // ->saved into iVar for whitelisting
    self.processPath = notification.userInfo[EVENT_PROCESS_PATH];
    
    //set device type for audio
    if(SOURCE_AUDIO.intValue == [notification.userInfo[EVENT_DEVICE] intValue])
    {
        //set
        deviceType = @"mic";
    }
    //set device type for mic
    else if(SOURCE_VIDEO.intValue == [notification.userInfo[EVENT_DEVICE] intValue])
    {
        //set
        deviceType = @"camera";
    }
    
    //set text
    [self.windowText setStringValue:[NSString stringWithFormat:@"always allow %@ (%@) to use the %@?", processName, processID, deviceType]];
    
    return;
}

//automatically invoked when user clicks button 'Allow'
-(IBAction)buttonHandler:(id)sender
{
    //xpc connection
    __block NSXPCConnection* xpcConnection = nil;
    
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"handling user response for 'allow' popup: %ld", (long)((NSButton*)sender).tag]);
    #endif
    
    //handle 'always allow' (whitelist) button
    if(BUTTON_ALWAYS_ALLOW == ((NSButton*)sender).tag)
    {
        //init XPC
        xpcConnection = [[NSXPCConnection alloc] initWithServiceName:@"com.objective-see.OverSightXPC"];
        
        //set remote object interface
        xpcConnection.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:@protocol(XPCProtocol)];
        
        //resume
        [xpcConnection resume];
        
        //dbg msg
        #ifdef DEBUG
        logMsg(LOG_DEBUG, @"sending XPC message to whitelist");
        #endif
        
        //invoke XPC method 'whitelistProcess' to add process to white list
        [[xpcConnection remoteObjectProxy] whitelistProcess:self.processPath reply:^(BOOL wasWhitelisted)
         {
            //dbg msg
            #ifdef DEBUG
            logMsg(LOG_DEBUG, [NSString stringWithFormat:@"got XPC response: %d", wasWhitelisted]);
            #endif
             
            //reload whitelist on success
            if(YES == wasWhitelisted)
            {
                //reload AVMonitor's whitelist
                [self.avMonitor loadWhitelist];
            }
            //err
            // ->log msg
            else
            {
                //err msg
                logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to whitelist: %@", self.processPath]);
            }

            //close connection
            [xpcConnection invalidate];

            //nil out
            xpcConnection = nil;
             
         }];
    }
    
//bail
bail:
    
    //always close
    [self.window close];

    return;
}
@end
