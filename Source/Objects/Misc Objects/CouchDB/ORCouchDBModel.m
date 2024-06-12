//
//  ORCouchDBModel.m
//  Orca
//
//  Created by Mark Howe on 10/18/06.
//  Copyright 2006 CENPA, University of Washington. All rights reserved.
//-----------------------------------------------------------
//This program was prepared for the Regents of the University of 
//Washington at the Center for Experimental Nuclear Physics and 
//Astrophysics (CENPA) sponsored in part by the United States 
//Department of Energy (DOE) under Grant #DE-FG02-97ER41020. 
//The University has certain rights in the program pursuant to 
//the contract and the program should not be copied or distributed 
//outside your organization.  The DOE and the University of 
//Washington reserve all rights in the program. Neither the authors,
//University of Washington, or U.S. Government make any warranty, 
//express or implied, or assume any liability or responsibility 
//for the use of this software.
//-------------------------------------------------------------

#import "ORBurstMonitorModel.h"
#import "ORCouchDBModel.h"
#import "ORCouchDB.h"
#import "MemoryWatcher.h"
#import "NSNotifications+Extensions.h"
#import "Utilities.h"
#import "ORRunModel.h"
#import "ORExperimentModel.h"
#import "ORAlarmCollection.h"
#import "ORAlarm.h"
#import "OR1DHisto.h"
#import "ORStatusController.h"
#import "ORProcessModel.h"
#import "ORProcessElementModel.h"
#import <sys/socket.h>
#import <ifaddrs.h>
#import <arpa/inet.h>

NSString* ORCouchDBModelSkipDataSetsChanged       = @"ORCouchDBModelSkipDataSetsChanged";
NSString* ORCouchDBModelAlertTypeChanged          = @"ORCouchDBModelAlertTypeChanged";
NSString* ORCouchDBModelAlertMessageChanged       = @"ORCouchDBModelAlertMessageChanged";
NSString* ORCouchDBModelReplicationRunningChanged = @"ORCouchDBModelReplicationRunningChanged";
NSString* ORCouchDBModelKeepHistoryChanged		  = @"ORCouchDBModelKeepHistoryChanged";
NSString* ORCouchDBModelStealthModeChanged		  = @"ORCouchDBModelStealthModeChanged";
NSString* ORCouchDBModelPostRunningScriptsChanged = @"ORCouchDBModelPostRunningScriptsChanged";
NSString* ORCouchDBPasswordChanged				  = @"ORCouchDBPasswordChanged";
NSString* ORCouchDBPortNumberChanged              = @"ORCouchDBPortNumberChanged";
NSString* ORCouchDBUserNameChanged				  = @"ORCouchDBUserNameChanged";
NSString* ORCouchDBRemoteHostNameChanged		  = @"ORCouchDBRemoteHostNameChanged";
NSString* ORCouchDBModelDBInfoChanged			  = @"ORCouchDBModelDBInfoChanged";
NSString* ORCouchDBLock							  = @"ORCouchDBLock";
NSString* ORCouchDBLocalHostNameChanged           = @"ORCouchDBLocalHostNameChanged";
NSString* ORCouchDBModelUsingUpdateHandleChanged  = @"ORCouchDBModelUsingUpdateHandleChanged";
NSString* ORCouchDBModeUseHttpsChanged            = @"ORCouchDBModeUseHttpsChanged";

#define kCreateDB           @"kCreateDB"
#define kReplicateDB        @"kReplicateDB"
#define kRestartReplicateDB @"kRestartReplicateDB"
#define kCreateRemoteDB     @"kCreateRemoteDB"
#define kDeleteDB           @"kDeleteDB"
#define kListDB             @"kListDB"
#define kRemoteInfo         @"kRemoteInfo"
#define kRemoteInfoVerbose  @"kRemoteInfoVerbose"
#define kDocument           @"kDocument"
#define kInfoDB             @"kInfoDB"
#define kDocumentAdded      @"kDocumentAdded"
#define kDocumentUpdated    @"kDocumentUpdated"
#define kDocumentDeleted    @"kDocumentDeleted"
#define kCompactDB          @"kCompactDB"
#define kInfoInternalDB     @"kInfoInternalDB"
#define kAttachmentAdded    @"kAttachmentAdded"
#define kInfoHistoryDB      @"kInfoHistoryDB"
#define kAddUpdateHandler   @"kAddUpdateHandler"

#define kCouchDBPort            5984
#define kUpdateStatsInterval    30

static NSString* ORCouchDBModelInConnector 	= @"ORCouchDBModelInConnector";

@interface ORCouchDBModel (private)
- (void) updateProcesses;
- (void) updateExperiment;
- (void) updateHistory;
- (void) updateBurstRecord;
- (void) updateMachineRecord;
- (void) postRunState:(NSNotification*)aNote;
- (void) postRunTime:(NSNotification*)aNote;
- (void) postRunOptions:(NSNotification*)aNote;
- (void) updateRunState:(ORRunModel*)rc;
- (void) processElementStateChanged:(NSNotification*)aNote;
- (void) periodicCompact;
- (void) updateDataSets;
- (void) _cancelAllPeriodicOperations;
- (void) _startAllPeriodicOperations;
@end

@implementation ORCouchDBModel

#pragma mark ***Initialization

- (id) init
{
    self = [super init];
    [self setPortNumber:kCouchDBPort];
    return self;
}

- (void) dealloc
{
    [alertMessage release];
	[NSObject cancelPreviousPerformRequestsWithTarget:self];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [password       release];
    [userName       release];
    [localHostName  release];
    [remoteHostName release];
	[docList        release];
    [replicationAlarm clearAlarm];
    [replicationAlarm release];
    [customDataBases  release];
    [thisHostAdress   release];

	[super dealloc];
}

- (void) wakeUp
{
    if(![self aWake]){
        [self createDatabases];
        [self _startAllPeriodicOperations];
        [self registerNotificationObservers];
    }
    [super wakeUp];
}


- (void) sleep
{
    [self _cancelAllPeriodicOperations];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
	[super sleep];
}

- (BOOL) solitaryObject
{
    return YES;
}

- (void) setUpImage
{
    [self setImage:[NSImage imageNamed:@"CouchDB"]];
}

- (void) makeMainController
{
    [self linkToController:@"ORCouchDBController"];
}

- (void) makeConnectors
{
    ORConnector* aConnector = [[ORConnector alloc] initAt:NSMakePoint(0,[self frame].size.height/2-kConnectorSize/2) withGuardian:self withObjectLink:self];
    [[self connectors] setObject:aConnector forKey:ORCouchDBModelInConnector];
    [aConnector setOffColor:[NSColor brownColor]];
    [aConnector setOnColor:[NSColor magentaColor]];
	[ aConnector setConnectorType: 'DB I' ];
	[ aConnector addRestrictedConnectionType: 'DB O' ]; //can only connect to DB outputs
	
    [aConnector release];
}

- (void) registerNotificationObservers
{
    NSNotificationCenter* notifyCenter = [NSNotificationCenter defaultCenter];
    
	[notifyCenter removeObserver:self];
	
    [notifyCenter addObserver : self
                     selector : @selector(applicationIsTerminating:)
                         name : @"ORAppTerminating"
                       object : (ORAppDelegate*)[NSApp delegate]];
	
	[notifyCenter addObserver : self
                     selector : @selector(runStatusChanged:)
                         name : ORRunStatusChangedNotification
                       object : nil];

    [notifyCenter addObserver : self
                     selector : @selector(runStarted:)
                         name : ORRunStartedNotification
                       object : nil];

    [notifyCenter addObserver : self
                     selector : @selector(runStopped:)
                         name : ORRunStoppedNotification
                       object : nil];
    
	[notifyCenter addObserver : self
                     selector : @selector(runOptionsOrTimeChanged:)
                         name : ORRunElapsedTimesChangedNotification
                       object : nil];
	
	[notifyCenter addObserver : self
                     selector : @selector(runOptionsOrTimeChanged:)
                         name : ORRunRepeatRunChangedNotification
                       object : nil];
	
    [notifyCenter addObserver : self
                     selector : @selector(alarmsChanged:)
                         name : ORAlarmWasPostedNotification
                       object : nil];	

    [notifyCenter addObserver : self
                     selector : @selector(alarmsChanged:)
                         name : ORAlarmWasAcknowledgedNotification
                       object : nil];
    
    [notifyCenter addObserver : self
                     selector : @selector(alarmsChanged:)
                         name : ORAlarmWasClearedNotification
                       object : nil];	
		
	[notifyCenter addObserver : self
					 selector : @selector(updateProcesses)
						 name : ORProcessRunningChangedNotification
					   object : nil];	
	
	[notifyCenter addObserver : self
					 selector : @selector(processElementStateChanged:)
						 name : ORProcessElementStateChangedNotification
					   object : nil];

    [notifyCenter addObserver : self
                     selector : @selector(addObjectValueRecord:)
                         name : @"ORCouchDBBlockStatusLogRecord"
                       object : nil];
        
    [notifyCenter addObserver : self
					 selector : @selector(addObjectValueRecord:)
						 name : @"ORCouchDBAddObjectRecord"
					   object : nil];
    
    [notifyCenter addObserver : self
                     selector : @selector(addObjectValueRecord:)
                         name : @"ORGenericObjectDBRecord"
                       object : nil];

    [notifyCenter addObserver : self
					 selector : @selector(addAdcsToHistoryRecord:)
						 name : @"ORCouchDBAddHistoryAdcRecord"
					   object : nil];

    [notifyCenter addObserver : self
					 selector : @selector(postOrPutCustomRecord:)
						 name : @"ORCouchDBPostOrPutCustomRecord"
					   object : nil];
    
}

