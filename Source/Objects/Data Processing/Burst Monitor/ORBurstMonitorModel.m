//
//  ORBurstMonitorModel.m
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


#pragma mark \[Bullet]\[Bullet]\[Bullet]Imported Files
#import "ORBurstMonitorModel.h"
#import "ORDataSet.h"
#import "ORDecoder.h"
#import "ORShaperModel.h"
#import "ORDataTypeAssigner.h"
#import "NSData+Extensions.h"
#import "ORMailer.h"
#import "ORTaskSequence.h"

NSString* ORBurstMonitorModelNumBurstsNeededChanged = @"ORBurstMonitorModelNumBurstsNeededChanged";
static NSString* ORBurstMonitorInConnector          = @"BurstMonitor In Connector";
static NSString* ORBurstMonitorOutConnector         = @"BurstMonitor Out Connector";
static NSString* ORBurstMonitorBurstConnector       = @"BurstMonitored Burst Connector";

//========================================================================

#pragma mark \[Bullet]\[Bullet]\[Bullet]Notification Strings
NSString* ORBurstMonitorTimeWindowChanged           = @"ORBurstMonitorTimeWindowChangedNotification";
NSString* ORBurstMonitorNHitChanged                 = @"ORBurstMonitorNHitChangedNotification";
NSString* ORBurstMonitorMinimumEnergyAllowedChanged = @"ORBurstMonitorMinimumEnergyAllowedChangedNotification";
NSString* ORBurstMonitorQueueChanged                = @"ORBurstMonitorQueueChangedNotification";
NSString* ORBurstMonitorEmailListChanged		    = @"ORBurstMonitorEmailListChanged";
NSString* ORBurstMonitorLock                        = @"ORBurstMonitorLock";
NSDate* burstStart = NULL;

#define kBurstRecordLength 12



@interface ORBurstMonitorModel (private)
- (void) deleteQueues;
- (void) monitorQueues;
- (void) delayedBurstEvent;
@end

@implementation ORBurstMonitorModel
#pragma mark \[Bullet]\[Bullet]\[Bullet]Initialization
- (id) init //designated initializer
{
	self = [super init];
    
    [[self undoManager] disableUndoRegistration];
    [[self undoManager] enableUndoRegistration];
	
	return self;
}

-(void) dealloc
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    
    [self deleteQueues];
    [theDecoder release];
    [runUserInfo release];
    [queueLock release];
    [emailList release];
    [burstString release];
    
    [super dealloc];
}

- (void) taskData:(NSDictionary*)taskData
{
    NSString* text = [[taskData objectForKey:@"Text"] retain];
    NSLog(@"Burstcommand Response:\n%@\n",text);
    [text release];
}

- (void) makeConnectors
{
    ORConnector* aConnector = [[ORConnector alloc] initAt:NSMakePoint(0,2*[self frame].size.height/3. - kConnectorSize/2) withGuardian:self withObjectLink:self];
    [[self connectors] setObject:aConnector forKey:ORBurstMonitorInConnector];
	[aConnector setIoType:kInputConnector];
    [aConnector release];
	
    aConnector = [[ORConnector alloc] initAt:NSMakePoint([self frame].size.width/2 - kConnectorSize/2 , 0) withGuardian:self withObjectLink:self];
    [[self connectors] setObject:aConnector forKey:ORBurstMonitorBurstConnector];
	[aConnector setIoType:kOutputConnector];
    [aConnector release];
    
    aConnector = [[ORConnector alloc] initAt:NSMakePoint([self frame].size.width-kConnectorSize,2*[self frame].size.height/3. - kConnectorSize/2) withGuardian:self withObjectLink:self];
    [[self connectors] setObject:aConnector forKey:ORBurstMonitorOutConnector];
	[aConnector setIoType:kOutputConnector];
    [aConnector release];
}

- (void) setUpImage
{
	[self setImage:[NSImage imageNamed:@"BurstMonitor"]];
}

- (void) makeMainController
{
    [self linkToController:@"ORBurstMonitorController"];
}

#pragma mark \[Bullet]\[Bullet]\[Bullet]Accessors
- (NSArray*) collectConnectedObjectsOfClass:(Class)aClass
{
    NSMutableArray* collection = [NSMutableArray arrayWithCapacity:256];
	id obj = [[connectors objectForKey:ORBurstMonitorOutConnector] connectedObject];
	[collection addObjectsFromArray:[obj collectConnectedObjectsOfClass:aClass]];
	return collection;
}

- (unsigned short) numBurstsNeeded      { return numBurstsNeeded; }
- (double) timeWindow           { return timeWindow; }
- (unsigned short) nHit                 { return nHit; }
- (unsigned short) minimumEnergyAllowed { return minimumEnergyAllowed; }

- (void) setNumBurstsNeeded:(unsigned short)aNumBurstsNeeded
{
    if(aNumBurstsNeeded<1)aNumBurstsNeeded=1;
    
    [[[self undoManager] prepareWithInvocationTarget:self] setNumBurstsNeeded:numBurstsNeeded];
    numBurstsNeeded = aNumBurstsNeeded;
    [[NSNotificationCenter defaultCenter] postNotificationName:ORBurstMonitorModelNumBurstsNeededChanged object:self];
}

- (void) setTimeWindow:(double)aValue //was unsigned short for integers
{
    if(aValue<0.000001)aValue = 0.000001;
	[[[self undoManager] prepareWithInvocationTarget:self] setTimeWindow:timeWindow];
    timeWindow = aValue;
    [[NSNotificationCenter defaultCenter] postNotificationName:ORBurstMonitorTimeWindowChanged object:self];
}

- (void) setNHit:(unsigned short)value
{
	[[[self undoManager] prepareWithInvocationTarget:self] setNHit:nHit];
    nHit = value;
    foundMult = nHit;
    //buffer
    //[chans removeAllObjects];
    //[cards removeAllObjects];
    //[adcs removeAllObjects];
    //[secs removeAllObjects];
    //[mics removeAllObjects];
    //[words removeAllObjects];
    [[NSNotificationCenter defaultCenter] postNotificationName:ORBurstMonitorNHitChanged object:self];
}



- (void) setMinimumEnergyAllowed:(unsigned short)value
{
    [[[self undoManager] prepareWithInvocationTarget:self] setMinimumEnergyAllowed:minimumEnergyAllowed];
    minimumEnergyAllowed = value;
    [[NSNotificationCenter defaultCenter] postNotificationName:ORBurstMonitorMinimumEnergyAllowedChanged object:self];
}

- (NSMutableArray*) queueArray
{
    return queueArray;
}

- (NSMutableDictionary*) queueMap
{
    return queueMap;
}

- (NSMutableArray*) emailList
{
    return emailList;
}

- (void) setEmailList:(NSMutableArray*)aEmailList
{
    [[[self undoManager] prepareWithInvocationTarget:self] setEmailList:emailList];
    
    [aEmailList retain];
    [emailList release];
    emailList = aEmailList;
    
    [[NSNotificationCenter defaultCenter] postNotificationName:ORBurstMonitorEmailListChanged object:self];
}

- (void) addAddress:(id)anAddress atIndex:(int)anIndex
{
	if(!emailList) emailList= [[NSMutableArray array] retain];
	if([emailList count] == 0)anIndex = 0;
	anIndex = (int)MIN(anIndex,[emailList count]);
	
	[[[self undoManager] prepareWithInvocationTarget:self] removeAddressAtIndex:anIndex];
	[emailList insertObject:anAddress atIndex:anIndex];
    [[NSNotificationCenter defaultCenter] postNotificationName:ORBurstMonitorEmailListChanged object:self];
}

- (void) removeAddressAtIndex:(int) anIndex
{
	id anAddress = [emailList objectAtIndex:anIndex];
	[[[self undoManager] prepareWithInvocationTarget:self] addAddress:anAddress atIndex:anIndex];
	[emailList removeObjectAtIndex:anIndex];
    [[NSNotificationCenter defaultCenter] postNotificationName:ORBurstMonitorEmailListChanged object:self];
}
- (int) boreX:(int) card Channel:(int) chan // finds x coord of this card and channel
{
    int X;
    X=0;
    if(card == 8 || card == 10 || card == 13 || card == 15) //square cards
    {
        if(chan==4 || chan == 5)
        {
            X = X + 250;
        }
        if(chan==0 || chan ==1)
        {
            X = X + 500;
        }
        if(chan==6 || chan ==7)
        {
            X = X + 750;
        }
        if(chan==2 || chan ==3)
        {
            X = X + 1000;
        }
        if(card == 13 || card == 15) //left cards
        {
            X = X - 1250;
        }
    }
    else if(card == 11 || card == 14)
    {
        if(chan==4 || chan ==5)
        {
            X = X + 500;
        }
        if(chan==0 || chan ==1)
        {
            X = X + 750;
        }
        if(chan==6 || chan ==7)
        {
            X = X + 1000;
        }
        if(chan==2 || chan ==3)
        {
            X = X + 0;
        }
        if(card == 11) //left card
        {
            X = X - 1000;
        }
    }
    else if(card == 9 || card == 12 || card ==5)
    {
        if(chan==4 || chan ==5)
        {
            X = X + 1000;
        }
        if(chan==0 || chan ==1)
        {
            X = X + 0;
        }
        if(chan==6 || chan ==7)
        {
            X = X + 250;
        }
        if(chan==2 || chan ==3)
        {
            X = X + 500;
        }
        if(card == 9) //left card, card 5 is card 12
        {
            X = X - 1000;
        }        
    }
    return X;
}
- (int) boreY:(int) card Channel:(int) chan // finds x coord of this card and channel
{
    int Y;
    Y=0;
    if(card == 8 || card == 10 || card == 13 || card == 15) //square cards
    {
        if(chan==4 || chan ==5 || chan==6 || chan ==7)
        {
            Y = Y + 250;
        }
        if(card == 15)
        {
            Y = Y + 500;
        }
        if(card == 10)
        {
            Y = Y - 250;
        }
        if(card == 8)
        {
            Y = Y - 750;
        }
    }
    else if(card == 11 || card == 14)
    {
        Y = Y - 250;
        if(chan==0 || chan ==1)
        {
            Y = Y - 250;
        }
        if(card == 14) //top card
        {
            Y = Y + 1000;
        }
    }
    else if(card == 9 || card == 12 || card == 5)
    {
        Y = Y + 250;
        if(chan==6 || chan ==7)
        {
            Y = Y + 250;
        }
        if(card == 9) //bottom card
        {
            Y = Y - 1000;
        }
    }
    return Y;
}

- (int) channelsCheck:(NSMutableArray*) aChans
{
    int searchChan = 0;
    int numChan = 0;
    while([aChans count]>0)
    {
        searchChan = [[aChans objectAtIndex:(0)] intValue]; //This is first channel, look to see if there are more of it
        int k; //MAH -- declaration has to be outside the loop for XCode < 5.x
        for(k = 1; k<[aChans count]; k++)
        {
            if([[aChans objectAtIndex:(k)] intValue] == searchChan)
            {
                [aChans removeObjectAtIndex:(k)];
                k=k-1;
            }
        }
        [aChans removeObjectAtIndex:(0)];
        numChan++;
    }
    return numChan;
}

