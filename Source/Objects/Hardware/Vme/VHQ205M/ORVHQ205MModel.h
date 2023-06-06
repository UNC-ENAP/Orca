/*
 *  ORVHQ205MModel.h
 *  Orca
 *
 *  Created by Mark Howe on Sat Nov 16 2002.
 *  Copyright (c) 2002 CENPA, University of Washington. All rights reserved.
 *
 */
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

#import "ORVmeIOCard.h"
#import "SBC_Config.h"

#pragma mark •••Register Definitions
enum {
    kStatusRegister1,		//0 	
    kSetVoltageA,			//1 	
    kSetVoltageB,			//2 	
    kRampSpeedA,			//3 	
    kRampSpeedB,			//4     
    kActVoltageA,			//5 	
    kActVoltageB,			//6 	
    kActCurrentA,			//7 	
    kActCurrentB,			//8 	
    kLimitsA,				//9 	
    kLimitsB,				//10 	
    kStatusRegister2,		//11 	
    kStartVoltA,			//12 	
    kStartVoltB,			//13 	
    kModID,					//14 	
    kSetCurrTripA,			//15 	
    kSetCurrTripB,			//16 	
    kNumberOfVHQ205MSRegisters			//must be last
};

#define kNumVHQ205MChannels 2
#define kVHQ205MMaxVoltage 10000

//status 1 word bits
#define kError		0x80
#define kStatV		0x40
#define kTrendV		0x20
#define kKillSwitch 0x10
#define kHVSwitch	0x08
#define kHVPolarity	0x04
#define kHVControl	0x02
#define kVZOut		0x01

//status 2 word bits
#define kCurrentTripBit  0x1
#define kRunningRamp	 0x2
#define kSwitchChanged	 0x4
#define kVMaxExceeded	 0x8
#define kInibitActive	 0x10
#define kCurrentExceeded 0x20
#define kQualityNotGiven 0x40

typedef enum eVHQ205MRampingState {
	kHVOff,     
	kHVStableLow,     
	kHVStableHigh,     
	kHVRampingUp,  
	kHVRampingDn 
}eVHQ205MRampingState;

@interface ORVHQ205MModel :  ORVmeIOCard
{
    @private
		int pollTime;
		uint32_t dataId;
		float voltage[2];
		float actVoltage[2];
		float actCurrent[2];
		float maxCurrent[2];
		unsigned short rampRate[2];
		unsigned short statusReg1Chan[2];
		unsigned short statusReg2Chan[2];
		BOOL timeOutError;
		BOOL useStatusReg1Anyway[2];
		BOOL statusChanged; 
		BOOL pollingError;
}

#pragma mark •••Accessors
- (BOOL) pollingError;
- (void) setPollingError:(BOOL)aPollingError;
- (void) setTimeErrorState:(BOOL)aState;
- (unsigned short) statusReg1Chan:(unsigned short)aChan;
- (void) setStatusReg1Chan:(unsigned short)aChan withValue:(unsigned short)aStatusWord;
- (unsigned short) statusReg2Chan:(unsigned short)aChan;
- (void) setStatusReg2Chan:(unsigned short)aChan withValue:(unsigned short)aStatusWord;
- (float) voltage:(unsigned short) aChan;
- (void)  setVoltage:(unsigned short) aChan withValue:(float) aVoltage;
- (float) actVoltage:(unsigned short) aChan;
- (void)  setActVoltage:(unsigned short) aChan withValue:(float) aVoltage;
- (float) actCurrent:(unsigned short) aChan;
- (void)  setActCurrent:(unsigned short) aChan withValue:(float) aCurrent;
- (unsigned short) rampRate:(unsigned short) aChan;
- (void) setRampRate:(unsigned short) aChan withValue:(unsigned short) aRampRate;
- (int) pollTime;
- (void) setPollTime:(int)aPollTime;
- (float) maxCurrent:(unsigned short) aChan;
- (void)  setMaxCurrent:(unsigned short) aChan withValue:(float) aCurrent;

- (uint32_t) dataId;
- (void) setDataId: (uint32_t) DataId;

#pragma mark •••HW Access
- (void) initBoard;
- (void) readModuleID;
- (unsigned short) readStatus1Word;
- (unsigned short) readStatus2Word;
- (void) pollHardware;
- (float) readActVoltage:(unsigned short)aChan;
- (float) readActCurrent:(unsigned short)aChan;
- (void) stopRamp:(unsigned short)aChan;

#pragma mark •••RecordShipper
- (NSMutableDictionary*) addParametersToDictionary:(NSMutableDictionary*)dictionary;
- (void) shipVoltageRecords;

#pragma mark •••Helpers
- (NSString*) rampStateString:(unsigned short)aChannel;
- (eVHQ205MRampingState) rampingState:(unsigned short)aChan;
- (BOOL) polarity:(unsigned short)aChannel;
- (BOOL) hvPower:(unsigned short)aChannel;
- (BOOL) controlState:(unsigned short)aChannel;
- (void) loadValues:(unsigned short)aChannel;
- (void) panicToZero:(unsigned short)aChannel;
- (BOOL) killSwitch:(unsigned short)aChannel;
- (BOOL) currentTripped:(unsigned short)aChannel;
- (BOOL) extInhibitActive:(unsigned short)aChannel;

#pragma mark •••Archival
- (id)   initWithCoder:(NSCoder*)decoder;
- (void) encodeWithCoder:(NSCoder*)encoder;
@end

#pragma mark •••External String Definitions
extern NSString* ORVHQ205MModelPollingErrorChanged;
extern NSString* ORVHQ205MModelStatusReg1Changed;
extern NSString* ORVHQ205MModelStatusReg2Changed;
extern NSString* ORVHQ205MChan;
extern NSString* ORVHQ205MSettingsLock;
extern NSString* ORVHQ205MSetVoltageChanged;
extern NSString* ORVHQ205MActVoltageChanged;
extern NSString* ORVHQ205MRampRateChanged;
extern NSString* ORVHQ205MPollTimeChanged;
extern NSString* ORVHQ205MModelTimeOutErrorChanged;
extern NSString* ORVHQ205MActCurrentChanged;
extern NSString* ORVHQ205MMaxCurrentChanged;

