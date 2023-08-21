
//--------------------------------------------------------
// ORBt610Model
// Created by Mark  A. Howe on Mon Jan 23, 2012
// Code partially generated by the OrcaCodeWizard. Written by Mark A. Howe.
// Copyright (c) 2012 University of North Carolina. All rights reserved.
//-----------------------------------------------------------
//This program was prepared for the Regents of the University of 
//North Carolina sponsored in part by the United States 
//Department of Energy (DOE) under Grant #DE-FG02-97ER41020. 
//The University has certain rights in the program pursuant to 
//the contract and the program should not be copied or distributed 
//outside your organization.  The DOE and the University of 
//Washington reserve all rights in the program. Neither the authors,
//University of North Carolina, or U.S. Government make any warranty, 
//express or implied, or assume any liability or responsibility 
//for the use of this software.
//-------------------------------------------------------------

#pragma mark ***Imported Files

#import "ORBt610Model.h"
#import "ORSerialPortAdditions.h"
#import "ORDataTypeAssigner.h"
#import "ORDataPacket.h"
#import "ORTimeRate.h"
#import "ORAlarm.h"

#pragma mark ***External Strings
NSString* ORBt610ModelDumpCountChanged		    = @"ORBt610ModelDumpCountChanged";
NSString* ORBt610ModelDumpInProgressChanged     = @"ORBt610ModelDumpInProgressChanged";
NSString* ORBt610ModelIsLogChanged			    = @"ORBt610ModelIsLogChanged";
NSString* ORBt610ModelHoldTimeChanged		    = @"ORBt610ModelHoldTimeChanged";
NSString* ORBt610ModelTempUnitsChanged		    = @"ORBt610ModelTempUnitsChanged";
NSString* ORBt610ModelCountUnitsChanged	        = @"ORBt610ModelCountUnitsChanged";
NSString* ORBt610ModelStatusBitsChanged	        = @"ORBt610ModelStatusBitsChanged";
NSString* ORBt610ModelLocationChanged		    = @"ORBt610ModelLocationChanged";
NSString* ORBt610ModelHumidityChanged		    = @"ORBt610ModelHumidityChanged";
NSString* ORBt610ModelTemperatureChanged	    = @"ORBt610ModelTemperatureChanged";
NSString* ORBt610ModelActualDurationChanged     = @"ORBt610ModelActualDurationChanged";
NSString* ORBt610ModelCountAlarmLimitChanged    = @"ORBt610ModelCountAlarmLimitChanged";
NSString* ORBt610ModelMaxCountsChanged		    = @"ORBt610ModelMaxCountsChanged";
NSString* ORBt610ModelCycleNumberChanged	    = @"ORBt610ModelCycleNumberChanged";
NSString* ORBt610ModelCycleStartedChanged	    = @"ORBt610ModelCycleStartedChanged";
NSString* ORBt610ModelRunningChanged		    = @"ORBt610ModelRunningChanged";
NSString* ORBt610ModelCycleDurationChanged      = @"ORBt610ModelCycleDurationChanged";
NSString* ORBt610ModelNumSamplesChanged	        = @"ORBt610ModelNumberSamplesChanged";
NSString* ORBt610ModelCountChanged			    = @"ORBt610ModelCount2Changed";
NSString* ORBt610ModelMissedCountChanged        = @"ORBt610ModelMissedCountChanged";
NSString* ORBt610ModelOpTimerChanged            = @"ORBt610ModelOpTimerChanged";
NSString* ORBt610ModelMeasurementDateChanged    = @"ORBt610ModelMeasurementDateChanged";

NSString* ORBt610Lock = @"ORBt610Lock";

@interface ORBt610Model (private)
- (void) addCmdToQueue:(NSString*)aCmd;
- (void) process_response:(NSString*)theResponse;
- (void) checkCycle;
- (void) cancelCycleCheck;

- (void) dumpTimeout;
- (void) clearDelay;
- (void) processOneCommandFromQueue;
- (void) startDataArrivalTimeout;
- (void) cancelDataArrivalTimeout;
- (void) doCycleKick;
- (void) postCouchDBRecord;
@end

@implementation ORBt610Model

- (id) init
{
	self = [super init];
	[[self undoManager] disableUndoRegistration];
	int i;
	for(i=0;i<6;i++){
		[self setIndex:i maxCounts:1000];
		[self setIndex:i countAlarmLimit:800];
	}
	[[self undoManager] enableUndoRegistration];
	return self;
}

- (void) dealloc
{
    [cycleStarted release];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    [buffer release];
    [opTimer release];
    [measurementDate release];

	int i;
	for(i=0;i<8;i++){
		[timeRates[i] release];
	}	
	
	[sensorErrorAlarm release];
	[sensorErrorAlarm clearAlarm];

	[lowBatteryAlarm release];
	[lowBatteryAlarm clearAlarm];

	[countSize1Alarm release];
	[countSize1Alarm clearAlarm];
  
    [countSize2Alarm release];
    [countSize2Alarm clearAlarm];
 
    
	[missingCyclesAlarm release];
	[missingCyclesAlarm clearAlarm];

	[super dealloc];
}