- (void) applicationIsTerminating:(NSNotification*)aNote
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    [[ORCouchDBQueue sharedCouchDBQueue] cancelAllOperations];
 }

- (void) awakeAfterDocumentLoaded
{
	[self updateRunInfo];
	[self alarmsChanged:nil];
	[self updateExperiment];
    NSDictionary* doc = [NSDictionary dictionaryWithObjectsAndKeys:
                         @"ORCA restarted",                                     @"comment",
                         @"O",                                                  @"Symbol",
                         nil];

    [self recordEvent:@"Restart" document:doc];
    
    NSNumber* didShutdown   = [[NSUserDefaults standardUserDefaults] objectForKey:ORNormalShutDownFlag];
    NSNumber* wasInDebugger = [[NSUserDefaults standardUserDefaults] objectForKey:ORWasInDebuggerFlag];
    
    if((didShutdown && ![didShutdown boolValue]) && (wasInDebugger && ![wasInDebugger boolValue])){
        NSDictionary* doc = [NSDictionary dictionaryWithObjectsAndKeys:
                             @"ORCA crashed",                                     @"comment",
                             @"C",                                                @"Symbol",
                             nil];
    
        [self recordEvent:@"Crash" document:doc];
    }


}

#pragma mark ***Accessors

- (BOOL) skipDataSets
{
    return skipDataSets;
}

- (void) setSkipDataSets:(BOOL)aSkipDataSets
{
    [[[self undoManager] prepareWithInvocationTarget:self] setSkipDataSets:skipDataSets];
    
    skipDataSets = aSkipDataSets;

    [[NSNotificationCenter defaultCenter] postNotificationName:ORCouchDBModelSkipDataSetsChanged object:self];
}

- (int) alertType
{
    return alertType;
}

- (void) setAlertType:(int)aAlertType
{
    [[[self undoManager] prepareWithInvocationTarget:self] setAlertType:alertType];
    
    alertType = aAlertType;

    [[NSNotificationCenter defaultCenter] postNotificationName:ORCouchDBModelAlertTypeChanged object:self];
}

- (NSString*) alertMessage
{
    if(!alertMessage)return @"";
    else             return alertMessage;
}

- (void) setAlertMessage:(NSString*)aAlertMessage
{
    [[[self undoManager] prepareWithInvocationTarget:self] setAlertMessage:alertMessage];
    
    [alertMessage autorelease];
    alertMessage = [aAlertMessage copy];    

    [[NSNotificationCenter defaultCenter] postNotificationName:ORCouchDBModelAlertMessageChanged object:self];
}

- (BOOL) usingUpdateHandler
{
    return usingUpdateHandler;
}
- (void) setUsingUpdateHandler:(BOOL)aState
{
    usingUpdateHandler = aState;
    [[NSNotificationCenter defaultCenter] postNotificationName:ORCouchDBModelUsingUpdateHandleChanged object:self];
}

- (BOOL) replicationRunning
{
    return replicationRunning;
}

- (void) setReplicationRunning:(BOOL)aReplicationRunning
{
    replicationRunning = aReplicationRunning;

    [[NSNotificationCenter defaultCenter] postNotificationName:ORCouchDBModelReplicationRunningChanged object:self];
}

- (BOOL) keepHistory
{
    return keepHistory;
}

- (void) setKeepHistory:(BOOL)aKeepHistory
{
    [[[self undoManager] prepareWithInvocationTarget:self] setKeepHistory:keepHistory];
    keepHistory = aKeepHistory;
    if(keepHistory){
        [self createHistoryDatabase];
    }

    [[NSNotificationCenter defaultCenter] postNotificationName:ORCouchDBModelKeepHistoryChanged object:self];
}
- (BOOL) useHttps
{
    return useHttps;
}
- (void) setUseHttps:(BOOL)aState;
{
    [[[self undoManager] prepareWithInvocationTarget:self] setUseHttps:useHttps];
    useHttps = aState;
    [[NSNotificationCenter defaultCenter] postNotificationName:ORCouchDBModeUseHttpsChanged object:self];
}

- (BOOL) stealthMode
{
    return stealthMode;
}

- (void) setStealthMode:(BOOL)aStealthMode
{
    [[[self undoManager] prepareWithInvocationTarget:self] setStealthMode:stealthMode];
    stealthMode = aStealthMode;
    if(stealthMode){
        if([ORCouchDBQueue operationCount]) [ORCouchDBQueue cancelAllOperations];
        [self _cancelAllPeriodicOperations];
    }
    else {
        [self createDatabases];
    }
	[[NSNotificationCenter defaultCenter] postNotificationName:ORCouchDBModelStealthModeChanged object:self];
}

- (BOOL) postRunningScripts
{
    return postRunningScripts;
}

- (void) setPostRunningScripts:(BOOL)postRunning
{
    if(postRunning == postRunningScripts) return;
    [[[self undoManager] prepareWithInvocationTarget:self] setPostRunningScripts:postRunningScripts];
    postRunningScripts = postRunning;
    [[NSNotificationCenter defaultCenter] postNotificationName:ORCouchDBModelPostRunningScriptsChanged object:self];
}

- (id) nextObject
{
	return [self objectConnectedTo:ORCouchDBModelInConnector];
}

- (NSString*) password
{
    return password;
}

- (void) setPassword:(NSString*)aPassword
{
	if(aPassword){
		[[[self undoManager] prepareWithInvocationTarget:self] setPassword:password];
		
		[password autorelease];
		password = ([aPassword length] == 0) ? nil : [aPassword copy];
		
		[[NSNotificationCenter defaultCenter] postNotificationName:ORCouchDBPasswordChanged object:self];
	}
}

- (NSUInteger) portNumber
{
    return portNumber;
}

- (void) setPortNumber:(NSUInteger)aPort
{
    [[[self undoManager] prepareWithInvocationTarget:self] setPortNumber:portNumber];
    if(aPort == 0)aPort = 5984;
    
    portNumber = aPort;
    
    [[NSNotificationCenter defaultCenter] postNotificationName:ORCouchDBPortNumberChanged object:self];
}

- (NSString*) userName
{
    return userName;
}

- (void) setUserName:(NSString*)aUserName
{
	if(aUserName){
		[[[self undoManager] prepareWithInvocationTarget:self] setUserName:userName];
		
		[userName autorelease];
		userName = ([aUserName length] == 0) ? nil : [aUserName copy];
		
		[[NSNotificationCenter defaultCenter] postNotificationName:ORCouchDBUserNameChanged object:self];
	}
}

- (NSString*) remoteHostName
{
    return remoteHostName;
}

- (void) setRemoteHostName:(NSString*)aHostName
{
	if(aHostName){
		[[[self undoManager] prepareWithInvocationTarget:self] setRemoteHostName:remoteHostName];
		
		[remoteHostName autorelease];
		remoteHostName = [aHostName copy];    
		
		[[NSNotificationCenter defaultCenter] postNotificationName:ORCouchDBRemoteHostNameChanged object:self];
	}
}

- (NSString*) localHostName
{
    return localHostName;
}

- (void) setLocalHostName:(NSString*)aHostName
{
	if(aHostName){
		[[[self undoManager] prepareWithInvocationTarget:self] setLocalHostName:localHostName];
		
		[localHostName autorelease];
		localHostName = [aHostName copy];
		
		[[NSNotificationCenter defaultCenter] postNotificationName:ORCouchDBLocalHostNameChanged object:self];
	}
}

- (NSString*) databaseName
{		
	return [self machineName];
}

