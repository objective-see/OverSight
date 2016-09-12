//
//  ProcessMonitor.m
//  BlockBlock
//
//  Created by Patrick Wardle on 10/19/14.
//  Copyright (c) 2015 Objective-See. All rights reserved.
//

#import "Consts.h"
#import "Logging.h"
//#import "Process.h"
#import "Utilities.h"
#import "EventMonitor.h"
//#import "OrderedDictionary.h"

#import <stdio.h>
#import <stdlib.h>
#import <arpa/inet.h>
#import <sys/ioctl.h>
#import <sys/socket.h>
#import <sys/kern_event.h>

//TODO: move into shared file
//vendor id string
#define OBJECTIVE_SEE_VENDOR "com.objectiveSee"

//process camera event
#define PROCESS_CAMERA_EVENT 0x1


@implementation EventMonitor

//@synthesize processList;
//@synthesize partialProcessEvents;

//init
-(id)init
{
    //init super
    self = [super init];
    if(nil != self)
    {
        //init process list
        //processList = [[OrderedDictionary alloc] init];
        
        //init partial process event dictionary
        //partialProcessEvents = [NSMutableDictionary dictionary];
    }
    
    return self;
}

//kick off threads to monitor
// ->dtrace/audit pipe/app callback
-(BOOL)monitor
{
    //return var
    BOOL bRet = NO;
    
    //start thread to get process creation notifications from kext
    [NSThread detachNewThreadSelector:@selector(recvProcNotifications) toTarget:self withObject:nil];
    
    //no errors
    bRet = YES;
    
//bail
bail:
    
    return bRet;
}