- (void) sleep
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self];
	[super sleep];
}

- (void) wakeUp
{
	[super wakeUp];
}

- (void) setUpImage
{
	[self setImage:[NSImage imageNamed:@"Bt610.tif"]];
}

- (void) makeMainController
{
	[self linkToController:@"ORBt610Controller"];
}
- (NSString*) helpURL
{
	return @"RS232/Bt610.html";
}

- (void) dataReceived:(NSNotification*)note
{
    if([[note userInfo] objectForKey:@"serialPort"] == serialPort){
		
        NSString* theString = [[[[NSString alloc] initWithData:[[note userInfo] objectForKey:@"data"] 
												      encoding:NSASCIIStringEncoding] autorelease] uppercaseString];
	
		
        //the serial port may break the data up into small chunks, so we have to accumulate the chunks until
		//we get a full piece.
				
        if(!buffer)buffer = [[NSMutableString string] retain];
        [buffer appendString:theString];	
		
        do {
            NSRange lineRange = [buffer rangeOfString:@"\r\n"];
            if(lineRange.location!= NSNotFound){
                NSString* theResponse = [[[buffer substringToIndex:lineRange.location+1] copy] autorelease];
                [buffer deleteCharactersInRange:NSMakeRange(0,lineRange.location+1)];      //take the cmd out of the buffer
				
				if([theResponse length] != 0){
					[self process_response:theResponse];
				}
				if(!dumpInProgress){
					[self setLastRequest:nil];			 //clear the last request
					[self processOneCommandFromQueue];	 //do the next command in the queue
				}

            }
        } while([buffer rangeOfString:@"\r\n"].location!= NSNotFound);
	}
}

#pragma mark ***Accessors
- (int) missedCycleCount
{
    return missedCycleCount;
}

- (void) setMissedCycleCount:(int)aValue
{
    missedCycleCount = aValue;
    [[NSNotificationCenter defaultCenter] postNotificationName:ORBt610ModelMissedCountChanged object:self];
    
	if(((missedCycleCount >= 3) && (numSamples==0)) ||
       ((missedCycleCount > 0) && (numSamples>0))){
		if(!missingCyclesAlarm){
			NSString* s = [NSString stringWithFormat:@"Bt610 (Unit %u) Missing Cycles",[self uniqueIdNumber]];
			missingCyclesAlarm = [[ORAlarm alloc] initWithName:s severity:kHardwareAlarm];
			[missingCyclesAlarm setSticky:YES];
            if(numSamples>0)[missingCyclesAlarm setHelpString:@"The particle counter did not report counts at the end of its last cycle.\n\nThis alarm will not go away until the problem is cleared. Acknowledging the alarm will silence it."];
            else [missingCyclesAlarm setHelpString:@"The particle counter is not reporting counts at the end of its cycle. ORCA tried to kick start it at least three times.\n\nThis alarm will not go away until the problem is cleared. Acknowledging the alarm will silence it."];
			[missingCyclesAlarm postAlarm];
		}
	}
	else {
		[missingCyclesAlarm clearAlarm];
		[missingCyclesAlarm release];
		missingCyclesAlarm = nil;
	}
}

- (int) dumpCount
{
    return dumpCount;
}

- (void) setDumpCount:(int)aDumpCount
{
    dumpCount = aDumpCount;

    [[NSNotificationCenter defaultCenter] postNotificationName:ORBt610ModelDumpCountChanged object:self];
}

- (BOOL) dumpInProgress
{
    return dumpInProgress;
}

- (void) setDumpInProgress:(BOOL)aDumpInProgress
{
    dumpInProgress = aDumpInProgress;

    [[NSNotificationCenter defaultCenter] postNotificationName:ORBt610ModelDumpInProgressChanged object:self];
}

- (BOOL) isLog
{
    return isLog;
}

- (void) setIsLog:(BOOL)aIsLog
{
    [[[self undoManager] prepareWithInvocationTarget:self] setIsLog:isLog];
    isLog = aIsLog;
    [[NSNotificationCenter defaultCenter] postNotificationName:ORBt610ModelIsLogChanged object:self];
}

- (int) holdTime
{
    return holdTime;
}

- (void) setHoldTime:(int)aHoldTime
{
	if(aHoldTime<0)aHoldTime = 0;
	if(aHoldTime>9999)aHoldTime = 9999;
    [[[self undoManager] prepareWithInvocationTarget:self] setHoldTime:holdTime];
    holdTime = aHoldTime;
    [[NSNotificationCenter defaultCenter] postNotificationName:ORBt610ModelHoldTimeChanged object:self];
}
- (void) setOpTimer:(NSString*)aValue
{
    [opTimer release];
    opTimer = nil;
    opTimer = [aValue copy];
    [[NSNotificationCenter defaultCenter] postNotificationName:ORBt610ModelOpTimerChanged object:self];
}

- (NSString*) opTimer
{
    if(opTimer)return opTimer;
    else return @"";
}

