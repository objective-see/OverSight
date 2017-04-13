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

@synthesize viewLogLabel;
@synthesize infoWindowController;
@synthesize aboutWindowController;
@synthesize rulesWindowController;

//center window
// ->also make front, init title bar, etc
-(void)awakeFromNib
{
    //center
    [self.window center];
    
    //set button states
    [self setButtonStates];
    
    //make it key window
    [self.window makeKeyAndOrderFront:self];
    
    //make window front
    [NSApp activateIgnoringOtherApps:YES];
    
    //set title
    self.window.title = [NSString stringWithFormat:@"OverSight Preferences (v. %@)", getAppVersion()];
    
    //make log link clickable
    makeTextViewHyperlink(self.viewLogLabel, [NSURL fileURLWithPath:logFilePath()]);
    
    return;
}

//app interface
// ->init user interface
-(void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    //preferences
    NSDictionary* preferences = nil;
    
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, @"OverSight Preferences App Launched");
    #endif
    
    //register for hotkey presses
    // ->for now, just cmd+q to quit app
    [self registerKeypressHandler];
    
    //create default prefs if there aren't any
    // ->should only happen if new user runs the app
    if(YES != [[NSFileManager defaultManager] fileExistsAtPath:[APP_PREFERENCES stringByExpandingTildeInPath]])
    {
        //dbg msg
        #ifdef DEBUG
        logMsg(LOG_DEBUG, @"preference file not found; manually creating");
        #endif
        
        //write em out
        // ->note; set 'start at login' to false, since no prefs here, mean installer wasn't run (user can later toggle)
        [@{PREF_LOG_ACTIVITY:@YES, PREF_START_AT_LOGIN:@NO, PREF_RUN_HEADLESS:@NO, PREF_DISABLE_INACTIVE:@NO, PREF_CHECK_4_UPDATES:@YES} writeToFile:[APP_PREFERENCES stringByExpandingTildeInPath] atomically:NO];
    }
    
    //load preferences
    preferences = [NSMutableDictionary dictionaryWithContentsOfFile:[APP_PREFERENCES stringByExpandingTildeInPath]];
    
    //when logging is enabled
    // ->open/create log file
    if(YES == [preferences[PREF_LOG_ACTIVITY] boolValue])
    {
        //init
        if(YES != initLogging())
        {
            //err msg
            logMsg(LOG_ERR, @"failed to init logging");
        }
    }
    
    //start login item in background
    // ->checks if already running though
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
    ^{
        //start
        // -> 'NO' means don't start if already running
        [self startLoginItem:NO args:nil];
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
    
    //set 'disable inactive' button state
    self.disableInactive.state = [preferences[PREF_DISABLE_INACTIVE] boolValue];
    
    //set 'automatically check for updates' button state
    self.check4Updates.state = [preferences[PREF_CHECK_4_UPDATES] boolValue];
    
    return;
}

//register handler for hot keys
// ->for now, it just handles cmd+q to quit
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
    
    //path to login item
    NSURL* loginItem = nil;
    
    //load preferences
    preferences = [NSMutableDictionary dictionaryWithContentsOfFile:[APP_PREFERENCES stringByExpandingTildeInPath]];
    
    //set 'log activity' button
    // ->also start/stop logging based on button state
    if(sender == self.logActivity)
    {
        //set
        preferences[PREF_LOG_ACTIVITY] = [NSNumber numberWithBool:[sender state]];
        
        //when logging is enabled
        // ->open/create log file
        if(YES == [preferences[PREF_LOG_ACTIVITY] boolValue])
        {
            //init
            if(YES != initLogging())
            {
                //err msg
                logMsg(LOG_ERR, @"failed to init logging");
            }
            //happy
            // ->log msg
            else
            {
                //log msg
                logMsg(LOG_DEBUG|LOG_TO_FILE, @"logging initialized");
            }
        }
        //when logging is disabled
        // ->close out the log file
        else
        {
            //log msg
            logMsg(LOG_DEBUG|LOG_TO_FILE, @"logging deinitialized");
            
            //close
            deinitLogging();
        }
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
        
        //init path to login item
        loginItem = [NSURL fileURLWithPath:[[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"/Contents/Library/LoginItems/OverSight Helper.app"]];
        
        //toggle
        toggleLoginItem(loginItem, (int)[sender state]);
    }
    
    //set 'run in headless mode'
    // ->then restart login item to realize this
    else if(sender == self.runHeadless)
    {
        //set
        preferences[PREF_RUN_HEADLESS] = [NSNumber numberWithBool:[sender state]];
        
        //save em now so new instance of login item can read them
        [preferences writeToFile:[APP_PREFERENCES stringByExpandingTildeInPath] atomically:YES];
        
        //restart login item in background
        // ->will read prefs, and run in headless mode
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
        ^{
            //start
            [self startLoginItem:YES args:nil];
        });
    }
    
    //set 'disable inactive alerts'
    else if(sender == self.disableInactive)
    {
        //set
        preferences[PREF_DISABLE_INACTIVE] = [NSNumber numberWithBool:[sender state]];
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
    
    //reset
    self.versionLabel.stringValue = @"";
    
    //re-draw
    [self.versionLabel displayIfNeeded];
    
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
    
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, @"checking for new version");
    #endif
    
    //check if available version is newer
    // ->show update popup/window
    if(YES == isNewVersion(versionString))
    {
        //dbg msg
        #ifdef DEBUG
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"a new version (%@) is available", versionString]);
        #endif
        
        //hide version message
        self.versionLabel.hidden = YES;
        
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
    // ->stop animations, etc
    else
    {
        //dbg msg
        #ifdef DEBUG
        logMsg(LOG_DEBUG, @"no updates available");
        #endif
        
        //stop/hide spinner
        [self.spinner stopAnimation:self];
        
        //re-enable button
        self.check4UpdatesNow.enabled = YES;
        
        //show now new version message
        self.versionLabel.hidden = NO;
        
        //set message
        self.versionLabel.stringValue = @"no new versions";
        
        //re-draw
        [self.versionLabel displayIfNeeded];
    }
    
    return;
}

