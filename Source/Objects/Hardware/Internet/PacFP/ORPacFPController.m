//--------------------------------------------------------
// ORPacFPController
// Created by Mark  A. Howe on Mon Jun 16, 2014
// Code partially generated by the OrcaCodeWizard. Written by Mark A. Howe.
// Copyright (c) 2014, University of North Carolina. All rights reserved.
//-----------------------------------------------------------
//This program was prepared for the Regents of the University of
//North Carolina sponsored in part by the United States
//Department of Energy (DOE) under Grant #DE-FG02-97ER41020.
//The University has certain rights in the program pursuant to
//the contract and the program should not be copied or distributed
//outside your organization.  The DOE and the University of
//North Carolina reserve all rights in the program. Neither the authors,
//University of North Carolina, or U.S. Government make any warranty,
//express or implied, or assume any liability or responsibility
//for the use of this software.
//-------------------------------------------------------------

#pragma mark •••Imported Files

#import "ORPacFPController.h"
#import "ORPacFPModel.h"
#import "ORTimeLinePlot.h"
#import "ORCompositePlotView.h"
#import "ORTimeAxis.h"
#import "ORTimeRate.h"
#import "OHexFormatter.h"
#import "ORValueBarGroupView.h"

@implementation ORPacFPController

#pragma mark •••Initialization

- (id) init
{
	self = [super initWithWindowNibName:@"PacFP"];
	return self;
}

- (void) dealloc
{
	[blankView release];
	[super dealloc];
}

- (void) awakeFromNib
{
			
	[[plotter0 yAxis] setRngLow:0.0 withHigh:6.];
	[[plotter0 yAxis] setRngLimitsLow:0.0 withHigh:6. withMinRng:1];
    [[plotter1 yAxis] setRngLow:0.0 withHigh:6.];
	[[plotter1 yAxis] setRngLimitsLow:0.0 withHigh:6. withMinRng:1];
	[[plotter0 yAxis] setInteger:NO];
	[[plotter1 yAxis] setInteger:NO];
	
    [[plotter0 xAxis] setRngLow:0.0 withHigh:10000];
	[[plotter0 xAxis] setRngLimitsLow:0.0 withHigh:200000. withMinRng:50];
    [[plotter1 xAxis] setRngLow:0.0 withHigh:10000];
	[[plotter1 xAxis] setRngLimitsLow:0.0 withHigh:200000. withMinRng:50];

	NSColor* color[4] = {
		[NSColor redColor],
		[NSColor greenColor],
		[NSColor blueColor],
		[NSColor brownColor],
	};
    int i;
	for(i=0;i<4;i++){
		ORTimeLinePlot* aPlot = [[ORTimeLinePlot alloc] initWithTag:i andDataSource:self];
		[plotter0 addPlot: aPlot];
		[aPlot setLineColor:color[i]];
		[aPlot setName:[model adcName:i]];
		[(ORTimeAxis*)[plotter0 xAxis] setStartTime: [[NSDate date] timeIntervalSince1970]];
		[aPlot release];
	}
	for(i=0;i<4;i++){
		ORTimeLinePlot* aPlot = [[ORTimeLinePlot alloc] initWithTag:i+4 andDataSource:self];
		[plotter1 addPlot: aPlot];
		[aPlot setName:[model adcName:i+4]];
		[aPlot setLineColor:color[i]];
		[(ORTimeAxis*)[plotter1 xAxis] setStartTime: [[NSDate date] timeIntervalSince1970]];
		[aPlot release];
	}
	[plotter0 setShowLegend:YES];
	[plotter1 setShowLegend:YES];
	
    [[queueValueBar xAxis] setRngLimitsLow:0 withHigh:300 withMinRng:10];
    [[queueValueBar xAxis] setRngDefaultsLow:0 withHigh:300];
    
    blankView = [[NSView alloc] init];
    setUpSize			= NSMakeSize(540,575);
    normalSize			= NSMakeSize(400,515);
    gainSize			= NSMakeSize(695,515);
    processLimitsSize	= NSMakeSize(470,515);
    trendSize           = NSMakeSize(555,515);

    NSString* key = [NSString stringWithFormat: @"orca.PacFP%lu.selectedtab",[model uniqueIdNumber]];
    NSInteger index = [[NSUserDefaults standardUserDefaults] integerForKey: key];
    if((index<0) || (index>[tabView numberOfTabViewItems]))index = 0;
    [tabView selectTabViewItemAtIndex: index];
    
    [progress setIndeterminate:NO];

    
	[super awakeFromNib];
}