- (int) tempUnits
{
    return tempUnits;
}

- (void) setTempUnits:(int)aTempUnits
{
	if(aTempUnits<0)aTempUnits = 0;
	if(aTempUnits>1)aTempUnits = 1;
    [[[self undoManager] prepareWithInvocationTarget:self] setTempUnits:tempUnits];
    tempUnits = aTempUnits;
    [[NSNotificationCenter defaultCenter] postNotificationName:ORBt610ModelTempUnitsChanged object:self];
}

- (int) countUnits
{
    return countUnits;
}

- (void) setCountUnits:(int)aCountUnits
{
    [[[self undoManager] prepareWithInvocationTarget:self] setCountUnits:countUnits];
    countUnits = aCountUnits;
    [[NSNotificationCenter defaultCenter] postNotificationName:ORBt610ModelCountUnitsChanged object:self];
}

- (int) statusBits
{
    return statusBits;
}

- (void) setStatusBits:(int)aStatusBits
{
    statusBits = aStatusBits;
	[self checkAlarms];
    [[NSNotificationCenter defaultCenter] postNotificationName:ORBt610ModelStatusBitsChanged object:self];
}

- (void) checkAlarms
{
	if(statusBits & 0x10){
		if(!lowBatteryAlarm){
			NSString* s = [NSString stringWithFormat:@"Bt610 (Unit %u)",[self uniqueIdNumber]];
			lowBatteryAlarm = [[ORAlarm alloc] initWithName:s severity:kHardwareAlarm];
			[lowBatteryAlarm setSticky:YES];
			[lowBatteryAlarm setHelpString:@"The battery on the particle counter is low. Is it supposed to be running on the battery?\n\nThis alarm will not go away until the problem is cleared. Acknowledging the alarm will silence it."];
			[lowBatteryAlarm postAlarm];
		}
	}
	else {
		[lowBatteryAlarm clearAlarm];
		[lowBatteryAlarm release];
		lowBatteryAlarm = nil;
	}
	
	if(statusBits & 0x20){
		if(!sensorErrorAlarm){
			NSString* s = [NSString stringWithFormat:@"Bt610 (Unit %u)",[self uniqueIdNumber]];
			sensorErrorAlarm = [[ORAlarm alloc] initWithName:s severity:kHardwareAlarm];
			[sensorErrorAlarm setSticky:YES];
			[sensorErrorAlarm setHelpString:@"The sensor is reporting a hardware error.\n\nThis alarm will not go away until the problem is cleared. Acknowledging the alarm will silence it."];
			[sensorErrorAlarm postAlarm];
		}
	}
	else {
		[sensorErrorAlarm clearAlarm];
		[sensorErrorAlarm release];
		sensorErrorAlarm = nil;
	}
	
	if(statusBits & 0x02){
		if(!countSize1Alarm){
			NSString* s = [NSString stringWithFormat:@"Bt610 (Unit %u)",[self uniqueIdNumber]];
			countSize1Alarm = [[ORAlarm alloc] initWithName:s severity:kRangeAlarm];
			[countSize1Alarm setSticky:YES];
			[countSize1Alarm setHelpString:@"The particle counter is reporting a count size 1 Alarm.\n\nThis alarm will not go away until the problem is cleared. Acknowledging the alarm will silence it."];
			[countSize1Alarm postAlarm];
		}
	}
	else {
		[countSize1Alarm clearAlarm];
		[countSize1Alarm release];
		countSize1Alarm = nil;
	}
    
    if(statusBits & 0x04){
        if(!countSize2Alarm){
            NSString* s = [NSString stringWithFormat:@"Bt610 (Unit %u)",[self uniqueIdNumber]];
            countSize2Alarm = [[ORAlarm alloc] initWithName:s severity:kRangeAlarm];
            [countSize2Alarm setSticky:YES];
            [countSize2Alarm setHelpString:@"The particle counter is reporting a count size 2.\n\nThis alarm will not go away until the problem is cleared. Acknowledging the alarm will silence it."];
            [countSize2Alarm postAlarm];
        }
    }
    else {
        [countSize2Alarm clearAlarm];
        [countSize2Alarm release];
        countSize2Alarm = nil;
    }
}

- (int) location
{
    return location;
}

- (void) setLocation:(int)aLocation
{
    [[[self undoManager] prepareWithInvocationTarget:self] setLocation:location];
    location = aLocation;
    [[NSNotificationCenter defaultCenter] postNotificationName:ORBt610ModelLocationChanged object:self];
}

- (float) humidity
{
    return humidity;
}

- (void) setHumidity:(float)aHumidity
{
    humidity = aHumidity;
    [[NSNotificationCenter defaultCenter] postNotificationName:ORBt610ModelHumidityChanged object:self];
	if(timeRates[7] == nil) timeRates[7] = [[ORTimeRate alloc] init];
	[timeRates[7] addDataToTimeAverage:humidity];
}

- (float) temperature
{
    return temperature;
}

