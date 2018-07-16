//--------------------------------------------------------
// ORMks651cController
// Created by David G. Phillips II on Tue Aug 30, 2011
// Code partially generated by the OrcaCodeWizard. Written by Mark A. Howe.
// Copyright (c) 2005 CENPA, University of Washington. All rights reserved.
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

#pragma mark ***Imported Files

#import "ORMks651cController.h"
#import "ORMks651cModel.h"
#import "ORTimeLinePlot.h"
#import "ORCompositePlotView.h"
#import "ORTimeAxis.h"
#import "ORSerialPortList.h"
#import "ORSerialPort.h"
#import "ORTimeRate.h"

@interface ORMks651cController (private)
- (void) populatePortListPopup;
@end

@implementation ORMks651cController

#pragma mark ***Initialization

- (id) init
{
	self = [super initWithWindowNibName:@"Mks651c"];
	return self;
}

- (void) dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[super dealloc];
}

- (void) awakeFromNib
{
    [self populatePortListPopup];
    [[plotter0 yAxis] setRngLow:-1000. withHigh:1000.];
	[[plotter0 yAxis] setRngLimitsLow:-100000 withHigh:100000 withMinRng:10];
	[plotter0 setUseGradient:YES];

    [[plotter0 xAxis] setRngLow:0.0 withHigh:10000];
	[[plotter0 xAxis] setRngLimitsLow:0.0 withHigh:200000. withMinRng:200];

	ORTimeLinePlot* aPlot;
	aPlot= [[ORTimeLinePlot alloc] initWithTag:0 andDataSource:self];
	[plotter0 addPlot: aPlot];
	[aPlot setLineColor:[NSColor redColor]];
	
	[(ORTimeAxis*)[plotter0 xAxis] setStartTime: [[NSDate date] timeIntervalSince1970]];
	[aPlot release];
	
	NSNumberFormatter *numberFormatter = [[[NSNumberFormatter alloc] init] autorelease];
	[numberFormatter setFormat:@"#0.0"];	

	setPointTypePU[0] = setPointTypePU0;
	setPointTypePU[1] = setPointTypePU1;
	setPointTypePU[2] = setPointTypePU2;
	setPointTypePU[3] = setPointTypePU3;
	setPointTypePU[4] = setPointTypePU4;
	
	int i;
	for(i=0;i<5;i++){
		[[setPointMatrix cellAtRow:i column:0] setTag:i];
		[[leadValueMatrix cellAtRow:i column:0] setTag:i];
		[[gainValueMatrix cellAtRow:i column:0] setTag:i];
		[[softstartRateMatrix cellAtRow:i column:0] setTag:i];
		[[setPtSelectionMatrix cellAtRow:i column:0] setTag:i];

		[setPointTypePU[i] setTag:i];
		
		[[gainValueMatrix cellAtRow:i column:0] setFormatter:numberFormatter];
		[[leadValueMatrix cellAtRow:i column:0] setFormatter:numberFormatter];
		[[setPointMatrix  cellAtRow:i column:0] setFormatter:numberFormatter];
		[[softstartRateMatrix  cellAtRow:i column:0] setFormatter:numberFormatter];
	}
	
	for(i=0;i<2;i++){
		[[lowThresholdMatrix  cellAtRow:i column:0] setTag:i];
		[[highThresholdMatrix cellAtRow:i column:0] setTag:i];
		
		[[lowThresholdMatrix  cellAtRow:i column:0] setFormatter:numberFormatter];
		[[highThresholdMatrix cellAtRow:i column:0] setFormatter:numberFormatter];
	}
	[super awakeFromNib];
}

