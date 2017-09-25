//
//  Utilities.m
//  OverSight
//
//  Created by Patrick Wardle on 7/7/16.
//  Copyright (c) 2016 Objective-See. All rights reserved.
//

#import "Consts.h"
#import "Logging.h"
#import "Utilities.h"

#import <signal.h>
#import <unistd.h>
#import <libproc.h>
#import <sys/stat.h>
#import <sys/sysctl.h>
#import <Security/Security.h>
#import <Foundation/Foundation.h>
#import <CommonCrypto/CommonDigest.h>
#import <SystemConfiguration/SystemConfiguration.h>


//get OS version
NSDictionary* getOSVersion()
{
    //os version info
    NSMutableDictionary* osVersionInfo = nil;
    
    //major v
    SInt32 majorVersion = 0;
    
    //minor v
    SInt32 minorVersion = 0;
    
    //alloc dictionary
    osVersionInfo = [NSMutableDictionary dictionary];
    
    //get major version
    if(STATUS_SUCCESS != Gestalt(gestaltSystemVersionMajor, &majorVersion))
    {
        //reset
        osVersionInfo = nil;
        
        //bail
        goto bail;
    }
    
    //get minor version
    if(STATUS_SUCCESS != Gestalt(gestaltSystemVersionMinor, &minorVersion))
    {
        //reset
        osVersionInfo = nil;
        
        //bail
        goto bail;
    }
    
    //set major version
    osVersionInfo[@"majorVersion"] = [NSNumber numberWithInteger:majorVersion];
    
    //set minor version
    osVersionInfo[@"minorVersion"] = [NSNumber numberWithInteger:minorVersion];
    
//bail
bail:
    
    return osVersionInfo;
    
}


//get app's version
// ->extracted from Info.plist
NSString* getAppVersion()
{
    //read and return 'CFBundleVersion' from bundle
    return [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
}

//given a path to binary
// parse it back up to find app's bundle
NSBundle* findAppBundle(NSString* binaryPath)
{
    //app's bundle
    NSBundle* appBundle = nil;
    
    //app's path
    NSString* appPath = nil;
    
    //first just try full path
    appPath = binaryPath;
    
    //try to find the app's bundle/info dictionary
    do
    {
        //try to load app's bundle
        appBundle = [NSBundle bundleWithPath:appPath];
        
        //check for match
        // ->binary path's match
        if( (nil != appBundle) &&
            (YES == [appBundle.executablePath isEqualToString:binaryPath]))
        {
            //all done
            break;
        }
        
        //always unset bundle var since it's being returned
        // ->and at this point, its not a match
        appBundle = nil;
        
        //remove last part
        // ->will try this next
        appPath = [appPath stringByDeletingLastPathComponent];
        
    //scan until we get to root
    // ->of course, loop will exit if app info dictionary is found/loaded
    } while( (nil != appPath) &&
             (YES != [appPath isEqualToString:@"/"]) &&
             (YES != [appPath isEqualToString:@""]) );
    
    return appBundle;
}

//set dir's|file's group/owner
BOOL setFileOwner(NSString* path, NSNumber* groupID, NSNumber* ownerID, BOOL recursive)
{
    //ret var
    BOOL bSetOwner = NO;
    
    //owner dictionary
    NSDictionary* fileOwner = nil;
    
    //sub paths
    NSArray* subPaths = nil;
    
    //full path
    // ->for recursive
    NSString* fullPath = nil;
    
    //init permissions dictionary
    fileOwner = @{NSFileGroupOwnerAccountID:groupID, NSFileOwnerAccountID:ownerID};
    
    //set group/owner
    if(YES != [[NSFileManager defaultManager] setAttributes:fileOwner ofItemAtPath:path error:NULL])
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to set ownership for %@ (%@)", path, fileOwner]);
        
        //bail
        goto bail;
    }
    
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"set ownership for %@ (%@)", path, fileOwner]);
    #endif
    
    //do it recursively
    if(YES == recursive)
    {
        //sanity check
        // ->make sure root starts with '/'
        if(YES != [path hasSuffix:@"/"])
        {
            //add '/'
            path = [NSString stringWithFormat:@"%@/", path];
        }
        
        //get all subpaths
        subPaths = [[NSFileManager defaultManager] subpathsAtPath:path];
        for(NSString *subPath in subPaths)
        {
            //init full path
            fullPath = [path stringByAppendingString:subPath];
            
            //set group/owner
            if(YES != [[NSFileManager defaultManager] setAttributes:fileOwner ofItemAtPath:fullPath error:NULL])
            {
                //err msg
                logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to set ownership for %@ (%@)", fullPath, fileOwner]);
                
                //bail
                goto bail;
            }
        }
    }
    
    //no errors
    bSetOwner = YES;
    