- (void) setTemperature:(float)aTemperature
{
    temperature = aTemperature;
    [[NSNotificationCenter defaultCenter] postNotificationName:ORBt610ModelTemperatureChanged object:self];
	if(timeRates[6] == nil) timeRates[6] = [[ORTimeRate alloc] init];
	[timeRates[6] addDataToTimeAverage:temperature];

}
- (NSString*) measurementDate
{
    if(!measurementDate)return @"";
    else return measurementDate;
}

- (void) setMeasurementDate:(NSString*)aMeasurementDate
{
    [measurementDate autorelease];
    measurementDate = [aMeasurementDate copy];

    [[NSNotificationCenter defaultCenter] postNotificationName:ORBt610ModelMeasurementDateChanged object:self];
}

- (int) actualDuration
{
    return actualDuration;
}

- (void) setActualDuration:(int)aActualDuration
{
    actualDuration = aActualDuration;
    [[NSNotificationCenter defaultCenter] postNotificationName:ORBt610ModelActualDurationChanged object:self];
}

- (float) countAlarmLimit:(int)index
{
	if(index>=0 && index<8) return countAlarmLimit[index];
	else return 0;
}

- (void) setIndex:(int)index countAlarmLimit:(float)aCountAlarmLimit
{
	if(index<0 || index>=8)return;
	[[[self undoManager] prepareWithInvocationTarget:self] setIndex:index countAlarmLimit:countAlarmLimit[index]];
    countAlarmLimit[index] = aCountAlarmLimit;
	NSMutableDictionary* userInfo = [NSMutableDictionary dictionary];
	[userInfo setObject:[NSNumber numberWithInt:index] forKey: @"Channel"];

    [[NSNotificationCenter defaultCenter] postNotificationName:ORBt610ModelCountAlarmLimitChanged object:self userInfo:userInfo];
}

- (float) maxCounts:(int)index
{
	if(index>=0 && index<8) return maxCounts[index];
	else return 0;
}

- (void) setIndex:(int)index maxCounts:(float)aMaxCounts
{
	if(index<0 || index>=8)return;
	[[[self undoManager] prepareWithInvocationTarget:self] setIndex:index maxCounts:maxCounts[index]];
	maxCounts[index] = aMaxCounts;
	NSMutableDictionary* userInfo = [NSMutableDictionary dictionary];
	[userInfo setObject:[NSNumber numberWithInt:index] forKey: @"Channel"];
    [[NSNotificationCenter defaultCenter] postNotificationName:ORBt610ModelMaxCountsChanged object:self  userInfo:userInfo];
}

- (ORTimeRate*)timeRate:(int)index
{
	if(index>=0 && index<8) return timeRates[index];
	else return nil;
}

- (int) cycleNumber
{
    return cycleNumber;
}

- (void) setCycleNumber:(int)aCycleNumber
{
    cycleNumber = aCycleNumber;
    [[NSNotificationCenter defaultCenter] postNotificationName:ORBt610ModelCycleNumberChanged object:self];
}

- (NSDate*) cycleStarted
{
    return cycleStarted;
}

- (void) setCycleStarted:(NSDate*)aCycleStarted
{
    [aCycleStarted retain];
    [cycleStarted release];
    cycleStarted = aCycleStarted;
	
    [[NSNotificationCenter defaultCenter] postNotificationName:ORBt610ModelCycleStartedChanged object:self];
}

- (BOOL) running
{
    return running;
}

- (void) setRunning:(BOOL)aRunning
{
    bool changed = NO;
    if(aRunning!=running)changed=YES;
    running = aRunning;
    
    if(changed)[self setCycleStarted:[NSDate date]];

    [[NSNotificationCenter defaultCenter] postNotificationName:ORBt610ModelRunningChanged object:self];
}

- (BOOL) holding
{
    return holding;
}

- (void) setHolding:(BOOL)aState
{
    holding = aState;

    [[NSNotificationCenter defaultCenter] postNotificationName:ORBt610ModelRunningChanged object:self];
}

- (int) cycleDuration
{
    return cycleDuration;
}

- (void) setCycleDuration:(int)aCycleDuration
{
	if(aCycleDuration < 10) aCycleDuration = 10;
	else if(aCycleDuration > 999) aCycleDuration = 999;
    [[[self undoManager] prepareWithInvocationTarget:self] setCycleDuration:cycleDuration];
    
    cycleDuration = aCycleDuration;

    [[NSNotificationCenter defaultCenter] postNotificationName:ORBt610ModelCycleDurationChanged object:self];
}

- (int) numSamples
{
    return numSamples;
}

- (void) setNumSamples:(int)aNum
{
    numSamples = aNum;

    [[NSNotificationCenter defaultCenter] postNotificationName:ORBt610ModelNumSamplesChanged object:self];
}

- (NSString*) countingModeString
{
    if([self numSamples]>0)return [NSString stringWithFormat:@"%d Samples",numSamples];
    else                   return @"Repeating";
}

- (void) setCount:(int)index value:(int)aValue
{
	if(index>=0 && index<6){
		count[index] = aValue;
		[[NSNotificationCenter defaultCenter] postNotificationName:ORBt610ModelCountChanged object:self];
		if(timeRates[index] == nil) timeRates[index] = [[ORTimeRate alloc] init];
		[timeRates[index] addDataToTimeAverage:aValue];
	}
}