#pragma mark •••Notifications

- (void) registerNotificationObservers
{
	NSNotificationCenter* notifyCenter = [NSNotificationCenter defaultCenter];
    [super registerNotificationObservers];
		
    [notifyCenter addObserver : self
                     selector : @selector(ipAddressChanged:)
                         name : ORPacFPModelIpAddressChanged
						object: model];
    
    [notifyCenter addObserver : self
                     selector : @selector(isConnectedChanged:)
                         name : ORPacFPModelIsConnectedChanged
						object: model];
	   
    [notifyCenter addObserver : self
                     selector : @selector(pollingStateChanged:)
                         name : ORPacFPModelPollingStateChanged
						object: model];
	
    [notifyCenter addObserver : self
                     selector : @selector(lockChanged:)
                         name : ORRunStatusChangedNotification
                       object : nil];
    
    [notifyCenter addObserver : self
                     selector : @selector(lockChanged:)
                         name : ORPacFPLock
                        object: nil];

    
    [notifyCenter addObserver : self
                     selector : @selector(adcChanged:)
                         name : ORPacFPModelAdcChanged
                       object : nil];
			
    [notifyCenter addObserver : self
                     selector : @selector(gainsChanged:)
                         name : ORPacFPModelGainsChanged
						object: model];

    [notifyCenter addObserver : self
                     selector : @selector(gainsReadBackChanged:)
                         name : ORPacFPModelGainsReadBackChanged
						object: model];

    
    [notifyCenter addObserver : self
                     selector : @selector(logToFileChanged:)
                         name : ORPacFPModelLogToFileChanged
						object: model];
	
    [notifyCenter addObserver : self
                     selector : @selector(logFileChanged:)
                         name : ORPacFPModelLogFileChanged
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
					 selector : @selector(queCountChanged:)
						 name : ORPacFPModelQueCountChanged
					   object : model];	
	
    [notifyCenter addObserver : self
                     selector : @selector(gainDisplayTypeChanged:)
                         name : ORPacFPModelGainDisplayTypeChanged
						object: model];

    [notifyCenter addObserver : self
                     selector : @selector(processLimitsChanged:)
                         name : ORPacFPModelProcessLimitsChanged
						object: model];

    [notifyCenter addObserver : self
                     selector : @selector(lcmChanged:)
                         name : ORPacFPModelLcmChanged
						object: model];
    
    [notifyCenter addObserver : self
                     selector : @selector(workingOnGainChanged:)
                         name : ORPacFPModelWorkingOnGainChanged
						object: model];

    [notifyCenter addObserver : self
                     selector : @selector(setGainsResultChanged:)
                         name : ORPacFPModelSetGainsResultChanged
						object: model];

    [notifyCenter addObserver : self
                     selector : @selector(preAmpSelectionChanged:)
                         name : ORPacFPModelPreAmpSelectionChanged
						object: model];

    [notifyCenter addObserver : self
                     selector : @selector(channelSelectionChanged:)
                         name : ORPacFPModelChannelSelectionChanged
						object: model];

    [notifyCenter addObserver : self
                     selector : @selector(lcmEnabledChanged:)
                         name : ORPacFPModelLcmEnabledChanged
						object: model];

    [notifyCenter addObserver : self
                     selector : @selector(vetoConditionChanged:)
                         name : ORPacFPModelVetoChanged
						object: model];

}

- (void) setModel:(id)aModel
{
	[super setModel:aModel];
	[[self window] setTitle:[NSString stringWithFormat:@"Power and Control (Unit %lu)",[model uniqueIdNumber]]];
}

