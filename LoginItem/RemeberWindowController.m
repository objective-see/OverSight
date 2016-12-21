//
//  RememberWindowController.m
//  OverSight
//
//  Created by Patrick Wardle on 7/15/16.
//  Copyright (c) 2016 Objective-See. All rights reserved.
//

#import "Consts.h"
#import "Utilities.h"
#import "RemeberWindowController.h"

@implementation RememberWindowController

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

//configure window w/ dynamic text
-(void)configure:(NSUserNotification*)notification
{
    //process ID
    NSNumber* processID = nil;
    
    //process name
    NSString* processName = nil;
    
    //device type
    NSString* deviceType = nil;
    
    //grab process id
    processID = notification.userInfo[EVENT_PROCESS_ID];
    
    //grab process name
    processName = notification.userInfo[EVENT_PROCESS_NAME];
    
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

//automatically invoked when user clicks button 'yes' / 'no'
-(IBAction)buttonHandler:(id)sender
{
    //handle 'always allow'  (whitelist) button
    if(BUTTON_ALWAYS_ALLOW == ((NSButton*)sender).tag)
    {
        //TODO: whitelist
    }
    
    //always close
    [self.window close];


    return;
}
@end
