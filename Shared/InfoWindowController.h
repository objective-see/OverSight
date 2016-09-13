//
//  PrefsWindowController.h
//  DHS
//
//  Created by Patrick Wardle on 2/6/15.
//  Copyright (c) 2015 Objective-See, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface InfoWindowController : NSWindowController <NSWindowDelegate>
{
    
}

/* PROPERTIES */

//version label/string
@property(weak)IBOutlet NSTextField *infoLabel;

//action button
@property(weak)IBOutlet NSButton *actionButton;

//label string
@property(nonatomic, retain)NSString* infoLabelString;

//first button ('update check')
@property(weak)IBOutlet NSView *firstButton;

//button title
@property(nonatomic, retain)NSString* actionButtonTitle;

//overlay view
@property(weak)IBOutlet NSView *overlayView;

//spinner
@property(weak)IBOutlet NSProgressIndicator *progressIndicator;

/* METHODS */

//save the main label's & button title's text
-(void)configure:(NSString*)label buttonTitle:(NSString*)buttonTitle;

//invoked when user clicks button
// ->trigger action such as opening product website, updating, etc
-(IBAction)buttonHandler:(id)sender;

@end