- (double) chanprob:(int) counts Channels:(int) chns Prob:(double) pr Filled:(int) nfull
{
    if((counts == 0) && (chns == 0))
    {
        return pr;
    }
    else if(counts == 0 || (chns < 0) || (chns > counts))
    {
        return 0;
    }
    else{
        return ([self chanprob:(counts - 1) Channels:chns Prob:(pr * nfull/64.0) Filled:nfull] +
                [self chanprob:(counts - 1) Channels:(chns - 1) Prob:(pr * (64.0 - nfull)/64.0) Filled:(nfull + 1)] );
    }
}
- (double) diffprob:(int) co Channels:(int) ch Expect:(double) ex Found:(int) fd
{
    if(ch == 0)
    {
        return 0.0;
    }
    else if((fabs(ch-ex)+0.01) > fabs(fd-ex))
    {
        return ([self chanprob:co Channels:ch Prob:1 Filled:0] + [self diffprob:co Channels:(ch - 1) Expect:ex Found:fd]);
    }
    else 
    {
        return ([self diffprob:co Channels:(ch - 1) Expect:ex Found:fd]);
    }
}
//double gaussp(double sigma) //resolition of 0.01 sigma
//{
//    double nowspot = 0;
//    double p = 0;
//    while(nowspot<sigma)
//    {
//        p = p + 2*0.01*(1/sqrt(2*3.14159))*exp(0.5*sigma*sigma);
//        nowspot = nowspot + 0.01;
//    }
//    return p;
//}
double facto(uint64_t num)
{
    if (num == 0) {
        return 1;
    }
    else {
        double factorial = 1;
        int k;
        for(k = 1; k<num+1; k++)
        {
            factorial = factorial*k;
        }
        return factorial;
    }
}

