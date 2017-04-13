//
//  AppDelegate.m
//  Login Item, (app helper)
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
    //preferences
    NSDictionary* preferences = nil;
    
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, @"starting login item app logic");
    #endif
    
    //drop group privs
    setgid(getgid());
    
    //drop user privs
    setuid(getuid());

    //load preferences
    preferences = [NSDictionary dictionaryWithContentsOfFile:[APP_PREFERENCES stringByExpandingTildeInPath]];
    
    //init/load status bar
    // ->but only if user didn't say: 'run in headless mode'
    if(YES != [preferences[PREF_RUN_HEADLESS] boolValue])
    {
        //load
        [self loadStatusBar];
        
        //dbg msg
        #ifdef DEBUG
        logMsg(LOG_DEBUG, @"initialized/loaded status bar (icon/menu)");
        #endif
    }
    #ifdef DEBUG
    //dbg msg
    else
    {
        //dbg msg
        logMsg(LOG_DEBUG, @"running in headless mode");
    }
    #endif
    
    //check for updates
    // ->but only when user has not disabled that feature
    if(YES == [preferences[PREF_CHECK_4_UPDATES] boolValue])
    {
        //after a minute
        //->check for updates in background
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 60 * NSEC_PER_SEC), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^
        {
            //dbg msg
            #ifdef DEBUG
            logMsg(LOG_DEBUG, @"checking for update");
            #endif
           
            //check
            [self isThereAnUpdate];
            
        });
    }
    
    //when logging is enabled
    // ->open/create log file
    if(YES == [preferences[PREF_LOG_ACTIVITY] boolValue])
    {
        //init
        if(YES != initLogging())
        {
            //err msg
            logMsg(LOG_ERR, @"failed to init logging");
            
            //bail
            goto bail;
        }
        
        //dbg msg
        // ->and to file
        logMsg(LOG_DEBUG|LOG_TO_FILE, @"logging intialized");
        
    }

    //create/init av event monitor
    avMonitor = [[AVMonitor alloc] init];
    
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, @"alloc/init'd AV monitor");
    #endif
    
    //start monitoring
    // ->sets up audio/video callbacks
    [avMonitor monitor];
    
    //log msg
    logMsg(LOG_DEBUG|LOG_TO_FILE, @"OverSight starting");
    
//bail
bail:
    
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
-(void)isThereAnUpdate
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
        #ifdef DEBUG
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"a new version (%@) is available", versionString]);
        #endif
        
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
    #ifdef DEBUG
    else
    {
        //dbg msg
        logMsg(LOG_DEBUG, @"no updates available");
    }
    #endif
    
    return;
}

//going bye-bye
// ->close logging
-(void)applicationWillTerminate:(NSNotification *)notification
{
    //log msg
    logMsg(LOG_DEBUG|LOG_TO_FILE, @"OverSight ending");
    
    //log msg
    logMsg(LOG_DEBUG|LOG_TO_FILE, @"logging deinitialized");
    
    //stop logz
    deinitLogging();
    
    return;
}

@end
