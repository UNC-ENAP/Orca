//
//  ORBurstMonitorModel.h
//  Orca
//
//  Created by Mark Howe on Mon Nov 18 2002.
//  Copyright (c) 2002 CENPA, University of Washington. All rights reserved.
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


#pragma mark •••Imported Files
#import "ORDataChainObject.h"
#import "ORBaseDecoder.h"
#import "ORDataProcessing.h"

#pragma mark •••Forward Declarations
@class ORDecoder;

@interface ORBurstMonitorModel :  ORDataChainObject <ORDataProcessing>
{

@private

    id					 thePassThruObject;         //cache the object on the other side of the pass thru connection
	id					 theBurstMonitoredObject;	//cache the object on the other side of the BurstMonitor connection
    double       timeWindow;
    unsigned short       nHit;
    unsigned short       minimumEnergyAllowed;
    uint32_t        shaperID;
    int runtype;
    int runnum;
    NSMutableArray* runbits;
    
    //buffer
    NSMutableArray* chans;
    NSMutableArray* cards;
    NSMutableArray* adcs;
    NSMutableArray* secs;
    NSMutableArray* mics;
    NSMutableArray* words;
    
    //burst channels
    NSMutableArray* Bchans;
    NSMutableArray* Bcards;
    NSMutableArray* Badcs;
    NSMutableArray* Bsecs;
    NSMutableArray* Bmics;
    NSMutableArray* Bwords;
    NSMutableArray* Bx;   //position from center in mm
    NSMutableArray* By;
    int Xcenter;
    int Ycenter;
    double Rcenter;
    double phi;
    double Xrms;
    double Yrms;
    double Rrms;
    double rSqrNorm;
    double numSecTillBurst;
    
    //neutron only buffer
    NSMutableArray* Nchans; 
    NSMutableArray* Ncards;
    NSMutableArray* Nadcs;
    NSMutableArray* Nsecs;
    NSMutableArray* Nmics;

    int32_t removedSec;
    int32_t removedMic;
    int numBurstChan;
    double durSec; //The number of seconds the burst takes to finish
    double rSec; //reduced number of seconds corresponding to most of the counts
    int countsInBurst;
    int foundMult;
    int multInBurst;
    double chanpvalue;
    int quietSec;
    int loudSec;
    int burstForce;
    int peakN;
    int lowN;
    int isgammalow;
    double adcP;
    double alphaP;
    double gammaP;
    
    //burst tags
    unsigned short burstTell; //1 if a bust still needs printing
    unsigned short burstState; //1 if in burst, 0 if not
    //unsigned short novaState; //1 if nova possible, 0 if not
    double novaP; //probability of data appearing from supernova
    
    NSMutableArray*      queueArray;
    NSMutableDictionary* queueMap;
    NSRecursiveLock*     queueLock;
    NSMutableArray*      emailList;
    unsigned short       numBurstsNeeded;
    NSData*              header;
    NSMutableDictionary* runHeader; //SV
    ORDecoder*           theDecoder;
    NSMutableDictionary* runUserInfo;
    unsigned short       burstCount;
    NSString*            burstString;
    uint32_t         dataId;
}
//uint64_t facto(uint64_t num); recusive one does not work any more

- (id)   init;
- (void) dealloc;


#pragma mark •••Accessors
- (unsigned short) numBurstsNeeded;
- (void) setNumBurstsNeeded:(unsigned short)aNumBurstsNeeded;

- (double) timeWindow;
- (void) setTimeWindow:(double)value;

- (void) setNHit:(unsigned short)value;
- (unsigned short) nHit;

- (unsigned short) minimumEnergyAllowed;
- (void) setMinimumEnergyAllowed:(unsigned short)value;

- (NSMutableArray*)      queueArray;
- (NSMutableDictionary*) queueMap;
- (NSMutableArray*)      emailList;
- (void) setEmailList:(NSMutableArray*)aEmailList;
- (void) addAddress:(id)anAddress atIndex:(int)anIndex;
- (void) removeAddressAtIndex:(int) anIndex;
- (int) channelsCheck:(NSMutableArray*) aChans;
- (void) lockArray;
- (void) unlockArray;

#pragma mark ***Data Records
- (void) appendDataDescription:(ORDataPacket*)aDataPacket userInfo:(NSDictionary*)userInfo;
- (NSDictionary*) dataRecordDescription;
- (uint32_t) dataId;
- (void) setDataId: (uint32_t) DataId;
- (void) setDataIds:(id)assigner;
- (void) syncDataIdsWith:(id)anotherVXM;

#pragma mark •••Run Methods
- (void) runTaskStarted:(NSDictionary*)userInfo;
- (void) runTaskStopped:(NSDictionary*)userInfo;
- (void) preCloseOut:(NSDictionary*)userInfo;
- (void) closeOutRun:(NSDictionary*)userInfo;
- (void) processData:(NSArray*)dataArray decoder:(ORDecoder*)aDecoder;
- (void) setRunMode:(int)aMode;

#pragma mark •••EMail
- (void) mailSent:(NSString*)address;
- (void) sendMail:(NSDictionary*)userInfo state:(int)eventState;
- (NSString*) cleanupAddresses:(NSArray*)aListOfAddresses;

#pragma mark •••Archival
- (id)   initWithCoder:(NSCoder*)decoder;
- (void) encodeWithCoder:(NSCoder*)encoder;
@end

#pragma mark •••External String Definitions
extern NSString* ORBurstMonitorModelNumBurstsNeededChanged;
extern NSString* ORBurstMonitorNameChanged;
extern NSString* ORBurstMonitorTimeWindowChanged;
extern NSString* ORBurstMonitorNHitChanged;
extern NSString* ORBurstMonitorMinimumEnergyAllowedChanged;
extern NSString* ORBurstMonitorQueueChanged;
extern NSString* ORBurstMonitorEmailListChanged;
extern NSString* ORBurstMonitorLock;
//extern NSDate* burstStart;

@interface ORBurstData : NSObject
{
    NSNumber* epSec; //Time from shaper card
    NSNumber* epMic;
    NSDate* datePosted;
    NSData* dataRecord;
}
@property (retain) NSDate* datePosted;
@property (retain) NSData* dataRecord;
@property (retain) NSNumber* epSec;
@property (retain) NSNumber* epMic;

@end