//bail
bail:
    
    return bSetOwner;
}

//set permissions for file
BOOL setFilePermissions(NSString* file, int permissions, BOOL recursive)
{
    //ret var
    BOOL bSetPermissions = NO;
    
    //file permissions
    NSDictionary* filePermissions = nil;
    
    //root directory
    NSURL* root = nil;
    
    //directory enumerator
    NSDirectoryEnumerator* enumerator = nil;
    
    //error
    NSError* error = nil;
    
    //init dictionary
    filePermissions = @{NSFilePosixPermissions: [NSNumber numberWithInt:permissions]};
    
    //apply file permissions recursively
    if(YES == recursive)
    {
        //init root
        root = [NSURL fileURLWithPath:file];
        
        //init enumerator
        enumerator = [[NSFileManager defaultManager] enumeratorAtURL:root includingPropertiesForKeys:[NSArray arrayWithObject:NSURLIsDirectoryKey] options:0
                                                        errorHandler:^(NSURL *url, NSError *error) { return YES; }];
    
        //set file permissions on each
        for(NSURL* currentFile in enumerator)
        {
            //set permissions
            if(YES != [[NSFileManager defaultManager] setAttributes:filePermissions ofItemAtPath:currentFile.path error:&error])
            {
                //err msg
                logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to set permissions for %@ (%@), %@", currentFile.path, filePermissions, error]);
                
                //bail
                goto bail;
            }
        }
    }
    
    //always set permissions on passed in file (or top-level directory)
    // ->note: recursive enumerator skips root directory, so execute this always
    if(YES != [[NSFileManager defaultManager] setAttributes:filePermissions ofItemAtPath:file error:NULL])
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to set permissions for %@ (%@)", file, filePermissions]);
        
        //bail
        goto bail;
    }
    
    //happy
    bSetPermissions = YES;
    
//bail
bail:
    
    return bSetPermissions;
}

//exec a process and grab it's output
NSData* execTask(NSString* binaryPath, NSArray* arguments, BOOL shouldWait)
{
    //task
    NSTask *task = nil;
    
    //output pipe
    NSPipe *outPipe = nil;
    
    //output
    NSData *output = nil;
    
    //init task
    task = [NSTask new];
    
    //init pipe
    outPipe = [NSPipe pipe];
    
    //set task's path
    task.launchPath = binaryPath;
    
    //set task's args
    task.arguments = arguments;
    
    //set task's output to pipe
    // ->but only if we're waiting for exit
    if(YES == shouldWait)
    {
        //redirect
        task.standardOutput = outPipe;
    }
    
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"@exec'ing %@ (args: %@)", binaryPath, arguments]);
    #endif
    
    //wrap task launch
    @try
    {
        //launch
        [task launch];
    }
    @catch(NSException* exception)
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"task failed with %@", exception]);
        
        //bail
        goto bail;
    }
    
    //when waiting
    // ->grab data
    if(YES == shouldWait)
    {
    
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, @"invoking 'readDataToEndOfFile' to get all data");
    #endif
    
    //read until file is closed
    output = [outPipe.fileHandleForReading readDataToEndOfFile];
    
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, @"now waiting for task to exit");
    #endif
    
    //wait till exit
    [task waitUntilExit];
        
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, @"task exited");
    #endif
    
    }//wait
    
//bail
bail:
    
    return output;
}

//get OS's major or minor version
SInt32 getVersion(OSType selector)
{
    //version
    // ->major or minor
    SInt32 version = -1;
    
    //get version info
    if(noErr != Gestalt(selector, &version))
    {
        //reset version
        version = -1;
        
        //err
        goto bail;
    }
    
//bail
bail:
    
    return version;
}

