//
//  AppDelegate.m
//  Test Application Helper
//
//  Created by Patrick Wardle on 9/10/16.
//  Copyright (c) 2016 Objective-See. All rights reserved.
//


#import "Logging.h"
#import "AppDelegate.h"


@interface AppDelegate ()

@property (weak) IBOutlet NSWindow *window;
@end

@implementation AppDelegate


@synthesize monitor;
@synthesize avMonitor;
@synthesize statusBarMenuController;


//app's main interface
// ->load status bar and kick off monitor
-(void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    //dbg msg
    logMsg(LOG_DEBUG, @"starting login item");
    
    //init/load status bar
    [self loadStatusBar];
    
    //dbg msg
    logMsg(LOG_DEBUG, @"initialized/loaded status bar (icon/menu)");
    
    //create/init av event monitor
    avMonitor = [[AVMonitor alloc] init];
    
    //dbg msg
    logMsg(LOG_DEBUG, @"alloc/init'd AV monitor");
    
    //start monitoring
    // ->sets up audio/video callbacks
    [avMonitor monitor];
    
    //dbg msg
    logMsg(LOG_DEBUG, @"AV monitor off and running");
    
    return;
}

//initialize status menu bar
-(void)loadStatusBar
{
    //alloc/load nib
    statusBarMenuController = [[StatusBarMenu alloc] init];
    
    //init menu
    [self.statusBarMenuController setupStatusItem];
    
    return;
}

@end
