//
//  file: StatusBarMenu.m
//  project: OverSight (login item)
//  description: menu handler for status bar icon
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

#import "consts.h"
#import "utilities.h"
#import "AppDelegate.h"
#import "StatusBarItem.h"
#import "StatusBarPopoverController.h"

/* GLOBALS */

//log handle
extern os_log_t logHandle;

//menu items
enum menuItems
{
    status = 100,
    devices,
    toggle,
    prefs,
    rules,
    quit,
    uninstall,
    end
};

//tag for active device
#define TAG_ACTIVE_DEVICE 1000

@implementation StatusBarItem

@synthesize isDisabled;
@synthesize statusItem;

//init method
// set some intial flags
-(id)init:(NSMenu*)menu
{
    //token
    static dispatch_once_t onceToken = 0;
    
    //super
    self = [super init];
    if(self != nil)
    {
        //create item
        [self createStatusItem:menu];
        
        //only once
        // show popover
        dispatch_once(&onceToken, ^{
            
            //first time?
            // show popover
            if(YES == [NSProcessInfo.processInfo.arguments containsObject:INITIAL_LAUNCH])
            {
                //dbg msg
                os_log_debug(logHandle, "initial launch, will show popover");
                
                //show
                [self showPopover];
            }
            
        });
        
        //set state based on (existing) preferences
        self.isDisabled = [NSUserDefaults.standardUserDefaults boolForKey:PREF_IS_DISABLED];
        
        //set initial menu state
        [self setState];
    }
    
    return self;
}

//create status item
-(void)createStatusItem:(NSMenu*)menu
{
    //init status item
    statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSSquareStatusItemLength];
    
    //set menu
    self.statusItem.menu = menu;
    
    //set delegate
    self.statusItem.menu.delegate = self;
    
    //set action handler for all menu items
    for(int i=toggle; i<end; i++)
    {
        //set action
        [self.statusItem.menu itemWithTag:i].action = @selector(handler:);
        
        //set state
        [self.statusItem.menu itemWithTag:i].enabled = YES;
        
        //set target
        [self.statusItem.menu itemWithTag:i].target = self;
    }
    
    return;
}

//update status item menu
-(void)setActiveDevices:(NSArray*)activeDevices
{
    //active menu item
    NSMenuItem* activeDeviceMenuItem = nil;
    
    //start index
    NSInteger menuIndex = -1;
    
    //string for device name/emoji
    NSMutableString* deviceDetails = nil;
    
    //get menu item
    activeDeviceMenuItem = [self.statusItem.menu itemWithTag:devices];
    
    //get menu item index start
    menuIndex = [self.statusItem.menu indexOfItemWithTag:devices];
    
    //iterate over menu
    // remove all (prev) active devices
    for(NSInteger i = self.statusItem.menu.itemArray.count-1; i>= 0; --i)
    {
        //remove active devices
        if(TAG_ACTIVE_DEVICE == [[self.statusItem.menu itemAtIndex:i] tag])
        {
            //remove
            [self.statusItem.menu removeItemAtIndex:i];
        }
    }
    
    //no active devices?
    // set title and then bail
    if(0 == activeDevices.count)
    {
        //set title
        activeDeviceMenuItem.title = NSLocalizedString(@"No Active Devices", @"No Active Devices");
        
        //gone
        goto bail;
    }
    
    //set title
    activeDeviceMenuItem.title = NSLocalizedString(@"Active Devices:", @"Active Devices:");
    
    //inc
    menuIndex++;
    
    //add each
    for(AVCaptureDevice* activeDevice in activeDevices)
    {
        //menu item
        NSMenuItem* item = nil;
        
        //init string for name/etc
        deviceDetails = [NSMutableString string];
        
        //mic?
        if(YES == [activeDevice isKindOfClass:NSClassFromString(@"AVCaptureHALDevice")])
        {
            //add
            [deviceDetails appendString:@"  🎙️ "];
        }
        //camera
        else
        {
            //add
            [deviceDetails appendString:@"  📸 "];
        }

        //add name
        [deviceDetails appendString:activeDevice.localizedName];
        
        //init item
        item = [[NSMenuItem alloc] initWithTitle:deviceDetails action:nil keyEquivalent:@""];
        
        //set tag
        item.tag = TAG_ACTIVE_DEVICE;
        
        //add item to menu
        [self.statusItem.menu insertItem:item atIndex:menuIndex];
        
        //inc
        menuIndex++;
    }
    
bail:
    
    return;
}