//get process's path
NSString* getProcessPath(pid_t pid)
{
    //task path
    NSString* taskPath = nil;
    
    //buffer for process path
    char pathBuffer[PROC_PIDPATHINFO_MAXSIZE] = {0};
    
    //status
    int status = -1;
    
    //'management info base' array
    int mib[3] = {0};
    
    //system's size for max args
    int systemMaxArgs = 0;
    
    //process's args
    char* taskArgs = NULL;
    
    //# of args
    int numberOfArgs = 0;
    
    //size of buffers, etc
    size_t size = 0;
    
    //reset buffer
    bzero(pathBuffer, PROC_PIDPATHINFO_MAXSIZE);
    
    //first attempt to get path via 'proc_pidpath()'
    status = proc_pidpath(pid, pathBuffer, sizeof(pathBuffer));
    if(0 != status)
    {
        //init task's name
        taskPath = [NSString stringWithUTF8String:pathBuffer];
    }
    //otherwise
    // ->try via task's args ('KERN_PROCARGS2')
    else
    {
        //init mib
        // ->want system's size for max args
        mib[0] = CTL_KERN;
        mib[1] = KERN_ARGMAX;
        
        //set size
        size = sizeof(systemMaxArgs);
        
        //get system's size for max args
        if(-1 == sysctl(mib, 2, &systemMaxArgs, &size, NULL, 0))
        {
            //bail
            goto bail;
        }
        
        //alloc space for args
        taskArgs = malloc(systemMaxArgs);
        if(NULL == taskArgs)
        {
            //bail
            goto bail;
        }
        
        //init mib
        // ->want process args
        mib[0] = CTL_KERN;
        mib[1] = KERN_PROCARGS2;
        mib[2] = pid;
        
        //set size
        size = (size_t)systemMaxArgs;
        
        //get process's args
        if(-1 == sysctl(mib, 3, taskArgs, &size, NULL, 0))
        {
            //bail
            goto bail;
        }
        
        //sanity check
        // ->ensure buffer is somewhat sane
        if(size <= sizeof(int))
        {
            //bail
            goto bail;
        }
        
        //extract number of args
        // ->at start of buffer
        memcpy(&numberOfArgs, taskArgs, sizeof(numberOfArgs));
        
        //extract task's name
        // ->follows # of args (int) and is NULL-terminated
        taskPath = [NSString stringWithUTF8String:taskArgs + sizeof(int)];
    }
    
//bail
bail:
    
    //free process args
    if(NULL != taskArgs)
    {
        //free
        free(taskArgs);
        
        //reset
        taskArgs = NULL;
    }
    
    return taskPath;
}

//given a pid
// ->get the name of the process
NSString* getProcessName(pid_t pid)
{
    //task path
    NSString* processName = nil;
    
    //process path
    NSString* processPath = nil;
    
    //app's bundle
    NSBundle* appBundle = nil;
    
    //get process path
    processPath = getProcessPath(pid);
    if( (nil == processPath) ||
        (0 == processPath.length) )
    {
        //default to 'unknown'
        processName = @"<unknown>";
        
        //bail
        goto bail;
    }
    
    //try find an app bundle
    appBundle = findAppBundle(processPath);
    if(nil != appBundle)
    {
        //grab name from app's bundle
        processName = [appBundle infoDictionary][@"CFBundleName"];
    }
    
    //still nil?
    // ->just grab from path
    if(nil == processName)
    {
        //from path
        processName = [processPath lastPathComponent];
    }
    
//bail
bail:
    
    return processName;
}