- (NSString*) historyDatabaseName
{		
	return [@"history_" stringByAppendingString:[self machineName]];
}

- (NSString*) machineName
{		
	NSString* machineName = [NSString stringWithFormat:@"%@",computerName()];
	machineName = [machineName stringByReplacingOccurrencesOfString:@" " withString:@"_"];
	return [machineName lowercaseString];
}

- (ORCouchDB*) statusDBRef
{
    return [self statusDBRef:[self databaseName]];
}

- (ORCouchDB*) statusDBRef:(NSString*)aDatabaseName
{
    if (localHostName == nil) {
        [self setLocalHostName:@"localhost"];
    }
	return [ORCouchDB couchHost:localHostName port:portNumber username:userName pwd:password database:aDatabaseName delegate:self];
}

- (ORCouchDB*) historyDBRef
{
    return [self historyDBRef:[self historyDatabaseName]];
}

- (ORCouchDB*) historyDBRef:(NSString*)aDatabaseName
{
    if (localHostName == nil) {
        [self setLocalHostName:@"localhost"];
    }
	return [ORCouchDB couchHost:localHostName port:portNumber username:userName pwd:password database:aDatabaseName delegate:self];
}

- (ORCouchDB*) remoteHistoryDBRef
{
    return [self remoteHistoryDBRef:[self historyDatabaseName]];
}

- (ORCouchDB*) remoteHistoryDBRef:(NSString*)aDatabaseName
{
    if([remoteHostName length]==0)return nil;
	else return [ORCouchDB couchHost:remoteHostName port:portNumber username:userName pwd:password database:aDatabaseName delegate:self];
}

- (ORCouchDB*) remoteDBRef
{
    return [self remoteDBRef:[self databaseName]];

}
- (ORCouchDB*) remoteDBRef:(NSString*)aDatabaseName
{
    if([remoteHostName length]==0)return nil;
	else return [ORCouchDB couchHost:remoteHostName port:portNumber username:userName pwd:password database:aDatabaseName delegate:self];
}

- (void) createDatabases
{
    [self createDatabase:   [self statusDBRef]];
    [self addUpdateHandler: [self statusDBRef]];
    if([remoteHostName length]){
        [self createDatabase:    [self remoteDBRef]];
        [self performSelector:@selector(startReplication) withObject:nil afterDelay:4];
    }
    [self _startAllPeriodicOperations];

}

- (void) createDatabase:(ORCouchDB*)aDBRef;
{
	[aDBRef createDatabase:kCreateDB views:nil];
}

- (void) deleteDatabases
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    [self deleteDatabase:[self statusDBRef]];
    [self deleteDatabase:[self remoteDBRef]];
}

- (void) deleteDatabase:(ORCouchDB*)aDBRef;
{
    [aDBRef deleteDatabase:kDeleteDB];
}

- (void) addUpdateHandler
{
    [self addUpdateHandler:[self statusDBRef]];
}

- (void) addUpdateHandler:(ORCouchDB*)aDBRef;
{
    NSBundle* mainBundle = [NSBundle mainBundle];
    
	NSString*  filePath = [mainBundle pathForResource: @"CouchUpdateHandler" ofType: @"txt"];
    if([[NSFileManager defaultManager] fileExistsAtPath:filePath] ){
		NSString* aHandler  = [NSString stringWithContentsOfFile:filePath encoding:NSASCIIStringEncoding error:nil];
        [aDBRef addUpdateHandler:kAddUpdateHandler updateHandler:aHandler];
    }
}


- (void) createHistoryDatabase
{
    [self createHistoryDatabase:[self historyDBRef]];
}

- (void) createHistoryDatabase:(ORCouchDB*)aDBRef;
{
	NSString*     aMap;
	NSString*     aReduce;
	NSDictionary* aMapDictionary;
	NSMutableDictionary* aViewDictionary = [NSMutableDictionary dictionary];
    
	aMap            = @"function(doc) {if(doc.title == \"adcs\"){emit([doc.time,doc.title],doc);}}";
	aMapDictionary  = [NSDictionary dictionaryWithObject:aMap forKey:@"map"];
	[aViewDictionary setObject:aMapDictionary forKey:@"adcs"];
    	
    NSBundle* mainBundle = [NSBundle mainBundle];
	NSString*   mapPath = [mainBundle pathForResource: @"CouchHistoryAveMap" ofType: @"txt"];
	NSString*   reducePath = [mainBundle pathForResource: @"CouchHistoryAveReduce" ofType: @"txt"];
    if([[NSFileManager defaultManager] fileExistsAtPath:mapPath] && [[NSFileManager defaultManager] fileExistsAtPath:reducePath] ){
		aMap            = [NSString stringWithContentsOfFile:mapPath encoding:NSASCIIStringEncoding error:nil];
		aReduce         = [NSString stringWithContentsOfFile:reducePath encoding:NSASCIIStringEncoding error:nil];
        aMapDictionary  = [NSDictionary dictionaryWithObjectsAndKeys:aMap,@"map",aReduce,@"reduce", nil];
        [aViewDictionary setObject:aMapDictionary   forKey:@"ave"];
    }
	
    
	mapPath = [mainBundle pathForResource: @"CouchHistoryValuesMap" ofType: @"txt"];
    if([[NSFileManager defaultManager] fileExistsAtPath:mapPath] ){
		aMap         = [NSString stringWithContentsOfFile:mapPath encoding:NSASCIIStringEncoding error:nil];
        aMapDictionary  = [NSDictionary dictionaryWithObjectsAndKeys:aMap, @"map",@"history",@"mapName",nil];
        [aViewDictionary setObject:aMapDictionary   forKey:@"values"];
   }
    
    mapPath = [mainBundle pathForResource: @"CouchHistoryEventsMap" ofType: @"txt"];
    if([[NSFileManager defaultManager] fileExistsAtPath:mapPath] ){
		aMap         = [NSString stringWithContentsOfFile:mapPath encoding:NSASCIIStringEncoding error:nil];
        aMapDictionary  = [NSDictionary dictionaryWithObjectsAndKeys:aMap, @"map",@"history",@"mapName",nil];
        [aViewDictionary setObject:aMapDictionary   forKey:@"events"];
   }

	NSDictionary* dbViews = [NSDictionary dictionaryWithObjectsAndKeys:
                             @"javascript",@"language",
							  aViewDictionary,@"views",
                             nil];
	
	[aDBRef createDatabase:kCreateDB views:dbViews];
}

- (void) createRemoteDataBases;
{			
	[[self remoteHistoryDBRef]  createDatabase:kCreateRemoteDB views:nil];
	[[self remoteDBRef]         createDatabase:kCreateRemoteDB views:nil];
    for(id aKey in [customDataBases allKeys]){
        [[self remoteHistoryDBRef:aKey]  createDatabase:kCreateRemoteDB views:nil];
    }
}

- (void) startReplication
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(updateDatabaseStats) object:nil];
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(startReplication) object:nil];
    @try {
        [self replicate:YES restart:replicationRunning];
    }
    @catch(NSException* e){
        NSLog(@"%@ %@ Exception: %@\n",[self fullID],NSStringFromSelector(_cmd),e);
    }
    @finally {
        [self performSelector:@selector(updateDatabaseStats) withObject:nil afterDelay:4];
        [self performSelector:@selector(startReplication) withObject:nil afterDelay:3600];
    }
}

- (void) replicate:(BOOL)continuously
{
    [self replicate:continuously restart:NO];
}

- (void)replicate:(BOOL)continuously restart:(BOOL)aRestart
{
    NSString* tag;
    
    if(!aRestart) tag = kReplicateDB;
    else         tag = kRestartReplicateDB;
    
	[[self remoteHistoryDBRef]  replicateLocalDatabase:tag continous:continuously];
	[[self remoteDBRef]         replicateLocalDatabase:tag continous:continuously];
    for(id aKey in [customDataBases allKeys]){
        [[self remoteHistoryDBRef:aKey]  replicateLocalDatabase:tag continous:YES];
    }
}