#pragma mark \[Bullet]\[Bullet]\[Bullet]Data Handling
- (void) processData:(NSArray*)dataArray decoder:(ORDecoder*)aDecoder;
{
    //pass it on
    
    [thePassThruObject processData:dataArray decoder:aDecoder];
    
    if(!theDecoder){
        theDecoder = [aDecoder retain];
    }
    //NSLog(@"%@", [aDecoder fileHeader]);
    NSDate* now = [NSDate date];
    [dataArray retain];
    //each block of data is an array of NSData objects, each potentially containing many records
    for(id data in dataArray){
        [data retain];
        int32_t totalLen = (uint32_t)([data length]/sizeof(int32_t));
        if(totalLen>0){
            uint32_t* ptr = (uint32_t*)[data bytes];
            while(totalLen>0){
                uint32_t dataID = ExtractDataId(ptr[0]);
                int32_t recordLen       = ExtractLength(ptr[0]);
                
                if(recordLen > totalLen){
                    NSLog(@"Bad Record Length\n");
                    NSLogError(@" ",@"BurstMonitor",@"Bad Record:Incorrect Length",nil);
                    printf("Bad Record Length\n");
                    break;
                }
                
                if(dataID==0){
                    header                      = [[NSData dataWithBytes:ptr length:recordLen*4] retain]; //save it for the secondary file
                    NSString* runHeaderString   = [[[NSString alloc] initWithBytes:&ptr[2] length:ptr[1] encoding:NSASCIIStringEncoding] autorelease];
                    //NSDictionary* runHeader     = [runHeaderString propertyList];
                    runHeader = [[runHeaderString propertyList] retain]; //save for burst file
                    
                    shaperID                    = (uint32_t)[[runHeader nestedObjectForKey:@"dataDescription",@"ORShaperModel",@"Shaper",@"dataId",nil] unsignedLongValue];
                    //Find run information
                    //headerID                    = [[runHeader nestedObjectForKey:@"ObjectInfo",@"DataChain",@"Run Control",@"runType",nil] unsignedLongValue];
                    //headerID                    = [[runHeader valueForKeyPath:@"dataDescription.ORShaperModel.Shaper.dataID"] unsignedLongValue];  //gets 0
                    NSDictionary* thing1 = [runHeader objectForKey:@"ObjectInfo"];
                    NSDictionary* thing2 = [thing1 objectForKey:@"DataChain"];
                    NSString* runglob = [NSString stringWithFormat:@"%@", thing2]; //The most specific reference that has no spaces
                    //NSLog(@"%@",runglob);
                    
                    NSRange runnumtitle = [runglob rangeOfString:@"RunNumber = "]; //12 lengnth, need 4 char for run number
                    NSRange runRange = NSMakeRange((runnumtitle.location+12), 4); ///109 4 for runnumber
                    NSString* runnumstr = [runglob substringWithRange:runRange];
                    //NSLog(@"string is %@\n",runnumstr);
                    runnum = [runnumstr intValue];
                    //NSLog(@"Run Number is %i\n", runnum);
                    
                    NSRange runtypetitle = [runglob rangeOfString:@"runType = "]; //10 lengnth, need 10 char for run number
                    NSRange typeRange = NSMakeRange((runtypetitle.location+10), 10); ///109 4 for runnumber
                    NSString* runtypestr = [runglob substringWithRange:typeRange];
                    //NSLog(@"string is space on each side| %@ |.....\n",runtypestr);
                    runtype = [runtypestr intValue];
                    NSLog(@"Run Type is %i \n", runtype);
                    
                    //convert runtype int to array of binary bits
                    int bitval =0;
                    int runtypemeal = runtype;
                    int bitplace;
                    int bitnum = 0;
                    for(bitplace=0; bitplace<11; bitplace++)
                    {
                        bitnum = 10 - bitplace;
                        bitval = log2(runtypemeal) - bitnum + 1;
                        if(bitval<1)
                        {
                            bitval = 0;
                        }
                        else
                        {
                            bitval = 1;
                            runtypemeal = runtypemeal - pow(2,bitnum);
                        }
                        [runbits insertObject:[NSNumber numberWithInt:bitval]  atIndex:0];
                    }
                    
                }
                // header gets here
                if (dataID == shaperID || burstForce==1) {
                    if (recordLen>1 || burstForce==1) {
                        //extract the card's info
                        uint32_t firstword = ShiftAndExtract(ptr[0], 0, 0xffffffff);
                        
                        unsigned short crateNum = ShiftAndExtract(ptr[1],21,0xf);
                        unsigned short cardNum  = ShiftAndExtract(ptr[1],16,0x1f);
                        unsigned short chanNum  = ShiftAndExtract(ptr[1],12,0xf);
                        unsigned short energy   = ShiftAndExtract(ptr[1], 0,0xfff);
                        
                        uint32_t secondsSinceEpoch = ShiftAndExtract(ptr[2], 0, 0xffffffff);
                        uint32_t microseconds = ShiftAndExtract(ptr[3], 0, 0xffffffff);
                        //cbmod check facto power //fixme // 171! == inf //1-erf(x/sqrt(2))
                        //int jj;
                        //double testnum;
                        //for(jj=0; jj<50; jj++)
                        //{
                            //testnum = facto(jj);
                            //testnum = erf(jj/(10.0*sqrt(2.0)));
                            //NSLog(@"%i, %f \n", jj, testnum);
                        //}
                        if(cardNum<=15){ //was break here, now just skip section to include release
                            
                            //was quietsec reset here, wrong
                            
                            
                            //make array of data to be buffered
                            [chans insertObject:[NSNumber numberWithInt:chanNum] atIndex:0];  //crash line, stopoing after burst //Fixme //CBdo
                            [cards insertObject:[NSNumber numberWithInt:cardNum] atIndex:0];
                            [adcs insertObject:[NSNumber numberWithInt:energy]  atIndex:0];
                            [secs insertObject:[NSNumber numberWithLong:secondsSinceEpoch] atIndex:0];
                            [mics insertObject:[NSNumber numberWithLong:microseconds] atIndex:0];
                            [words insertObject:[NSNumber numberWithLong:firstword] atIndex:0];
                            if((energy >= minimumEnergyAllowed && energy <= 1400 && cardNum <= 15) || burstForce ==1){  //Filter
                                quietSec=0;
                                //make a key for looking up the correct queue for this record
                                NSString* aShaperKey = [NSString stringWithFormat:@"%d,%d,%d",crateNum,cardNum,chanNum];
                                
                                [queueLock lock]; //--begin critial section
                                if(![queueMap objectForKey:aShaperKey]){
                                    if(!queueArray) queueArray = [[NSMutableArray array] retain];
                                    
                                    //haven't seen this one before so make a look up table and add a queue for it
                                    [queueMap   setObject:[NSNumber numberWithInteger:[queueArray count]] forKey:aShaperKey];
                                    [queueArray addObject:[NSMutableArray array]];
                                }
                                
                                //get the right queue for this record and insert the record
                                int     queueIndex      = [[queueMap objectForKey:aShaperKey] intValue];
                                NSData* theShaperRecord = [NSData dataWithBytes:ptr length:recordLen*sizeof(int32_t)]; //couldnt put humpdy together again //CBDO re the count
                                
                                ORBurstData* burstData = [[ORBurstData alloc] init];
                                burstData.datePosted = now; //DAQ at LU has a different time zone than the data records do.  It might be best not to mix DAQ time and SBC time in the monitor.
                                burstData.dataRecord = theShaperRecord;
                                NSNumber* epochSec = [NSNumber numberWithLong:secondsSinceEpoch];
                                NSNumber* epochMic = [NSNumber numberWithLong:microseconds];
                                //burstData.epSec = [epochSec copy]; <--- leaks....
                                //burstData.epMic = [epochMic copy]; <--- leaks....
                                burstData.epSec = epochSec; //MAH 9/30/14--no need to copy or retain. the property is doing that.
                                burstData.epMic = epochMic;
                                
                                //[[queueArray objectAtIndex:queueIndex ] addObject:burstData]; //fixme dont add the last event of the burst
                                //[burstData release];
                                int addThisToQueue = 1;
                                
                                [queueLock unlock]; //--end critial section
                                
                                //NSLog(@"length of Nchans is %i", Nchans.count);
                                //fill neutron array
                                [Nchans insertObject:[NSNumber numberWithInt:chanNum] atIndex:0];
                                [Ncards insertObject:[NSNumber numberWithInt:cardNum] atIndex:0];
                                [Nadcs insertObject:[NSNumber numberWithInt:energy]  atIndex:0];
                                [Nsecs insertObject:[NSNumber numberWithLong:secondsSinceEpoch] atIndex:0];
                                [Nmics insertObject:[NSNumber numberWithLong:microseconds] atIndex:0];
                                //NSLog(@"2length of Nchans is %i", Nchans.count);
                                
                                if([Nchans count] >= nHit){ //There is enough data in the buffer now, start looking for bursts
                                    NSUInteger countofchan = [chans count];
                                    NSUInteger countofNchan = [Nchans count]; //CB this probs needs implementing
                                    double lastTime = ([[Nsecs objectAtIndex:0] longValue] + 0.000001*[[Nmics objectAtIndex:0] longValue]);
                                    double firstTime = ([[Nsecs objectAtIndex:(nHit-1)] longValue] + 0.000001*[[Nmics objectAtIndex:(nHit-1)] longValue]);
                                    double diffTime = (lastTime - firstTime);
                                    if(diffTime < timeWindow && burstForce==0){ //burst found, start saveing everything untill it stops
                                        //Record mult in foundMult and see if the count increases it
                                        if (burstState == 1)
                                        {
                                            double lastT = ([[Nsecs objectAtIndex:0] longValue] + 0.000001*[[Nmics objectAtIndex:0] longValue]);
                                            double firstT = ([[Nsecs objectAtIndex:(foundMult)] longValue] + 0.000001*[[Nmics objectAtIndex:(foundMult)] longValue]); //fixme exists?
                                            double diffT = (lastT - firstT);
                                            if(diffT < timeWindow)
                                            {
                                                foundMult = foundMult + 1;
                                                //NSLog(@"foundMult is %i \n", foundMult);
                                            }
                                        }
                                        burstState = 1;
                                        //novaState = 1;
                                        novaP = 1;
                                    }
                                    else{ //no burst found, stop saveing things and send alarm if there was a burst directly before.
                                        if(burstState == 1){
                                            @synchronized(self) //maybe not Bchans
                                            {
                                                multInBurst = foundMult;
                                                foundMult = nHit;
                                                //Make copies of the chans so analysis does not look at new stuff coming in
                                                [Bchans release];
                                                Bchans = [chans mutableCopy]; //part of (old)crash line
                                                
                                                [Bcards release];
                                                Bcards = [cards mutableCopy];
                                                
                                                [Badcs  release];
                                                Badcs  = [adcs mutableCopy];
                                                
                                                [Bsecs  release];
                                                Bsecs  = [secs mutableCopy];
                                                
                                                [Bmics  release];
                                                Bmics  = [mics mutableCopy];
                                                
                                                [Bwords release];
                                                Bwords = [words mutableCopy];
                                                
                                                double firstTime=[[Nsecs objectAtIndex:(countofNchan-1)] intValue] + 0.000001*[[Nmics objectAtIndex:(countofNchan-1)] intValue];
                                                int iter;
                                                NSString* bString = @"";
                                                NSString* lString = @"";
                                                for(iter=1; iter<countofchan; iter++) //Skip most recent event, print all others
                                                {
                                                    double countTime = [[secs objectAtIndex:iter] longValue] + 0.000001*[[mics objectAtIndex:iter] longValue];
                                                    //NSLog(@"count %i t=%f, adc=%i, chan=%i-%i \n", iter, countTime, [[adcs objectAtIndex:iter] intValue], [[cards objectAtIndex:iter] intValue], [[chans objectAtIndex:iter] intValue]);
                                                    //bString = [bString stringByAppendingString:[NSString stringWithFormat:@"count %i t=%lf, t-tB=%lf, adc=%i, chan=%i-%i ", (countofchan - iter), countTime, (countTime-firstTime), [[Badcs objectAtIndex:iter] intValue], [[Bcards objectAtIndex:iter] intValue], [[Bchans objectAtIndex:iter] intValue]]];
                                                    lString = @"";
                                                    lString = [lString stringByAppendingString:[NSString stringWithFormat:@"count %lu ",(countofchan - iter)]];
                                                    lString = [lString stringByPaddingToLength:10 withString:@" " startingAtIndex:0];               //lenth 10
                                                    lString = [lString stringByAppendingString:[NSString stringWithFormat:@"t=%lf, ",countTime]];   //lenth 21
                                                    lString = [lString stringByAppendingString:[NSString stringWithFormat:@"t-tB=%lf,  ",(countTime-firstTime)]];
                                                    lString = [lString stringByPaddingToLength:47 withString:@" " startingAtIndex:0];               //lenth 16 if <100sec int32_t
                                                    lString = [lString stringByAppendingString:[NSString stringWithFormat:@"adc=%i, ",[[Badcs objectAtIndex:iter] intValue]]];
                                                    lString = [lString stringByPaddingToLength:57 withString:@" " startingAtIndex:0];               //lenth 10
                                                    lString = [lString stringByAppendingString:[NSString stringWithFormat:@"chan=%i-%i, ",[[Bcards objectAtIndex:iter] intValue], [[Bchans objectAtIndex:iter] intValue]]];
                                                    lString = [lString stringByPaddingToLength:68 withString:@" " startingAtIndex:0];
                                                    int Xbormm=0;
                                                    int Ybormm=0;
                                                    //NSLog(@"preborxy iter is %i \n", iter);
                                                    Xbormm = [self boreX:[[Bcards objectAtIndex:iter] intValue] Channel:[[Bchans objectAtIndex:iter] intValue]];
                                                    Ybormm = [self boreY:[[Bcards objectAtIndex:iter] intValue] Channel:[[Bchans objectAtIndex:iter] intValue]];
                                                    //NSLog(@"postborxy iter is %i \n", iter);
                                                    lString = [lString stringByAppendingString:[NSString stringWithFormat:@"(x,y)=(%i,%i) ",Xbormm, Ybormm]];
                                                    lString = [lString stringByPaddingToLength:85 withString:@" " startingAtIndex:0];               //lenth 17
                                                    bString = [bString stringByAppendingString:lString];        //Place the line in burststring
                                                    if([[Badcs objectAtIndex:iter] intValue] >= minimumEnergyAllowed && [[Badcs objectAtIndex:iter] intValue] <= 1400)
                                                    {
                                                        bString = [bString stringByAppendingString:[NSString stringWithFormat:@" <---"]];
                                                    }
                                                    if([[Badcs objectAtIndex:iter] intValue] > 1400)
                                                    {
                                                        bString = [bString stringByAppendingString:[NSString stringWithFormat:@" *a*"]];
                                                    }
                                                    if([[Bsecs objectAtIndex:iter] intValue] == [[Nsecs objectAtIndex:(countofNchan-1)] intValue] &&
                                                       [[Bmics objectAtIndex:iter] intValue] == [[Nmics objectAtIndex:(countofNchan-1)] intValue])
                                                    {
                                                        bString = [bString stringByAppendingString:[NSString stringWithFormat:@" <= Burst Start"]];
                                                        numSecTillBurst = [[secs objectAtIndex:iter] longValue] + 0.000001*[[mics objectAtIndex:iter] longValue];
                                                    }
                                                    if([[Bsecs objectAtIndex:iter] intValue] == [[Nsecs objectAtIndex:1] intValue] &&
                                                       [[Bmics objectAtIndex:iter] intValue] == [[Nmics objectAtIndex:1] intValue])
                                                    {
                                                        bString = [bString stringByAppendingString:[NSString stringWithFormat:@" <= Burst End"]];
                                                    }
                                                    bString = [bString stringByAppendingString:[NSString stringWithFormat:@"\n"]];
                                                }
                                                //NSTimeInterval secTillBurst = [NSTimeIntervalSince1970 timeZoneForSecondsFromGMT:numSecTillBurst];
                                                //Bdate = [NSDate dateWithTimeIntervalSince1970:numSecTillBurst];
                                                //NSLog(@"Bdate is %@ \n", Bdate);
                                                
                                                
                                                //Find channel likelyhood of burst
                                                NSMutableArray* reChans = [[Nchans mutableCopy] autorelease]; //MAH added autorelease to prevent memory leak
                                                int j; //MAH -- declaration has to be outside the loop for XCode < 5.x
                                                for(j=0; j<[reChans count]; j++)
                                                {
                                                    int chanID = [[reChans objectAtIndex:j] intValue] + 10*[[Ncards objectAtIndex:j] intValue];
                                                    [reChans replaceObjectAtIndex:j withObject:[NSNumber numberWithInt:chanID]];
                                                }
                                                [reChans removeObjectAtIndex:(0)];
                                                int numChan = [self channelsCheck:(reChans)];
                                                numBurstChan = numChan;
                                                
                                                //Find ADC likelyhood of burst //fixme: has sporatically broken, don't know why.  Possibly stopped breaking after trivial edits.
                                                // did I fix this?  I think it was stuff with the type if the factorial
                                                peakN = 0;
                                                lowN = 0;
                                                int n;
                                                for(n=1; n<[Nadcs count]; n++)
                                                {
                                                    if([[Nadcs objectAtIndex:n] intValue]>380 && [[Nadcs objectAtIndex:n] intValue]<900)
                                                    {
                                                        lowN = lowN + 1;
                                                    }
                                                    else
                                                    {
                                                        if([[Nadcs objectAtIndex:n] intValue]>899 && [[Nadcs objectAtIndex:n] intValue]<1400)
                                                        {
                                                            peakN = peakN + 1;
                                                        }
                                                    }
                                                }
                                                adcP = 0;
                                                double peakP=0.89; //from neutron source data
                                                double peakExpect = peakP*(peakN+lowN);
                                                for(n=0; n<(peakN + lowN + 1); n++)
                                                {
                                                    //uint64_t nfac = facto(n);
                                                    //uint64_t neutfac = facto(peakN+lowN);
                                                    //uint64_t allfac = facto(peakN+lowN-n);
                                                    //int nummy = peakN+lowN-n;
                                                    //NSLog(@"n!, (peak+low-n)!, nummy!, denom is %i, %i, %i, %i \n", facto(n), facto(peakN + lowN - n), facto(nummy), (facto(n)*facto(peakN + lowN - n)));
                                                    //double partP = ( facto (peakN + lowN)/(facto(n)*facto(nummy)) )*pow(peakP,n)*pow((1-peakP),(peakN + lowN - n));
                                                    double partPtop = facto(peakN + lowN);
                                                    double partPbot = facto(n)*facto(peakN + lowN - n);
                                                    double partPpow = pow(peakP,n)*pow((1-peakP),(peakN + lowN - n));
                                                    double partP = 0;
                                                    if (partPbot == 0)
                                                    {
                                                        NSLog(@"Error, factorial failed, n, peak, low, is %i, %i, %i, \n", n, peakN, lowN);
                                                        NSLog(@"And partPtop is %i \n", partPtop);
                                                    }
                                                    else
                                                    {
                                                        //NSLog(@"NP ok, n, peak, low is %i, %i, %i \n", n, peakN, lowN);
                                                        partP = (partPtop*partPpow)/partPbot;
                                                    }
                                                    double partDisk = fabs(n-(peakP*(peakN + lowN)));
                                                    if ((partDisk+0.01)>fabs(peakN - peakExpect))
                                                    {
                                                        adcP = adcP + partP;
                                                    }
                                                    
                                                }
                                                NSLog(@"adcP is %f, peak/lowN is %i, %i \n", adcP, peakN, lowN); //fixme CB remove when confident this works
                                                
                                                //Find background likelyhood in burst //fixme
                                                int numgamma = 0;
                                                double rategamma = 4.95; // 3.8 From run 3681, //4.95 as of 5180
                                                int numalpha = 0;
                                                double ratealpha = 319.0/86400.0; // From a bunch of runs before Aug 2015
                                                double tbackground = 1;
                                                for(n=1; n<[Badcs count]; n++)
                                                {
                                                    if([[Badcs objectAtIndex:n] intValue]<250) //CBdo fixme this should be less than peak/4 - a few peaksigma
                                                    {
                                                        numgamma++;
                                                    }
                                                    else
                                                    {
                                                        if([[Badcs objectAtIndex:n] intValue]>1400)
                                                        {
                                                            numalpha++;
                                                        }
                                                    }
                                                }
                                                tbackground = ([[Bsecs objectAtIndex:1] longValue] + 0.000001*[[Bmics objectAtIndex:1] longValue]) - ([[Bsecs objectAtIndex:([Bsecs count]-1)] longValue] + 0.000001*[[Bmics objectAtIndex:([Bmics count]-1)] longValue]);
                                                double egamma = rategamma*tbackground;
                                                double ealpha = ratealpha*tbackground;
                                                double errgamma=egamma;
                                                double erralpha=ealpha;
                                                if(numgamma>0)
                                                {
                                                    errgamma = (numgamma - egamma)/(sqrt(numgamma));
                                                }
                                                if(numalpha>0)
                                                {
                                                    erralpha = (numalpha - ealpha)/(sqrt(numalpha));
                                                }
                                                isgammalow = 0;
                                                if(egamma>numgamma)
                                                {
                                                    isgammalow = 1;
                                                }
                                                NSLog(@"BG parameters are time of %f, gamma of %i, alpha of %i, expect %f,%f, errs %f,%f \n", tbackground, numgamma, numalpha, rategamma*tbackground, ratealpha*tbackground, errgamma, erralpha );
                                                double inprob = 0;
                                                if(egamma + fabs(numgamma - egamma) < 100) //factorial will work
                                                {
                                                    for(n=0; n<(numgamma + 2*egamma); n++)
                                                    {
                                                        if(fabs(n-egamma) < fabs(numgamma - egamma))
                                                        {
                                                            inprob = inprob + (pow (egamma,n)/(pow(2.7182818284,egamma)*facto(n)));
                                                        }
                                                    }
                                                }
                                                else //normal will work
                                                {
                                                    inprob =erf(fabs (errgamma)/sqrt(2.0));
                                                }
                                                gammaP = 1 - inprob;
                                                inprob = 0;
                                                for(n=0; n<(numalpha + 2*ealpha); n++)
                                                {
                                                    if(fabs(n-ealpha) < fabs(numalpha - ealpha))
                                                    {
                                                        inprob = inprob + (pow (ealpha,n)/(pow(2.7182818284,ealpha)*facto(n)));
                                                    }
                                                }
                                                alphaP = 1 - inprob;
                                                
                                                
                                                //Report basic traits before veto
                                                double startTime = ([[Nsecs objectAtIndex:(countofNchan-1)] longValue] + 0.000001*[[Nmics objectAtIndex:(countofNchan-1)] longValue]);
                                                double endTime = ([[Nsecs objectAtIndex:1] longValue] + 0.000001*[[Nmics objectAtIndex:1] longValue]);
                                                int adcStart = ([[Nadcs objectAtIndex:(countofNchan-1)] intValue]);
                                                durSec = (endTime - startTime);
                                                NSLog(@"Burst duration is %f, start is %f, end is %f, adc %i \n", durSec, startTime, endTime, adcStart);
                                                countsInBurst = (int)countofNchan - 1;
                                                
                                                //Position and reduced duration of burst
                                                rSec = 0;
                                                NSUInteger BurstLen = Nchans.count;
                                                int m;
                                                Xcenter = 0;
                                                Ycenter = 0;
                                                int Xsqr;
                                                int Ysqr;
                                                Xsqr = 0;
                                                Ysqr = 0;
                                                for(m=1;m<BurstLen; m++)
                                                {
                                                    int Xposn;
                                                    int Yposn;
                                                    Xposn = [self boreX:[[Ncards objectAtIndex:m] intValue] Channel:[[Nchans objectAtIndex:m] intValue]];
                                                    Yposn = [self boreY:[[Ncards objectAtIndex:m] intValue] Channel:[[Nchans objectAtIndex:m] intValue]];
                                                    [Bx insertObject:[NSNumber numberWithInt:Xposn] atIndex:0];
                                                    [By insertObject:[NSNumber numberWithInt:Yposn] atIndex:0];
                                                    Xcenter = Xcenter + Xposn;
                                                    //NSLog(@"xposn is %i \n", Xposn);
                                                    Xsqr = Xsqr + (Xposn * Xposn);
                                                    Ycenter = Ycenter + Yposn;
                                                    Ysqr = Ysqr + (Yposn * Yposn);
                                                    //Record reduced time
                                                    if(m>1)
                                                    {
                                                        double rsTime = ([[Nsecs objectAtIndex:(m)] longValue] + 0.000001*[[Nmics objectAtIndex:(m)] longValue]);
                                                        double reTime = ([[Nsecs objectAtIndex:(m-1)] longValue] + 0.000001*[[Nmics objectAtIndex:(m-1)] longValue]);
                                                        rSec = rSec + pow((reTime - rsTime),2);
                                                    }
                                                }
                                                //reduced time scaling
                                                rSec = rSec/(pow(durSec,2));
                                                rSec = (1 - (sqrt(rSec)))*durSec;
                                                //NSLog(@"xcenter is %i \n", Xcenter);
                                                Xcenter = Xcenter / (BurstLen - 1);
                                                Ycenter = Ycenter / (BurstLen - 1);
                                                Rcenter = sqrt((Xcenter*Xcenter) + (Ycenter*Ycenter));
                                                if(Xcenter == 0)
                                                {
                                                    if(Ycenter > 0)
                                                    {
                                                        phi = 3.14159/2;
                                                    }
                                                    else
                                                    {
                                                        phi = 3.14159*1.5;
                                                    }
                                                }
                                                else
                                                {
                                                    phi = atan((1.0*Ycenter)/Xcenter);
                                                }
                                                if(Xcenter < 0)
                                                {
                                                    phi = phi + 3.14159;
                                                }
                                                if(BurstLen > 2)
                                                {
                                                    Xsqr = Xsqr / (BurstLen - 1);
                                                    Ysqr = Ysqr / (BurstLen - 1);
                                                    Xrms = (Xsqr - (Xcenter * Xcenter))*(BurstLen - 1)/(BurstLen - 2);
                                                    Yrms = (Ysqr - (Ycenter * Ycenter))*(BurstLen - 1)/(BurstLen - 2);
                                                    Rrms = Xrms + Yrms;
                                                    Xrms = sqrt(Xrms);
                                                    Yrms = sqrt(Yrms);
                                                    Rrms = sqrt(Rrms);
                                                }
                                                else
                                                {
                                                    Xrms = 0;
                                                    Yrms = 0;
                                                    Rrms = 0;
                                                    
                                                }
                                                rSqrNorm = ((BurstLen-1) * ((Xcenter/250.0) * (Xcenter/250.0)) * 0.145877) + ((BurstLen-1) * ((Ycenter/250.0) * (Ycenter/250.0)) * 0.241784);
                                                [Bx release];
                                                [By release];
                                                //NSLog(@"Burst position is (%i,%i) mm from center, spread of (%i,%i) \n", Xcenter, Ycenter, Xrms, Yrms);
                                                
                                                addThisToQueue = 0;
                                                
                                                [burstString release];
                                                burstString = [bString retain];
                                                
                                                //NSLog(@"precall \n");
                                                //[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(delayedBurstEvent) object:nil]; //monitorqueues 2 lines
                                                //[self performSelector:@selector(delayedBurstEvent) withObject:nil afterDelay:0]; //Has no effect
                                                //NSLog(@"postcall \n");
                                                
                                                //fixme //Try to start DelayedBurstEvent directly, but does not work
                                                //[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(monitorQueues) object:nil];
                                                //[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(delayedBurstEvent) object:nil]; //copied from monitorqueues, maybe?
                                                //[self performSelector:@selector(monitorQueues) withObject:nil afterDelay:1]; //does not work in this function
                                                //NSInvocation *newvoke = [NSInvocation invocationWithMethodSignature:[self, [instanceMethodSignitureForSelector monitorQueues]];
                                                //newvoke.target = self;
                                                //newvoke.selector = monitorQueues;
                                                //[newvoke setArgument:nil atIndex:2];
                                                //[newvoke invoke];
                                                
                                                if(numBurstChan>=numBurstsNeeded)
                                                {
                                                    burstTell = 1;
                                                }
                                                else
                                                {
                                                    NSLog(@"Burst had only %i channels, needed %i \n", numBurstChan, numBurstsNeeded);
                                                    removedSec = (uint32_t)[[secs objectAtIndex:1] longValue];
                                                    removedMic = (uint32_t)[[mics objectAtIndex:1] longValue];
                                                }
                                                //Clean up
                                                [chans removeAllObjects];
                                                [cards removeAllObjects];
                                                [adcs removeAllObjects];
                                                [secs removeAllObjects];
                                                [mics removeAllObjects];
                                                [words removeAllObjects];
                                                
                                                [Nchans removeAllObjects];
                                                [Ncards removeAllObjects];
                                                [Nadcs removeAllObjects];
                                                [Nsecs removeAllObjects];
                                                [Nmics removeAllObjects];
                                            }//end of synch
                                        }//end of burststate = 1 stuff
                                        loudSec=0;
                                        burstForce=0;
                                        //novaState = 0;
                                        novaP = 0;
                                        burstState = 0;
                                        if(Nchans.count<nHit){ // happens if a burst had too few channels and just got whiped
                                            [burstData release]; //MAH... added to prevent memory leak on early return.
                                            return;
                                        }
                                        removedSec = (uint32_t)[[Nsecs objectAtIndex:(nHit-2)] longValue];
                                        removedMic = (uint32_t)[[Nmics objectAtIndex:(nHit-2)] longValue];
                                        
                                        //NSLog(@"removed time is now %f \n", removedSec+0.000001*removedMic);
                                        [Nchans removeObjectAtIndex:nHit-1]; //remove old things from the buffer
                                        [Ncards removeObjectAtIndex:nHit-1];
                                        [Nadcs removeObjectAtIndex:nHit-1];
                                        [Nsecs removeObjectAtIndex:nHit-1];
                                        [Nmics removeObjectAtIndex:nHit-1];
                                        int k=0;
                                        for(k = nHit-1; k<chans.count; k++) //remove old things from the buffer (was k<countofchan, this terminates the function);
                                        {
                                            if(([[secs objectAtIndex:k] longValue] + 0.000001*[[mics objectAtIndex:k] longValue])<(removedSec-5+0.000001*removedMic)) //CB 10 sec early
                                            {
                                                //NSLog(@"removeing stuff, index is %i, time is %li.%li \n", k,[[secs objectAtIndex:k] longValue],[[mics objectAtIndex:k] longValue]);
                                                [chans removeObjectAtIndex:k];
                                                [cards removeObjectAtIndex:k];
                                                [adcs removeObjectAtIndex:k];
                                                [secs removeObjectAtIndex:k];
                                                [mics removeObjectAtIndex:k];
                                                [words removeObjectAtIndex:k];
                                                k=k-1;
                                            }
                                        }
                                        //NSLog(@"Nchans,chans lengths: %i,%i \n", [Nchans count], [chans count]);
                                        NSTimeInterval removedSeconds = removedSec;
                                        burstStart = [NSDate dateWithTimeIntervalSince1970:removedSeconds]; //Fixme hard to get consistency, so used removedSec instead
                                    }//End of no burst found
                                }//End of Nchans>nHit
                                else{
                                    loudSec=0;
                                    burstForce=0;
                                    NSLog(@"not full, has %i neutrons\n", [Nchans count]);
                                    if(burstTell ==1) //Event showed up before burst was prossessed, say it for now but don't record it.
                                    {
                                        double lateTime = [[secs objectAtIndex:0] longValue] + 0.000001*[[mics objectAtIndex:0] longValue];
                                        NSLog(@"extra trip: t=%lf, adc=%i, chan=%i-%i \n", lateTime, [[adcs objectAtIndex:0] intValue], [[cards objectAtIndex:0] intValue], [[chans objectAtIndex:0] intValue]);
                                        addThisToQueue = 0;
                                    }
                                }
                                if((addThisToQueue == 1) || (burstState + burstTell ==0)){
                                    [[queueArray objectAtIndex:queueIndex ] addObject:burstData]; //fixme dont add the last event of the burst
                                }
                                [burstData release];
                            }//end Filter
                        }
                    }//end of valid event with recordlen>1
                }
                
                ptr += recordLen;
                totalLen -= recordLen;
                
            }
        }
        [data release];
    }
    [dataArray release];
}