//remove status item
-(void)removeStatusItem
{
    //remove item
    [[NSStatusBar systemStatusBar] removeStatusItem:self.statusItem];
    
    //unset
    self.statusItem = nil;
    
    return;
}

//show popver
-(void)showPopover
{
    //alloc popover
    self.popover = [[NSPopover alloc] init];
    
    //don't want highlight for popover
    self.statusItem.button.cell.highlighted = NO;
    
    //set target
    self.statusItem.button.target = self;
    
    //set view controller
    self.popover.contentViewController = [[StatusBarPopoverController alloc] initWithNibName:@"StatusBarPopover" bundle:nil];
    
    //set behavior
    // don't want it close before timeout (unless user clicks '^')
    self.popover.behavior = NSPopoverBehaviorApplicationDefined;
    
    //set delegate
    self.popover.delegate = self;
    
    //show popover
    // have to wait cuz...
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.5 * NSEC_PER_SEC), dispatch_get_main_queue(),
    ^{
       //show
       [self.popover showRelativeToRect:self.statusItem.button.bounds ofView:self.statusItem.button preferredEdge:NSMinYEdge];
    });
    
    //wait a bit
    // then automatically hide popup if user has not closed it
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3.5 * NSEC_PER_SEC), dispatch_get_main_queue(),
    ^{
        //still visible?
        // close it then...
        if(YES == self.popover.shown)
        {
            //close
            [self.popover performClose:nil];
        }
            
        //remove action handler
        self.statusItem.button.action = nil;
        
        //reset highlight mode
        ((NSButtonCell*)self.statusItem.button.cell).highlightsBy = NSContentsCellMask | NSChangeBackgroundCellMask;
    });
    
    return;
}

//cleanup popover
-(void)popoverDidClose:(NSNotification *)notification
{
    //unset
    self.popover = nil;
    
    //reset highlight mode
    ((NSButtonCell*)self.statusItem.button.cell).highlightsBy = NSContentsCellMask | NSChangeBackgroundCellMask;
    
    return;
}