- (void) updateProcesses
{
	if(!stealthMode){
        @try {
            [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(updateProcesses) object:nil];
            NSArray* theProcesses = [[[[self document] collectObjectsOfClass:NSClassFromString(@"ORProcessModel")] retain] autorelease];
        
            NSMutableArray* arrayForDoc = [NSMutableArray array];
            if([theProcesses count]){
                for(id aProcess in theProcesses){
                    NSString* shortName     = [aProcess shortName];
                    
                    NSDate *localDate = [aProcess lastSampleTime];
                    
                    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
                    dateFormatter.dateFormat = @"yyyy/MM/dd HH:mm:ss";
                    
                    NSTimeZone *gmt = [NSTimeZone timeZoneWithAbbreviation:@"GMT"];
                    [dateFormatter setTimeZone:gmt];
                    NSString *lastTimeStamp = [dateFormatter stringFromDate:localDate];
                    NSDate* gmtTime = [dateFormatter dateFromString:lastTimeStamp];
                    uint32_t secondsSince1970 = [gmtTime timeIntervalSince1970];
                    [dateFormatter release];
                    
                    if(![lastTimeStamp length]) lastTimeStamp = @"0";
                    if(![shortName length]) shortName = @"Untitled";
                    
                    NSString* s = [aProcess report];
                    
                    NSDictionary* processInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                                                 [aProcess fullID],@"name",
                                                 shortName,@"title",
                                                 lastTimeStamp,@"timestamp",
                                                 [NSNumber numberWithUnsignedLong: secondsSince1970],		@"time",
                                                 s,@"data",
                                                 [NSNumber numberWithUnsignedLong:[aProcess processRunning]] ,@"state",
                                                 nil];
                    [arrayForDoc addObject:processInfo];
                }
            }
        
            NSDictionary* processInfo  = [NSDictionary dictionaryWithObjectsAndKeys:@"processinfo",@"_id",@"processinfo",@"name",arrayForDoc,@"processlist",@"processes",@"type",nil];
            [[self statusDBRef] updateDocument:processInfo documentId:@"processinfo" tag:kDocumentUpdated];
        }
        @catch(NSException* e){
            NSLog(@"%@ %@ Exception: %@\n",[self fullID],NSStringFromSelector(_cmd),e);
        }
        @finally {
            [self performSelector:@selector(updateProcesses) withObject:nil afterDelay:30];
        }

	}
}

- (void) updateBurstRecord
{
        if(!stealthMode){
            @try {
                [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(updateBurstRecord) object:nil];
                NSArray* theBurstMonitor = [[[[self document] collectObjectsOfClass:NSClassFromString(@"ORBurstMonitorModel")] retain] autorelease];
                if([theBurstMonitor count]){
                    for(id aMonitor in theBurstMonitor){
                        NSDate *currentDate = [NSDate date];
                        NSTimeInterval Timestamp = [currentDate timeIntervalSince1970];
                                
                        NSDictionary* burstInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                                                   @"burstinfo", @"_id",
                                                   @"burstinfo", @"type",
                                                   [NSNumber numberWithInteger:Timestamp],@"time",
                                                   [NSNumber numberWithUnsignedShort:[aMonitor minimumEnergyAllowed]],@"minimumADC",
                                                   [NSNumber numberWithUnsignedShort:[aMonitor nHit]], @"nHit",
                                                   [NSNumber numberWithUnsignedShort:[aMonitor numBurstsNeeded]], @"numBurstsNeeded",
                                                   [NSNumber numberWithDouble:[aMonitor timeWindow]], @"timeWindow",
                                                   nil];
                        [[self statusDBRef] updateDocument:burstInfo  documentId:@"burstinfo" tag:kDocumentUpdated];
                    }
                }
            }
            @catch (NSException* e){
                NSLog(@"%@ %@ Exception: %@\n",[self fullID],NSStringFromSelector(_cmd),e);
            }
            @finally{
                [self performSelector:@selector(updateBurstRecord) withObject:nil afterDelay:60];
            }

        }
}

- (void) updateMachineRecord
{
        if(!stealthMode){
            @try {
                [NSObject  cancelPreviousPerformRequestsWithTarget:self selector:@selector(updateMachineRecord) object:nil];
                if([thisHostAdress length]==0){
                    //only have to get this once
                    struct ifaddrs *ifaddr, *ifa;
                    if (getifaddrs(&ifaddr) == 0) {
                        // Successfully received the structs of addresses.
                        char tempInterAddr[INET_ADDRSTRLEN];
                        NSMutableArray* names = [NSMutableArray array];
                        // The following is a replacement for [[NSHost currentHost] addresses].  The problem is
                        // that the NSHost call can do reverse DNS calls which block and are *very* slow.  The
                        // following is much faster.
                        for (ifa = ifaddr; ifa != nil; ifa = ifa->ifa_next) {
                            // skip IPv6 addresses
                            if (ifa->ifa_addr->sa_family != AF_INET) continue;
                            inet_ntop(AF_INET,
                                      &((struct sockaddr_in *)ifa->ifa_addr)->sin_addr,
                                      tempInterAddr,
                                      sizeof(tempInterAddr));
                            [names addObject:[NSString stringWithCString:tempInterAddr encoding:NSASCIIStringEncoding]];
                        }
                        freeifaddrs(ifaddr);
                        // Now enumerate and find the first non-loop-back address.
                        NSEnumerator* e = [names objectEnumerator];
                        id aName;
                        while(aName = [e nextObject]){
                            if([aName rangeOfString:@".0.0."].location == NSNotFound){
                                thisHostAdress = [aName copy];
                                break;
                            }
                        }
                    }
                }
                if(!thisHostAdress)thisHostAdress = @"";
                
                NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
                dateFormatter.dateFormat = @"yyyy/MM/dd HH:mm:ss";
                
                NSTimeZone *gmt = [NSTimeZone timeZoneWithAbbreviation:@"GMT"];
                [dateFormatter setTimeZone:gmt];
                NSString *lastTimeStamp = [dateFormatter stringFromDate:[NSDate date]];
                NSDate* gmtTime = [dateFormatter dateFromString:lastTimeStamp];
                uint32_t secondsSince1970 = [gmtTime timeIntervalSince1970];
                [dateFormatter release];
                
                
                if(![lastTimeStamp length]) lastTimeStamp = @"0";
                
                NSMutableDictionary* machineInfo = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                                        @"machineinfo", @"_id",
                                                        @"machineinfo", @"type",
                                                        [NSNumber numberWithLong:[[(ORAppDelegate*)(ORAppDelegate*)[NSApp delegate] memoryWatcher] accurateUptime]], @"uptime",
                                                        computerName(), @"name",
                                                        macAddress(),   @"hw_address",
                                                        thisHostAdress, @"ip_address",
                                                        fullVersion(),  @"version",
                                                        lastTimeStamp,  @"timestamp",
                                                        [NSNumber numberWithUnsignedLong: secondsSince1970],		@"time",
        nil];
                
                NSFileManager* fm = [NSFileManager defaultManager];
                
                NSArray* diskInfo = [fm mountedVolumeURLsIncludingResourceValuesForKeys:0 options:NSVolumeEnumerationSkipHiddenVolumes];
                NSMutableArray* diskStats = [NSMutableArray array];
                for(id aVolume in diskInfo){
                    NSError *fsError = nil;
                    aVolume = [aVolume relativePath];
                    NSDictionary *fsDictionary = [fm attributesOfFileSystemForPath:aVolume error:&fsError];
                    
                    if (fsDictionary != nil){
                        double freeSpace   = [[fsDictionary objectForKey:@"NSFileSystemFreeSize"] doubleValue]/1E9;
                        double totalSpace  = [[fsDictionary objectForKey:@"NSFileSystemSize"] doubleValue]/1E9;
                        double percentUsed   = 100*(totalSpace-freeSpace)/totalSpace;
                        if([aVolume rangeOfString:@"Volumes"].location !=NSNotFound){
                            aVolume = [aVolume substringFromIndex:9];
                        }
                        NSDictionary* dict = [NSDictionary dictionaryWithObject:[NSString stringWithFormat:@"%.02f%% Full",percentUsed] forKey:aVolume];
                        [diskStats addObject:dict];
                     }
                }
                if([diskStats count]>0) [machineInfo setObject:diskStats forKey:@"diskInfo"];

                [[self statusDBRef] updateDocument:machineInfo documentId:@"machineinfo" tag:kDocumentUpdated];
            }
            @catch (NSException* e){
                NSLog(@"%@ %@ Exception: %@\n",[self fullID],NSStringFromSelector(_cmd),e);
            }
            @finally {
                [self performSelector:@selector(updateMachineRecord) withObject:nil afterDelay:60];
            }
        }

}

- (void) processElementStateChanged:(NSNotification*)aNote
{
	if(!historyUpdateScheduled){
		[self performSelector:@selector(updateHistory) withObject:nil afterDelay:60];
		historyUpdateScheduled = YES;
	}
}