#pragma mark ***Notifications
- (void) registerNotificationObservers
{
	NSNotificationCenter* notifyCenter = [NSNotificationCenter defaultCenter];
    [super registerNotificationObservers];
    [notifyCenter addObserver : self
                     selector : @selector(lockChanged:)
                         name : ORRunStatusChangedNotification
                       object : nil];
    
    [notifyCenter addObserver : self
                     selector : @selector(lockChanged:)
                         name : ORMks651cLock
                        object: nil];

    [notifyCenter addObserver : self
                     selector : @selector(portNameChanged:)
                         name : ORMks651cPortNameChanged
                        object: nil];

    [notifyCenter addObserver : self
                     selector : @selector(portStateChanged:)
                         name : ORSerialPortStateChanged
                       object : nil];
                                              
    [notifyCenter addObserver : self
                     selector : @selector(pressureChanged:)
                         name : ORMks651cPressureChanged
                       object : nil];
        
    [notifyCenter addObserver : self
                     selector : @selector(setPointChanged:)
                         name : ORMks651cSetPointChanged
                       object : nil];
    
    [notifyCenter addObserver : self
                     selector : @selector(softstartRateChanged:)
                         name : ORMks651cSoftstartRateChanged
                       object : nil];
    
    [notifyCenter addObserver : self
                     selector : @selector(valveTypeChanged:)
                         name : ORMks651cValveTypeChanged
                       object : nil];
    
    [notifyCenter addObserver : self
                     selector : @selector(analogRangeChanged:)
                         name : ORMks651cAnalogRangeChanged
                       object : nil];
    
    [notifyCenter addObserver : self
                     selector : @selector(setPointTypeChanged:)
                         name : ORMks651cSetPointTypeChanged
                       object : nil];
    
    [notifyCenter addObserver : self
                     selector : @selector(positionRangeChanged:)
                         name : ORMks651cPositionRangeChanged
                       object : nil];
    
    [notifyCenter addObserver : self
                     selector : @selector(controlDirectionChanged:)
                         name : ORMks651cControlDirectionChanged
                       object : nil];
    
    [notifyCenter addObserver : self
                     selector : @selector(sensorRangeChanged:)
                         name : ORMks651cSensorRangeChanged
                       object : nil];
    
    [notifyCenter addObserver : self
                     selector : @selector(sensorVoltageRangeChanged:)
                         name : ORMks651cSensorVoltageRangeChanged
                       object : nil];
    
    [notifyCenter addObserver : self
                     selector : @selector(sensorTypeChanged:)
                         name : ORMks651cSensorTypeChanged
                       object : nil];
    
    [notifyCenter addObserver : self
                     selector : @selector(systemStatusChanged:)
                         name : ORMks651cSystemStatusChanged
                       object : nil];
    
    [notifyCenter addObserver : self
                     selector : @selector(softwareVersionChanged:)
                         name : ORMks651cSoftwareVersionChanged
                       object : nil];
    
    [notifyCenter addObserver : self
                     selector : @selector(batteryStatusChanged:)
                         name : ORMks651cBatteryStatusChanged
                       object : nil];
    
    [notifyCenter addObserver : self
                     selector : @selector(valveResponseChanged:)
                         name : ORMks651cValveResponseChanged
                       object : nil];
    
    [notifyCenter addObserver : self
                     selector : @selector(leadValueChanged:)
                         name : ORMks651cLeadValueChanged
                       object : nil];
    
    [notifyCenter addObserver : self
                     selector : @selector(gainValueChanged:)
                         name : ORMks651cGainValueChanged
                       object : nil];
    
    [notifyCenter addObserver : self
                     selector : @selector(controlTypeChanged:)
                         name : ORMks651cControlTypeChanged
                       object : nil];
    
    [notifyCenter addObserver : self
                     selector : @selector(checksumChanged:)
                         name : ORMks651cChecksumChanged
                       object : nil];

    [notifyCenter addObserver : self
                     selector : @selector(pollTimeChanged:)
                         name : ORMks651cPollTimeChanged
                       object : nil];

    [notifyCenter addObserver : self
                     selector : @selector(shipPressuresChanged:)
                         name : ORMks651cShipPressuresChanged
						object: model];

    [notifyCenter addObserver : self
					 selector : @selector(scaleAction:)
						 name : ORAxisRangeChangedNotification
					   object : nil];

    [notifyCenter addObserver : self
					 selector : @selector(miscAttributesChanged:)
						 name : ORMiscAttributesChanged
					   object : model];

    [notifyCenter addObserver : self
					 selector : @selector(updateTimePlot:)
						 name : ORRateAverageChangedNotification
					   object : nil];
					   
    [notifyCenter addObserver : self
                     selector : @selector(pressureScaleChanged:)
                         name : ORMks651cPressureScaleChanged
						object: model];

    [notifyCenter addObserver : self
                     selector : @selector(unitsChanged:)
                         name : ORMks651cUnitsChanged
						object: model];

    [notifyCenter addObserver : self
                     selector : @selector(localChanged:)
                         name : ORMks651cLocalChanged
						object: model];

    [notifyCenter addObserver : self
                     selector : @selector(learningChanged:)
                         name : ORMks651cLearningChanged
						object: model];
    [notifyCenter addObserver : self
                     selector : @selector(analogFSLevelChanged:)
                         name : ORMks651cAnalogFSLevelChanged
						object: model];

    [notifyCenter addObserver : self
                     selector : @selector(analogSetPointChanged:)
                         name : ORMks651cAnalogSetPointChanged
						object: model];
	
    [notifyCenter addObserver : self
                     selector : @selector(unitsChanged:)
                         name : ORMks651cUnitsChanged
						object: model];	

    [notifyCenter addObserver : self
                     selector : @selector(analogSoftstartChanged:)
                         name : ORMks651cAnalogSoftstartChanged
						object: model];

    [notifyCenter addObserver : self
                     selector : @selector(closeSoftstartChanged:)
                         name : ORMks651cCloseSoftstartChanged
						object: model];

    [notifyCenter addObserver : self
                     selector : @selector(openSoftstartChanged:)
                         name : ORMks651cOpenSoftstartChanged
						object: model];

	[notifyCenter addObserver : self
                     selector : @selector(lowThresholdChanged:)
                         name : ORMks651cLowThresholdChanged
						object: model];
	
	[notifyCenter addObserver : self
                     selector : @selector(highThresholdChanged:)
                         name : ORMks651cHighThresholdChanged
						object: model];
    [notifyCenter addObserver : self
                     selector : @selector(setPtSelectionChanged:)
                         name : ORMks651cModelSetPtSelectionChanged
						object: model];

    [notifyCenter addObserver : self
                     selector : @selector(specialZeroChanged:)
                         name : ORMks651cModelSpecialZeroChanged
						object: model];

    [notifyCenter addObserver : self
                     selector : @selector(spanCalibrationChanged:)
                         name : ORMks651cModelSpanCalibrationChanged
						object: model];

}