//given a process name
// ->get the (first) instance of that process
pid_t getProcessID(NSString* processName, uid_t userID)
{
    //status
    int status = -1;
    
    //process id
    pid_t processID = -1;
        
    //# of procs
    int numberOfProcesses = 0;
        
    //array of pids
    pid_t* pids = NULL;
    
    //process info struct
    struct kinfo_proc procInfo = {0};
    
    //size of struct
    size_t procInfoSize = sizeof(procInfo);
    
    //mib
    int mib[4] = {CTL_KERN, KERN_PROC, KERN_PROC_PID, -1};
    
    //get # of procs
    numberOfProcesses = proc_listpids(PROC_ALL_PIDS, 0, NULL, 0);
    
    //alloc buffer for pids
    pids = calloc(numberOfProcesses, sizeof(pid_t));
    
    //get list of pids
    status = proc_listpids(PROC_ALL_PIDS, 0, pids, numberOfProcesses * sizeof(pid_t));
    if(status < 0)
    {
        //bail
        goto bail;
    }
        
    //iterate over all pids
    // ->get name for each
    for(int i = 0; i < numberOfProcesses; ++i)
    {
        //skip blank pids
        if(0 == pids[i])
        {
            //skip
            continue;
        }
        
        //skip if name doesn't match
        if(YES != [processName isEqualToString:getProcessName(pids[i])])
        {
            //next
            continue;
        }
        
        //init mib
        mib[0x3] = pids[i];
        
        //make syscall to get proc info
        if( (0 != sysctl(mib, 0x4, &procInfo, &procInfoSize, NULL, 0)) ||
            (0 == procInfoSize) )
        {
            //skip
            continue;
        }

        //skip if user id doesn't match
        if(userID != procInfo.kp_eproc.e_ucred.cr_uid)
        {
            //skip
            continue;
        }
        
        //got match
        processID = pids[i];
        
        //exit loop
        break;
    }
        
//bail
bail:
        
    //free buffer
    if(NULL != pids)
    {
        //free
        free(pids);
        
        //reset
        pids = NULL;
    }
    
    return processID;
}


//get an icon for a process
// ->for apps, this will be app's icon, otherwise just a standard system one
NSImage* getIconForProcess(NSString* path)
{
    //icon's file name
    NSString* iconFile = nil;
    
    //icon's path
    NSString* iconPath = nil;
    
    //icon's path extension
    NSString* iconExtension = nil;
    
    //icon
    NSImage* icon = nil;
    
    //system's document icon
    static NSData* documentIcon = nil;
    
    //bundle
    NSBundle* appBundle = nil;
    
    //first try grab bundle
    // ->then extact icon from this
    appBundle = findAppBundle(path);
    if(nil != appBundle)
    {
        //get file
        iconFile = appBundle.infoDictionary[@"CFBundleIconFile"];
        
        //get path extension
        iconExtension = [iconFile pathExtension];
        
        //if its blank (i.e. not specified)
        // ->go with 'icns'
        if(YES == [iconExtension isEqualTo:@""])
        {
            //set type
            iconExtension = @"icns";
        }
        
        //set full path
        iconPath = [appBundle pathForResource:[iconFile stringByDeletingPathExtension] ofType:iconExtension];
        
        //load it
        icon = [[NSImage alloc] initWithContentsOfFile:iconPath];
    }
    
    //process is not an app or couldn't get icon
    // ->try to get it via shared workspace
    if( (nil == appBundle) ||
        (nil == icon) )
    {
        //extract icon
        icon = [[NSWorkspace sharedWorkspace] iconForFile:path];
        
        //load system document icon
        // ->static var, so only load once
        if(nil == documentIcon)
        {
            //load
            documentIcon = [[[NSWorkspace sharedWorkspace] iconForFileType:
                             NSFileTypeForHFSTypeCode(kGenericDocumentIcon)] TIFFRepresentation];
        }
        
        //if 'iconForFile' method doesn't find and icon, it returns the system 'document' icon
        // ->the system 'applicatoon' icon seems more applicable, so use that here...
        if(YES == [[icon TIFFRepresentation] isEqual:documentIcon])
        {
            //set icon to system 'applicaiton' icon
            icon = [[NSWorkspace sharedWorkspace]
                         iconForFileType: NSFileTypeForHFSTypeCode(kGenericApplicationIcon)];
        }
        
        //'iconForFileType' returns small icons
        // ->so set size to 128
        [icon setSize:NSMakeSize(128, 128)];
    }
    
    return icon;
}

