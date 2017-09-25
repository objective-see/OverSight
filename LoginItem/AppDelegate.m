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
#import "XPCProtocol.h"

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
    
    //logged in user info
    NSMutableDictionary* userInfo = nil;
    
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, @"starting login item app logic");
    #endif
    
    //get user
    userInfo = loggedinUser();
    if(nil == userInfo[@"user"])
    {
        //err msg
        logMsg(LOG_ERR, @"failed to determine logged-in user");
        
        //bail
        goto bail;
    }
    
    //drop group privs
    setgid([userInfo[@"gid"] intValue]);
    
    //drop user privs
    setuid([userInfo[@"uid"] intValue]);

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
        logMsg(LOG_DEBUG|LOG_TO_FILE, @"logging intialized (login item)");
    }
    
    //spawn 'heartbeat' thread to XPC to keep it open
    [NSThread detachNewThreadSelector:@selector(heartBeat) toTarget:self withObject:nil];
    
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

//ping XPC service to keep it alive
-(void)heartBeat
{
    //pool
    @autoreleasepool {
    
    //xpc connection
    __block NSXPCConnection* xpcConnection = nil;
    
    //wait semaphore
    dispatch_semaphore_t waitSema = nil;
    
    //alloc XPC connection
    xpcConnection = [[NSXPCConnection alloc] initWithServiceName:@"com.objective-see.OverSightXPC"];
    
    //set remote object interface
    xpcConnection.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:@protocol(XPCProtocol)];
    
    //resume
    [xpcConnection resume];

    //forever
    while(YES)
    {
        //init wait semaphore
        waitSema = dispatch_semaphore_create(0);
        
        #ifdef DEBUG
        //dbg msg
        logMsg(LOG_DEBUG, @"sending XPC heart beat request");
        #endif
        
        //XPC service to begin baselining mach messages
        // ->wait, since want this to compelete before doing other things!
        [[xpcConnection remoteObjectProxy] heartBeat:^(BOOL reply)
         {
             //signal sema
             dispatch_semaphore_signal(waitSema);
             
         }];
        
        //wait until XPC is done
        // ->XPC reply block will signal semaphore
        dispatch_semaphore_wait(waitSema, DISPATCH_TIME_FOREVER);
        
        //nap
        [NSThread sleepForTimeInterval:3.0f];
    }
    
    }//pool
    
    return;
}

//going bye-bye
// ->close logging
-(void)applicationWillTerminate:(NSNotification *)notification
{
    //log msg
    logMsg(LOG_DEBUG|LOG_TO_FILE, @"OverSight ending");
    
    //log msg
    logMsg(LOG_DEBUG|LOG_TO_FILE, @"logging deinitialized (login item)");
    
    //stop logz
    deinitLogging();
    
    return;
}

@end