- (void) setModel:(id)aModel
{
	[super setModel:aModel];
	[[self window] setTitle:[NSString stringWithFormat:@"MKS 651c (Unit %lu)",[model uniqueIdNumber]]];
}

- (void) updateWindow
{
    [super updateWindow];
    [self lockChanged:nil];
    [self portStateChanged:nil];
    [self portNameChanged:nil];
	[self pressureChanged:nil];
    [self setPointChanged:nil];
    [self softstartRateChanged:nil];
    [self valveTypeChanged:nil];
    [self analogRangeChanged:nil];
    [self setPointTypeChanged:nil];
    [self positionRangeChanged:nil];
    [self controlDirectionChanged:nil];
    [self sensorRangeChanged:nil];
    [self sensorVoltageRangeChanged:nil];
    [self softwareVersionChanged:nil];
    [self valveResponseChanged:nil];
    [self sensorTypeChanged:nil];
    [self systemStatusChanged:nil];
    [self batteryStatusChanged:nil];
    [self leadValueChanged:nil];
    [self gainValueChanged:nil];
    [self controlTypeChanged:nil];
    [self checksumChanged:nil];
	[self pollTimeChanged:nil];
	[self shipPressuresChanged:nil];
	[self updateTimePlot:nil];
    [self miscAttributesChanged:nil];
	[self pressureScaleChanged:nil];
	[self unitsChanged:nil];
	[self localChanged:nil];
	[self learningChanged:nil];
	[self analogFSLevelChanged:nil];
	[self analogSetPointChanged:nil];
	[self unitsChanged:nil];
	[self analogSoftstartChanged:nil];
	[self closeSoftstartChanged:nil];
	[self openSoftstartChanged:nil];
	[self lowThresholdChanged:nil];
	[self highThresholdChanged:nil];
	[self setPtSelectionChanged:nil];
	[self specialZeroChanged:nil];
	[self spanCalibrationChanged:nil];
}

- (void) spanCalibrationChanged:(NSNotification*)aNote
{
	[spanCalibrationField setFloatValue: [model spanCalibration]];
}

- (void) specialZeroChanged:(NSNotification*)aNote
{
	[specialZeroField setFloatValue: [model specialZero]];
}

- (void) setPtSelectionChanged:(NSNotification*)aNote
{
	[setPtSelectionMatrix selectCellWithTag:[model setPtSelection]];
}