- (void) updateWindow
{
    [super updateWindow];
    [self lockChanged:nil];
	[self gainsChanged:nil];
	[self gainsReadBackChanged:nil];
    [self pollingStateChanged:nil];
	[self logToFileChanged:nil];
	[self logFileChanged:nil];
    [self miscAttributesChanged:nil];
	[self queCountChanged:nil];
	[self gainDisplayTypeChanged:nil];
	[self processLimitsChanged:nil];
	[self adcChanged:nil];
	[self lcmEnabledChanged:nil];
    
	[self ipAddressChanged:nil];
	[self isConnectedChanged:nil];
	[self setGainsResultChanged:nil];
	[self preAmpSelectionChanged:nil];
	[self channelSelectionChanged:nil];
	[self vetoConditionChanged:nil];
}

- (void) vetoConditionChanged:(NSNotification*)aNote
{
    if([model vetoInPlace])[ lcmRunVetoWarning setStringValue:@"Run is Vetoed because of the LCM setting!"];
	else					[lcmRunVetoWarning setStringValue:@""];
}

- (void) lcmEnabledChanged:(NSNotification*)aNote
{
    BOOL state = [model lcmEnabled];
	[lcmEnabledMatrix selectCellWithTag: state];
    [adc0Line0 setHidden:state];
    [adc0Line1 setHidden:state];
    [adc0Line2 setHidden:!state];
    
    NSColor* enabledColor = [NSColor blackColor];
    NSColor* disabledColor = [NSColor grayColor];
    
    [[channelMatrix cellAtRow:0 column:0] setTextColor:!state?enabledColor:disabledColor];
    [[adcNameMatrix cellAtRow:0 column:0] setTextColor:!state?enabledColor:disabledColor];
    [[adcMatrix cellAtRow:0 column:0] setTextColor:!state?enabledColor:disabledColor];
    [[timeMatrix cellAtRow:0 column:0] setTextColor:!state?enabledColor:disabledColor];
    
    
    [[channelMatrix cellAtRow:1 column:0] setTextColor:state?enabledColor:disabledColor];
    [[adcNameMatrix cellAtRow:1 column:0] setTextColor:state?enabledColor:disabledColor];
    [[adcMatrix cellAtRow:1 column:0] setTextColor:state?enabledColor:disabledColor];
    [[timeMatrix cellAtRow:1 column:0] setTextColor:state?enabledColor:disabledColor];
}

- (void) channelSelectionChanged:(NSNotification*)aNote
{
	[channelSelectionField setIntValue: [model channelSelection]];
}

- (void) preAmpSelectionChanged:(NSNotification*)aNote
{
	[preAmpSelectionField setIntValue: [model preAmpSelection]];
}

- (void) setGainsResultChanged:(NSNotification*)aNote
{
	[setGainsResultTextField setStringValue: [model setGainsResult]?@"Success":@"Failed"];
}

- (void) workingOnGainChanged:(NSNotification*)aNote
{
	[workingOnGainTextField setIntValue: [model workingOnGain]];
    if([model workingOnGain] == 1){
        [progress setMaxValue:148];
        [progress startAnimation:self];
        [setGainsResultTextField setStringValue:@"Working..."];
    }
    [progressField setStringValue:[NSString stringWithFormat:@"%d/148",[model workingOnGain]]];
    [progress setDoubleValue:[model workingOnGain]];
    if([model workingOnGain] == 148){
        [progress stopAnimation:self];
        [progressField setStringValue:@"--"];
    }
}

- (void) isConnectedChanged:(NSNotification*)aNote
{
	[ipConnectedTextField setStringValue: [model isConnected]?@"Connected":@"Not Connected"];
    [ipConnectButton setTitle:[model isConnected]?@"Disconnect":@"Connect"];
}

- (void) ipAddressChanged:(NSNotification*)aNote
{
	[ipAddressTextField setStringValue: [model ipAddress]];
	[[self window] setTitle:[model title]];
}

- (void) lastGainReadChanged:(NSNotification*)aNote
{
    NSDate* theLastRead = [model lastGainRead];
    if(!theLastRead) [lastGainReadField setObjectValue: @"Gains not read since ORCA start"];
    else             [lastGainReadField setObjectValue: [NSString stringWithFormat:@"Gains last read: %@",theLastRead]];
}

- (void) processLimitsChanged:(NSNotification*)aNote
{
    [processLimitsTableView reloadData];
}

