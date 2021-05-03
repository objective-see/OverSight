//
//  file: HelperComms.h
//  project: OverSight (config)
//  description: interface to talk to blessed installer (header)
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

@import Foundation;

#import "XPCProtocol.h"

@interface HelperComms : NSObject

//remote deamon proxy object
@property(nonatomic, retain) id <XPCProtocol> daemon;

//xpc connection
@property (atomic, strong, readwrite) NSXPCConnection* xpcServiceConnection;

/* METHODS */

//uninstall
-(BOOL)uninstall:(NSString*)prefsDirectory;

//cleanup
// remove self
-(BOOL)cleanup;

@end
