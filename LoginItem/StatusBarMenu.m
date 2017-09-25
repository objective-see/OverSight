//
//  StatusBarMenu.m
//  OverSight
//
//  Created by Patrick Wardle on 1/4/15.
//  Copyright (c) 2015 Objective-See. All rights reserved.
//

#import "Consts.h"
#import "Logging.h"
#import "Utilities.h"
#import "AppDelegate.h"
#import "XPCProtocol.h"
#import "StatusBarMenu.h"

#import <CoreMediaIO/CMIOHardware.h>
#import <AVFoundation/AVFoundation.h>


@implementation StatusBarMenu

@synthesize isEnabled;

//init method
// ->set some intial flags, etc
-(id)init
{
    //load from nib
    self = [super init];
    if(self != nil)
    {
        //set flag
        self.isEnabled = YES;
    }
    
    return self;
}

//setup status item
// ->init button, show popover, etc
-(void)setupStatusItem
{
    //status bar image
    NSImage *image = nil;
    
    //init status item
    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSSquareStatusItemLength];
    
    //init image
    image = [NSImage imageNamed:@"statusIcon"];
    
    //tell OS to handle image
    // ->dark mode, etc
    [image setTemplate:YES];
    
    //set image
    self.statusItem.image = image;
    
    //init menu
    // ->enumerator will re-invoke with devices and their status
    [self updateStatusItemMenu:nil];
    
    return;
}

//create/update status item menu
-(void)updateStatusItemMenu:(NSArray*)devices
{
    //pool
    @autoreleasepool
    {
        
    //menu
    NSMenu* menu = nil;
    
    //array of active devices
    NSMutableArray* activeDevices = nil;
    
    //array of inactive devices
    NSMutableArray* inactiveDevices = nil;
    
    //string for device name/emoji
    NSMutableString* deviceDetails = nil;

    //alloc/init window
    menu = [[NSMenu alloc] init];
    
    //alloc array for active devices
    activeDevices = [NSMutableArray array];
    
    //alloc array for inactive devices
    inactiveDevices = [NSMutableArray array];

    //add status msg
    [menu addItemWithTitle:@"OVERSIGHT: monitoring 🎤 + 📸" action:NULL keyEquivalent:@""];
    
    //add top separator
    [menu addItem:[NSMenuItem separatorItem]];
    
    //iterate over all devices
    // ->classify each, and built details string for menu
    for(NSDictionary* device in devices)
    {
        //init string for name/etc
        deviceDetails = [NSMutableString string];
        
        //add device emoji
        // ->audio device
        if(YES == [device[EVENT_DEVICE] isKindOfClass:NSClassFromString(@"AVCaptureHALDevice")])
        {
            //add
            [deviceDetails appendString:@" 🎤 "];
        }
        //add device emoji
        // ->video device
        else
        {
            //add
            [deviceDetails appendString:@" 📸 "];
        }
        
        //add device name
        [deviceDetails appendString:((AVCaptureDevice*)device[EVENT_DEVICE]).localizedName];
        
        //classify
        // ->active devices
        if(DEVICE_ACTIVE.intValue == [device[EVENT_DEVICE_STATUS] intValue])
        {
            //add
            [activeDevices addObject:deviceDetails];
        }
        //classify
        // ->inactive devices
        else
        {
            //add
            [inactiveDevices addObject:deviceDetails];
        }
    }
    
    //add active devices to menu
    if(0 != activeDevices.count)
    {
        //add title
        [menu addItem:[self initializeMenuItem:@"Active Devices" action:NULL]];
        
        //add each
        for(NSString* deviceDetails in activeDevices)
        {
            [menu addItem:[self initializeMenuItem:deviceDetails action:NULL]];
        }
    }
    //when no active devices
    // ->add title to reflect that fact
    else
    {
        //add
        [menu addItem:[self initializeMenuItem:@"No Active Devices" action:NULL]];
    }
    
    //add item separator
    [menu addItem:[NSMenuItem separatorItem]];
    
    //add inactive devices to menu
    if(0 != inactiveDevices.count)
    {
        //add title
        [menu addItem:[self initializeMenuItem:@"Inactive Devices" action:NULL]];
        
        //add each
        for(NSString* deviceDetails in inactiveDevices)
        {
            [menu addItem:[self initializeMenuItem:deviceDetails action:NULL]];
        }
    }
    //when no inactive devices
    // ->add title to reflect that fact
    else
    {
        //add
        [menu addItem:[self initializeMenuItem:@"No Inactive Devices" action:NULL]];
    }
    
    //add item separator
    [menu addItem:[NSMenuItem separatorItem]];
    
    //create/add menu item
    // ->'preferences'
    [menu addItem:[self initializeMenuItem:@"Preferences" action:@selector(preferences:)]];
    
    //add bottom separator
    [menu addItem:[NSMenuItem separatorItem]];
    
    //create/add menu item
    // ->'about'
    [menu addItem:[self initializeMenuItem:@"Quit" action:@selector(quit:)]];
    
    //tie menu to status item
    self.statusItem.menu = menu;
    
    }//pool
    
    return;
}

//init a menu item
-(NSMenuItem*)initializeMenuItem:(NSString*)title action:(SEL)action
{
    //menu item
    NSMenuItem* menuItem =  nil;
    
    //alloc menu item
    // ->toggle ('enable'/'disable')
    menuItem = [[NSMenuItem alloc] initWithTitle:title action:action keyEquivalent:@""];
    
    //enabled
    menuItem.enabled = YES;
    
    //self
    menuItem.target = self;
    
    return menuItem;
}

#pragma mark - Menu actions

//handler for 'quit'
// ->just exit the application
-(void)quit:(id)sender
{
    //xpc connection
    __block NSXPCConnection* xpcConnection = nil;
    
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, @"user clicked 'quit', so goodbye!");
    #endif
    
    //alloc XPC connection
    xpcConnection = [[NSXPCConnection alloc] initWithServiceName:@"com.objective-see.OverSightXPC"];
    
    //set remote object interface
    xpcConnection.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:@protocol(XPCProtocol)];
    
    //resume
    [xpcConnection resume];
    
    //tell XPC to exit
    [[xpcConnection remoteObjectProxy] exit];
    
    //give it a sec for XPC msg to go thru
    // ->don't wait on XPC since its killing itself!
    [NSThread sleepForTimeInterval:0.10f];
    
    //kill main (preference) app
    // ->might be open, and looks odd if its still present
    execTask(PKILL, @[[APP_NAME stringByDeletingPathExtension]], YES);
    
    //bye!
    [[NSApplication sharedApplication] terminate:nil];
    
    return;
}

//handler for 'preferences' menu item
// ->launch main application which will show prefs
-(void)preferences:(id)sender
{
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, @"launching main app (from /Applications)");
    #endif
    
    //launch main app
    [[NSWorkspace sharedWorkspace] launchApplication:[APPS_FOLDER stringByAppendingPathComponent:APP_NAME]];

//bail
bail:
    
    return;
}

@end