- (void) gainDisplayTypeChanged:(NSNotification*)aNote
{
	[gainDisplayTypeMatrix selectCellWithTag : [model gainDisplayType]];
	NSFormatter* aFormatter = nil;
	if([model gainDisplayType] == 0){
		aFormatter = [[OHexFormatter alloc] init];
	}

	[[[gainTableView tableColumnWithIdentifier:@"Board0"] dataCell] setFormatter:aFormatter];
	[[[gainTableView tableColumnWithIdentifier:@"Board1"] dataCell] setFormatter:aFormatter];
	[[[gainTableView tableColumnWithIdentifier:@"Board2"] dataCell] setFormatter:aFormatter];
	[[[gainTableView tableColumnWithIdentifier:@"Board3"] dataCell] setFormatter:aFormatter];
    
    [[[gainReadBackTableView tableColumnWithIdentifier:@"Board0"] dataCell] setFormatter:aFormatter];
	[[[gainReadBackTableView tableColumnWithIdentifier:@"Board1"] dataCell] setFormatter:aFormatter];
	[[[gainReadBackTableView tableColumnWithIdentifier:@"Board2"] dataCell] setFormatter:aFormatter];
	[[[gainReadBackTableView tableColumnWithIdentifier:@"Board3"] dataCell] setFormatter:aFormatter];

	[aFormatter release];
	[gainTableView reloadData];
	[gainReadBackTableView reloadData];
}

- (void) scaleAction:(NSNotification*)aNotification
{
	if(aNotification == nil || [aNotification object] == [plotter0 xAxis]){
		[model setMiscAttributes:[(ORAxis*)[plotter0 xAxis]attributes] forKey:@"XAttributes0"];
	};
	
	if(aNotification == nil || [aNotification object] == [plotter0 yAxis]){
		[model setMiscAttributes:[(ORAxis*)[plotter0 yAxis]attributes] forKey:@"YAttributes0"];
	};
	
	if(aNotification == nil || [aNotification object] == [plotter1 xAxis]){
		[model setMiscAttributes:[(ORAxis*)[plotter1 xAxis]attributes] forKey:@"XAttributes1"];
	};
	
	if(aNotification == nil || [aNotification object] == [plotter1 yAxis]){
		[model setMiscAttributes:[(ORAxis*)[plotter1 yAxis]attributes] forKey:@"YAttributes1"];
	};
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
	
	if(aNote == nil || [key isEqualToString:@"XAttributes1"]){
		if(aNote==nil)attrib = [model miscAttributesForKey:@"XAttributes1"];
		if(attrib){
			[(ORAxis*)[plotter1 xAxis] setAttributes:attrib];
			[plotter1 setNeedsDisplay:YES];
			[[plotter1 xAxis] setNeedsDisplay:YES];
		}
	}
	if(aNote == nil || [key isEqualToString:@"YAttributes1"]){
		if(aNote==nil)attrib = [model miscAttributesForKey:@"YAttributes1"];
		if(attrib){
			[(ORAxis*)[plotter1 yAxis] setAttributes:attrib];
			[plotter1 setNeedsDisplay:YES];
			[[plotter1 yAxis] setNeedsDisplay:YES];
		}
	}
}
- (void) updateTimePlot:(NSNotification*)aNote
{
	if(!aNote || ([aNote object] == [model timeRate:0])){
		[plotter0 setNeedsDisplay:YES];
	}
	else if(!aNote || ([aNote object] == [model timeRate:1])){
		[plotter1 setNeedsDisplay:YES];
	}
}
- (void) pollingStateChanged:(NSNotification*)aNotification
{
	[pollingButton selectItemAtIndex:[pollingButton indexOfItemWithTag:[model pollingState]]];
    [self lockChanged:nil];
}

- (void) queCountChanged:(NSNotification*)aNotification
{
	[cmdQueCountField setIntValue:[model queCount]];
    [queueValueBar setNeedsDisplay:YES];
}

- (void) logFileChanged:(NSNotification*)aNote
{
	if([model logFile])[logFileTextField setStringValue: [model logFile]];
	else [logFileTextField setStringValue: @"---"];
}

- (void) logToFileChanged:(NSNotification*)aNote
{
	[logToFileButton setIntValue: [model logToFile]];
}

- (void) gainsChanged:(NSNotification*)aNote
{
	[gainTableView reloadData];
}

- (void) gainsReadBackChanged:(NSNotification*)aNote
{
	[gainReadBackTableView reloadData];
}