- (NSMutableDictionary*) addParametersToDictionary:(NSMutableDictionary*)dictionary
{
    NSMutableDictionary* objDictionary = [NSMutableDictionary dictionary];
    [dictionary setObject:objDictionary forKey:@"BurstMonitorObject"];
	return objDictionary;
}

- (void) runTaskStarted:(NSDictionary*)userInfo
{
    burstCount          = 0;
    shaperID            = 0;

    [theDecoder release];
    theDecoder = nil;
    
	thePassThruObject       = [self objectConnectedTo:ORBurstMonitorOutConnector];
	theBurstMonitoredObject = [self objectConnectedTo:ORBurstMonitorBurstConnector];
	
	[thePassThruObject runTaskStarted:userInfo];
	[thePassThruObject setInvolvedInCurrentRun:YES];
	
    [runUserInfo release];
	runUserInfo = [userInfo mutableCopy];
    
    //make sure we start clean
    [self deleteQueues];
    
    if(!queueLock)queueLock = [[NSRecursiveLock alloc] init];
    queueMap = [[NSMutableDictionary dictionary] retain];
    
    chans   = [[NSMutableArray alloc] init]; //Def Bchans here? //crash source?  
    cards   = [[NSMutableArray alloc] init];
    adcs    = [[NSMutableArray alloc] init];
    secs    = [[NSMutableArray alloc] init];
    mics    = [[NSMutableArray alloc] init];
    words   = [[NSMutableArray alloc] init];
    
    Nchans  = [[NSMutableArray alloc] init];
    Ncards  = [[NSMutableArray alloc] init];
    Nadcs   = [[NSMutableArray alloc] init];
    Nsecs   = [[NSMutableArray alloc] init];
    Nmics   = [[NSMutableArray alloc] init];
    
    runbits   = [[NSMutableArray alloc] init];
    
    burstTell   = 0;
    burstState  = 0;
    //novaState   = 0;
    novaP       = 0;
    quietSec    = 0;
    loudSec     = 0;
    
    //start the monitoring
    [self performSelector:@selector(monitorQueues) withObject:nil afterDelay:1];
    
}