//determine if there is a new version
// -1, YES or NO
NSInteger isNewVersion(NSMutableString* versionString)
{
    //flag
    NSInteger newVersionExists = -1;
    
    //installed version
    NSString* installedVersion = nil;
    
    //latest version
    NSString* latestVersion = nil;
    
    //get installed version
    installedVersion = getAppVersion();
    
    //get latest version
    // ->will query internet (obj-see website)
    latestVersion = getLatestVersion();
    if(nil == latestVersion)
    {
        //set error msg
        [versionString setString:@"failed to get latest version"];
        
        //bail
        goto bail;
    }
    
    //save version
    [versionString setString:latestVersion];
    
    //set version flag
    // ->YES/NO
    newVersionExists = (NSOrderedAscending == [installedVersion compare:latestVersion options:NSNumericSearch]);
    
//bail
bail:
    
    return newVersionExists;
}

//query interwebz to get latest version
NSString* getLatestVersion()
{
    //version data
    __block NSData* versionData = nil;
    
    //version dictionary
    NSDictionary* versionDictionary = nil;
    
    //latest version
    NSString* latestVersion = nil;
    
    //run in background if main thread
    if(YES == [NSThread isMainThread])
    {
        //run in background
        dispatch_sync(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
        ^{
            //get version data
            versionData = [[NSData alloc] initWithContentsOfURL:[NSURL URLWithString:PRODUCT_VERSION_URL]];
        });
    }
    //no need to background
    else
    {
        //get version from remote URL
        versionData = [[NSData alloc] initWithContentsOfURL:[NSURL URLWithString:PRODUCT_VERSION_URL]];
    }
    
    //sanity check
    if(nil == versionData)
    {
        //bail
        goto bail;
    }
    
    //convert JSON to dictionary
    versionDictionary = [NSJSONSerialization JSONObjectWithData:versionData options:0 error:nil];
    
    //sanity check
    if(nil == versionDictionary)
    {
        //bail
        goto bail;
    }
    
    //extract latest version
    latestVersion = versionDictionary[@"latestVersion"];
    
//bail
bail:
    
    return latestVersion;
}


//wait until a window is non nil
// ->then make it modal
void makeModal(NSWindowController* windowController)
{
    //wait up to 1 second window to be non-nil
    // ->then make modal
    for(int i=0; i<20; i++)
    {
        //can make it modal once we have a window
        if(nil != windowController.window)
        {
            //make modal on main thread
            dispatch_sync(dispatch_get_main_queue(), ^{
                
                //modal
                [[NSApplication sharedApplication] runModalForWindow:windowController.window];
                
            });
            
            //all done
            break;
        }
        
        //nap
        [NSThread sleepForTimeInterval:0.05f];
        
    }//until 1 second
    
    return;
}