- (void) lcmChanged:(NSNotification*)aNote
{
    [self loadLcmTimeValues];
}
- (void) loadLcmTimeValues
{
	[[adcMatrix cellWithTag:0] setFloatValue:[model convertedLcm]];
	unsigned long t = [model lcmTimeMeasured];
	NSDate* theDate;
	if(t){
		theDate = [NSDate dateWithTimeIntervalSince1970:t];
		[[timeMatrix cellWithTag:0] setObjectValue:[theDate description]];
	}
	else [[timeMatrix cellWithTag:0] setObjectValue:@"--"];
}

- (void) adcChanged:(NSNotification*)aNote
{
	if(aNote){
		int index = [[[aNote userInfo] objectForKey:@"Index"] intValue];
		[self loadAdcTimeValuesForIndex:index];
	}
	else {
		int i;
		for(i=0;i<8;i++){
			[self loadAdcTimeValuesForIndex:i];
		}
	}
}

- (void) loadAdcTimeValuesForIndex:(int)index
{
 	    //DEBUG                NSLog(@"%@::%@:  index: %i\n",NSStringFromClass([self class]),NSStringFromSelector(_cmd),index);//TODO: DEBUG testing ...-tb-
	[[adcMatrix cellWithTag:index+1] setFloatValue:[model convertedAdc:index]];
	unsigned long t = [model timeMeasured:index];
	NSDate* theDate;
	if(t){
		theDate = [NSDate dateWithTimeIntervalSince1970:t];
		[[timeMatrix cellWithTag:index+1] setObjectValue:[theDate descriptionFromTemplate:@"MM/dd hh:mm:SS"]];
	}
	else [[timeMatrix cellWithTag:index+1] setObjectValue:@"--"];
}

- (void) checkGlobalSecurity
{
    BOOL secure = [[[NSUserDefaults standardUserDefaults] objectForKey:OROrcaSecurityEnabled] boolValue];
    [gSecurity setLock:ORPacFPLock to:secure];
    [lockButton setEnabled:secure];
}

- (void) lockChanged:(NSNotification*)aNotification
{

    BOOL runInProgress = [gOrcaGlobals runInProgress];
    //BOOL lockedOrRunningMaintenance = [gSecurity runInProgressButNotType:eMaintenanceRunType orIsLocked:ORPacFPLock];
    BOOL locked = [gSecurity isLocked:ORPacFPLock];

    [lockButton setState: locked];

    [readAllGainsButton setEnabled:!locked];
    [writeAllGainsButton setEnabled:!locked];
    [readAdcsButton setEnabled:!locked];
    [readAllAdcsButton setEnabled:!locked && [model pollingState]==0];
    [gainTableView setEnabled:!locked];
    [lcmEnabledMatrix setEnabled:!locked && !runInProgress];
}

#pragma mark •••Actions
- (IBAction) lcmEnabledAction:(id)sender
{
	[model setLcmEnabled:[[sender selectedCell]tag]];
}

- (IBAction) channelSelectionAction:(id)sender
{
	[model setChannelSelection:[sender intValue]];
}

- (IBAction) preAmpSelectionAction:(id)sender
{
	[model setPreAmpSelection:[sender intValue]];
}

- (IBAction) sendPreAmpAndChannelAction:(id)sender
{
 	[self endEditing];
    [model writeModuleSelect];
}


- (IBAction) setGainsAction:(id)sender
{
	[model setGains];
	[self lockChanged:nil];
}

- (IBAction) getGainsAction:(id)sender
{
	[self endEditing];
	[model getGains];
}

- (IBAction) lockAction:(id) sender
{
    [gSecurity tryToSetLock:ORPacFPLock to:[sender intValue] forWindow:[self window]];
}

- (IBAction) readAdcsAction:(id)sender
{
	[self endEditing];
	[model readAdcs];
}

- (IBAction) readAllAdcsAction:(id)sender
{
 	[self endEditing];
	[model readAllAdcs];
}

- (void) ipAddressFieldAction:(id)sender
{
	[model setIpAddress:[sender stringValue]];
}

- (IBAction) connectAction: (id) aSender
{
    [self endEditing];
    [model connect];
}