- (int) count:(int)index
{
	if(index>=0 && index<6)return count[index];
	else return 0;
}

- (void) setUpPort
{
	[serialPort setSpeed:9600];
	[serialPort setParityNone];
	[serialPort setStopBits2:NO];
	[serialPort setDataBits:8];
}

- (void) firstActionAfterOpeningPort
{
	[self probe];
}

#pragma mark ***Archival
- (id) initWithCoder:(NSCoder*)decoder
{
	self = [super initWithCoder:decoder];
	[[self undoManager] disableUndoRegistration];
	[self setIsLog:				[decoder decodeBoolForKey:@"isLog"]];
	[self setHoldTime:			[decoder decodeIntForKey:   @"holdTime"]];
	[self setTempUnits:			[decoder decodeIntForKey:   @"tempUnits"]];
	[self setCountUnits:		[decoder decodeIntForKey:   @"countUnits"]];
	[self setLocation:			[decoder decodeIntForKey:   @"location"]];
	wasRunning =				[decoder decodeBoolForKey:  @"wasRunning"];
	[self setCycleDuration:		[decoder decodeIntForKey:   @"cycleDuration"]];
	[self setNumSamples:		[decoder decodeIntForKey:   @"numSamples"]];

	int i; 
	for(i=0;i<8;i++){
		timeRates[i] = [[ORTimeRate alloc] init];
		[self setIndex:i countAlarmLimit:  	[decoder decodeFloatForKey: [NSString stringWithFormat:@"countAlarmLimit%d",i]]];
		[self setIndex:i maxCounts:			[decoder decodeFloatForKey: [NSString stringWithFormat:@"maxCounts%d",i]]];
	}
	
	[[self undoManager] enableUndoRegistration];
	
	return self;
}
- (void) encodeWithCoder:(NSCoder*)encoder
{
    [super encodeWithCoder:encoder];
    [encoder encodeBool:	isLog			forKey: @"isLog"];
    [encoder encodeInteger:	holdTime		forKey: @"holdTime"];
    [encoder encodeInteger:	tempUnits		forKey: @"tempUnits"];
    [encoder encodeInteger:	countUnits		forKey: @"countUnits"];
    [encoder encodeInteger:	location		forKey: @"location"];
    [encoder encodeInteger:	cycleDuration	forKey: @"cycleDuration"];
    [encoder encodeInteger:	numSamples	    forKey: @"numSamples"];
    [encoder encodeBool:	wasRunning		forKey:	@"wasRunning"];
	int i; 
	for(i=0;i<8;i++){
		[encoder encodeFloat:	countAlarmLimit[i] forKey: [NSString stringWithFormat:@"countAlarmLimit%d",i]];
		[encoder encodeFloat:	maxCounts[i]	   forKey: [NSString stringWithFormat:@"maxCounts%d",i]];

	}
}
#pragma mark *** Commands
- (void) sendNewData
{
	if([serialPort isOpen]){
		NSLog(@"Bt610 (%d): Starting dump of new data since last dump\n",[self uniqueIdNumber]);
	}
	[self addCmdToQueue:@"3"]; 
}

- (void) sendAllData 
{ 
	if([serialPort isOpen]){
		NSLog(@"Bt610 (%d): Starting dump of all data\n",[self uniqueIdNumber]);
	}
	[self addCmdToQueue:@"2"]; 
}

- (void) setDate
{ 
#if defined(MAC_OS_X_VERSION_10_10) && MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_10 // 10.10-specific	
	unsigned unitFlags = NSCalendarUnitYear | NSCalendarUnitMonth |  NSCalendarUnitDay | NSCalendarUnitMinute | NSCalendarUnitHour;
	NSDate *today = [NSDate date];
	NSCalendar *gregorian = [[[NSCalendar alloc]  initWithCalendarIdentifier:NSCalendarIdentifierGregorian] autorelease];
#else
	unsigned unitFlags = NSYearCalendarUnit | NSMonthCalendarUnit |  NSDayCalendarUnit | NSMinuteCalendarUnit | NSHourCalendarUnit;
	NSDate *today = [NSDate date];
	NSCalendar *gregorian = [[[NSCalendar alloc]  initWithCalendarIdentifier:NSGregorianCalendar] autorelease];
#endif
	NSDateComponents *comps = [gregorian components:unitFlags fromDate:today];
	[self addCmdToQueue:[NSString stringWithFormat:@"D %02ld/%02ld/%02ld",[comps month],[comps day],[comps year]-2000]];
	[self addCmdToQueue:[NSString stringWithFormat:@"T %02ld:%02ld",[comps hour],[comps minute]]];
}
- (void) sendClearData				{ [self addCmdToQueue:@"C\rY"]; }
- (void) sendStart					{ [self addCmdToQueue:@"S"]; }
- (void) sendEnd					{ [self addCmdToQueue:@"E"]; }
- (void) getSampleTime				{ [self addCmdToQueue:@"ST"]; }
- (void) getLocation				{ [self addCmdToQueue:@"ID"]; }
- (void) getHoldTime                { [self addCmdToQueue:@"SH"]; }
- (void) getUnits                   { [self addCmdToQueue:@"CU\rTU"]; }

