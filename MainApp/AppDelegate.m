//
//  AppDelegate.m
//  Test Application
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

@synthesize infoWindowController;
@synthesize aboutWindowController;

//center window
// ->also make front, init title bar, etc
-(void)awakeFromNib
{
    //center
    [self.window center];
    
    //make it key window
    [self.window makeKeyAndOrderFront:self];
    
    //make window front
    [NSApp activateIgnoringOtherApps:YES];
    
    //set title
    self.window.title = [NSString stringWithFormat:@"OverSight Preferences (v. %@)", getAppVersion()];
    
    return;
}

//app interface
// ->init user interface
-(void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    //set button states
    [self setButtonStates];
    
    //register for hotkey presses
    // ->for now, just cmd+q to quit app
    [self registerKeypressHandler];
    
    //start login item in background
    // ->checks if already running though
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
    ^{
        //start
        [self startLoginItem:NO];
    });
    
    
    
    return;
}

//automatically close when user closes window
-(BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)theApplication
{
    return YES;
}

//set button states from preferences
-(void)setButtonStates
{
    //preferences
    NSDictionary* preferences = nil;
    
    //load preferences
    preferences = [NSDictionary dictionaryWithContentsOfFile:[APP_PREFERENCES stringByExpandingTildeInPath]];
    
    //set 'log activity' button state
    self.logActivity.state = [preferences[PREF_LOG_ACTIVITY] boolValue];
    
    //set 'start at login' button state
    self.startAtLogin.state = [preferences[PREF_START_AT_LOGIN] boolValue];
    
    //set 'run headless' button state
    self.runHeadless.state = [preferences[PREF_RUN_HEADLESS] boolValue];
    
    //set 'automatically check for updates' button state
    self.check4Updates.state = [preferences[PREF_CHECK_4_UPDATES] boolValue];
    
    return;
}

//register handler for hot keys
-(void)registerKeypressHandler
{
    //event handler
    NSEvent* (^keypressHandler)(NSEvent *) = nil;
    
    //init handler block
    // ->just call helper function
    keypressHandler = ^NSEvent * (NSEvent * theEvent){
        
        //invoke helper
        return [self handleKeypress:theEvent];
    };
    
    //register for key-down events
    [NSEvent addLocalMonitorForEventsMatchingMask:NSKeyDownMask handler:keypressHandler];
    
    return;
}


//helper function for keypresses
// ->for now, only handle cmd+q, to quit
-(NSEvent*)handleKeypress:(NSEvent*)event
{
    //flag indicating event was handled
    BOOL wasHandled = NO;
    
    //only care about 'cmd' + something
    if(NSCommandKeyMask != (event.modifierFlags & NSCommandKeyMask))
    {
        //bail
        goto bail;
    }
    
    //handle key-code
    // command+q: quite
    switch ([event keyCode])
    {
        //'q' (quit)
        case KEYCODE_Q:
            
            //bye!
            [[NSApplication sharedApplication] terminate:nil];
            
            //set flag
            wasHandled = YES;
            
            break;
        
        //default
        // ->do nothing
        default:
            
            break;
    }
    
//bail
bail:
    
    //nil out event if it was handled
    if(YES == wasHandled)
    {
        //nil
        event = nil;
    }
    
    return event;

}

//toggle/set preferences
-(IBAction)togglePreference:(NSButton *)sender
{
    //preferences
    NSMutableDictionary* preferences = nil;
    
    //load preferences
    preferences = [NSMutableDictionary dictionaryWithContentsOfFile:[APP_PREFERENCES stringByExpandingTildeInPath]];
    
    //set 'log activity' button
    if(sender == self.logActivity)
    {
        //set
        preferences[PREF_LOG_ACTIVITY] = [NSNumber numberWithBool:[sender state]];
    }
    
    //set 'automatically check for updates'
    else if(sender == self.check4Updates)
    {
        //set
        preferences[PREF_CHECK_4_UPDATES] = [NSNumber numberWithBool:[sender state]];
        
    }
    
    //set 'start at login'
    // ->then also toggle for current user
    else if(sender == self.startAtLogin)
    {
        //set
        preferences[PREF_START_AT_LOGIN] = [NSNumber numberWithBool:[sender state]];
        
        //toggle
        
    }
    
    //set 'run in headless mode'
    // ->then restart login item to realize this
    else if(sender == self.runHeadless)
    {
        //set
        preferences[PREF_RUN_HEADLESS] = [NSNumber numberWithBool:[sender state]];
        
        //restart login item in background
        // ->will read prefs, and run in headless mode
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
        ^{
            //start
            [self startLoginItem:YES];
        });
    }
    
    //save em
    [preferences writeToFile:[APP_PREFERENCES stringByExpandingTildeInPath] atomically:YES];
    
    return;
}