//(re)start the login item
-(void)startLoginItem:(BOOL)shouldRestart args:(NSArray*)args
{
    //path to login item
    NSString* loginItem = nil;
    
    //login item's pid
    pid_t loginItemPID = -1;
    
    //error
    NSError* error = nil;
    
    //config (args, etc)
    // ->can't be nil, so init to blank here
    NSDictionary* configuration = @{};
    
    //get pid of login item for user
    loginItemPID = getProcessID(@"OverSight Helper", getuid());
    
    //no need to start if already running
    // ->well, and if 'shouldRestart' is not set
    if( (-1 != loginItemPID) &&
        (YES != shouldRestart) )
    {
        //dbg msg
        #ifdef DEBUG
        logMsg(LOG_DEBUG, @"login item already running and 'shouldRestart' not set, so no need to start it!");
        #endif
        
        //bail
        goto bail;
    }
    
    //running?
    // ->kill
    else if(-1 != loginItemPID)
    {
        //kill it
        kill(loginItemPID, SIGTERM);
        
        //sleep
        [NSThread sleepForTimeInterval:1.0f];
        
        //really kill
        kill(loginItemPID, SIGKILL);
    }
    
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, @"starting login item");
    #endif
    
    //add overlay
    [self addOverlay:shouldRestart];
    
    //init path to login item
    loginItem = [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"/Contents/Library/LoginItems/OverSight Helper.app"];
    
    //any args?
    // ->init config with them args
    if(nil != args)
    {
        //add args
        configuration = @{NSWorkspaceLaunchConfigurationArguments:args};
    }
    
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"starting login item with: %@/%@", configuration, args]);
    #endif
    
    //launch it
    [[NSWorkspace sharedWorkspace] launchApplicationAtURL:[NSURL fileURLWithPath:loginItem] options:NSWorkspaceLaunchWithoutActivation configuration:configuration error:&error];
    
    //remove overlay
    [self removeOverlay];
    
    //check if login launch was ok
    // ->do down here, since always want to remove overlay
    if(nil != error)
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to start login item, %@/%@", loginItem, error]);
        
        //bail
        goto bail;
    }
    
    
//bail
bail:

    return;
}

//add overlay to main window
-(void)addOverlay:(BOOL)restarting
{
    //show overlay view on main thread
    dispatch_async(dispatch_get_main_queue(), ^{
        
        //frame
        NSRect frame = {0};
        
        //pre-req
        [self.overlay setWantsLayer:YES];
        
        //get main window's frame
        frame = self.window.contentView.frame;
       
        //set origin to 0/0
        frame.origin = CGPointZero;
        
        //tweak since window is rounded
        // ->and adding this view doesn't get rounded?
        frame.origin.y += 1;
        frame.origin.x += 1;
        frame.size.width -= 2;
        
        //update overlay to take up entire window
        self.overlay.frame = frame;
        
        //set overlay's view color to white
        self.overlay.layer.backgroundColor = [NSColor whiteColor].CGColor;
        
        //make it semi-transparent
        self.overlay.alphaValue = 0.85;
        
        //set start message
        if(YES != restarting)
        {
            //set
            self.statusMessage.stringValue = @"starting monitor...";
        }
        //set restart message
        else
        {
            //set
            self.statusMessage.stringValue = @"(re)starting monitor...";
        }
        
        //show message
        self.statusMessage.hidden = NO;
        
        //show spinner
        self.progressIndicator.hidden = NO;
        
        //animate it
        [self.progressIndicator startAnimation:nil];
        
        //add to main window
        [self.window.contentView addSubview:self.overlay];
        
        //show
        self.overlay.hidden = NO;
        
    });
    
    return;
}

//remove overlay from main window
-(void)removeOverlay
{
    //sleep to give message more viewing time
    [NSThread sleepForTimeInterval:2];
    
    //remove overlay view on main thread
    dispatch_async(dispatch_get_main_queue(), ^{
        
        //hide spinner
        self.progressIndicator.hidden = YES;
        
        //hide view
        self.overlay.hidden = YES;
        
        //hide message
        self.statusMessage.hidden = YES;
        
        //remove
        [self.overlay removeFromSuperview];
        
    });
    
    return;
}

-(IBAction)showLog:(id)sender
{
    return;
}


//button handle when user clicks 'Manage Rules'
// ->just shwo the rules window
-(IBAction)manageRules:(id)sender
{
    //alloc
    rulesWindowController = [[RulesWindowController alloc] initWithWindowNibName:@"Rules"];

    //center window
    [[self.rulesWindowController window] center];
    
    //show it
    [self.rulesWindowController showWindow:self];
    
    return;
}

-(NSAttributedString *)stringFromHTML:(NSString *)html withFont:(NSFont *)font
{
    if (!font) font = [NSFont systemFontOfSize:0.0];  // Default font
    html = [NSString stringWithFormat:@"<span style=\"font-family:'%@'; font-size:%dpx;\">%@</span>", [font fontName], (int)[font pointSize], html];
    NSData *data = [html dataUsingEncoding:NSUTF8StringEncoding];
    NSAttributedString* string = [[NSAttributedString alloc] initWithHTML:data documentAttributes:nil];
    return string;
}


@end