- (void) updateHistory
{
	historyUpdateScheduled = NO;
	if(!stealthMode && keepHistory){
		[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(updateHistory) object:nil];
        NSArray* theProcesses = [[[[self document] collectObjectsOfClass:NSClassFromString(@"ORProcessModel")] retain] autorelease];
                
        for(id aProcess in theProcesses){
            if([aProcess processRunning]){
                NSString* shortName     = [aProcess shortName];
                NSDate *localDate = [aProcess lastSampleTime];
                
                NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
                dateFormatter.dateFormat = @"yyyy/MM/dd HH:mm:ss";
                
                NSTimeZone *gmt = [NSTimeZone timeZoneWithAbbreviation:@"GMT"];
                [dateFormatter setTimeZone:gmt];
                NSString *lastTimeStamp = [dateFormatter stringFromDate:localDate];
                NSDate* gmtTime = [dateFormatter dateFromString:lastTimeStamp];
                uint32_t secondsSince1970 = [gmtTime timeIntervalSince1970];
                [dateFormatter release];
                
                
                if(![lastTimeStamp length]) lastTimeStamp = @"0";
                if(![shortName length]) shortName = @"Untitled";
                
                NSMutableDictionary* processDictionary = [aProcess processDictionary];
                if([processDictionary count]){
                    
                    NSMutableDictionary* processInfo = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                                [aProcess fullID],	@"name",
                                                shortName,			@"title",
                                                lastTimeStamp,		@"timestamp",
                                                [NSNumber numberWithUnsignedLong: secondsSince1970],		@"time",
                                                nil];
                    
                    [processInfo addEntriesFromDictionary:processDictionary];
                    [[self historyDBRef] addDocument:processInfo tag:kDocumentAdded];
                }
            }
        }
		
	}
}

- (void) recordEvent:(NSString*)eventName document:aDocument
{
    if (stealthMode) return;
    
    NSDate* localDate = [NSDate date];
    
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.dateFormat = @"yyyy/MM/dd HH:mm:ss";
    
    NSTimeZone *gmt = [NSTimeZone timeZoneWithAbbreviation:@"GMT"];
    [dateFormatter setTimeZone:gmt];
    NSString* lastTimeStamp = [dateFormatter stringFromDate:localDate];
    NSDate* gmtTime = [dateFormatter dateFromString:lastTimeStamp];
    uint32_t secondsSince1970 = [gmtTime timeIntervalSince1970];
    [dateFormatter release];
    
    NSMutableDictionary* eventInfo = [NSMutableDictionary dictionaryWithDictionary:aDocument];
    [eventInfo setObject:eventName forKey:@"name"];
    [eventInfo setObject:@"Events" forKey:@"title"];
    [eventInfo setObject:lastTimeStamp forKey:@"timestamp"];
    [eventInfo setObject:[NSNumber numberWithUnsignedLong: secondsSince1970] forKey:@"time"];
 
    
    id aDataBaseRef = [self historyDBRef];
    [self checkDataBaseExists:aDataBaseRef];

    
    [aDataBaseRef addDocument:eventInfo tag:kDocumentAdded];
	
	[aDataBaseRef updateEventCatalog:eventInfo documentId:@"eventCatalog" tag:kDocumentAdded];

}

- (void) updateDatabaseStats
{
    if (stealthMode) return;
    @try {
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(updateDatabaseStats) object:nil];
        [[self statusDBRef] databaseInfo:self tag:kInfoInternalDB];
        if(keepHistory)[[self historyDBRef] databaseInfo:self tag:kInfoHistoryDB];
        [self getRemoteInfo:NO];
    }
    @catch (NSException* e){
        NSLog(@"%@ %@ Exception: %@\n",[self fullID],NSStringFromSelector(_cmd),e);
    }
    @finally {
        [self performSelector:@selector(updateDatabaseStats) withObject:nil afterDelay:kUpdateStatsInterval];
    }
}

- (void) setDBInfo:(NSDictionary*)someInfo
{
	@synchronized(self){
		[someInfo retain];
		[dBInfo release];
		dBInfo = someInfo;
	}
	[[NSNotificationCenter defaultCenter] postNotificationName:ORCouchDBModelDBInfoChanged object:self];
}

- (void) setDocuments:(NSDictionary*)someInfo
{
	@synchronized(self){
		[someInfo retain];
		[docList release];
		docList = someInfo;
	}
	[[NSNotificationCenter defaultCenter] postNotificationName:ORCouchDBModelDBInfoChanged object:self];
}

- (void) setDBHistoryInfo:(NSDictionary*)someInfo
{
	@synchronized(self){
		[someInfo retain];
		[dBHistoryInfo release];
		dBHistoryInfo = someInfo;
	}
	[[NSNotificationCenter defaultCenter] postNotificationName:ORCouchDBModelDBInfoChanged object:self];
}

- (NSDictionary*) dBInfo
{
	return [[dBInfo retain] autorelease];
}
- (NSDictionary*) dBHistoryInfo
{
	return [[dBHistoryInfo retain] autorelease];
}

- (void) couchDBResult:(id)aResult tag:(NSString*)aTag op:(id)anOp
{
    
    // a couple of things below call methods that can update the GUI.
    // Must do that on the main thread
	@synchronized(self){
		if([aResult isKindOfClass:[NSDictionary class]]){
			NSString* message = [aResult objectForKey:@"Message"];
			if(message){
				if([aTag isEqualToString:kCreateRemoteDB]){
					NSLog(@"Following Couch Message is from: %@\n",remoteHostName);
				}
                if([aTag isEqualToString:kCreateDB]){
                    if([[aResult objectForKey:@"Reason"] rangeOfString:@"already exists"].location == NSNotFound){
                        [aResult prettyPrint:@"CouchDB Message:"];
                    }
                }
				else [aResult prettyPrint:@"CouchDB Message:"];
			}
			else {
				if([aTag isEqualToString:kInfoDB]){
					[aResult prettyPrint:@"CouchDB Info:"];
				}
				else if([aTag isEqualToString:kDocumentAdded]){
					//ignore
				}
				else if([aTag isEqualToString:kRestartReplicateDB]){
					//ignore
				}
				else if([aTag isEqualToString:kCreateDB]){
					[aResult prettyPrint:@"CouchDB Message:"];
				}
				else if([aTag isEqualToString:kCreateRemoteDB]){
					[aResult prettyPrint:@"Remote Create Action:"];
				}
				else if([aTag isEqualToString:kDeleteDB]){
                    if(![aResult objectForKey:@"error"]){
                        [aResult prettyPrint:@"Deleted Main Database:"];
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self setUsingUpdateHandler:NO];
                        });

                    }
                    else {
                        [aResult prettyPrint:@"Deleted Main Database FAILED:"];
                    }
				}
				
				else if([aTag isEqualToString:kInfoInternalDB]){
					[self performSelectorOnMainThread:@selector(setDBInfo:) withObject:aResult waitUntilDone:NO];
				}
				else if([aTag isEqualToString:kInfoHistoryDB]){
					[self performSelectorOnMainThread:@selector(setDBHistoryInfo:) withObject:aResult waitUntilDone:NO];
				}
				
				else if([aTag isEqualToString:@"Message"]){
					[aResult prettyPrint:@"CouchDB Message:"];
				}
				else if([aTag isEqualToString:kCompactDB]){
					//[aResult prettyPrint:@"CouchDB Compacted:"];
				}
                else if([aTag isEqualToString:kAddUpdateHandler]){
                    if([[aResult objectForKey:@"error"] isEqualToString:@"conflict"]){
                        dispatch_async(dispatch_get_main_queue(), ^{
                                [self setUsingUpdateHandler:YES];
                        });
                    }
                    else if(![aResult objectForKey:@"error"]){
                        [aResult prettyPrint:@"CouchDB Update Handler Installation:"];
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self setUsingUpdateHandler:YES];
                        });
                   }
                    else {
                        [aResult prettyPrint:@"CouchDB Update Handler Installation Error:"];
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self setUsingUpdateHandler:NO];
                        });
                    }
				}

				else {
                    if( [[aResult objectForKey:@"_local_id"] rangeOfString:@"+continuous"].location == NSNotFound &&
                        [[aResult objectForKey:@"ok"] intValue] != 1){
                         [aResult prettyPrint:@"CouchDB"];
                    }
				}
			}
		}
		else if([aResult isKindOfClass:[NSArray class]]){
			if([aTag isEqualToString:kListDB]){
				[aResult prettyPrint:@"CouchDB List:"];
			}
			else if([aTag isEqualToString:kRemoteInfo]){
				[self processRemoteTaskList:aResult verbose:NO];
			}
			else if([aTag isEqualToString:kRemoteInfoVerbose]){
				[self processRemoteTaskList:aResult verbose:YES];
			}
			else [aResult prettyPrint:@"CouchDB"];
		}
		else {
			NSLog(@"%@\n",aResult);
		}
	}
}
- (void) processRemoteTaskList:(NSArray*)aList verbose:(BOOL)verbose
{
    if([remoteHostName length]==0)return;
	if([aList count] && verbose)NSLog(@"Couch Remote Tasks:\n");
    dispatch_async(dispatch_get_main_queue(), ^{
        [self setReplicationRunning:NO];
    });

	for(id aTask in aList){
		if([[[aTask objectForKey:@"type"] lowercaseString] isEqualToString:@"replication"]){
			NSArray* keys = [aTask allKeys];
			for(id aKey in keys){
				id item = [aTask objectForKey:aKey];
				if([item isKindOfClass:NSClassFromString(@"NSString")]){
					if([(NSString*)item rangeOfString:remoteHostName].location != NSNotFound){
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self setReplicationRunning:YES];
                        });
                        wasReplicationRunning = YES;
                        replicationCheckCount = 0;
					}
				}
			}
		}
		if(verbose)NSLog(@"%@\n",aTask);
	}
    [self performSelectorOnMainThread:@selector(checkReplication) withObject:nil waitUntilDone:NO];
}

