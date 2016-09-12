//
//  AppDelegate.m
//  Test Application
//
//  Created by Patrick Wardle on 9/10/16.
//  Copyright (c) 2016 Objective-See. All rights reserved.
//

#import "AppDelegate.h"
#import <ServiceManagement/ServiceManagement.h>

@interface AppDelegate ()

@property (weak) IBOutlet NSWindow *window;
@end

//TODO: add uninstall?

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    // Insert code here to initialize your application
    
    self.loginButton.state = [[NSUserDefaults standardUserDefaults] boolForKey:@"LoginEnabled"];
    
}

- (void)applicationWillTerminate:(NSNotification *)aNotification
{
    // Insert code here to tear down your application
}

//automatically close when user closes window
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)theApplication
{
    return YES;
}

- (IBAction)loginButtonPressed:(NSButton *)sender
{
    if (!SMLoginItemSetEnabled((__bridge CFStringRef)@"com.objective-see.OverSightHelper", [sender state])) {
        NSLog(@"Login Item Was Not Successful");
    }
    
    [[NSUserDefaults standardUserDefaults] setBool:[sender state] forKey:@"LoginEnabled"];
}

@end