- (void) sendNumSamples:(int)aValue { [self addCmdToQueue:[NSString stringWithFormat:@"SN %d",aValue]]; }
- (void) sendCountingTime:(int)aValue { [self addCmdToQueue:[NSString stringWithFormat:@"ST %d",aValue]]; }
- (void) sendID:(int)aValue			{ [self addCmdToQueue:[NSString stringWithFormat:@"ID %d",aValue]]; }
- (void) sendHoldTime:(int)aValue	{ [self addCmdToQueue:[NSString stringWithFormat:@"SH %d",aValue]]; }
- (void) sendTempUnit:(int)aTempUnit countUnits:(int)aCountUnit		{ int esc = 27; [self addCmdToQueue:[NSString stringWithFormat:@"CU %d\r%cTU %d",aTempUnit,esc,aCountUnit]]; }
- (void) probe						{ probing = YES; [self getOpStatus]; }
- (void) getOpStatus                { [self addCmdToQueue:@"OP"]; }

#pragma mark ***Polling and Cycles
- (void) startCycle
{
    [self startCycle:NO];
}
- (void) startCycle:(BOOL)force
{
	if((![self running] || force) && [serialPort isOpen]){
		[self sendEnd];
        [self enqueueCmd:@"++Delay"];
		[self setCycleNumber:1];

		[self sendHoldTime:holdTime];
        [self sendNumSamples:numSamples];
		[self sendTempUnit:tempUnits countUnits:countUnits];
		[self sendCountingTime:cycleDuration];
        [self enqueueCmd:@"++Delay"];
        
		[self sendStart];
        [self enqueueCmd:@"++Delay"];
        [self startDataArrivalTimeout];
		NSLog(@"Bt610(%d) Starting particle counter: %@ \n",[self uniqueIdNumber], [self countingModeString]);
        [self checkCycle];
	}
}

- (void) stopCycle
{
	if([self running] && [serialPort isOpen]){
		[self setCycleNumber:0];
		[self sendEnd];
        [self cancelDataArrivalTimeout];
		NSLog(@"Bt610(%d) Stopping particle counter. Number of Cycles %d\n",[self uniqueIdNumber], [self cycleNumber]);
	}
}


#pragma mark •••Bit Processing Protocol
- (void) processIsStarting
{
	if(!running){
		if(!sentStartOnce){
		   sentStartOnce = YES;
		   sentStopOnce = NO;
            wasRunning = NO;

			[self startCycle:YES];
		}
	}
    else wasRunning = YES;
}

- (void) processIsStopping
{
	if(!wasRunning){
		if(!sentStopOnce){
			sentStopOnce = YES;
			sentStartOnce = NO;
			[self stopCycle];
		}
	}
}

//note that everything called by these routines MUST be threadsafe
- (void) startProcessCycle
{    
	@try { 
	}
	@catch(NSException* localException) { 
		//catch this here to prevent it from falling thru, but nothing to do.
	}
}

- (void) endProcessCycle
{
}

- (NSString*) identifier
{
	NSString* s;
 	@synchronized(self){
		s= [NSString stringWithFormat:@"Bt610,%u",[self uniqueIdNumber]];
	}
	return s;
}

- (NSString*) processingTitle
{
	NSString* s;
 	@synchronized(self){
		s= [self identifier];
	}
	return s;
}

- (double) convertedValue:(int)aChan
{
	double theValue = 0;
	@synchronized(self){
		if(aChan<6)			theValue = [self count:aChan];
		else if(aChan==6)	theValue = [self temperature];
		else if(aChan==7)	theValue = [self humidity];
	}
	return theValue;
}

- (double) maxValueForChan:(int)aChan
{
	double theValue;
	@synchronized(self){
		theValue = (double)[self maxCounts:aChan]; 
	}
	return theValue;
}

- (double) minValueForChan:(int)aChan
{
	return 0;
}

- (void) getAlarmRangeLow:(double*)theLowLimit high:(double*)theHighLimit channel:(int)channel
{
	@synchronized(self){
		*theLowLimit = -.001;
		*theHighLimit =  [self countAlarmLimit:channel]; 
	}		
}

- (BOOL) processValue:(int)channel
{
	BOOL r;
	@synchronized(self){
		r = YES;    //temp -- figure out what the process bool for this object should be.
	}
	return r;
}

- (void) setProcessOutput:(int)channel value:(int)value
{
    //nothing to do. not used in adcs. really shouldn't be in the protocol
}

- (BOOL) dataForChannelValid:(int)aChannel
{
    return [self isValid] && [serialPort isOpen];
}

@end

@implementation ORBt610Model (private)

