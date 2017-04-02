//
//  ConfigureWindowController.h
//  OverSight
//
//  Created by Patrick Wardle on 9/01/16.
//  Copyright (c) 2016 Objective-See. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface ConfigureWindowController : NSWindowController <NSWindowDelegate>
{
    
}

/* PROPERTIES */

@property (weak) IBOutlet NSProgressIndicator *activityIndicator;
@property (weak) IBOutlet NSTextField *statusMsg;
@property (weak) IBOutlet NSButton *installButton;
@property (weak) IBOutlet NSButton *uninstallButton;
@property (weak) IBOutlet NSButton *moreInfoButton;
@property (weak) IBOutlet NSButton *supportButton;
@property (strong) IBOutlet NSView *supportView;





/* METHODS */

//install/uninstall button handler
-(IBAction)buttonHandler:(id)sender;

//(more) info button handler
-(IBAction)info:(id)sender;

//configure window/buttons
// ->also brings to front
-(void)configure:(BOOL)isInstalled;

//display (show) window
-(void)display;

@end