//'about' button/menu handler
-(IBAction)about:(id)sender
{
    //alloc/init settings window
    if(nil == self.aboutWindowController)
    {
        //alloc/init
        aboutWindowController = [[AboutWindowController alloc] initWithWindowNibName:@"AboutWindow"];
    }
    
    //center window
    [[self.aboutWindowController window] center];
    
    //show it
    [self.aboutWindowController showWindow:self];
    
    //invoke function in background that will make window modal
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        //make modal
        makeModal(self.aboutWindowController);
        
    });
    
    return;
}

//'check for update' (now) button handler
-(IBAction)check4Update:(id)sender
{
    //disable button
    self.check4UpdatesNow.enabled = NO;
    
    //hide version msg
    self.versionLabel.hidden = YES;
    
    //show spinner
    [self.spinner startAnimation:self];
    
    //check for update
    [self isThereAnUpdate];
    
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
        
        //stop/hide spinner
        [self.spinner stopAnimation:self];
        
        //re-enable button
        self.check4UpdatesNow.enabled = YES;
    }
    
    //no new version
    // ->just (debug) log msg
    else
    {
        //dbg msg
        logMsg(LOG_DEBUG, @"no updates available");
        
        //stop/hide spinner
        [self.spinner stopAnimation:self];
        
        //re-enable button
        self.check4UpdatesNow.enabled = YES;
        
        //show now new version message
        self.versionLabel.hidden = NO;
    }
    
    return;
}

//start the login item
-(void)startLoginItem:(BOOL)shouldRestart
{
    //path to login item
    NSString* loginItem = nil;
    
    //login item's pid
    pid_t loginItemPID = -1;
    
    //get pid of login item
    loginItemPID = getProcessID(@"OverSight Helper", getuid());
    
    //already running?
    // ->kill the login item
    if( (YES == shouldRestart) &&
        (-1 != loginItemPID) )
    {
        //kill
        kill(loginItemPID, SIGTERM);
        
        //sleep
        sleep(2);
        
        //really kill
        kill(loginItemPID, SIGKILL);
        
        //reset pid
        loginItemPID = -1;
    }
    
    //start not already running
    if(-1 == loginItemPID)
    {
        //dbg msg
        logMsg(LOG_DEBUG, @"starting login item");
        
        //show overlay view on main thread
        dispatch_sync(dispatch_get_main_queue(), ^{
        
            //pre-req
            [self.overlay setWantsLayer:YES];
            
            //set overlay's view color to black
            self.overlay.layer.backgroundColor = [NSColor whiteColor].CGColor;
            
            //make it semi-transparent
            self.overlay.alphaValue = 0.85;
            
            //show it
            self.overlay.hidden = NO;
            
            //TODO:
            //set message
            
            //show spinner
            self.progressIndicator.hidden = NO;
            
            //animate it
            [self.progressIndicator startAnimation:nil];
            
        });
    }
                      
    
    //init path
    loginItem = [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"/Contents/Library/LoginItems/OverSight Helper.app"];
    
    //launch it
    if(YES != [[NSWorkspace sharedWorkspace] launchApplication:loginItem])
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to start login item, %@", loginItem]);
        
        //bail
        goto bail;
    }
    
    //(re)obtain focus for app
    [[NSRunningApplication currentApplication] activateWithOptions:NSApplicationActivateIgnoringOtherApps];
    
    //TODO:
    //hide overlay
    
//bail
bail:
    
    return;
}


//manage rules
-(IBAction)manageRules:(id)sender
{
    return;
}


@end