- (void) openSoftstartChanged:(NSNotification*)aNote
{
	[openSoftstartField setFloatValue: [model openSoftstart]];
}

- (void) closeSoftstartChanged:(NSNotification*)aNote
{
	[closeSoftstartField setFloatValue: [model closeSoftstart]];
}

- (void) analogSoftstartChanged:(NSNotification*)aNote
{
	[analogSoftstartField setFloatValue: [model analogSoftstart]];
}

- (void) analogSetPointChanged:(NSNotification*)aNote
{
	[analogSetPointField setFloatValue: [model analogSetPoint]];
}

- (void) unitsChanged:(NSNotification*)aNote
{
	[unitsPU selectItemAtIndex: [(ORMks651cModel*)model units]];
	[unitsField setStringValue: [model unitsString]];
}

- (void) analogFSLevelChanged:(NSNotification*)aNote
{
	[analogFSLevelPU selectItemAtIndex: [model analogFSLevel]];
}

- (void) learningChanged:(NSNotification*)aNote
{
	NSString* s=@"?";
	int learning = [model learning];
	if(learning==0)		s = @"--";
	else if(learning==1)s = @"System";
	else if(learning==2)s = @"Valve";
	
	[learningField setStringValue: s];
}

- (void) localChanged:(NSNotification*)aNote
{
	[localField setStringValue: [model local]?@"Remote":@"Local"];
}

- (void) pressureScaleChanged:(NSNotification*)aNote
{
	[pressureScalePU selectItemAtIndex: [model pressureScale]];
	[plotter0 setNeedsDisplay:YES];
}

- (void) scaleAction:(NSNotification*)aNotification
{
	if(aNotification == nil || [aNotification object] == [plotter0 xAxis]){
		[model setMiscAttributes:[(ORAxis*)[plotter0 xAxis]attributes] forKey:@"XAttributes0"];
	}
	
	if(aNotification == nil || [aNotification object] == [plotter0 yAxis]){
		[model setMiscAttributes:[(ORAxis*)[plotter0 yAxis]attributes] forKey:@"YAttributes0"];
	}
}

- (void) miscAttributesChanged:(NSNotification*)aNote
{

	NSString*				key = [[aNote userInfo] objectForKey:ORMiscAttributeKey];
	NSMutableDictionary* attrib = [model miscAttributesForKey:key];
	
	if(aNote == nil || [key isEqualToString:@"XAttributes0"]){
		if(aNote==nil)attrib = [model miscAttributesForKey:@"XAttributes0"];
		if(attrib){
			[(ORAxis*)[plotter0 xAxis] setAttributes:attrib];
			[plotter0 setNeedsDisplay:YES];
			[[plotter0 xAxis] setNeedsDisplay:YES];
		}
	}
	if(aNote == nil || [key isEqualToString:@"YAttributes0"]){
		if(aNote==nil)attrib = [model miscAttributesForKey:@"YAttributes0"];
		if(attrib){
			[(ORAxis*)[plotter0 yAxis] setAttributes:attrib];
			[plotter0 setNeedsDisplay:YES];
			[[plotter0 yAxis] setNeedsDisplay:YES];
		}
	}
}

- (void) updateTimePlot:(NSNotification*)aNote
{
	if(!aNote || ([aNote object] == [model timeRate])){
		[plotter0 setNeedsDisplay:YES];
	}
}

- (void) shipPressuresChanged:(NSNotification*)aNote
{
	[shipPressuresButton setIntValue: [model shipPressures]];
}

- (void) lowThresholdChanged:(NSNotification*)aNote
{
    int i;
    for(i=0;i<2;i++){
		[[lowThresholdMatrix cellWithTag:i] setFloatValue: [model lowThreshold:i]];
    }
}

- (void) highThresholdChanged:(NSNotification*)aNote
{
    int i;
    for(i=0;i<2;i++){
		[[highThresholdMatrix cellWithTag:i] setFloatValue: [model highThreshold:i]];
    }
}

- (void) setPointChanged:(NSNotification*)aNote
{
    int i;
    for(i=0;i<5;i++){
		[[setPointMatrix cellWithTag:i] setFloatValue: [model setPoint:i]];
    }
}