- (void) postCouchDBRecord
{    
    NSDictionary* values = [NSDictionary dictionaryWithObjectsAndKeys:
                            [NSArray arrayWithObjects:
                                [NSNumber numberWithInt:count[0]],
                                [NSNumber numberWithInt:count[1]],
                                [NSNumber numberWithInt:count[2]],
                                [NSNumber numberWithInt:count[3]],
                                [NSNumber numberWithInt:count[4]],
                                [NSNumber numberWithInt:count[5]],
                                nil], @"counts",
                            [NSArray arrayWithObjects:
                                 [NSNumber numberWithInt:countAlarmLimit[0]],
                                 [NSNumber numberWithInt:countAlarmLimit[1]],
                                 [NSNumber numberWithInt:countAlarmLimit[2]],
                                 [NSNumber numberWithInt:countAlarmLimit[3]],
                                 [NSNumber numberWithInt:countAlarmLimit[4]],
                                 [NSNumber numberWithInt:countAlarmLimit[5]],
                                 nil], @"countLimits",
                            [NSNumber numberWithFloat:  temperature],       @"temperature",
                            [NSNumber numberWithFloat:  humidity],         @"humidity",
                            [NSNumber numberWithInt:    actualDuration],   @"actualDuration",
                            [NSNumber numberWithInt:    statusBits],       @"statusBits",
                            [NSNumber numberWithInt:    cycleDuration],    @"pollTime",
                            nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"ORCouchDBAddObjectRecord" object:self userInfo:values];
}

- (void) checkCycle
{
	if([serialPort isOpen]){ 
        if(!dumpInProgress)[self probe];
        [self cancelCycleCheck];
        [self performSelector:@selector(checkCycle) withObject:nil afterDelay:1];
    }
}
- (void) cancelCycleCheck
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(checkCycle) object:nil];
}

- (void) startDataArrivalTimeout
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(doCycleKick) object:nil];
    [self performSelector:@selector(doCycleKick)  withObject:nil afterDelay:(cycleDuration+20)];
}

- (void) cancelDataArrivalTimeout
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(doCycleKick) object:nil];
}

- (void) doCycleKick
{
    [self setMissedCycleCount:missedCycleCount+1];
    NSLogColor([NSColor redColor],@"%@ data did not arrive at end of cycle (missed %d)\n",[self fullID],missedCycleCount);
    if(numSamples==0){ //repeating mode
        NSLogColor([NSColor redColor],@"Kickstarting %@\n",[self fullID]);
        [self setCount:0 value:0];
        [self setCount:1 value:0];
        [self setCount:2 value:0];
        [self setCount:3 value:0];
        [self setCount:4 value:0];
        [self setCount:5 value:0];       
        [self setTemperature:0];
        [self setHumidity:0];
        [self setIsValid:NO];

        [self stopCycle];
        [self startCycle:YES];
    }
}


- (void) addCmdToQueue:(NSString*)aCmd
{
	if([serialPort isOpen]){ 
        aCmd = [aCmd stringByReplacingOccurrencesOfString:@"\n" withString:@""];
        aCmd = [aCmd stringByReplacingOccurrencesOfString:@"\r" withString:@""];
        int esc = 27;

        aCmd = [NSString stringWithFormat:@"%c%@\r",esc,aCmd];
		
		[self enqueueCmd:aCmd];
		[self enqueueCmd:@"++Delay"];
		
		if(!lastRequest){
			[self processOneCommandFromQueue];
		}
	}
	else NSLog(@"Bt610 (%d): Serial Port not open. Cmd Ignored.\n",[self uniqueIdNumber]);
}

