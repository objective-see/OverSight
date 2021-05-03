//
//  file: Configure.h
//  project: OverSight (config)
//  description: install/uninstall logic (header)
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

#import "HelperComms.h"
#import <Foundation/Foundation.h>

@interface Configure : NSObject
{
    
}

/* PROPERTIES */

//helper installed & connected
@property(nonatomic) BOOL gotHelp;

//daemom comms object
@property(nonatomic, retain) HelperComms* xpcComms;

/* METHODS */

//determine if installed
-(BOOL)isInstalled;

//old version installed?
-(BOOL)isV1Installed;

//invokes appropriate install || uninstall logic
-(BOOL)configure:(NSInteger)parameter;

//install
-(BOOL)install;

//uninstall
-(BOOL)uninstall:(BOOL)full;

//remove helper (daemon)
-(BOOL)removeHelper;

@end