//menu handler
-(void)handler:(id)sender
{
    //dbg msg
    os_log_debug(logHandle, "user clicked status menu item %lu", ((NSMenuItem*)sender).tag);
    
    //handle user selection
    switch(((NSMenuItem*)sender).tag)
    {
        //toggle
        case toggle:
        
            //dbg msg
            os_log_debug(logHandle, "toggling (%d)", self.isDisabled);
        
            //invert since toggling
            self.isDisabled = !self.isDisabled;
        
            //set menu state
            [self setState];
        
            //set & sync
            [NSUserDefaults.standardUserDefaults setBool:self.isDisabled forKey:PREF_IS_DISABLED];
            [NSUserDefaults.standardUserDefaults synchronize];
            
            //stop monitor
            if(YES == self.isDisabled)
            {
                //dbg msg
                os_log_debug(logHandle, "will stop monitor");
                
                //stop
                [((AppDelegate*)[[NSApplication sharedApplication] delegate]).avMonitor stop];
            }
            //(re)start monitor
            else
            {
                //dbg msg
                os_log_debug(logHandle, "will (re)start monitor");
                
                //start
                [((AppDelegate*)[[NSApplication sharedApplication] delegate]).avMonitor start];
            }
        
            break;
            
        //rules
        case rules:
            
            //show rules
            [((AppDelegate*)[[NSApplication sharedApplication] delegate]) showRules:nil];
            
            break;
            
        //prefs
        case prefs:
            
            //show prefs
            [((AppDelegate*)[[NSApplication sharedApplication] delegate]) showPreferences:nil];
            
            break;
            
        //quit
        case quit:
            
            //dbg msg
            os_log_debug(logHandle, "quitting...");
            
            //exit
            [NSApp terminate:self];
            
            break;
            
        //uninstall
        case uninstall:
        {
            //uninstaller path
            NSURL* uninstaller = nil;
            
            //config options
            NSWorkspaceOpenConfiguration* configuration = nil;
            
            //init path to uninstaller
            uninstaller = [NSBundle.mainBundle URLForResource:@"OverSight Installer" withExtension:@".app"];
            if(nil == uninstaller)
            {
                //err msg
                os_log_debug(logHandle, "failed to find uninstaller");
                
                //bail
                goto bail;
            }
            
            //init configuration
            configuration = [[NSWorkspaceOpenConfiguration alloc] init];
            
            //set args
            configuration.arguments = @[CMD_UNINSTALL_VIA_UI];
        
            //dbg msg
            os_log_debug(logHandle, "launching uninstaller %{public}@", uninstaller);
            
            @try
            {
                
            //launch (in)/(un)installer
            [NSWorkspace.sharedWorkspace openApplicationAtURL:uninstaller configuration:configuration completionHandler:^(NSRunningApplication * _Nullable app, NSError * _Nullable error) {
                
                //dbg msg
                os_log_debug(logHandle, "launched uninstaller: %{public}@ (error: %{public}@)", app, error);
                
            }];
                
            }
            @catch(NSException *exception)
            {
                //err msg
                os_log_debug(logHandle, "failed to launch task (%{public}@)", exception);
                
                //bail
                goto bail;
            }
            
            break;
        }
            
        default:
            
            break;
    }
    
bail:
    
    return;
}

//set menu status
// logic based on 'isEnabled' iVar
-(void)setState
{
    //dbg msg
    os_log_debug(logHandle, "setting state to: %@", (self.isDisabled) ? @"disabled" : @"enabled");
    
    //set to disabled
    if(YES == self.isDisabled)
    {
        //update status
        [self.statusItem.menu itemWithTag:status].title = [NSString stringWithFormat:NSLocalizedString(@"%@: disabled", @"%@: disabled"), PRODUCT_NAME];
        
        //set icon
        self.statusItem.button.image = [NSImage imageNamed:@"StatusInactive"];
        self.statusItem.button.image.template = YES;
        
        //change toggle text
        [self.statusItem.menu itemWithTag:toggle].title = NSLocalizedString(@"Enable", @"Enable");
    }
    
    //set to enabled
    else
    {
        //update status
        [self.statusItem.menu itemWithTag:status].title = [NSString stringWithFormat:NSLocalizedString(@"%@: enabled", @"%@: enabled"), PRODUCT_NAME];
        
        //set icon
        self.statusItem.button.image = [NSImage imageNamed:@"StatusActive"];
        self.statusItem.button.image.template = YES;
        
        //change toggle text
        [self.statusItem.menu itemWithTag:toggle].title = NSLocalizedString(@"Disable", @"Disable");
    }
    
    return;
}

//menu delegate method
// menu will open: update active devices
-(void)menuWillOpen:(NSMenu *)menu
{
    //av monitor
    AVMonitor* avMonitor = nil;
    
    //status bar item controller
    StatusBarItem* statusBarItemController = nil;
    
    //first
    // sure to close popover
    if(YES == self.popover.shown)
    {
        //close
        [self.popover performClose:nil];
    }

    //grab
    avMonitor = ((AppDelegate*)[[NSApplication sharedApplication] delegate]).avMonitor;
    
    //grab
    statusBarItemController = ((AppDelegate*)[[NSApplication sharedApplication] delegate]).statusBarItemController;
    
    //enumerate and update
    [statusBarItemController setActiveDevices:[avMonitor enumerateActiveDevices]];
    
    return;
}

@end