- (void) pressureChanged:(NSNotification*)aNote
{
	NSString* pressureAsString = [NSString stringWithFormat:@"%.3E",[model pressure]];
	[pressureField setStringValue:pressureAsString];
	unsigned long t = [model timeMeasured];
	NSDate* theDate;
	if(t){
		theDate = [NSDate dateWithTimeIntervalSince1970:t];
		[timeField setObjectValue:[theDate description]];
	}
	else [timeField setObjectValue:@"--"];
}

- (void) softstartRateChanged:(NSNotification*)aNote
{
    int i;
    for(i=0;i<5;i++){
        [[softstartRateMatrix cellWithTag:i] setFloatValue: [model softstartRate:i]];
    }
}

- (void) valveTypeChanged:(NSNotification*)aNote
{
	[valveTypePU selectItemAtIndex:[model valveType]];
}

- (void) analogRangeChanged:(NSNotification*)aNote
{
	[analogRangePU selectItemAtIndex:[model analogRange]];
}

- (void) setPointTypeChanged:(NSNotification*)aNote
{
    int i;
    for(i=0;i<5;i++){
        [setPointTypePU[i] selectItemAtIndex: [model setPointType:i]];
    }
}

- (void) positionRangeChanged:(NSNotification*)aNote
{
	[positionRangePU selectItemAtIndex:[model positionRange]];
}

- (void) controlDirectionChanged:(NSNotification*)aNote
{
	[controlDirectionPU selectItemAtIndex:[model controlDirection]];
}

- (void) sensorRangeChanged:(NSNotification*)aNote
{
	[sensorRangePU selectItemAtIndex:[model sensorRange]];
}

- (void) sensorVoltageRangeChanged:(NSNotification*)aNote
{
	[sensorVoltageRangePU selectItemAtIndex:[model sensorVoltageRange]];
}

- (void) sensorTypeChanged:(NSNotification*)aNote
{
	[sensorTypePU selectItemAtIndex:[model sensorType]];
}

- (void) systemStatusChanged:(NSNotification*)aNote
{
	int val = [model systemStatus];
	NSString* s = @"?";
	switch(val){
		case 0: s = @"open"; break;
		case 1: s = @"close"; break;
		case 2: s = @"stop"; break;
		case 3: s = @"SetPt A"; break;
		case 4: s = @"SetPt B"; break;
		case 5: s = @"SetPt C"; break;
		case 6: s = @"SetPt D"; break;
		case 7: s = @"SetPt E"; break;
		case 8: s = @"Analog SetPt"; break;
	}
	[systemStatusField setStringValue:s];
}

- (void) softwareVersionChanged:(NSNotification*)aNote
{
	[softwareVersionField setFloatValue:[model softwareVersion]];
}

- (void) batteryStatusChanged:(NSNotification*)aNote
{
	int state = [model batteryStatus];
	NSString* s = @"?";
	if(state == 0)		s = @"BAD";
	else if(state == 1)	s = @"GOOD";
	else if(state == 2)	s = @"N/A";
	[batteryStatusField setStringValue:s];
}

- (void) valveResponseChanged:(NSNotification*)aNote
{
	[valveResponsePU selectItemAtIndex:[model valveResponse]];
}

- (void) leadValueChanged:(NSNotification*)aNote
{
    int i;
    for(i=0;i<5;i++){        
        [[leadValueMatrix cellWithTag:i] setFloatValue: [model leadValue:i]];
    }
}

- (void) gainValueChanged:(NSNotification*)aNote
{
    int i;
    for(i=0;i<5;i++){
        [[gainValueMatrix cellWithTag:i] setFloatValue: [model gainValue:i]];
    }
}

- (void) controlTypeChanged:(NSNotification*)aNote
{
	[controlTypePU selectItemAtIndex:[model controlType]];
}

- (void) checksumChanged:(NSNotification*)aNote
{
	[checksumField setStringValue:[model checksum]==1?@"CheckSum Error":@""];
}

- (void) checkGlobalSecurity
{
    BOOL secure = [[[NSUserDefaults standardUserDefaults] objectForKey:OROrcaSecurityEnabled] boolValue];
    [gSecurity setLock:ORMks651cLock to:secure];
    [lockButton setEnabled:secure];
}