- (void) subRunTaskStarted:(NSDictionary*)userInfo
{
	//we don't care
}

- (void) runTaskStopped:(NSDictionary*)userInfo
{
    //stop monitoring the queues
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
   
	[thePassThruObject          runTaskStopped:userInfo];
	[thePassThruObject          setInvolvedInCurrentRun:NO];
    //Clean up -- this are only used in the run process so just release them
    //here. No need to release them in the dealloc.
    [chans release];
    [cards release];
    [adcs release];
    [secs release];
    [mics release];
    
    [words release];
    [Nchans release];
    [Ncards release];
    [Nadcs release];
    [Nsecs release];
    [Nmics release];
    
    [runbits removeAllObjects]; //cb fixme not sure if needed
    [runbits release];

}
- (void) preCloseOut:(NSDictionary*)userInfo
{
}

- (void) closeOutRun:(NSDictionary*)userInfo
{
	[thePassThruObject       closeOutRun:userInfo];
 
    [self deleteQueues];
    
    [theDecoder release];
    theDecoder = nil;
    
    [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:ORBurstMonitorQueueChanged object:self];

}

- (void) setRunMode:(int)aMode
{
	[[self objectConnectedTo:ORBurstMonitorOutConnector] setRunMode:aMode];
	[[self objectConnectedTo:ORBurstMonitorBurstConnector] setRunMode:aMode];
}

- (void) runTaskBoundary
{
}

#pragma mark \[Bullet]\[Bullet]\[Bullet]Archival
static NSString* ORBurstMonitorTimeWindow			 = @"ORBurstMonitor Time Window";
static NSString* ORBurstMonitorNHit                  = @"ORBurstMonitor N Hit";
static NSString* ORBurstMonitorMinimumEnergyAllowed  = @"ORBurstMonitor Minimum Energy Allowed";

- (id) initWithCoder:(NSCoder*)decoder
{
    self = [super initWithCoder:decoder];
	
    [[self undoManager] disableUndoRegistration];
    
    [self setNumBurstsNeeded:       [decoder decodeIntegerForKey:@"numBurstsNeeded"]];
    [self setTimeWindow:            [decoder decodeIntegerForKey:ORBurstMonitorTimeWindow]];
    [self setNHit:                  [decoder decodeIntegerForKey:ORBurstMonitorNHit]];
    [self setMinimumEnergyAllowed:  [decoder decodeIntegerForKey:ORBurstMonitorMinimumEnergyAllowed]];
    [self setEmailList:             [decoder decodeObjectForKey:@"emailList"]];
	
    [[self undoManager] enableUndoRegistration];
	
    return self;
}

- (void) encodeWithCoder:(NSCoder*)encoder
{
    [super encodeWithCoder:encoder];
    [encoder encodeInteger:numBurstsNeeded               forKey:@"numBurstsNeeded"];
    [encoder encodeInteger:[self timeWindow]		     forKey:ORBurstMonitorTimeWindow];
    [encoder encodeInteger:[self nHit]		         forKey:ORBurstMonitorNHit];
    [encoder encodeInteger:[self minimumEnergyAllowed] forKey:ORBurstMonitorMinimumEnergyAllowed];
	[encoder encodeObject:emailList                  forKey:@"emailList"];
}

#pragma mark \[Bullet]\[Bullet]\[Bullet]EMail
- (void) mailSent:(NSString*)address
{
	NSLog(@"Process Center status was sent to:\n%@\n",address);
}

- (void) sendMail:(NSDictionary*)userInfo state:(int)eventState;
{
	NSString* address =  [userInfo objectForKey:@"Address"];
	NSString* content = [NSString string];
	NSString* hostAddress = @"<Unable to get host address>";
	NSArray* names =  [[NSHost currentHost] addresses];
	for(id aName in names){
		if([aName rangeOfString:@"::"].location == NSNotFound){
			if([aName rangeOfString:@".0.0."].location == NSNotFound){
				hostAddress = aName;
				break;
			}
		}
	}
	content = [content stringByAppendingString:@"+++++++++++++++++++++++++++++++++++++++++++++++++++++\n"];
	content = [content stringByAppendingFormat:@"ORCA Message From Host: %@\n",hostAddress];
	content = [content stringByAppendingString:@"+++++++++++++++++++++++++++++++++++++++++++++++++++++\n\n"];
	NSString* theMessage = [userInfo objectForKey:@"Message"];
	if(theMessage){
		content = [content stringByAppendingString:theMessage];
	}
	
	NSAttributedString* theContent = [[NSAttributedString alloc] initWithString:content];
	ORMailer* mailer = [ORMailer mailer];
	[mailer setTo:address];
    NSLog(@"EventState is %i \n", eventState); //mod remove
    if(eventState == 3)
    {
        [mailer setSubject:@"HALO Burst: SN candidate"];
	}
    else if(eventState == 2)
    {
        [mailer setSubject:@"HALO Burst: Spallation"];
	}
    else if(eventState == 1)
    {
        [mailer setSubject:@"HALO Burst: Coincidence"];
	}
    else
    {
        [mailer setSubject:@"HALO Burst: Other"];
    }
    [mailer setBody:theContent];
	[mailer send:self];
	[theContent release];
}

- (NSString*) cleanupAddresses:(NSArray*)aListOfAddresses
{
	NSMutableArray* listCopy = [NSMutableArray array];
	for(id anAddress in aListOfAddresses){
		if([anAddress length] && [anAddress rangeOfString:@"@"].location!= NSNotFound){
			[listCopy addObject:anAddress];
		}
	}
	return [listCopy componentsJoinedByString:@","];
}

- (void) lockArray
{
    [queueLock lock]; //--begin critial section
    
}
- (void) unlockArray
{
    [queueLock unlock];//--end critial section  
}

#pragma mark ***Data Records
- (uint32_t) dataId
{
    return dataId;   }
- (void) setDataId: (uint32_t) DataId  { dataId = DataId; }
- (void) setDataIds:(id)assigner            { dataId  = [assigner assignDataIds:kLongForm]; }
- (void) syncDataIdsWith:(id)anotherVXM     { [self setDataId:[anotherVXM dataId]]; }

- (void) appendDataDescription:(ORDataPacket*)aDataPacket userInfo:(NSDictionary*)userInfo
{
    // add our description to the data description
    [aDataPacket addDataDescriptionItem:[self dataRecordDescription] forKey:@"VXMModel"];
}

- (NSDictionary*) dataRecordDescription
{
    NSMutableDictionary* dataDictionary = [NSMutableDictionary dictionary];
    NSDictionary* aDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
                                 @"ORBurstMonitorDecoderForBurst",              @"decoder",
                                 [NSNumber numberWithLong:dataId],              @"dataId",
                                 [NSNumber numberWithBool:NO],                  @"variable",
                                 [NSNumber numberWithLong:kBurstRecordLength],  @"length",
                                 nil];
    [dataDictionary setObject:aDictionary forKey:@"Burst"];
    return dataDictionary;
}

@end

@implementation ORBurstMonitorModel (private)
- (void) deleteQueues
{
    
    [queueLock lock]; //--begin critial section
    [queueArray release];
    queueArray = nil;

    [queueMap release];
    queueMap = nil;
    [queueLock unlock]; //--end critial section

    [header release];
    header = nil;

}

- (void) monitorQueues
{
    //first make sure that we don't start a new timer
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(monitorQueues) object:nil];
    [queueLock lock]; //--begin critial section
    
    //NSDate* now = [NSDate date];
    int numBurstingChannels = 0;
	int numTotalCounts = 0;

    NSArray* allKeys = [queueMap allKeys];
    for(id aKey in allKeys){
        int i     = [[queueMap  objectForKey:aKey]intValue];
        id aQueue = [queueArray objectAtIndex:i];
            
        while ([aQueue count]) {
			ORBurstData* aRecord = [aQueue objectAtIndex:0]; 
            //NSDate* datePosted = aRecord.datePosted;
            double timePosted = ([aRecord.epSec longValue] + 0.000001*[aRecord.epMic longValue]);
            double timeRemoved = (removedSec + 0.000001*removedMic);
            if(timePosted < timeRemoved){
                [aQueue removeObjectAtIndex:0];
            }
            else break; //done -- no records in queue are older than the time window
        }
		numTotalCounts = numTotalCounts + (int)[aQueue count];
        //check if the number still in the queue would signify a burst then count it.
         if([aQueue count] >= 1){
            numBurstingChannels++;
         }
    }
    
    
    [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:ORBurstMonitorQueueChanged object:self];
    [queueLock unlock];//--end critial section

    //only tag this as a true burst if the number of detectors seeing the burst is more than the number specified.
    //if(numBurstingChannels>=numBurstsNeeded && numTotalCounts>=nHit){
    if(burstTell == 1){  //just call delayedburst when told by data proc //fixme need to remove last event from buffer, or not add it to queue
        burstTell = 0;
        NSLog(@"numBurstingChannels is %i \n", numBurstingChannels);
        NSLog(@"Burst Detected\n");
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(delayedBurstEvent) object:nil]; //CB dissabled for now
        [self performSelector:@selector(delayedBurstEvent) withObject:nil afterDelay:0];
    }
    //Check stall in buffer
    if(burstState == 1){
        quietSec++;
        //loudSec = 1; //temp
        loudSec=(int)([[Nsecs objectAtIndex:1] longValue] - [[Nsecs objectAtIndex:(Nsecs.count-1)] longValue]);  //CB crash source ??? use Bsecs?  can't, not writen yet
        if(quietSec > 10){
            burstForce=1;
            [theBurstMonitoredObject processData:[NSArray arrayWithObject:header] decoder:theDecoder];
        }
        if(loudSec > 120){
            burstForce=1;
            //[theBurstMonitoredObject processData:[NSArray arrayWithObject:header] decoder:theDecoder];
        }
    }

    [self performSelector:@selector(monitorQueues) withObject:nil afterDelay:1];
}