- (IBAction) selectFileAction:(id)sender
{
	NSSavePanel *savePanel = [NSSavePanel savePanel];
    [savePanel setPrompt:@"Log To File"];
    [savePanel setCanCreateDirectories:YES];
    
    NSString* startingDir;
    NSString* defaultFile;
    
	NSString* fullPath = [[model logFile] stringByExpandingTildeInPath];
    if(fullPath){
        startingDir = [fullPath stringByDeletingLastPathComponent];
        defaultFile = [fullPath lastPathComponent];
    }
    else {
        startingDir = NSHomeDirectory();
        defaultFile = @"OrcaScript";
    }
    
    [savePanel setDirectoryURL:[NSURL fileURLWithPath:startingDir]];
    [savePanel setNameFieldLabel:defaultFile];
    [savePanel beginSheetModalForWindow:[self window] completionHandler:^(NSInteger result){
        if (result == NSFileHandlingPanelOKButton){
            [model setLogFile:[[[savePanel URL] path] stringByAbbreviatingWithTildeInPath]];
        }
    }];
}

- (IBAction) logToFileAction:(id)sender
{
	[model setLogToFile:[sender intValue]];	
}
- (IBAction) setPollingAction:(id)sender
{
    [model setPollingState:(NSTimeInterval)[[sender selectedItem] tag]];
}

#pragma mark •••Table Data Source
- (id) tableView:(NSTableView *) aTableView objectValueForTableColumn:(NSTableColumn *) aTableColumn row:(int) rowIndex
{
    if(gainTableView == aTableView){
        if([[aTableColumn identifier] isEqualToString:@"Channel"]) return [NSNumber numberWithInt:rowIndex];
        else {
            int board;
            if([[aTableColumn identifier] isEqualToString:@"Board0"])board = 0;
            else if([[aTableColumn identifier] isEqualToString:@"Board1"])board = 1;
            else if([[aTableColumn identifier] isEqualToString:@"Board2"])board = 2;
            else board = 3;
            return [NSNumber numberWithInt:[model gain:rowIndex + board*37]];
        }
    }
    else if(gainReadBackTableView == aTableView){
        if([[aTableColumn identifier] isEqualToString:@"Channel"]) return [NSNumber numberWithInt:rowIndex];
        else {
            int board;
            if([[aTableColumn identifier] isEqualToString:@"Board0"])board = 0;
            else if([[aTableColumn identifier] isEqualToString:@"Board1"])board = 1;
            else if([[aTableColumn identifier] isEqualToString:@"Board2"])board = 2;
            else board = 3;
            return [NSNumber numberWithInt:[model gainReadBack:rowIndex + board*37]];
        }
    }

    else if(processLimitsTableView == aTableView){
        id columnId = [aTableColumn identifier];
        if([columnId isEqualToString:@"Name"])return [model processName:rowIndex];
        else if([columnId isEqualToString:@"ChannelNumber"])return [NSNumber numberWithInt:rowIndex];
        else if([columnId isEqualToString:@"AdcNumber"])return [NSNumber numberWithInt:rowIndex];
        else {
            id obj = [[model processLimits] objectAtIndex:rowIndex];
            return [obj objectForKey:columnId];
        }
    }
    else return nil;
}

// just returns the number of items we have.
- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
	if(gainTableView == aTableView)return 37;
	else if(gainReadBackTableView == aTableView)return 37;
    else if(processLimitsTableView == aTableView)return 5;
	else return 0;
}

- (void)tableView:(NSTableView *)aTableView setObjectValue:(id)anObject forTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
    if(anObject == nil)return;
    
    if(gainTableView == aTableView){
        if([[aTableColumn identifier] isEqualToString:@"Channel"]) return;
        int board;
        if([[aTableColumn identifier] isEqualToString:@"Board0"])board = 0;
        else if([[aTableColumn identifier] isEqualToString:@"Board1"])board = 1;
        else if([[aTableColumn identifier] isEqualToString:@"Board2"])board = 2;
        else board = 3;
        [model setGain:(int)(rowIndex+(board*37)) withValue:[anObject intValue]];
        [model setGain:(int)(rowIndex+(board*37)) withValue:[anObject intValue]];

    }
    else if(processLimitsTableView == aTableView){
        id obj = [[model processLimits] objectAtIndex:rowIndex];
		[[[self undoManager] prepareWithInvocationTarget:self] tableView:aTableView setObjectValue:[obj objectForKey:[aTableColumn identifier]] forTableColumn:aTableColumn row:rowIndex];
		[obj setObject:anObject forKey:[aTableColumn identifier]];
		[aTableView reloadData];
    }
}