//thread function
// ->recv() process creation notification events
-(void)recvProcNotifications
{
    //status var
    int status = -1;
    
    //system socket
    int systemSocket = -1;
    
    //struct for vendor code
    // ->set via call to ioctl/SIOCGKEVVENDOR
    struct kev_vendor_code vendorCode = {0};
    
    //struct for kernel request
    // ->set filtering options
    struct kev_request kevRequest = {0};
    
    //struct for broadcast data from the kext
    struct kern_event_msg *kernEventMsg = {0};
    
    //message from kext
    // ->size is cumulation of header, pid
    char kextMsg[KEV_MSG_HEADER_SIZE + sizeof(pid_t)] = {0};
    
    //bytes received from system socket
    ssize_t bytesReceived = -1;
    
    //process path
    // ->could be partial...
    char path[MAXPATHLEN+1] = {0};

    //length of path bytes
    // ->might not be NULL terminated, so have to calc manually
    int pathLength = 0;
    
    //cumulative path
    // ->when path is long & thus chunked
    NSMutableString* cumulativePath = nil;
    
    //custom struct
    // ->process data from kext
    //struct processStartEvent* procStartEvent = NULL;
    
    //pid of process that triggered alert
    pid_t triggerProcess = -1;
    
    //process info
    //NSMutableDictionary* procInfo = nil;
    
    //process object
    //Process* processObj = nil;
    
    //create system socket
    systemSocket = socket(PF_SYSTEM, SOCK_RAW, SYSPROTO_EVENT);
    if(-1 == systemSocket)
    {
        //set status var
        status = errno;
        
        //err msg
        //logMsg(LOG_ERR, [NSString stringWithFormat:@"socket() failed with %d", status]);
        
        //bail
        goto bail;
    }
    
    //set vendor name string
    strncpy(vendorCode.vendor_string, OBJECTIVE_SEE_VENDOR, KEV_VENDOR_CODE_MAX_STR_LEN);
    
    //get vendor name -> vendor code mapping
    status = ioctl(systemSocket, SIOCGKEVVENDOR, &vendorCode);
    if(0 != status)
    {
        //err msg
        //logMsg(LOG_ERR, [NSString stringWithFormat:@"ioctl(...,SIOCGKEVVENDOR,...) failed with %d", status]);
        
        //goto bail;
        goto bail;
    }
    
    //init filtering options
    // ->only interested in objective-see's events
    kevRequest.vendor_code = vendorCode.vendor_code;
    
    //...any class
    kevRequest.kev_class = KEV_ANY_CLASS;
    
    //...any subclass
    kevRequest.kev_subclass = KEV_ANY_SUBCLASS;
    
    //tell kernel what we want to filter on
    status = ioctl(systemSocket, SIOCSKEVFILT, &kevRequest);
    if(0 != status)
    {
        //err msg
        //logMsg(LOG_ERR, [NSString stringWithFormat:@"ioctl(...,SIOCSKEVFILT,...) failed with %d", status]);
        
        //goto bail;
        goto bail;
    }
    
    //dbg msg
    //logMsg(LOG_DEBUG, @"created system socket & set options, now entering recv() loop");
    
    //foreverz
    // ->listen/parse process creation events from kext
    while(YES)
    {
        //ask the kext for process began events
        // ->will block until event is ready
        bytesReceived = recv(systemSocket, kextMsg, sizeof(kextMsg), 0);
        
        //type cast
        // ->to access kev_event_msg header
        kernEventMsg = (struct kern_event_msg*)kextMsg;
        
        //sanity check
        // ->make sure data recv'd looks ok, sizewise
        if( (bytesReceived < KEV_MSG_HEADER_SIZE) ||
            (bytesReceived != kernEventMsg->total_size))
        {
            //dbg msg
            //logMsg(LOG_DEBUG, [NSString stringWithFormat:@"recv count: %d, wanted: %d", (int)bytesReceived, kernEventMsg->total_size]);
            
            //ignore
            continue;
        }
        
        //only care about 'process began' events
        if(PROCESS_CAMERA_EVENT != kernEventMsg->event_code)
        {
            //skip
            continue;
        }
        
        //dbg msg
        //logMsg(LOG_DEBUG, [NSString stringWithFormat:@"got msg from kernel, size: %d", kernEventMsg->total_size]);
        
        //zero out process path
        bzero(path, sizeof(path));
        
        //typecast custom data
        // ->begins right after header
        //procStartEvent = (struct processStartEvent*)&kernEventMsg->event_data[0];
        
        //dbg msg(s)
        //logMsg(LOG_DEBUG, [NSString stringWithFormat:@"  path (in this chunk): %s \n", procStartEvent->path]);
        //logMsg(LOG_DEBUG, [NSString stringWithFormat:@"  pid: %d ppid: %d uid: %d\n\n", procStartEvent->pid, procStartEvent->ppid, procStartEvent->uid]);
    
        //init proc info dictionary
        //procInfo = [NSMutableDictionary dictionary];
        
        triggerProcess = (pid_t)kernEventMsg->event_data[0];
        
        NSLog(@"proc %d triggered alert", triggerProcess);
        
        /*
        //save pid
        procInfo[@"pid"] = [NSNumber numberWithInt:procStartEvent->pid];
        
        //save uid
        procInfo[@"uid"] = [NSNumber numberWithInt:procStartEvent->uid];
        
        //save ppid
        procInfo[@"ppid"] = [NSNumber numberWithInt:procStartEvent->ppid];
    
        //calc number of bytes in path
        // ->might not be NULL terminated, so have to do it manually
        pathLength = kernEventMsg->total_size - KEV_MSG_HEADER_SIZE - sizeof(pid_t) - sizeof(uid_t) - sizeof(pid_t);
        
        //sanity check
        // ->should never happen...
        if(pathLength > MAXPATHLEN)
        {
            //ignore
            continue;
        }
        
        //copy path into buffer
        memcpy(path, (const char*)procStartEvent->path, pathLength);
        
        //NULL terminate it
        path[pathLength] = 0x0;
        
        //final chunk will end in NULL
        if(0x0 == *(((char*)kernEventMsg->event_data) + kernEventMsg->total_size-KEV_MSG_HEADER_SIZE-1))
        {
            //check if there are path components
            // ->pid is key into partial process list
            cumulativePath = self.partialProcessEvents[procInfo[@"pid"]];
            
            //finalize path
            // ->append this last path component chunk
            if(nil != cumulativePath)
            {
                //append
                [cumulativePath appendString:[NSString stringWithUTF8String:path]];
                
                //set final path
                procInfo[@"path"] = cumulativePath;
                
                //remove entry from partial list
                [self.partialProcessEvents removeObjectForKey:procInfo[@"pid"]];
            }
            //path wasn't chunked
            // ->can just use path as is
            else
            {
                //set final path
                procInfo[@"path"] = [NSString stringWithUTF8String:path];
            }
            
            //dbg msg
            //logMsg(LOG_DEBUG, [NSString stringWithFormat:@"new process: %@", procInfo[@"path"]]);
            
            //now, create process object
            processObj = [[Process alloc] initWithPid:procStartEvent->pid infoDictionary:procInfo];

            //sync process list
            // ->then insert it into list
            @synchronized(self.processList)
            {
                //trim list if needed
                if(self.processList.count >= PROCESS_LIST_MAX_SIZE)
                {
                    //toss first (oldest) item
                    [self.processList removeObjectForKey:[self.processList keyAtIndex:0]];
                }
                
                //insert process at end
                [self.processList addObject:processObj forKey:procInfo[@"pid"] atStart:NO];
                
            }//sync
            
        }//final chunk
        
        //non-final chunk
        // ->insert it, or append to partial process list
        else
        {
            //try grab existing (partial) path
            cumulativePath = self.partialProcessEvents[procInfo[@"pid"]];
            
            //check if there are path components already...
            // ->i.e. this is just another chunk, so append
            if(nil != cumulativePath)
            {
                //append
                [cumulativePath appendString:[NSString stringWithUTF8String:path]];
            }
            //new process
            // ->insert into partial process list
            else
            {
                //insert
                self.partialProcessEvents[procInfo[@"pid"]] = [NSMutableString stringWithUTF8String:path];
            }
            
        }//non-final chunk
         
        */
        
    }//while(YES)
    
//bail
bail:
    
    //close socket
    if(-1 != systemSocket)
    {
        //close
        close(systemSocket);
    }

    return;

}

@end