//toggle login item
// ->either add (install) or remove (uninstall)
BOOL toggleLoginItem(NSURL* loginItem, int toggleFlag)
{
    //flag
    BOOL wasToggled = NO;

    //login item ref
    LSSharedFileListRef loginItemsRef = NULL;
    
    //login items
    CFArrayRef loginItems = NULL;
    
    //current login item
    CFURLRef currentLoginItem = NULL;
    
    //get reference to login items
    loginItemsRef = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
    
    //add (install)
    if(ACTION_INSTALL_FLAG == toggleFlag)
    {
        //dbg msg
        #ifdef DEBUG
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"adding login item %@", loginItem]);
        #endif
        
        //add
        LSSharedFileListItemRef itemRef = LSSharedFileListInsertItemURL(loginItemsRef, kLSSharedFileListItemLast, NULL, NULL, (__bridge CFURLRef)(loginItem), NULL, NULL);
        
        //release item ref
        if(NULL != itemRef)
        {
            //dbg msg
            #ifdef DEBUG
            logMsg(LOG_DEBUG, [NSString stringWithFormat:@"added %@/%@", loginItem, itemRef]);
            #endif
            
            //release
            CFRelease(itemRef);
            
            //reset
            itemRef = NULL;
        }
        //failed
        else
        {
            //err msg
            logMsg(LOG_ERR, @"failed to add login item");
            
            //bail
            goto bail;
        }
        
        //happy
        wasToggled = YES;
    }
    //remove (uninstall)
    else
    {
        //dbg msg
        #ifdef DEBUG
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"removing login item %@", loginItem]);
        #endif
        
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
            if(YES == [(__bridge NSURL *)currentLoginItem isEqual:loginItem])
            {
                //remove
                if(noErr != LSSharedFileListItemRemove(loginItemsRef, (__bridge LSSharedFileListItemRef)item))
                {
                    //err msg
                    logMsg(LOG_ERR, @"failed to remove login item");
                    
                    //bail
                    goto bail;
                }
                
                //dbg msg
                logMsg(LOG_DEBUG, [NSString stringWithFormat:@"removed loginItem: %@", loginItem]);
                
                //happy
                wasToggled = YES;
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

//get logged in user
NSString* loggedinUser()
{
    //store
    SCDynamicStoreRef store = nil;
    
    //user
    NSString* user = nil;
    
    //create store
    store = SCDynamicStoreCreate(NULL, CFSTR("GetConsoleUser"), NULL, NULL);
    if(NULL == store)
    {
        //bail
        goto bail;
    }
    
    //get user
    user = CFBridgingRelease(SCDynamicStoreCopyConsoleUser(store, NULL, NULL));
    
//bail
bail:
    
    //release store
    if(NULL != store)
    {
        //release
        CFRelease(store);
    }
    
    return user;
}

//find a process by name
pid_t findProcess(NSString* processName)
{
    //pid
    pid_t processID = 0;
    
    //status
    int status = -1;
    
    //# of procs
    int numberOfProcesses = 0;
    
    //array of pids
    pid_t* pids = NULL;
    
    //process path
    NSString* processPath = nil;
    
    //get # of procs
    numberOfProcesses = proc_listpids(PROC_ALL_PIDS, 0, NULL, 0);
    
    //alloc buffer for pids
    pids = calloc(numberOfProcesses, sizeof(pid_t));
    
    //get list of pids
    status = proc_listpids(PROC_ALL_PIDS, 0, pids, numberOfProcesses * sizeof(pid_t));
    if(status < 0)
    {
        //bail
        goto bail;
    }
    
    //iterate over all pids
    // ->get name for each via helper function
    for(int i = 0; i < numberOfProcesses; ++i)
    {
        //skip blank pids
        if(0 == pids[i])
        {
            //skip
            continue;
        }
        
        //get name
        processPath = getProcessPath(pids[i]);
        if( (nil == processPath) ||
           (0 == processPath.length) )
        {
            //skip
            continue;
        }
        
        //match?
        if(YES == [processPath isEqualToString:processName])
        {
            //save
            processID = pids[i];
            
            //pau
            break;
        }
        
    }//all procs
    
//bail
bail:
    
    //free buffer
    if(NULL != pids)
    {
        //free
        free(pids);
    }
    
    return processID;
}

//convert a textview to a clickable hyperlink
void makeTextViewHyperlink(NSTextField* textField, NSURL* url)
{
    //hyperlink
    NSMutableAttributedString *hyperlinkString = nil;
    
    //range
    NSRange range = {0};
    
    //init hyper link
    hyperlinkString = [[NSMutableAttributedString alloc] initWithString:textField.stringValue];
    
    //init range
    range = NSMakeRange(0, [hyperlinkString length]);
    
    //start editing
    [hyperlinkString beginEditing];
    
    //add url
    [hyperlinkString addAttribute:NSLinkAttributeName value:url range:range];
    
    //make it blue
    [hyperlinkString addAttribute:NSForegroundColorAttributeName value:[NSColor blueColor] range:NSMakeRange(0, [hyperlinkString length])];
    
    //underline
    [hyperlinkString addAttribute:
     NSUnderlineStyleAttributeName value:[NSNumber numberWithInt:NSSingleUnderlineStyle] range:NSMakeRange(0, [hyperlinkString length])];
    
    //done editing
    [hyperlinkString endEditing];
    
    //set text
    [textField setAttributedStringValue:hyperlinkString];
    
    return;
}

//get frontmost (active) app
pid_t frontmostApplication()
{
    //get/ret
    return NSWorkspace.sharedWorkspace.frontmostApplication.processIdentifier;
}

