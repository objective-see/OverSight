//
//  AboutWindowController.h
//  OverSight
//
//  Created by Patrick Wardle on 7/15/16.
//  Copyright (c) 2016 Objective-See. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class AVMonitor;

@interface RememberWindowController : NSWindowController <NSWindowDelegate>
{
    
}

/* PROPERTIES */

//process path
// ->used for whitelisting
@property (nonatomic, retain)NSString* processPath;

//device
// ->used for whitelisting
@property (nonatomic, retain)NSNumber* device;

//instance of av monitor
@property (nonatomic, retain)AVMonitor* avMonitor;

//version label/string
@property (weak) IBOutlet NSTextField *windowText;

/* METHODS */

//save stuff into iVars
// ->configure window w/ dynamic text
-(void)configure:(NSUserNotification*)notification avMonitor:(AVMonitor*)monitor;

@end
