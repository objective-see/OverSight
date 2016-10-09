//
//  main.m
//  Test Application Helper
//
//  Created by Patrick Wardle on 9/10/16.
//  Copyright (c) 2016 Objective-See. All rights reserved.
//

#import "main.h"

//go go go
// ->either install/uninstall, or just launch normally
int main(int argc, const char * argv[])
{
    //return var
    int iReturn = 0;
    
    //dbg msg
    logMsg(LOG_DEBUG, @"starting login item");

    //check for uninstall/install flags
    if(2 == argc)
    {
        //install
        if(0 == strcmp(argv[1], ACTION_INSTALL.UTF8String))
        {
            //drop user privs
            setuid(getuid());

            //install
            toggleLoginItem(ACTION_INSTALL_FLAG);
            
            //bail
            goto bail;
        }
        //uninstall
        else if(0 == strcmp(argv[1], ACTION_UNINSTALL.UTF8String))
        {
            //drop user privs
            setuid(getuid());
            
            //unistall
            toggleLoginItem(ACTION_UNINSTALL_FLAG);
            
            //bail
            goto bail;
        }
    }
    
    //launch app normally
    iReturn = NSApplicationMain(argc, argv);
    
//bail
bail:
    
    return iReturn;
}

//toggle login item
// ->either add (install) or remove (uninstall)
BOOL toggleLoginItem(int toggleFlag)
{
    //flag
    BOOL wasToggled = NO;
    
    //path to self
    NSURL* path2Self = NULL;
    
    //login item ref
    LSSharedFileListRef loginItemsRef = NULL;
    
    //login items
    CFArrayRef loginItems = NULL;
    
    //current login item
    CFURLRef currentLoginItem = NULL;
    
    //init path to self
    path2Self = [NSURL fileURLWithPath:[[NSBundle mainBundle] bundlePath]];
    
    //get reference to login items
    loginItemsRef = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
    
    //add (install)
    if(ACTION_INSTALL_FLAG == toggleFlag)
    {
        //dbg msg
        logMsg(LOG_DEBUG, @"adding login item");
        
        //add
        LSSharedFileListItemRef itemRef = LSSharedFileListInsertItemURL(loginItemsRef, kLSSharedFileListItemLast, NULL, NULL, (__bridge CFURLRef)(path2Self), NULL, NULL);
    
        //release item ref
        if(NULL != itemRef)
        {
            //dbg msg
            logMsg(LOG_DEBUG, [NSString stringWithFormat:@"added %@/%@", path2Self, itemRef]);
            
            //release
            CFRelease(itemRef);
            
            //reset
            itemRef = NULL;
        }
        //failed
        else
        {
            //err msg
            logMsg(LOG_ERR, @"failed to added login item");
            
            //bail
            goto bail;
        }
    }
    //remove (uninstall)
    else
    {
        //dbg msg
        logMsg(LOG_DEBUG, @"removing login item");
        
        //grab existing login items
        loginItems = LSSharedFileListCopySnapshot(loginItemsRef, nil);
        
        //iterate over all login items
        // ->look for self, then remove it/them
        for (id item in (__bridge NSArray *)loginItems)
        {
            //get current login item
            if( (noErr != LSSharedFileListItemResolve((__bridge LSSharedFileListItemRef)item, 0, (CFURLRef*)&currentLoginItem, NULL)) ||
                 (NULL == currentLoginItem) )
            {
                //skip
                continue;
            }
                
            //current login item match self?
            if ([(__bridge NSURL *)currentLoginItem isEqual:path2Self])
            {
                //remove
                LSSharedFileListItemRemove(loginItemsRef, (__bridge LSSharedFileListItemRef)item);
            }
            
            //release
            if(NULL != currentLoginItem)
            {
                //release
                CFRelease(currentLoginItem);
                
                //reset
                currentLoginItem = NULL;
            }
            
        }//all login items
        
    }//remove/uninstall
    
    //happy
    wasToggled = YES;
    
//bail
bail:
    
    //release login items
    if(NULL != loginItems)
    {
        //release
        CFRelease(loginItems);
        
        //reset
        loginItems = NULL;
    }

    //release login ref
    if(NULL != loginItemsRef)
    {
        //release
        CFRelease(loginItemsRef);
        
        //reset
        loginItemsRef = NULL;
    }
    
   return wasToggled;
}