- (void) process_response:(NSString*)theResponse
{
	[self setIsValid:YES];
    theResponse = [theResponse stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    theResponse = [theResponse stringByTrimmingCharactersInSet:[NSCharacterSet controlCharacterSet]];
	NSArray* partsByComma = [theResponse componentsSeparatedByString:@","];
	if([partsByComma count] >= 14 && (![lastRequest hasPrefix:@"2"] && ![lastRequest hasPrefix:@"3"])){
		if(!dumpInProgress){
            [self setMeasurementDate:[partsByComma objectAtIndex:0]];
			[self setCount:0 value:[[partsByComma objectAtIndex:2] intValue]];
			[self setCount:1 value:[[partsByComma objectAtIndex:4] intValue]];
			[self setCount:2 value:[[partsByComma objectAtIndex:6] intValue]];
			[self setCount:3 value:[[partsByComma objectAtIndex:8] intValue]];
			[self setCount:4 value:[[partsByComma objectAtIndex:10] intValue]];
			[self setCount:5 value:[[partsByComma objectAtIndex:12] intValue]];
			
			[self setTemperature:[[partsByComma objectAtIndex:13] floatValue]];
			[self setHumidity:[[partsByComma objectAtIndex:14] floatValue]];
			[self setLocation:[[partsByComma objectAtIndex:15] floatValue]];

			[self setActualDuration:[[partsByComma objectAtIndex:16] intValue]];
            
            NSString* statusString = [[partsByComma objectAtIndex:19] stringByReplacingOccurrencesOfString:@"*" withString:@""]; //remove the leading '*'
			[self setStatusBits:[statusString intValue]];
            
            [self setMissedCycleCount:0];
            [self cancelDataArrivalTimeout];
        
            [self postCouchDBRecord];
            
            [self startDataArrivalTimeout];
            int theCount = [self cycleNumber];
            [self setCycleNumber:theCount+1];
			
            [self probe];
		}
		else {
			theResponse = [theResponse stringByReplacingOccurrencesOfString:@"\n" withString:@""];
			theResponse = [theResponse stringByReplacingOccurrencesOfString:@"\r" withString:@""];
			//put in a unix time stamp for convenience
			NSString* aDate = [partsByComma objectAtIndex:0];
			
			NSDateFormatter* dateFormatter = [[[NSDateFormatter alloc] init] autorelease];
			[dateFormatter setDateFormat:@"dd-MMM-yyyy HH:mm:ss"];
			NSDate* gmtTime = [dateFormatter dateFromString:aDate];
			NSNumber *timestamp=[[[NSNumber alloc] initWithDouble:[gmtTime timeIntervalSince1970]] autorelease];
			
			NSLog(@"%d, %@, %@\n",dumpCount,timestamp,theResponse);
			[self setDumpCount:dumpCount+1];
			[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(dumpTimeout) object:nil];
			[self performSelector:@selector(dumpTimeout) withObject:nil afterDelay:.5];
		}
	}
	else {
		if([lastRequest hasPrefix:@"2"] || [lastRequest hasPrefix:@"3"]){
			[self setDumpInProgress:YES];
			[self setDumpCount:0];
			[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(dumpTimeout) object:nil];
			[self performSelector:@selector(dumpTimeout) withObject:nil afterDelay:.5];
		}
		else if([theResponse hasPrefix:@"CU"]){
			if([partsByComma count] == 2){
				NSString* theUnits = [partsByComma objectAtIndex:1];
				if([theUnits hasPrefix:@"CF"])[self setCountUnits:0];
				else if([theUnits hasPrefix:@"/L"])[self setCountUnits:1];
				else if([theUnits hasPrefix:@"TC"])[self setCountUnits:2];
			}
		}
		else if([theResponse hasPrefix:@"ST"]){
			NSArray* partsBySpaces = [theResponse componentsSeparatedByString:@" "];
			if([partsBySpaces count]==2){
				NSString* st = [partsBySpaces objectAtIndex:1];
				[self setCycleDuration:[st intValue]];
			}
		}
		else if([theResponse hasPrefix:@"TU"]){
			NSArray* partsBySpaces = [theResponse componentsSeparatedByString:@" "];
			if([partsBySpaces count]==2){
				NSString* st = [partsBySpaces objectAtIndex:1];
				[self setTempUnits:[st intValue]];
			}
		}
        else if([theResponse  isEqualToString:@"S"]){
            [self setRunning:YES];
        }
        else if([theResponse isEqualToString:@"E"]){
            [self setRunning:NO];
        }
        else if([theResponse hasPrefix:@"OP"]){
            NSArray* partsBySpaces = [theResponse componentsSeparatedByString:@" "];
            if([partsBySpaces count]>1){
                NSString* state = [partsBySpaces objectAtIndex:1];
                if([state hasPrefix:@"R"]){ //running
                    [self setHolding:NO];
                    [self setRunning:YES];
                    if([partsBySpaces count]>2){
                        [self setOpTimer:[partsBySpaces objectAtIndex:2]];
                    }
                }
                else if([state hasPrefix:@"H"]){ //holding
                    [self setHolding:YES];
                    if([partsBySpaces count]>2){
                        [self setOpTimer:[partsBySpaces objectAtIndex:2]];
                    }
                }
                else if([state hasPrefix:@"S"]){ //stopped
                    [self setRunning:NO];
                    [self setHolding:NO];
                    [self setOpTimer:@""];
                    [self cancelCycleCheck];
                }
            }
        }
	}
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(timeout) object:nil];
}



- (void) clearDelay
{
	delay = NO;
	[self processOneCommandFromQueue];
}

- (void) dumpTimeout
{
	[self setDumpInProgress:NO];
	[self setDumpCount:0];
	[self setLastRequest:nil];			 //clear the last request
	[self processOneCommandFromQueue];	 //do the next command in the queue

	NSLog(@"Bt610 (%d): Data printout finished\n",[self uniqueIdNumber]);
}

- (void) processOneCommandFromQueue
{
    if(delay)return;
	
	NSString* aCmd = [self nextCmd];
	if(aCmd){
		if([aCmd isEqualToString:@"++Delay"]){
			delay = YES;
			[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(clearDelay) object:nil];
			[self performSelector:@selector(clearDelay) withObject:nil afterDelay:kBt610DelayTime];
		}
		else {
			[self startTimeout:3];
            NSString* s = [aCmd stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            s = [aCmd stringByTrimmingCharactersInSet:[NSCharacterSet controlCharacterSet]];

			[self setLastRequest:s];
			[serialPort writeString:aCmd];
		}
	}
}

@end