- (void) lockChanged:(NSNotification*)aNotification
{

    BOOL runInProgress = [gOrcaGlobals runInProgress];
    BOOL lockedOrRunningMaintenance = [gSecurity runInProgressButNotType:eMaintenanceRunType orIsLocked:ORMks651cLock];
    BOOL locked = [gSecurity isLocked:ORMks651cLock];

    [lockButton setState: locked];

    [portListPopup setEnabled:!locked];
    [openPortButton setEnabled:!locked];
    [pollTimePopup setEnabled:!locked];
    [shipPressuresButton setEnabled:!locked];
 
	[spanCalibrationField setEnabled:!locked];
	[specialZeroField setEnabled:!locked];
	[setPtSelectionMatrix setEnabled:!locked];
	[openSoftstartField setEnabled:!locked];
	[closeSoftstartField setEnabled:!locked];
	[analogSoftstartField setEnabled:!locked];
	[analogSetPointField setEnabled:!locked];
	[analogFSLevelPU setEnabled:!locked];
    [analogRangePU setEnabled:!locked];
    [unitsPU setEnabled:!locked];
    [initHardwareButton setEnabled:!locked];
    [readPressuresButton setEnabled:!locked];
    [softstartRateMatrix setEnabled:!locked];
    [valveTypePU setEnabled:!locked];
    [positionRangePU setEnabled:!locked];
    [controlDirectionPU setEnabled:!locked];
    [sensorRangePU setEnabled:!locked];
    [sensorVoltageRangePU setEnabled:!locked];
    [sensorTypePU setEnabled:!locked];
    [systemStatusField setEnabled:!locked];
    [valveResponsePU setEnabled:!locked];
    [controlTypePU setEnabled:!locked];
    [openValveButton setEnabled:!locked];
    [closeValveButton setEnabled:!locked];
    [holdValveButton setEnabled:!locked];
	
    [setPointMatrix setEnabled:!locked];
    [leadValueMatrix setEnabled:!locked];
    [gainValueMatrix setEnabled:!locked];
	[lowThresholdMatrix setEnabled:!locked];
	[highThresholdMatrix setEnabled:!locked];

	int i;
	for(i=0;i<5;i++){
		[setPointTypePU[i] setEnabled:!locked];
	}
	
    NSString* s = @"";
    if(lockedOrRunningMaintenance){
        if(runInProgress && ![gSecurity isLocked:ORMks651cLock])s = @"Not in Maintenance Run.";
    }
    [lockDocField setStringValue:s];

}

- (void) portStateChanged:(NSNotification*)aNotification
{
    if(aNotification == nil || [aNotification object] == [model serialPort]){
        if([model serialPort]){
            [openPortButton setEnabled:YES];

            if([[model serialPort] isOpen]){
                [openPortButton setTitle:@"Close"];
                [portStateField setTextColor:[NSColor colorWithCalibratedRed:0.0 green:.8 blue:0.0 alpha:1.0]];
                [portStateField setStringValue:@"Open"];
            }
            else {
                [openPortButton setTitle:@"Open"];
                [portStateField setStringValue:@"Closed"];
                [portStateField setTextColor:[NSColor redColor]];
            }
        }
        else {
            [openPortButton setEnabled:NO];
            [portStateField setTextColor:[NSColor blackColor]];
            [portStateField setStringValue:@"---"];
            [openPortButton setTitle:@"---"];
        }
    }
}

- (void) pollTimeChanged:(NSNotification*)aNotification
{
	[pollTimePopup selectItemWithTag:[model pollTime]];
}

- (void) portNameChanged:(NSNotification*)aNotification
{
    NSString* portName = [model portName];
    
	NSEnumerator *enumerator = [ORSerialPortList portEnumerator];
	ORSerialPort *aPort;

    [portListPopup selectItemAtIndex:0]; //the default
    while (aPort = [enumerator nextObject]) {
        if([portName isEqualToString:[aPort name]]){
            [portListPopup selectItemWithTitle:portName];
            break;
        }
	}  
    [self portStateChanged:nil];
}

