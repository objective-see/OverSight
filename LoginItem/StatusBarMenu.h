//
//  StatusBarMenu.h
//  OverSight
//
//  Created by Patrick Wardle on 1/4/15.
//  Copyright (c) 2015 Objective-See. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface StatusBarMenu : NSObject
{

}

//status item
@property (nonatomic, strong, readwrite) NSStatusItem *statusItem;

//popover
@property (retain, nonatomic)NSPopover *popover;

//enabled flag
@property BOOL isEnabled;

/* METHODS */

//setup status item
// ->init button, show popover, etc
-(void)setupStatusItem;

//create/update status item menu
-(void)updateStatusItemMenu:(NSArray*)devices;

//init a menu item
-(NSMenuItem*)initializeMenuItem:(NSString*)title action:(SEL)action;

//menu handler for 'enable'/'disable'
// ->toggle blockblock & update menu
//-(void)toggle:(id)sender;

//menu handler for 'uninstall'
// ->kick off uninstall
//-(void)uninstall:(id)sender;

//menu handler for 'perferences'
// ->show preferences window
-(void)preferences:(id)sender;

@end