- (void) checkReplication
{
    if(wasReplicationRunning && !replicationRunning){
        replicationCheckCount++;
        if(replicationCheckCount==5 || replicationCheckCount==7){
            [self startReplication];
        }
        if(replicationCheckCount >= 10){
            if(!replicationAlarm){
                NSString* s = [NSString stringWithFormat:@"CouchDB (%u)",[self uniqueIdNumber]];
                replicationAlarm = [[ORAlarm alloc] initWithName:s severity:kImportantAlarm];
                [replicationAlarm setSticky:YES];
                [replicationAlarm setHelpString:@"CouchDB replication has failed.\nORCA has tried repeatedly and has been unable to restart it. Intervention is required. Contact your database manager.\n\nThis alarm will not go away until the problem is cleared. Acknowledging the alarm will silence it."];
                [replicationAlarm postAlarm];
            }
            replicationCheckCount = 0;
        }
    }
    else {
        [replicationAlarm clearAlarm];
        [replicationAlarm release];
        replicationAlarm = nil;
    }

}

- (void) periodicCompact
{
    if (stealthMode) return;
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(periodicCompact) object:nil];
    @try {
        [self compactDatabase];
    }
    @catch (NSException* e){
        NSLog(@"%@ %@ Exception: %@\n",[self fullID],NSStringFromSelector(_cmd),e);
    }
    @finally {
        [self performSelector:@selector(periodicCompact) withObject:nil afterDelay:60*60];
    }
}

- (void) compactDatabase
{
    [[self statusDBRef]  compactDatabase:self tag:kCompactDB];
    [[self historyDBRef] compactDatabase:self tag:kCompactDB];
    
	[self performSelector:@selector(updateDatabaseStats) withObject:nil afterDelay:4];
}

- (void) listDatabases
{
	[[self statusDBRef] listDatabases:self tag:kListDB];
}

- (void) getRemoteInfo:(BOOL)verbose
{
	if(verbose)[[self statusDBRef] listTasks:self tag:kRemoteInfoVerbose];
	else	   [[self statusDBRef] listTasks:self tag:kRemoteInfo];
}

- (void) databaseInfo:(BOOL)toStatusWindow
{
	if(toStatusWindow)	[[self statusDBRef] databaseInfo:self tag:kInfoDB];
	else				[[self statusDBRef] databaseInfo:self tag:kInfoInternalDB];
}

- (void) runStatusChanged:(NSNotification*)aNote
{
	[self updateRunState:[aNote object]];
	[self updateDataSets];
}

- (void) runStarted:(NSNotification*)aNote
{
    NSDictionary* info = [aNote userInfo];
    if([[info objectForKey:@"kRunMode"] intValue]==0){
        uint32_t runNumberLocal     = (uint32_t)[[info objectForKey:@"kRunNumber"] unsignedLongValue];
        uint32_t subRunNumberLocal  = (uint32_t)[[info objectForKey:@"kSubRunNumber"]unsignedLongValue];
        NSString* comment;
        if(subRunNumberLocal==0) comment = [NSString stringWithFormat:@"Run %u Started",runNumberLocal];
        else                     comment = [NSString stringWithFormat:@"Run %u.%u Started",runNumberLocal,subRunNumberLocal];
        
        NSDictionary* doc = [NSDictionary dictionaryWithObjectsAndKeys:
                             [NSNumber numberWithUnsignedLong:runNumberLocal]   , @"RunNumber",
                             [NSNumber numberWithUnsignedLong:subRunNumberLocal], @"SubRunNumber",
                             comment,@"comment",
                             @"S",@"Symbol",
                             nil];
        
        
        
        [self recordEvent:@"RunStarted" document:doc];
    }
    [self updateRunInfo];
}

- (void) runStopped:(NSNotification*)aNote
{
    NSDictionary* info = [aNote userInfo];
    if([[info objectForKey:@"kRunMode"] intValue]==0){
        uint32_t runNumberLocal     = (uint32_t)[[info objectForKey:@"kRunNumber"] unsignedLongValue];
        uint32_t subRunNumberLocal  = (uint32_t)[[info objectForKey:@"kSubRunNumber"]unsignedLongValue];
        float elapsedTimeLocal   = [[info objectForKey:@"kElapsedTime"]floatValue];
        NSString* comment;
        if(subRunNumberLocal==0) comment = [NSString stringWithFormat:@"Run %u Stopped",runNumberLocal];
        else                     comment = [NSString stringWithFormat:@"Run %u.%u Stopped",runNumberLocal,subRunNumberLocal];
        
        
        NSDictionary* doc = [NSDictionary dictionaryWithObjectsAndKeys:
                             [NSNumber numberWithUnsignedLong:runNumberLocal]   , @"RunNumber",
                             [NSNumber numberWithUnsignedLong:subRunNumberLocal], @"SubRunNumber",
                             [NSNumber numberWithFloat:elapsedTimeLocal],         @"ElapsedTime",
                             
                             comment,@"comment",
                             @"E",@"Symbol",
                             nil];

        [self recordEvent:@"RunStopped" document:doc];
    }
    [self updateRunInfo];
}

- (void) clearAlert
{
    [self setAlertMessage:@""];
    NSDictionary* alertMessageDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
                                            @"",                        @"alertMessage",
                                            [NSNumber numberWithInt:0], @"alertMessageType",
                                            nil];
    [self addObject:self valueDictionary:alertMessageDictionary];
    NSLog(@"Database operator message cleared from database\n");

}
- (void) postAlert
{
    NSString* messageToPost;
    if([alertMessage length]==0)messageToPost = @"";
    else messageToPost = alertMessage;
    
    NSDictionary* alertMessageDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
                                            messageToPost,                      @"alertMessage",
                                            [NSNumber numberWithInt:alertType], @"alertMessageType",
                                            nil];
    [self addObject:self valueDictionary:alertMessageDictionary];
    NSLog(@"Operator message posted To database: %@\n",messageToPost);

}

- (void) runOptionsOrTimeChanged:(NSNotification*)aNote
{
    if(!scheduledForRunInfoUpdate){
        scheduledForRunInfoUpdate = YES;
        [self performSelector:@selector(updateRunState:) withObject:[aNote object] afterDelay:5];
    }
}

- (void) addObjectValueRecord:(NSNotification*)aNote
{
    [self addObject:[aNote object] valueDictionary:[aNote userInfo]];
}

- (void) addObject:(OrcaObject*)anObj valueDictionary:(NSDictionary*)aDictionary
{
    NSString* customDataBase = [aDictionary objectForKey:@"CustomDataBase"];
    if(customDataBase){
        aDictionary = [aDictionary objectForKey:@"DataBaseRecord"];
        [self addObject:anObj valueDictionary:aDictionary dataBaseRef:[self statusDBRef:customDataBase]];
    }
    else {
        [self addObject:anObj valueDictionary:aDictionary dataBaseRef:[self statusDBRef]];
    }
}

