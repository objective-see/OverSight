//
//  AppDelegate.m
//  Test Application Helper
//
//  Created by Patrick Wardle on 9/10/16.
//  Copyright (c) 2016 Objective-See. All rights reserved.
//

#import "Consts.h"
#import "Logging.h"
#import "Utilities.h"
#import "AppDelegate.h"


@interface AppDelegate ()

@property (weak) IBOutlet NSWindow *window;
@end

@implementation AppDelegate


@synthesize avMonitor;
@synthesize infoWindowController;
@synthesize statusBarMenuController;

//app's main interface
// ->load status bar and kick off monitor
-(void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    //default
    NSDictionary* preferences = nil;
    
    //dbg msg
    logMsg(LOG_DEBUG, @"starting login item");
    
    //init/load status bar
    [self loadStatusBar];
    
    //dbg msg
    logMsg(LOG_DEBUG, @"initialized/loaded status bar (icon/menu)");
    
    //first time, register defaults (manually cuz NSUserDefaults wasn't working - wtf)
    // ->note: do this in here, since main app (with prefs) isn't run until user manually launches it
    if(YES != [[NSFileManager defaultManager] fileExistsAtPath:[APP_PREFERENCES stringByExpandingTildeInPath]])
    {
        //dbg msg
        logMsg(LOG_DEBUG, @"preference file not found; manually creating");

        //write em out
        [@{PREF_LOG_ACTIVITY:@YES, PREF_CHECK_4_UPDATES:@YES} writeToFile:[APP_PREFERENCES stringByExpandingTildeInPath] atomically:NO];
    }
    
    //always (manually) load preferences
    preferences = [NSDictionary dictionaryWithContentsOfFile:[APP_PREFERENCES stringByExpandingTildeInPath]];
    
    //check for updates
    // ->but only when user has not disabled that feature
    if(YES == [preferences[PREF_CHECK_4_UPDATES] boolValue])
    {
        //after a minute
        //->check for updates in background
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 60 * NSEC_PER_SEC), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^
        {
           //dbg msg
           logMsg(LOG_DEBUG, @"checking for update");
           
           //check
           [self isThereAndUpdate];
        });
    }
    
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

//check for an update
-(void)isThereAndUpdate
{
    //version string
    NSMutableString* versionString = nil;
    
    //alloc string
    versionString = [NSMutableString string];
    
    //check if available version is newer
    // ->show update window
    if(YES == isNewVersion(versionString))
    {
        //new version!
        // ->show update popup on main thread
        dispatch_sync(dispatch_get_main_queue(), ^{
        
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"a new version (%@) is available", versionString]);
        
        //alloc/init about window
        infoWindowController = [[InfoWindowController alloc] initWithWindowNibName:@"InfoWindow"];
        
        //configure
        [self.infoWindowController configure:[NSString stringWithFormat:@"a new version (%@) is available!", versionString] buttonTitle:@"update"];
        
        //center window
        [[self.infoWindowController window] center];
        
        //show it
        [self.infoWindowController showWindow:self];
        
        //invoke function in background that will make window modal
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            
            //make modal
            makeModal(self.infoWindowController);
            
        });
            
        });
    }
    
    //no new version
    // ->just (debug) log msg
    else
    {
        //dbg msg
        logMsg(LOG_DEBUG, @"no updates available");
    }
    
    return;
}

@end