#pragma mark ***Actions
- (IBAction) loadDialogFromHW:(id)sender
{
    [self endEditing];
#if defined(MAC_OS_X_VERSION_10_10) && MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_10 // 10.10-specific
    NSAlert *alert = [[[NSAlert alloc] init] autorelease];
    [alert setMessageText:@"Transfer HW Settings To Dialog"];
    [alert setInformativeText:@"This will read the values that are in the hardware unit and put those values into the dialog.\n\nReally do this?"];
    [alert addButtonWithTitle:@"Yes/Do It"];
    [alert addButtonWithTitle:@"Cancel"];
    [alert setAlertStyle:NSWarningAlertStyle];
    
    [alert beginSheetModalForWindow:[self window] completionHandler:^(NSModalResponse result){
        if (result == NSAlertFirstButtonReturn){
            [model readAndLoad];
       }
    }];
#else
    NSBeginAlertSheet(@"Transfer HW Settings To Dialog",
					  @"YES/Do it",
					  @"Cancel",
					  nil,[self window],
					  self,
					  @selector(loadDialogDidFinish:returnCode:contextInfo:),
					  nil,
					  nil,
					  @"This will read the values that are in the hardware unit and put those values into the dialog.\n\nReally do this?");
#endif
}

#if !defined(MAC_OS_X_VERSION_10_10) && MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_10 // 10.10-specific
- (void) loadDialogDidFinish:(id)sheet returnCode:(int)returnCode contextInfo:(NSDictionary*)userInfo
{
	if(returnCode == NSAlertDefaultReturn){
		[model readAndLoad];
    }
}
#endif

- (void) spanCalibrationAction:(id)sender
{
	[self endEditing];
	[model setSpanCalibration:[sender floatValue]];	
}

- (void) specialZeroAction:(id)sender
{
	[self endEditing];
	[model setSpecialZero:[sender floatValue]];	
}

- (void) setPtSelectionAction:(id)sender
{
	[self endEditing];
	[model setSetPtSelection:(int)[[sender selectedCell ]tag]];
}

- (void) openSoftstartAction:(id)sender
{
	[self endEditing];
	[model setOpenSoftstart:[sender floatValue]];	
}

- (void) closeSoftstartAction:(id)sender
{
	[self endEditing];
	[model setCloseSoftstart:[sender floatValue]];	
}

- (void) analogSoftstartAction:(id)sender
{
	[model setAnalogSoftstart:[sender floatValue]];	
}

- (void) analogFSLevelAction:(id)sender
{
	[model setAnalogFSLevel:(int)[sender indexOfSelectedItem]];
}

- (IBAction) pollNowAction:(id)sender
{
	[model pollHardware];	
}
- (IBAction) unitsAction:(id)sender
{
	[model setUnits:(int)[sender indexOfSelectedItem]];
}

- (IBAction) pressureScaleAction:(id)sender
{
	[model setPressureScale:(int)[sender indexOfSelectedItem]];
}

- (IBAction) shipPressuresAction:(id)sender
{
	[model setShipPressures:(int)[sender intValue]];
}

- (IBAction) lockAction:(id) sender
{
    [gSecurity tryToSetLock:ORMks651cLock to:[sender intValue] forWindow:[self window]];
}

- (IBAction) portListAction:(id) sender
{
    [model setPortName: [portListPopup titleOfSelectedItem]];
}

- (IBAction) openPortAction:(id)sender
{
    [model openPort:![[model serialPort] isOpen]];
}

- (IBAction) readPressuresAction:(id)sender
{
	[model readPressures];
}

- (IBAction) readHardware:(id)sender
{
	NSLog(@"MKS651(%d) Reading back all values. Any mismatches will follow.\n",[model uniqueIdNumber]);
	[model readAndCompare];
}

- (IBAction) valveTypeAction:(id)sender
{
	[model setValveType:(int)[sender indexOfSelectedItem]];
}

- (IBAction) analogRangeAction:(id)sender
{
	[model setAnalogRange:(int)[sender indexOfSelectedItem]];
}

- (IBAction) positionRangeAction:(id)sender
{
	[model setPositionRange:[sender indexOfSelectedItem]];
}

- (IBAction) controlDirectionAction:(id)sender
{
	[model setControlDirection:[sender indexOfSelectedItem]];
}

- (IBAction) sensorRangeAction:(id)sender;
{
	[model setSensorRange: (int)[sender indexOfSelectedItem]];
}

- (IBAction) sensorVoltageRangeAction:(id)sender
{
	[model setSensorVoltageRange:(int)[sender indexOfSelectedItem]];
}

- (IBAction) sensorTypeAction:(id)sender
{
	[model setSensorType:(int)[sender indexOfSelectedItem]];
}