- (void) addObject:(OrcaObject*)anObj valueDictionary:(NSDictionary*)aDictionary dataBaseRef:(ORCouchDB*)aDataBaseRef
{
 //these are special records that any object can insert into the database via this notification
 //the userInfo should just be a dictionary that you want to go into the database
    if(!stealthMode){

        [self checkDataBaseExists:aDataBaseRef];

        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        dateFormatter.dateFormat = @"yyyy/MM/dd HH:mm:ss";
        
        NSTimeZone* gmt = [NSTimeZone timeZoneWithAbbreviation:@"GMT"];
        [dateFormatter setTimeZone:gmt];
        NSString*   lastTimeStamp       = [dateFormatter stringFromDate:[NSDate date]];
        NSDate*     gmtTime             = [dateFormatter dateFromString:lastTimeStamp];
        uint32_t secondsSince1970  = [gmtTime timeIntervalSince1970];
        [dateFormatter release];
        
        NSString* anId = [anObj fullID];
        if([anId length] && aDictionary){
            if(![lastTimeStamp length]) lastTimeStamp = @"0";
            
            NSMutableDictionary* aRecord = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                                anId,           @"_id",
                                                anId,           @"name",
                                                anId,			@"title",
                                                lastTimeStamp,	@"timestamp",
                                                [NSNumber numberWithUnsignedLong: secondsSince1970],		@"time",
                                                nil];
            
            [aRecord addEntriesFromDictionary:aDictionary];
            [aDataBaseRef updateDocument:aRecord documentId:anId tag:kDocumentAdded];
        }
    }
}

- (void) postOrPutCustomRecord:(NSNotification*)aNote
{
    // Notifications can be sent to post or put a document to a particular address.
    // The address may be a combination of database name and name of documents, so that, e.g.
    // one may post to update handlers or other parts of the couch API.
    // The document is sent in the body in the http request.
    // The userInfo of the notification should be formulated like:
    //
    // {
    //   "Address" : "path/to/destination",
    //   "Document"   : { ... }.
    // }
    //
    // (NSDictionary).
    //
    // The notification can also pass itself as an object to have its delegate called.
    if(!stealthMode){

        NSDictionary* aDict = [aNote userInfo];
        NSString* postToAddress = [aDict objectForKey:@"Address"];
        NSDictionary* document = [aDict objectForKey:@"Document"];
        if (postToAddress && document) {
            [self postOrPutCustomRecord:document toAddress:postToAddress withDelegate:[aNote object]];
        } else {
            NSLog(@"postOrPutCustomRecord notification not properly constructed\n");
        }
    }
}

- (void) postOrPutCustomRecord:(NSDictionary*)aRecord toAddress:(NSString*)anAddr withDelegate:(id)del
{
    // See documentation for postOrPutCustomRecord:(NSNotification*)aNote
    if(!stealthMode){

        ORCouchDB* ref = [self statusDBRef:anAddr];
        [ref setDelegate:del];
        [self postOrPutCustomRecord:aRecord dataBaseRef:ref];
    }
}

- (void) postOrPutCustomRecord:(NSDictionary*)aRecord dataBaseRef:(ORCouchDB*)aDataBaseRef
{
    // See documentation for postOrPutCustomRecord:(NSNotification*)aNote
    if(!stealthMode){
        [aDataBaseRef addDocument:aRecord tag:nil];
    }
}

- (void) checkDataBaseExists:(ORCouchDB*)aDataBase
{
    //this is mainly to help make sure that custom databases are created. The machine and normal history databases should take careof themselves. 
    if(!customDataBases)customDataBases = [[NSMutableDictionary dictionary]retain];
    NSString* dbName = [aDataBase database];
    if(![customDataBases objectForKey:dbName]){
        if([dbName hasPrefix:@"history"]){
            [self createHistoryDatabase:aDataBase];
        }
        else {
            [self createDatabase:aDataBase];
        }
        [customDataBases setObject:dbName forKey:dbName];
    }
}

- (void) addAdcsToHistoryRecord:(NSNotification*)aNote
{
    if(!stealthMode){
        [self addObject:[aNote object] adcDictionary:[aNote userInfo]];
    }
}

- (void) addObject:(OrcaObject*)anObj adcDictionary:(NSDictionary*)aDictionary
{
    if(!stealthMode){
        NSString* customDataBase = [aDictionary objectForKey:@"CustomDataBase"];
        if(customDataBase){
            aDictionary = [aDictionary objectForKey:@"DataBaseRecord"];
            [self addObject:anObj adcDictionary:aDictionary dataBaseRef:[self historyDBRef:[@"history_" stringByAppendingString:customDataBase]]];
        }
        else {
            [self addObject:anObj adcDictionary:aDictionary dataBaseRef:[self historyDBRef]];
        }
    }
}

- (void) addObject:(OrcaObject*)anObj adcDictionary:(NSDictionary*)aDictionary dataBaseRef:(ORCouchDB*)aDataBaseRef
{
    if(!stealthMode){
        [self checkDataBaseExists:aDataBaseRef];
        //these are special records that any object can insert into the database via this notification
        //the userInfo should just be a dictionary that you want to go into the database
        
        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        dateFormatter.dateFormat = @"yyyy/MM/dd HH:mm:ss";
        
        NSTimeZone* gmt = [NSTimeZone timeZoneWithAbbreviation:@"GMT"];
        [dateFormatter setTimeZone:gmt];
        NSString*   lastTimeStamp       = [dateFormatter stringFromDate:[NSDate date]];
        NSDate*     gmtTime             = [dateFormatter dateFromString:lastTimeStamp];
        uint32_t secondsSince1970  = [gmtTime timeIntervalSince1970];
        [dateFormatter release];
        
        NSString* anId = [anObj fullID];
        if([anId length] && aDictionary){
            if(![lastTimeStamp length]) lastTimeStamp = @"0";
            
            
            NSMutableDictionary* aRecord = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                            lastTimeStamp,	@"timestamp",
                                            [NSNumber numberWithUnsignedLong: secondsSince1970],		@"time",
                                            nil];
            
            [aRecord addEntriesFromDictionary:aDictionary];
            [aDataBaseRef addDocument:aRecord tag:kDocumentAdded];
        }
    }
}

- (void) updateRunInfo
{
    if(!stealthMode){
        NSArray* runObjects = [[self document] collectObjectsOfClass:NSClassFromString(@"ORRunModel")];
        if([runObjects count]){
            ORRunModel* rc = [runObjects objectAtIndex:0];
            [self updateRunState:rc];
            [self updateDataSets];
        }
    }
}

- (void) updateRunState:(ORRunModel*)rc
{
	if(!stealthMode){
		@try {
            [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(updateRunState:) object:rc];
            scheduledForRunInfoUpdate = NO;
			id nextObject = [self nextObject];
			NSString* experimentName;
			if(!nextObject)	experimentName = @"TestStand";
			else {
				experimentName = [nextObject className];
				if([experimentName hasPrefix:@"OR"])experimentName = [experimentName substringFromIndex:2];
				if([experimentName hasSuffix:@"Model"])experimentName = [experimentName substringToIndex:[experimentName length] - 5];
			}
			
			NSMutableDictionary* runInfo = [NSMutableDictionary dictionaryWithDictionary:[rc fullRunInfo]];
			runNumber = [rc runNumber];
			subRunNumber = [rc subRunNumber];
			if(![rc isRunning] && ![rc offlineRun]){
				runNumber=0;
				subRunNumber=0;
			}
            
            NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
            dateFormatter.dateFormat = @"yyyy/MM/dd HH:mm:ss";
            
            NSTimeZone* gmt = [NSTimeZone timeZoneWithAbbreviation:@"GMT"];
            [dateFormatter setTimeZone:gmt];
            NSString *lastTimeStamp = [dateFormatter stringFromDate:[NSDate date]];
            [dateFormatter release];
            [runInfo setObject:@"runinfo" forKey:@"_id"];
			[runInfo setObject:@"runinfo" forKey:@"type"];
			[runInfo setObject:experimentName forKey:@"experiment"];
            [runInfo setObject:lastTimeStamp forKey:@"timestamp"];
            
			[[self statusDBRef] updateDocument:runInfo documentId:@"runinfo" tag:kDocumentUpdated];
			
			int runState = [[runInfo objectForKey:@"state"] intValue];
			if(runState == eRunInProgress){
				if(!dataMonitors){
					dataMonitors = [[NSMutableArray array] retain];
					NSArray* list = [[self document] collectObjectsOfClass:NSClassFromString(@"ORHistoModel")];
					for(ORDataChainObject* aDataMonitor in list){
						if([aDataMonitor involvedInCurrentRun]){
							[dataMonitors addObject:aDataMonitor];
						}
					}
				}
			}
			else {
				[dataMonitors release];
				dataMonitors = nil;
				[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(updateDataSets) object:nil];
			}
		}
		@catch (NSException* e) {
			//silently catch and continue
		}
	}
}