- (void) delayedBurstEvent
{
    burstCount++;
    [queueLock lock]; //--begin critial section
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(delayedBurstEvent) object:nil];
    //calc chan prob
    double exChan =999.999;
    int novaState = 0;
    if(multInBurst > 3 && rSec > 0.01 && adcP > 0.001 && (gammaP > 0.00001 || isgammalow) && alphaP > 0.00001)
    {
        novaState = 3; //SN-Candidate
    }
    else
    {
        novaState = 0; //Other
        if (adcP > 0.001 && (gammaP > 0.001 || isgammalow) && alphaP > 0.001) //Coincidence
        {
            novaState = 1;
        }
        if (multInBurst > 2 && rSec < 0.01 && adcP > 0.001) //Spallation or SF
        {
            novaState = 2;
        }
        if (rSec > durSec + 2) //SBC disconnected
        {
            novaState = 0;
        }
    }
    NSLog(@"Novastate set to %i \n", novaState);
    NSLog(@"isgammalow? %i \n", isgammalow);

    // rhill: Move the determination of the p value here so I can access it to snews.
    // It is a class variable that is calculated later on but I believe it can be done now
    // as all the appropriate variables are defined. 
    if(countsInBurst < 20)
    {
        exChan = 64.0*(1.0-exp(-(countsInBurst/64.0)));
        chanpvalue = [self diffprob:countsInBurst Channels:countsInBurst Expect:exChan Found:numBurstChan];
    }
    else{
        chanpvalue = 999.999;
    }


    if(novaState == 3) //Send a cping somewhere if the burst is good enough
    {
        NSLog(@"Supdernova candidate, send ping if SNEWS run\n");
        //make the time into a sendable string
        NSDate* burstdate = [NSDate dateWithTimeIntervalSince1970:numSecTillBurst];
        NSCalendar* cal = [NSCalendar currentCalendar];
        [cal setTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"UTC"]];
        NSDateComponents* burstcomp = [cal components:(NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay | NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond) fromDate:burstdate];
        NSInteger century = ([burstcomp year]/100);
        NSInteger yy = [burstcomp year] - (100*century);
        NSInteger mmo = 100*[burstcomp month];
        NSInteger dd = 10000*[burstcomp day];
        NSInteger hh = 10000*[burstcomp hour];
        NSInteger mmi = 100*[burstcomp minute];
        NSInteger ss = [burstcomp second];
        NSInteger dateint = yy + mmo + dd;
        NSInteger timeint = ss + mmi + hh;
        NSDateFormatter* dateFormatter = [[[NSDateFormatter alloc] init]autorelease];
        [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
        NSDate* now = [NSDate date];
        NSString* burstDateString = [dateFormatter stringFromDate:burstdate];
        NSString* nowDateString = [dateFormatter stringFromDate:now];

        NSString* burstcommand = @"";
        NSString* snews2burstcommand = @"";
        NSInteger level = 2; //Good alarm, auto.  0=test 1=possible 2=good 3=confirmed -1=retraction
        if([[runbits objectAtIndex:5] intValue] || adcP<0.01 || gammaP<0.01 || alphaP<0.01 || Rrms<453)
        {
            level = 1;
            NSLog(@"Level reduced to 1 (possible)\n");
        }
        NSInteger signif = (multInBurst*0.5)+3; //cbmod current background and best (round) fit with likelyhood as of dec 2016 with logaritmic rounding
        burstcommand = [burstcommand stringByAppendingFormat:@"/home/halo/snews/coinccode/ctestgcli %i %i 0 %i %i 9", (int32_t)dateint, (int)timeint, (int)level, (int)signif];  //maybe add nanoseconds? 9 is halo
       // burstcommand = [burstcommand stringByAppendingFormat:@"/home/halo/snews/testserver/ctestgcli %i %i 5 %i %i 9", (int32_t)dateint, (int)timeint, (int)level, (int)signif];  //maybe add nanoseconds? 9 is halo
        NSLog(@"burstcommand witha a space on each side: | %@ |\n", burstcommand);
        snews2burstcommand = [snews2burstcommand stringByAppendingFormat:@"/home/halosim/remington/snews-venv/submit-halo-sn-candidate.sh %i halo \"%@\" \"%@\" \"%@\" \"Sudbury,ON\" %f ON \"alert\"; ", (int)timeint, nowDateString, burstDateString, nowDateString, (double)chanpvalue];
        NSLog(@"snews2burstcommand with a space on each side: | %@ |\n", snews2burstcommand);
//        NSTask* Cping;
//        Cping =[[NSTask alloc] init];
        ORTaskSequence* tasks=[[ORTaskSequence taskSequenceWithDelegate:self] retain];
        [tasks setVerbose:NO];
        [tasks setTextToDelegate:YES];
        [tasks addTask:@"/usr/bin/ssh" arguments:[NSArray arrayWithObjects:@"halo@10.0.3.1", burstcommand, nil]];
        
        ORTaskSequence* tasks2=[[ORTaskSequence taskSequenceWithDelegate:self] retain];
        [tasks2 setVerbose:NO];
        [tasks2 setTextToDelegate:YES];
        // rhill: Here we will add our task for the SNEWS 2.0 alert.
        [tasks addTask:@"/usr/bin/ssh" arguments:[NSArray arrayWithObjects:@"halosim@10.0.3.1", snews2burstcommand, nil]];
        NSLog(@"end1\n");
        if(1-[[runbits objectAtIndex:6] intValue])  //Send to local machine  //mod change to ping again
        {
            NSLog(@"No pulse sent to snews because run type is not 'SNEWS'\n");
            NSLog(@"Parameters (d,t,l,s) were %i %i %i %i\n", dateint, timeint, level, signif);
//            [Cping setLaunchPath: @"/usr/bin/printf"];
 //           [Cping setArguments: [NSArray arrayWithObjects: @"test string one\n", nil]];
        }
        else{ //Send to halo shift
            NSLog(@"Pulse sent to SNEWS\n");
 //           [Cping setLaunchPath: @"/usr/bin/ssh"];  //@"/usr/bin/ssh"
   //         [Cping setArguments: [NSArray arrayWithObjects: @"halo@10.0.3.1", burstcommand, nil]];  //.223 only for ug
            //[Cping setArguments: [NSArray arrayWithObjects: @"halo@10.0.3.1", @"cd snews/coinccode/ ; mkdir AAASNEWSPINGTEST", nil]];
        }  // -c successfully made directories in home
        NSLog(@"end2\n");
//        [Cping launch]; //Send the ping!
        [tasks launch]; //snews1.0 ping
        [tasks2 launch]; //snews2.0 ping
        NSLog(@"end3\n");
        //system("ssh halo@10.0.3.1 'cd snews/coinccode/ && ./cping all 0 0 0 3'"); freezes orca for about 30 seconds but works
        
        //NSData* pingdata;
        //pingdata = [pingfile readDataToEndOfFile]; //dont do this, it freezes orca
        //NSString* pingstring;
        //pingstring =[[NSString alloc] initWithData:pingdata encoding:NSUTF8StringEncoding];
        //NSLog(@"pingstring is %@ \n", pingstring);
    }
    if((novaState == 1)||(novaState == 2)) //Send a cping somewhere if the burst is good enough
    {
        NSLog(@"Low-threshold candidate, send ping if SNEWS run\n");
        //make the time into a sendable string
        NSDate* burstdate = [NSDate dateWithTimeIntervalSince1970:numSecTillBurst];
        NSCalendar* cal = [NSCalendar currentCalendar];
        [cal setTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"UTC"]];
        NSDateComponents* burstcomp = [cal components:(NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay | NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond) fromDate:burstdate];
        NSDateFormatter* dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
        NSDate* now = [NSDate date];
        NSString* burstDateString = [dateFormatter stringFromDate:burstdate];
        NSString* nowDateString = [dateFormatter stringFromDate:now];
        [dateFormatter release];
        NSInteger century = ([burstcomp year]/100);
        NSInteger yy = [burstcomp year] - (100*century);
        NSInteger mmo = 100*[burstcomp month];
        NSInteger dd = 10000*[burstcomp day];
        NSInteger hh = 10000*[burstcomp hour];
        NSInteger mmi = 100*[burstcomp minute];
        NSInteger ss = [burstcomp second];
        NSInteger dateint = yy + mmo + dd;
        NSInteger timeint = ss + mmi + hh;
        NSString* burstcommand = @"";
        // rhill: I added this stuff for the SNEWS 2.0 alarm. 
        // We will leave the SNEWS 1.0 alarm stuff as is. 
        NSString* snews2burstcommand = @"";
        NSInteger level = 1; //Good alarm, auto.  0=test 1=possible 2=good 3=confirmed -1=retraction
        NSInteger signif = (multInBurst*0.5)+3; //cbmod current background and best (round) fit with likelyhood as of dec 2016 with logaritmic rounding
        burstcommand = [burstcommand stringByAppendingFormat:@"/home/halo/snews/testserver/ctestgcli %i %i 0 %i %i 9; ", (int32_t)dateint, (int)timeint, (int)level, (int)signif];  //maybe add nanoseconds? 9 is halo
         // rhill: Here we will define the snews2burstcommand. Just use the timeint as the message id.
	 // Should be little to no concern about two messages sharing an id. 
	snews2burstcommand = [snews2burstcommand stringByAppendingFormat:@"/home/halosim/remington/snews-venv/submit-halo-sn-candidate.sh %i halo \"%@\" \"%@\" \"%@\" \"Sudbury,ON\" %f ON \"alert test - coincidence or spallation observed\"; ", (int)timeint, nowDateString, burstDateString, nowDateString, (double)chanpvalue];
        NSLog(@"burstcommand witha a space on each side: | %@ |\n", burstcommand);
        // rhill: Add my stuff to the log if it does any good. 
        NSLog(@"snews2burstcommand with a space on each side: | %@ |\n", snews2burstcommand);