- (IBAction) valveResponseAction:(id)sender
{
	[model setValveResponse:[sender intValue]];
}

- (IBAction) readChecksumAction:(id)sender
{
	[model readChecksum];
}

- (IBAction) controlTypeAction:(id)sender
{
	[model setControlType:(int)[sender indexOfSelectedItem]];
}

- (IBAction) pollTimeAction:(id)sender
{
	[model setPollTime:(int)[[sender selectedItem] tag]];
}

- (IBAction) setPointTypeAction:(id)sender
{
	int theValue = [[sender selectedCell] intValue];
	[model setSetPointType:(int)[sender tag] withValue:theValue];
}

- (IBAction) setPointAction:(id)sender;
{
	int index = (int)[[sender selectedCell] tag];
	float theValue = [[sender selectedCell] floatValue];
	[model setSetPoint:index withValue:theValue];
}

- (IBAction) softstartRateAction:(id)sender
{
	int index = (int)[[sender selectedCell] tag];
	float theValue = [[sender selectedCell] floatValue];
	[model setSoftstartRate:index withValue:theValue];
}

- (IBAction) lowThresholdAction:(id)sender
{
	[self endEditing];
	int index = (int)[[sender selectedCell] tag];
	float theValue = [[sender selectedCell] floatValue];
	[model setLowThreshold:index withValue:theValue];
}

- (IBAction) highThresholdAction:(id)sender
{
	[self endEditing];
	int index = (int)[[sender selectedCell] tag];
	float theValue = [[sender selectedCell] floatValue];
	[model setHighThreshold:index withValue:theValue];
}

- (IBAction) gainValueAction:(id)sender;
{
	[self endEditing];
	int index = (int)[[sender selectedCell] tag];
	float theValue = [[sender selectedCell] floatValue];
	[model setGainValue:index withValue:theValue];
}

- (IBAction) leadValueAction:(id)sender;
{
	[self endEditing];
	int index = (int)[[sender selectedCell] tag];
	float theValue = [[sender selectedCell] floatValue];
	[model setLeadValue:index withValue:theValue];
}

- (IBAction) openValveAction:(id)sender
{
	[model writeOpenValve];
}

- (IBAction) closeValveAction:(id)sender
{
	[model writeCloseValve];
}

- (IBAction) holdValveAction:(id)sender
{
	[model writeHoldValve];
}

- (IBAction) initHardwareAction:(id)sender;
{
	NSLog(@"MKS651 (%d) Loading and reading back all values. Any mismatches will be listed.\n",[model uniqueIdNumber]);
	[model initHardware];
}

- (IBAction) writeZeroSensorAction:(id)sender
{
	[model writeZeroSensor];
}

- (IBAction) writeSpecialZeroAction:(id)sender
{
	[model writeSpecialZero];
}

- (IBAction) writeRemoveZeroCorrectionAction:(id)sender
{
	[model writeRemoveZeroCorrection];
}

- (IBAction) writeLearnAnalogZeroAction:(id)sender
{
	[model writeLearnAnalogZero];
}

- (IBAction) writeCalibrateSpanAction:(id)sender
{
	[model writeCalibrateSpan];
}

- (IBAction) writeLearnFullScaleAction:(id)sender
{
	[model writeLearnFullScale];
}

- (IBAction) writeLearnSystemAction:(id)sender
{
	[model writeLearnSystem];
}

- (IBAction) writeStopLearnAction:(id)sender
{
	[model writeStopLearn];
}

#pragma mark ***Data Source
- (int) numberPointsInPlot:(id)aPlotter
{
	return (int)[[model timeRate] count];
}

- (void) plotter:(id)aPlotter index:(int)i x:(double*)xValue y:(double*)yValue
{
	int count = (int)[[model timeRate] count];
	int index = count-i-1;
	*xValue = [[model timeRate]timeSampledAtIndex:index];
	*yValue = [[model timeRate] valueAtIndex:index] * [model pressureScaleValue];
}

@end

@implementation ORMks651cController (private)

- (void) populatePortListPopup
{
	NSEnumerator *enumerator = [ORSerialPortList portEnumerator];
	ORSerialPort *aPort;
    [portListPopup removeAllItems];
    [portListPopup addItemWithTitle:@"--"];

	while (aPort = [enumerator nextObject]) {
        [portListPopup addItemWithTitle:[aPort name]];
	}    
}
@end

