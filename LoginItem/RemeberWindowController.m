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

@synthesize device;
@synthesize avMonitor;
@synthesize processPath;

//automatically called when nib is loaded
// ->center window
-(void)awakeFromNib
{
    //center
    [self.window center];
}

//automatically invoked when window is loaded
// ->set to window to white
-(void)windowDidLoad
{
    //super
    [super windowDidLoad];
    
    //make white
    [self.window setBackgroundColor: NSColor.whiteColor];
    
    return;
}

//save stuff into iVars
// ->also configure window w/ dynamic text
-(void)configure:(NSUserNotification*)notification avMonitor:(AVMonitor*)monitor;
{
    //process name
    NSString* processName = nil;
    
    //device type
    NSString* deviceType = nil;
    
    //save monitor into iVar
    self.avMonitor = monitor;
    
    //grab process name
    processName = notification.userInfo[EVENT_PROCESS_NAME];
    
    //grab process path
    // ->saved into iVar for whitelisting
    self.processPath = notification.userInfo[EVENT_PROCESS_PATH];
    
    //grab device
    // ->saved into iVar for whitelisting
    self.device = notification.userInfo[EVENT_DEVICE];
    
    //set device type for audio
    if(SOURCE_AUDIO.intValue == [self.device intValue])
    {
        //set
        deviceType = @"mic";
    }
    //set device type for mic
    else if(SOURCE_VIDEO.intValue == [self.device intValue])
    {
        //set
        deviceType = @"camera";
    }
    
    //set text
    [self.windowText setStringValue:[NSString stringWithFormat:@"always allow %@ to use the %@?", processName, deviceType]];
    
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
        [[xpcConnection remoteObjectProxy] whitelistProcess:self.processPath device:self.device reply:^(BOOL wasWhitelisted)
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

         }];
    }
    
//bail
bail:
    
    //always close
    [self.window close];

    return;
}

//automatically invoked when window is closing
// ->remove self from array
-(void)windowWillClose:(NSNotification *)notification
{
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, @"window is closing, will remove array reference");
    #endif

    //sync to remove
    @synchronized (self.avMonitor) {
        
        //remove
        [self.avMonitor.rememberPopups removeObject:self];
    }
    
    return;
}

@end