- (void) tabView:(NSTabView*)aTabView didSelectTabViewItem:(NSTabViewItem*)item
{	
    
    [[self window] setContentView:blankView];
    switch([tabView indexOfTabViewItem:item]){
		case  0: [self resizeWindowToSize:setUpSize];	    break;
		case  1: [self resizeWindowToSize:gainSize];	    break;
		case  2: [self resizeWindowToSize:trendSize];	    break;
		case  3: [self resizeWindowToSize:processLimitsSize];	    break;
            
		default: [self resizeWindowToSize:normalSize];	    break;
    }

    NSInteger index = [tabView indexOfTabViewItem:item];
    [[NSUserDefaults standardUserDefaults] setInteger:index forKey:[NSString stringWithFormat:@"orca.PacFP%lu.selectedtab",[model uniqueIdNumber]]];
    [[self window] setContentView:totalView];
}

#pragma mark •••Data Source
- (int) numberPointsInPlot:(id)aPlotter
{
	return (int)[[model timeRate:(int)[aPlotter tag]]   count];
}

- (void) plotter:(id)aPlotter index:(int)i x:(double*)xValue y:(double*)yValue
{
	int set = (int)[aPlotter tag];
	NSUInteger count = (int)[[model timeRate:set] count];
    NSUInteger index = count-i-1;
 	*yValue = [[model timeRate:set] valueAtIndex:(int)index];
	*xValue = [[model timeRate:set] timeSampledAtIndex:(int)index];
}

- (IBAction) gainDisplayTypeAction:(id)sender
{
	[model setGainDisplayType:(int)[[sender selectedCell] tag]];
}

- (IBAction) readGainFileAction:(id)sender
{
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    [openPanel setCanChooseDirectories:NO];
    [openPanel setCanChooseFiles:YES];
    [openPanel setAllowsMultipleSelection:NO];
    [openPanel setPrompt:@"Choose"];
    NSString* startingDir;
	NSString* fullPath = [[model lastGainFile] stringByExpandingTildeInPath];
    if(fullPath){
        startingDir = [fullPath stringByDeletingLastPathComponent];
    }
    else {
        startingDir = NSHomeDirectory();
    }
    
    [openPanel setDirectoryURL:[NSURL fileURLWithPath:startingDir]];
    [openPanel beginSheetModalForWindow:[self window] completionHandler:^(NSInteger result){
        if (result == NSFileHandlingPanelOKButton){
            [model readGainFile:[[openPanel URL] path]];
        }
    }];
}

- (IBAction) flushQueueAction: (id) aSender
{
    [model flushQueue];
}

- (IBAction) saveGainFileAction:(id)sender
{
    NSSavePanel *savePanel = [NSSavePanel savePanel];
    [savePanel setPrompt:@"Save As"];
    [savePanel setCanCreateDirectories:YES];
    
    NSString* startingDir;
    NSString* defaultFile;
    
	NSString* fullPath = [[model lastGainFile] stringByExpandingTildeInPath];
    if(fullPath){
        startingDir = [fullPath stringByDeletingLastPathComponent];
        defaultFile = [fullPath lastPathComponent];
    }
    else {
        startingDir = NSHomeDirectory();
        defaultFile = [model lastGainFile];
        
    }
    [savePanel setDirectoryURL:[NSURL fileURLWithPath:startingDir]];
    [savePanel setNameFieldLabel:defaultFile];
    [savePanel beginSheetModalForWindow:[self window] completionHandler:^(NSInteger result){
        if (result == NSFileHandlingPanelOKButton){
            [model saveGainFile:[[savePanel URL]path]];
        }
    }];
}

#pragma  mark •••Delegate Responsiblities
- (BOOL) outlineView:(NSOutlineView *)outlineView shouldEditTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
    return NO;
}

- (BOOL) tableView:(NSTableView *)tableView shouldSelectRow:(int)row
{
	return YES;
}
@end