- (void) updateExperiment
{
	if(!stealthMode){
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(updateExperiment) object:nil];
        @try {
            id experiment = [self objectConnectedTo:ORCouchDBModelInConnector];
            [experiment postCouchDBRecord];
        }
        @catch (NSException* e){
            NSLog(@"%@ %@ Exception: %@\n",[self fullID],NSStringFromSelector(_cmd),e);
        }
        @finally {
            [self performSelector:@selector(updateExperiment) withObject:nil afterDelay:30];
        }
	}
}

- (void) alarmsChanged:(NSNotification*)aNote
{
	if(!stealthMode){
		ORAlarmCollection* alarmCollection = [ORAlarmCollection sharedAlarmCollection];
		NSArray* theAlarms = [[[alarmCollection alarms] retain] autorelease];
		NSMutableArray* arrayForDoc = [NSMutableArray array];
		if([theAlarms count]){
			for(id anAlarm in theAlarms)[arrayForDoc addObject:[anAlarm alarmInfo]];
		}
		NSDictionary* alarmInfo  = [NSDictionary dictionaryWithObjectsAndKeys:@"alarms",@"_id",@"alarms",@"name",arrayForDoc,@"alarmlist",@"alarms",@"type",nil];
		[[self statusDBRef] updateDocument:alarmInfo documentId:@"alarms" tag:kDocumentUpdated];
	}
}

- (void) updateDataSets
{
	if(!stealthMode && !skipDataSets){
		[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(updateDataSets) object:nil];
        
        @try {
            if([[ORCouchDBQueue sharedCouchDBQueue]lowPriorityOperationCount]<10){
                NSMutableArray* dataSetNames = [NSMutableArray array];
                for(id aMonitor in dataMonitors){
                    NSArray* objs1d = [[aMonitor  collectObjectsOfClass:[OR1DHisto class]] retain];
                    NSString* baseMonitorName = [NSString stringWithFormat:@"Monitor%u",[aMonitor uniqueIdNumber]];
                    @try {
                        
                        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
                        dateFormatter.dateFormat = @"yyyy/MM/dd HH:mm:ss";
                        
                        NSTimeZone* gmt = [NSTimeZone timeZoneWithAbbreviation:@"GMT"];
                        [dateFormatter setTimeZone:gmt];
                        NSString*   lastTimeStamp       = [dateFormatter stringFromDate:[NSDate date]];
                        NSDate*     gmtTime             = [dateFormatter dateFromString:lastTimeStamp];
                        uint32_t secondsSince1970  = [gmtTime timeIntervalSince1970];
                        [dateFormatter release];

                        for(OR1DHisto* aDataSet in objs1d){
                            uint32_t start,end;
                            NSString* s = [aDataSet getnonZeroDataAsStringWithStart:&start end:&end];
                            NSString* dataSetName = [baseMonitorName stringByAppendingFormat:@",%@",[aDataSet fullName]];
                            NSDictionary* dataInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                                                        dataSetName,                                                @"name",
                                                        [NSNumber numberWithUnsignedLong:[aDataSet totalCounts]],	@"counts",
                                                        [NSNumber numberWithUnsignedLong:start],					@"start",
                                                        [NSNumber numberWithUnsignedLong:end],                      @"end",
                                                        [NSNumber numberWithUnsignedLong:[aDataSet numberBins]],	@"length",
                                                        s,															@"PlotData",
                                                        lastTimeStamp,                                              @"timestamp",
                                                        [NSNumber numberWithUnsignedLong: secondsSince1970],		@"time",

                                                        @"Histogram1D",												@"type",
                                                         nil];
                            NSString* dataName = [[dataSetName lowercaseString] stringByReplacingOccurrencesOfString:@" " withString:@""];
                            [dataSetNames addObject:
                                [NSDictionary dictionaryWithObjectsAndKeys:dataName,@"_id",dataName,@"name",[NSNumber numberWithUnsignedLong:[aDataSet totalCounts]],@"counts",nil]
                             ];

                            [[self statusDBRef] updateLowPriorityDocument:dataInfo documentId:dataName tag:kDocumentUpdated];
                            
                        }
                        
                        if([dataSetNames count]){
                            NSDictionary* dataInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                                                      @"HistogramCatalog",              @"_id",
                                                      @"HistogramCatalog",              @"name",
                                                      dataSetNames,                     @"list",
                                                      lastTimeStamp,                                            @"timestamp",
                                                      [NSNumber numberWithUnsignedLong: secondsSince1970],		@"time",
                                                      nil];
                            
                            [[self statusDBRef] updateDocument:dataInfo documentId:@"HistogramCatalog" tag:kDocumentUpdated];
                          
                        }
                        else {
                            [[self statusDBRef] deleteDocumentId:@"HistogramCatalog" tag:kDocumentDeleted];
                        }
                    }
                    @catch(NSException* e){
                        [objs1d release];
                        [e raise]; //throw out to the outer level
                    }
                }
            }
        }
        @catch (NSException* e){
            NSLog(@"%@ %@ Exception: %@\n",[self fullID],NSStringFromSelector(_cmd),e);
        }
        @finally {
            [self performSelector:@selector(updateDataSets) withObject:nil afterDelay:30];
        }
	}
}

- (void) _cancelAllPeriodicOperations
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self];
}

- (void) _startAllPeriodicOperations
{
    [self performSelector:@selector(updateMachineRecord) withObject:nil afterDelay:2];
    [self performSelector:@selector(updateExperiment)    withObject:nil afterDelay:3];
    [self performSelector:@selector(updateRunInfo)       withObject:nil afterDelay:4];
    [self performSelector:@selector(updateDatabaseStats) withObject:nil afterDelay:5];
    [self performSelector:@selector(updateBurstRecord)
        withObject:nil afterDelay:6];
    [self performSelector:@selector(periodicCompact)     withObject:nil afterDelay:60*60];
}


#pragma mark ***Archival
- (id)initWithCoder:(NSCoder*)decoder
{    
    self = [super initWithCoder:decoder];
    [[self undoManager] disableUndoRegistration];
    [self setSkipDataSets:  [decoder decodeBoolForKey:   @"skipDataSets"]];
    [self setUseHttps:      [decoder decodeBoolForKey:   @"useHttps"]];
    [self setAlertType:     [decoder decodeIntForKey:    @"alertType"]];
    [self setAlertMessage:  [decoder decodeObjectForKey: @"alertMessage"]];
    [self setKeepHistory:   [decoder decodeBoolForKey:   @"keepHistory"]];
    [self setPassword:      [decoder decodeObjectForKey: @"Password"]];
    [self setLocalHostName: [decoder decodeObjectForKey: @"LocalHostName"]];
    [self setUserName:      [decoder decodeObjectForKey: @"UserName"]];
    [self setRemoteHostName:[decoder decodeObjectForKey: @"RemoteHostName"]];
    [self setPortNumber:    [decoder decodeIntegerForKey:@"PortNumber"]];
    
    customDataBases = [[decoder decodeObjectForKey:@"customDataBases"] retain];
    
    wasReplicationRunning = [decoder decodeBoolForKey:@"wasReplicationRunning"];
	if(wasReplicationRunning){
        [self performSelector:@selector(startReplication) withObject:nil afterDelay:4];
    }
    replicationCheckCount = 0;
    [self setStealthMode:[decoder decodeBoolForKey:@"stealthMode"]];
    [self setPostRunningScripts:[decoder decodeBoolForKey:@"postRunningScripts"]];

    [[self undoManager] enableUndoRegistration];
	[self registerNotificationObservers];
   return self;
}

- (void)encodeWithCoder:(NSCoder*)encoder
{
    [super encodeWithCoder:encoder];
    [encoder encodeBool:skipDataSets            forKey:@"skipDataSets"];
    [encoder encodeInteger:alertType                forKey:@"alertType"];
    [encoder encodeObject:alertMessage          forKey:@"alertMessage"];
    [encoder encodeBool:keepHistory             forKey:@"keepHistory"];
    [encoder encodeBool:useHttps                forKey:@"useHttps"];
    [encoder encodeBool:stealthMode             forKey:@"stealthMode"];
    [encoder encodeBool:postRunningScripts      forKey:@"postRunningScripts"];
    [encoder encodeObject:password              forKey:@"Password"];
    [encoder encodeInteger:portNumber           forKey:@"PortNumber"];
    [encoder encodeObject:userName              forKey:@"UserName"];
    [encoder encodeObject:localHostName         forKey:@"LocalHostName"];
    [encoder encodeObject:remoteHostName        forKey:@"RemoteHostName"];
    [encoder encodeBool:wasReplicationRunning   forKey:@"wasReplicationRunning"];
    [encoder encodeObject:customDataBases       forKey:@"customDataBases"];

}
@end