// NSTask* Cping;
  //      Cping =[[NSTask alloc] init];
        ORTaskSequence* tasks=[[ORTaskSequence taskSequenceWithDelegate:self] retain];
        [tasks setVerbose:NO];
        [tasks setTextToDelegate:YES];
        [tasks addTask:@"/usr/bin/ssh" arguments:[NSArray arrayWithObjects:@"halo@10.0.3.1", burstcommand, nil]];
        
        ORTaskSequence* tasks2=[[ORTaskSequence taskSequenceWithDelegate:self] retain];
        [tasks2 setVerbose:NO];
        [tasks2 setTextToDelegate:YES];
        // rhill: Here we will add our task for the SNEWS 2.0 alert.
        [tasks addTask:@"/usr/bin/ssh" arguments:[NSArray arrayWithObjects:@"halosim@10.0.3.1", snews2burstcommand, nil]];
        NSLog(@"end1\n");
        if(1-[[runbits objectAtIndex:6] intValue])  //Send to local machine  //mod change to ping again
        {
            NSLog(@"No pulse sent to snews because run type is not 'SNEWS'\n");
            NSLog(@"Parameters (d,t,l,s) were %i %i %i %i\n", dateint, timeint, level, signif);
   //         [Cping setLaunchPath: @"/usr/bin/printf"];
   //         [Cping setArguments: [NSArray arrayWithObjects: @"test string one\n", nil]];
        }
        else{ //Send to halo shift
            NSLog(@"Pulse sent to SNEWS Test Server\n");
     //       [Cping setLaunchPath: @"/usr/bin/ssh"];  //@"/usr/bin/ssh"
    //        [Cping setArguments: [NSArray arrayWithObjects: @"halo@10.0.3.1", burstcommand, nil]];  //.223 only for ug
        }  // -c successfully made directories in home
        NSLog(@"end2\n");
        [tasks launch]; //snews1.0 ping
        [tasks2 launch]; //snews2.0 ping
    //    [Cping launch]; //Send the ping!
        NSLog(@"end3\n");
    }
    if(countsInBurst < 20)
    {
        //exChan = 64.0*(1.0-exp(-(countsInBurst/64.0)));
        //chanpvalue = [self diffprob:countsInBurst Channels:countsInBurst Expect:exChan Found:numBurstChan];
        NSLog(@"chanpvalue is %f, expected is %f \n", chanpvalue, exChan);
    }
    //else{
    //    chanpvalue = 999.999;
    //}
    //make runtype string
    NSString* theRuntypes = @"[";
    if([[runbits objectAtIndex:0] intValue] == 1) theRuntypes = [theRuntypes stringByAppendingString:@"\"Maintenance\""];
    if([[runbits objectAtIndex:1] intValue] == 1) theRuntypes = [theRuntypes stringByAppendingString:@"\"Supernova\""];
    if([[runbits objectAtIndex:2] intValue] == 1) theRuntypes = [theRuntypes stringByAppendingString:@"\"Calibration\""];
    if([[runbits objectAtIndex:3] intValue] == 1) theRuntypes = [theRuntypes stringByAppendingString:@", \"Underground\""];
    if([[runbits objectAtIndex:4] intValue] == 1) theRuntypes = [theRuntypes stringByAppendingString:@", \"Front Shielding\""];
    if([[runbits objectAtIndex:5] intValue] == 1) theRuntypes = [theRuntypes stringByAppendingString:@", \"Unusual Condition\""];
    if([[runbits objectAtIndex:6] intValue] == 1) theRuntypes = [theRuntypes stringByAppendingString:@", \"SNEWS\""];
    if([[runbits objectAtIndex:7] intValue] == 1) theRuntypes = [theRuntypes stringByAppendingString:@", \"Pulser\""];
    if([[runbits objectAtIndex:8] intValue] == 1) theRuntypes = [theRuntypes stringByAppendingString:@", \"Source in Storage\""];
    if([[runbits objectAtIndex:9] intValue] == 1) theRuntypes = [theRuntypes stringByAppendingString:@", \"Source in Area\""];
    if([[runbits objectAtIndex:10] intValue] == 1) theRuntypes = [theRuntypes stringByAppendingString:@", \"Source in HALO\""];
    theRuntypes = [theRuntypes stringByAppendingString:@"]"];
    //send email to announce the burst
    int numMicTillBurst = (1000000*fmod(numSecTillBurst,1));
    NSLog(@"Novastate is now %i \n", novaState); ////////////////////////////////////////////////////////////
    NSString* theContent = @"";
    theContent = [theContent stringByAppendingString:@"+++++++++++++++++++++++++++++++++++++++++++++++++++++\n"];
    theContent = [theContent stringByAppendingString:@"Triage: "];
    NSString* theTriage = @"";
    if(novaState == 3)
    {
        theTriage = [theTriage stringByAppendingString:@"SN candidate!"];
        if([[runbits objectAtIndex:6] intValue])
        {
            theContent = [theContent stringByAppendingString:@"SN candidate!  Ping sent to snews \n"];
        }
        else
        {
            theContent = [theContent stringByAppendingString:@"SN candidate, ping not sent beacsue run tag 'SNEWS' is off. \n"];
        }
    }
    if(novaState == 2)
    {
        theTriage = [theTriage stringByAppendingString:@"Spallation/SF"];
        theContent = [theContent stringByAppendingString:@"Spallation or SF \n"];
    }
    if(novaState == 1)
    {
        theTriage = [theTriage stringByAppendingString:@"Coincidence"];
        theContent  = [theContent stringByAppendingString:@"Neutron coincidence \n"];
    }
    if(novaState == 0)
    {
        theTriage = [theTriage stringByAppendingString:@"Other"];
        theContent  = [theContent stringByAppendingString:@"Other (Not neutrons) \n"];
    }
    theContent = [theContent stringByAppendingString:@"+++++++++++++++++++++++++++++++++++++++++++++++++++++\n"];
    theContent = [theContent stringByAppendingFormat:@"This report was generated automatically at:\n"];
    theContent = [theContent stringByAppendingFormat:@"%@ (Local time of ORCA machine) in run number %i of run type %i \n",[NSDate date], runnum, runtype];
    theContent = [theContent stringByAppendingFormat:@"Run type: %@ \n",theRuntypes];
    theContent = [theContent stringByAppendingFormat:@"First event in burst:\n"];
    theContent = [theContent stringByAppendingFormat:@"%@, %i us (UTC), time from SBC cards \n", [NSDate dateWithTimeIntervalSince1970:numSecTillBurst], numMicTillBurst];
    theContent = [theContent stringByAppendingString:@"+++++++++++++++++++++++++++++++++++++++++++++++++++++\n"];
    theContent = [theContent stringByAppendingFormat:@"Time Window: %f sec\n",timeWindow];
    theContent = [theContent stringByAppendingFormat:@"Events/Window Needed: %d\n",nHit];
    theContent = [theContent stringByAppendingFormat:@"Minimum ADC Energy: %d\n",minimumEnergyAllowed];
    theContent = [theContent stringByAppendingFormat:@"Number of channels required: %d\n",numBurstsNeeded];
    theContent = [theContent stringByAppendingString:@"+++++++++++++++++++++++++++++++++++++++++++++++++++++\n"];
    theContent = [theContent stringByAppendingFormat:@"Total counts in the burst: %d\n",countsInBurst];
    theContent = [theContent stringByAppendingFormat:@"Detected multiplicity in time window: %d\n",multInBurst];
    theContent = [theContent stringByAppendingFormat:@"Number of channels in this burst: %d\n",numBurstChan];
    theContent = [theContent stringByAppendingFormat:@"Epected number of channels: %f, Probablility given number of counts: %f \n", exChan, chanpvalue];
    theContent = [theContent stringByAppendingFormat:@"Number of events with neutron-like energy: %d\n",peakN + lowN];
    theContent = [theContent stringByAppendingFormat:@"Likelyhood of neutron energy distribution: %f, Likelyhood of (<250adc, >1400adc) background: %f,%f\n",adcP,gammaP,alphaP];
    theContent = [theContent stringByAppendingFormat:@"Position: (x,y)=(%i+-%f,%i+-%f) mm, phi=%f, r=%f mm, rms=%f mm  \n", Xcenter, Xrms, Ycenter, Yrms, phi, Rcenter, Rrms];
    theContent = [theContent stringByAppendingFormat:@"SN expected: (x,y)=(0+-655,0+-508) mm, r=0 mm, rms=829 mm  \n"];
    theContent = [theContent stringByAppendingFormat:@"Likelyhood of central position: chisquared %f/2, p = %f \n", rSqrNorm, exp(-0.5*rSqrNorm)];
    theContent = [theContent stringByAppendingFormat:@"Duration of burst: %f seconds \n",durSec];
    theContent = [theContent stringByAppendingFormat:@"Reduced  duration: %f seconds \n",rSec];
    theContent = [theContent stringByAppendingFormat:@"Num Bursts this run: %d\n",burstCount];
    theContent = [theContent stringByAppendingString:@"+++++++++++++++++++++++++++++++++++++++++++++++++++++\n"];
    theContent = [theContent stringByAppendingString:@"Counts from 5 seconds before the burst untill the next out-of-burst above-threshold event. Time in s, distance in mm \n"];
    theContent = [theContent stringByAppendingString:@"+++++++++++++++++++++++++++++++++++++++++++++++++++++\n"];
    theContent = [theContent stringByAppendingString:burstString];
    theContent = [theContent stringByAppendingString:@"+++++++++++++++++++++++++++++++++++++++++++++++++++++\n"];
    
    NSArray* allKeys = [[queueMap allKeys]sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
    for(id aKey in allKeys){
        int i     = [[queueMap  objectForKey:aKey]intValue];
        id aQueue = [queueArray objectAtIndex:i];
        NSUInteger count = [aQueue count];
        theContent = [theContent stringByAppendingFormat:@"Channel: %@ Number Events: %d %@\n",aKey,(int)[aQueue count],count>=1?@" <---":@""];
    }
    if(novaState == 3 && [[runbits objectAtIndex:6] intValue]){  //if supernova candidate
        [emailList insertObject:@"halo_snews_burst@snolab.ca"  atIndex:0]; //add halo full, HALO_full@snolab.ca
    }
    theContent = [theContent stringByAppendingString:@"+++++++++++++++++++++++++++++++++++++++++++++++++++++\n"];
    theContent = [theContent stringByAppendingString:@"The following people received this message:\n"];
    for(id address in emailList) theContent = [theContent stringByAppendingFormat:@"%@\n",address];
    theContent = [theContent stringByAppendingString:@"+++++++++++++++++++++++++++++++++++++++++++++++++++++\n"];
    
    NSLog(@"theContent in delayedBurstEvent is: \n %@", theContent);
    NSDictionary* userInfo = [NSDictionary dictionaryWithObjectsAndKeys:[self cleanupAddresses:emailList],@"Address",theContent,@"Message",nil];
    [self sendMail:userInfo state:novaState];
    if(novaState == 3 && [[runbits objectAtIndex:6] intValue]){
        [emailList removeObjectAtIndex:0]; //clean up extra email addressses
    }
    
    //write file with burst data
    NSString* allBurstData = [NSString stringWithFormat:@"\",\"novaState\":%i,\"dateSec\":%f,\"dateMic\":%i,\"runNum\":%i,\"runType\":%@,\"Ncount\":%i,\"Nmult\":%i,\"Nchan\":%i,\"ENchan\":%f,\"pNchan\":%f,\"N\":%i,\"adcP\":%f,\"gammaP\":%f,\"alphaP\":%f,\"Xcenter\":%i,\"Xrms\":%f,\"Ycenter\":%i,\"Yrms\":%f,\"phi\":%f,\"Rcenter\":%f,\"Rrms\":%f,\"Pcenter\":%f,\"durSec\":%f,\"rSec\":%f,\"burstNum\":%i}",novaState,numSecTillBurst,numMicTillBurst,runnum,theRuntypes,countsInBurst,multInBurst,numBurstChan,exChan,chanpvalue,peakN+lowN,adcP,gammaP,alphaP,Xcenter,Xrms,Ycenter,Yrms,phi,Rcenter,Rrms,exp(-0.5*rSqrNorm),durSec,rSec,burstCount];
    
    NSTask* getrev;
    getrev =[[NSTask alloc] init];
    NSPipe* piperev;
    piperev = [NSPipe pipe];
    [getrev setStandardOutput: piperev];
    
    [getrev setLaunchPath: @"/usr/bin/curl"];  //curl is there
    ////[getrev setArguments: [NSArray arrayWithObjects: @"-s", @"-X", @"GET", @"http://10.0.3.1:5984/shapers/card8channel0", @"|", @"cut", @"-d", @"\"}\"", @"-f", 1, @"|", @"cut", @"-d", @"\",\"", @"-f", 2, @"|", @"cut", @"-d", @"\":\"", @"-f", 2, nil]]; //gets bad access
    ////[getrev setArguments: [NSArray arrayWithObjects: @"-s", @"-X", @"GET", @"http://10.0.3.1:5984/shapers/card8channel0", @"|", @"cut", @"-d", @"\"}\"", @"-f", @"1", @"|", @"cut", @"-d", @"\",\"", @"-f", @"2", @"|", @"cut", @"-d", @"\":\"", @"-f", @"2", nil]];  //this returns min args return on DAQ1 somehow
    [getrev setArguments: [NSArray arrayWithObjects: @"-s", @"-X", @"GET", @"http://10.0.3.1:5984/bursts/burstevents", nil]];  //was @"http://10.0.3.1:5984/shapers/card8channel0"
    NSFileHandle* revfile;
    NSData *revdata;
    NSString *revstring;
    NSString* bursttextstr = @"{\"_id\":\"burstevents\",\"_rev\":\"";
    @try{
    [getrev launch]; //find the rev!!!
    NSLog(@"part 0\n"); //got here with end card8channel0, and with } end
    
    [getrev waitUntilExit]; //waits like 60 seconds for 10.0.3.1 on lu daq, freezes before without this
    //NSLog(@"part 1\n");
    //[getrev terminate]; //needs this to work
    [getrev release];
    //NSLog(@"part 2\n");
    revfile =[piperev fileHandleForReading];  //maybe need declare here
    revdata = [revfile readDataToEndOfFile];
    //NSLog(@"part 3\n");
    revstring = [[[NSString alloc] initWithData:revdata encoding:NSUTF8StringEncoding]autorelease];
    //revstring = [revstring stringByAppendingString:@"{\"_id\":\"card8channel0\",\"_rev\":\"37-5b3dc887d615db963492927bfb3fb124\",\"Run\":\"3832\",\"Card\":\"8\",\"Channel\":\"0\",\"Centroids\":\"187.524,324.44,457.7,593.55,727.29,860.39,994.6,1127.99,1262.36,1396.07\",\"Standard_deviation_centroids\":\"1.15036,0.316961,0.299833,0.30639,0.336242,0.317772,0.294958,0.277667,0.333023,0.325655\",\"Fit_parameter 0\":\"-2.43283\",\"Error_param 0\":\"0.643567\",\"Fit_parameter 1\":\"9.61408\",\"Error_param 1\":\"0.0160168\",\"Fit_parameter 2\":\"-0.000254695\",\"Error_param 2\":\"8.90062e-05\",\"Reduced_chisquare\":\"3.91508\"}"]; //Set to this for test
    NSLog(@"early allburstdata is %@\n", allBurstData);
    NSLog(@"early revstring is %@\n", revstring);
    NSRange revnumstart = [revstring rangeOfString:@"rev\":\""];
    NSRange revnumend =[revstring rangeOfString:@"\",\"novaState\":"];
    int revnumlen = (int)(revnumend.location - (revnumstart.location + 6));
    NSRange revRange = NSMakeRange((revnumstart.location + 6), revnumlen);
    revstring = [revstring substringWithRange:revRange];
    bursttextstr = [bursttextstr stringByAppendingString:revstring];
    bursttextstr = [bursttextstr stringByAppendingString:allBurstData];
    //allBurstData = [revstring stringByAppendingString:allBurstData];
    NSLog(@"part 4\n");
    }
    @catch(NSException* exc)
    {
        NSLog(@"Could not contact couchDB to get revision number.  Exception is %@\n", exc);
    }
    NSLog(@"bursttextstr is %@\n", bursttextstr);
    //////stringWithFormat:@"{'novaState':'%i','dateSec':'%f','dateMic':'%i','runNum':'%i','runType':'%@','Ncount':'%i','Nmult':'%i','Nchan':'%i','ENchan':'%f','pNchan':'%f','N':'%i','adcP':'%f','gammaP':'%f','alphaP':'%f','Xcenter':'%i','Xrms':'%f','Ycenter':'%i','Yrms':'%f','phi':'%f','Rcenter':'%f','Rrms':'%f','Pcenter':'%f','durSec':'%f','rSec':'%f','burstNum':'%i'}",novaState,numSecTillBurst,numMicTillBurst,runnum,theRuntypes,countsInBurst,multInBurst,numBurstChan,exChan,chanpvalue,peakN+lowN,adcP,gammaP,alphaP,Xcenter,Xrms,Ycenter,Yrms,phi,Rcenter,Rrms,exp(-0.5*rSqrNorm),durSec,rSec,burstCount];
    /// return from min args {"_id":"card8channel0","_rev":"37-5b3dc887d615db963492927bfb3fb124","Run":"3832","Card":"8","Channel":"0","Centroids":"187.524,324.44,457.7,593.55,727.29,860.39,994.6,1127.99,1262.36,1396.07","Standard_deviation_centroids":"1.15036,0.316961,0.299833,0.30639,0.336242,0.317772,0.294958,0.277667,0.333023,0.325655","Fit_parameter 0":"-2.43283","Error_param 0":"0.643567","Fit_parameter 1":"9.61408","Error_param 1":"0.0160168","Fit_parameter 2":"-0.000254695","Error_param 2":"8.90062e-05","Reduced_chisquare":"3.91508"}
    //make append string
    if(1){ //write the file when we want to do that
        NSError* fileWriteErr;
        NSFileManager* fileman = nil;
        NSString* currentDir = [fileman currentDirectoryPath];
        BOOL ok = [bursttextstr writeToFile:@"/Users/daq/lastburst.txt" atomically:1 encoding:NSASCIIStringEncoding error:&fileWriteErr]; //Encoding that dont work: NSUnicodeStringEncoding
        NSLog(@"file write okness is %i\n", ok);
        NSLog(@"look for the file at %@\n", currentDir);
    }
    //send the file to couchdb
    system("/Users/daq/burstcouch.sh");
    /*
    NSTask* sendrev;
    NSFileHandle* sendfile;
    NSData *senddata;
    NSString *sendstring;
    sendrev =[[NSTask alloc] init];
    NSPipe* pipesend;
    pipesend = [NSPipe pipe];
    @try{
    [sendrev setStandardOutput: pipesend];
    [sendrev setLaunchPath: @"/usr/bin/curl"];
    [sendrev setArguments: [NSArray arrayWithObjects: @"-s", @"-X", @"PUT", @"http://10.0.3.1:5984/bursts/burstevents", @"-d", @"@/Users/daq/lastburst.txt", @"-H", @"\"Content-Type: application/json\"", nil]];
    ///curl -s -X PUT http://10.0.3.1:5984/DATABASE_NAME/DOCUMENT_NAME -d @/PATH/TO/TEXT/FILE.txt -H "Content-Type: application/json"
    NSLog(@" Now Sending the burst data to couch\n");
    [sendrev launch];
    [sendrev waitUntilExit];
    [sendrev terminate];
    [sendrev release];
    NSLog(@"Done Sending the burst data to couch\n");
    sendfile =[pipesend fileHandleForReading];  //maybe need declare here
    senddata = [sendfile readDataToEndOfFile];
    sendstring = [[NSString alloc] initWithData:senddata encoding:NSUTF8StringEncoding];
    NSLog(@"Send to couch result: %@\n", sendstring);
    }
    @catch(NSException* exc)
    {
        NSLog(@"Could not send text file to couchdb.  Exception is %@\n", exc);
    }
    */
    
    //flush all queues to the disk fle
    NSString* fileSuffix = [NSString stringWithFormat:@"Burst_%d_",burstCount];
    [runUserInfo setObject:fileSuffix forKey:kFileSuffix];
	[theBurstMonitoredObject runTaskStarted:runUserInfo];
	[theBurstMonitoredObject setInvolvedInCurrentRun:YES];

    
    [theBurstMonitoredObject processData:[NSArray arrayWithObject:header] decoder:theDecoder]; //this is the header of the data file
    //ship the burst data record
    //use a union to encode the duration
    union {
        int32_t asLong;
        float asFloat;
    }LongFloatUnion;
    
    //get the time(UT!)
    time_t	ut_time;
    time(&ut_time);
    
    
    uint32_t data[kBurstRecordLength];
    data[0] = dataId | kBurstRecordLength;
    data[1] = burstCount;
    data[2] = numSecTillBurst;
    
    LongFloatUnion.asFloat = durSec;
    data[3] = LongFloatUnion.asLong;
    
    data[4] = multInBurst;
    data[5] = novaState;
    data[6] = Rcenter;
    data[7] = Rrms;
    LongFloatUnion.asFloat = adcP;
    data[8] = LongFloatUnion.asLong;
    LongFloatUnion.asFloat = gammaP;
    data[9] = LongFloatUnion.asLong;
    LongFloatUnion.asFloat = alphaP;
    data[10] = LongFloatUnion.asLong;
    data[11] = (uint32_t)ut_time;

    //pass the record on to the next object
    [theBurstMonitoredObject processData:[NSArray arrayWithObject:[NSData dataWithBytes:data length:sizeof(int32_t)*kBurstRecordLength]] decoder:theDecoder];
    
    NSMutableArray* anArrayOfData = [NSMutableArray array];
    //ORBurstData* someData = [[[ORBurstData alloc] init] autorelease]; //<<<<MAH. added the autorelease to prevent memory leak below. //was separate, test
    /*
    int dursecond = durSec;
    int durmicro = (durSec - dursecond)*1000000;
    int intSecTillBurst = numSecTillBurst;
    int burstbit = MIN(burstCount,250);
    int multbit = MIN(multInBurst,4000);
    //novastate alread int from 0 to 4
    dursecond = MIN(dursecond,250);
    uint32_t burststats[4];
    burststats[0]=[[Bwords objectAtIndex:0] longValue];
    burststats[1]=burstbit+(multbit << 8)+(novaState << 20) + (dursecond << 24); // adc 3 digets, channel, card
    burststats[2]=durmicro;
    burststats[3]=intSecTillBurst;
    NSLog(@"before: %@\n", someData.dataRecord);
    //someData.dataRecord = [NSData dataWithBytes:&testsec length: sizeof(testsec)];
    someData.dataRecord = [NSData dataWithBytes:burststats length: sizeof(burststats)];
    [anArrayOfData addObject:someData.dataRecord];
    NSLog(@"after: %@\n", someData.dataRecord);
     */
    
//    [theBurstMonitoredObject processData:[NSArray arrayWithObject:burstHeaderData] decoder:theDecoder]; //this is the header of the data file
    
    /*NSRange headerLengthSpot = [headerAsString rangeOfString:@"</string>"];
    NSString* header1 = [headerAsString substringToIndex:headerLengthSpot.location];
    NSString* header2 = [headerAsString substringFromIndex:headerLengthSpot.location];
    int intSecTillBurst = numSecTillBurst;
    
    //header1 = [header1 stringByAppendingFormat:@"<key>BurstInfo</key>\n\t<dict>\n\t\t<key>BurstNumber</key>\n\t\t<integer>%i</integer>\n\t\t<key>BurstStartTime</key>\n\t\t<integer>%i</integer>\n\t\t<key>Triage</key>\n\t\t<string>%@</string>\n\t\t<key>BurstDuration</key>\n\t\t<real>%f</real>\n\t\t<key>Multiplicity</key>\n\t\t<integer>%i</integer>\n\t</dict>\n\t", burstCount, intSecTillBurst, theTriage, durSec, countsInBurst];  //theTriage or novaState?
    //header1 = [header1 stringByAppendingFormat:@"Num(%i)T(%i)Tr(%@)BD(%f)M(%i)", burstCount, intSecTillBurst, theTriage, durSec, countsInBurst];
    //header1 = [header1 stringByAppendingFormat:@"Num(%i)T(%i)Tr(%@)BD(%f)M(%i)", burstCount, intSecTillBurst, theTriage, durSec, countsInBurst];
    header1 = [header1 stringByAppendingString:header2];
    NSLog(header1);
    NSData* newheader=[header1 dataUsingEncoding:NSASCIIStringEncoding];
                       //NSUTF8StringEncoding];
    */
    
    //NSMutableArray* anArrayOfData = [NSMutableArray array];  //Cb moved this thing //fixme
    //Make the data record from the burst array
    @synchronized(self)
    {
    int BurstSize = (int)Bchans.count;
    NSLog(@"Size of burst file: %i \n", (BurstSize - 1) );
    int l;
    for(l=1;l<BurstSize; l++)
    {
        
        //------------------------
        //MAH 09/16/14 Some notes:
        //this was some really bad code below... modified slightly by MAH to get rid of compiler warnings.
        //you should review this and make additional changes. Please review the use of pointers and objects...
        //if you are trying to make a data record, we need to talk. you need to use the proper data id and data
        //record size in the first word in order to have it work....
        //-------------------------
        ORBurstData* someData = [[[ORBurstData alloc] init] autorelease]; //<<<<MAH. added the autorelease to prevent memory leak below. //was separate, test
        //someData.epSec=[[Bsecs objectAtIndex:l] longValue]; //crashes from bad access, but seems unneccesary //fixme?
        //someData.epMic=[[Bmics objectAtIndex:l] longValue];
       // uint32_t* testsec[4]; <<--this is not being used as a pointer. removed MAH 09/16/14
        uint32_t testsec[4];
        testsec[0]=(uint32_t)[[Bwords objectAtIndex:l] longValue];
        testsec[1]=(uint32_t)([[Badcs objectAtIndex:l] longValue]+(4096*[[Bchans objectAtIndex:l] longValue])+(65536*[[Bcards objectAtIndex:l] longValue])); // adc 3 digets, channel, card
        testsec[2]=(uint32_t)[[Bsecs objectAtIndex:l] longValue];
        testsec[3]=(uint32_t)[[Bmics objectAtIndex:l] longValue]; //CB works, make data file from array now
        //someData.dataRecord = [NSData dataWithBytes:&testsec length: sizeof(testsec)]; <<--removed MAH 09/16/14
        someData.dataRecord = [NSData dataWithBytes:testsec length: sizeof(testsec)];
        [anArrayOfData addObject:someData.dataRecord];
    }
    [theBurstMonitoredObject processData:anArrayOfData decoder:theDecoder];
    //end of adding things to the data file
    }// end synch
        
    for(NSMutableArray* aQueue in queueArray){
        //Data file writing was here before
        //for(ORBurstData* someData in aQueue)
        //[anArrayOfData addObject:someData.dataRecord];
        [aQueue removeAllObjects];
    }
    [queueLock unlock];//--end critial section
    
	[theBurstMonitoredObject    runTaskStopped:userInfo];
    [theBurstMonitoredObject    closeOutRun:userInfo];
	[theBurstMonitoredObject    setInvolvedInCurrentRun:NO];
}

@end

@implementation ORBurstData

@synthesize datePosted;
@synthesize dataRecord;
@synthesize epSec;
@synthesize epMic;

- (void) dealloc
{
    //release the properties
    self.dataRecord =   nil;
    self.datePosted =   nil;
    self.epSec      =   nil;
    self.epMic      =   nil;
    [super dealloc];
}
@end
