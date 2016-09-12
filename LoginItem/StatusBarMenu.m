//
//  StatusBarMenu.m
//  OverSight
//
//  Created by Patrick Wardle on 1/4/15.
//  Copyright (c) 2015 Objective-See. All rights reserved.
//


#import "Logging.h"
#import "AppDelegate.h"
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
    //dbg msg
    logMsg(LOG_DEBUG, @"user clicked 'exit', so goodbye!");
    
    //exit
    [[NSApplication sharedApplication] terminate:nil];
    
    return;
}

//handler for 'preferences' menu item
// ->launch main application which will show prefs
-(void)preferences:(id)sender
{
    
    //this works when packaged into Login Item into top-level app
    NSArray *pathComponents = [[[NSBundle mainBundle] bundlePath] pathComponents];
    pathComponents = [pathComponents subarrayWithRange:NSMakeRange(0, [pathComponents count] - 4)];
    NSString *path = [NSString pathWithComponents:pathComponents];
    [[NSWorkspace sharedWorkspace] launchApplication:path];
    
    
    
    /*
    //controller for preferences window
    PrefsWindowController* prefsWindowController = nil;
    
    //dbg msg
    logMsg(LOG_DEBUG, @"displaying preferences window");
    
    //grab controller
    prefsWindowController = ((AppDelegate*)[[NSApplication sharedApplication] delegate]).prefsWindowController;
    
    //show pref window
    [prefsWindowController showWindow:sender];
    
    //invoke function in background that will make window modal
    // ->waits until window is non-nil
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        //make modal
        makeModal(prefsWindowController);
        
    });
     
    */
    
    return;
}

//menu handler that's automatically invoked when user clicks 'about'
// ->load objective-see's documentation for BlockBlock
-(void)about:(id)sender
{
    /*
    
    //alloc/init about window
    infoWindowController = [[InfoWindowController alloc] initWithWindowNibName:@"InfoWindow"];
    
    //configure label and button
    [self.infoWindowController configure:[NSString stringWithFormat:@"version: %@", getAppVersion()] buttonTitle:@"more info"];
    
    //center window
    [[self.infoWindowController window] center];
    
    //show it
    [self.infoWindowController showWindow:self];
     
    */
    
    return;
}

@end