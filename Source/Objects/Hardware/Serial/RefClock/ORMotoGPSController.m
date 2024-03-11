//--------------------------------------------------------
// ORMotoGPSController
// Created by Mark  A. Howe on Fri Jul 22 2005 / Julius Hartmann, KIT, November 2017
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
//for the use of this softwarePulser.
//-------------------------------------------------------------

#pragma mark ***Imported Files

#import "ORMotoGPSController.h"
#import "ORMotoGPSModel.h"
#import "ORRefClockModel.h"

@implementation ORMotoGPSController
- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [topLevelObjects release];
    [super dealloc];
}

#pragma mark ***Initialization

- (void) awakeFromNib
{
    if(!deviceContent){
        if ([[NSBundle mainBundle] loadNibNamed:@"MotoGPS" owner:self  topLevelObjects:&topLevelObjects]) {
            [topLevelObjects retain];
        
            [deviceView setContentView:deviceContent];
            [[self model] setStatusPoll:[statusPollCB state]];
        }
        else NSLog(@"Failed to load MotoGPS.nib");
    }
}

- (id) model
{
    return model;
}

- (void) setModel:(id)aModel
{
    model = aModel;
    [self registerNotificationObservers];
    [self updateWindow];
}

#pragma mark ***Notifications
- (void) registerNotificationObservers
{
	NSNotificationCenter* notifyCenter = [NSNotificationCenter defaultCenter];

    [notifyCenter addObserver : self
                     selector : @selector(statusChanged:)
                         name : ORMotoGPSModelStatusChanged
                        object: model];

    [notifyCenter addObserver : self
                     selector : @selector(statusPollChanged:)
                         name : ORMotoGPSModelStatusPollChanged
                        object: model];

    [notifyCenter addObserver : self
                     selector : @selector(receivedMessageChanged:)
                         name : ORMotoGPSModelReceivedMessageChanged
                        object: nil];
    [notifyCenter addObserver : self
                     selector : @selector(updateStatusDisplay:)
                         name : ORMotoGPSStatusValuesReceived
                        object: nil];
    [notifyCenter addObserver : self
                     selector : @selector(updateDeviceIDDisplay:)
                         name : ORMotoGPSModelDeviceModelInfoChanged
                        object: nil];

    
    
}

- (void) updateWindow
{
    [self statusChanged:nil];
    [self statusPollChanged:nil];
    [self receivedMessageChanged:nil];
}

- (void) setButtonStates
{
    //BOOL runInProgress = [gOrcaGlobals runInProgress];
    BOOL lockedOrRunningMaintenance = [gSecurity runInProgressButNotType:eMaintenanceRunType orIsLocked:ORRefClockLock];//ORMotoGPSLock];
    BOOL portOpen = [model portIsOpen];
    [setDefaults         setEnabled:!lockedOrRunningMaintenance && portOpen];
    [autoSurveyButton    setEnabled:!lockedOrRunningMaintenance && portOpen];
    [statusButton        setEnabled:!lockedOrRunningMaintenance && portOpen];
    [statusPollCB        setEnabled:!lockedOrRunningMaintenance && portOpen];
    [deviceIDButton      setEnabled:!lockedOrRunningMaintenance && portOpen];
    [cableDelayCorButton setEnabled:!lockedOrRunningMaintenance && portOpen];
}

- (void) receivedMessageChanged:(NSNotification*)aNote
{   if([[model refClockModel] verbose]){
        NSLog(@"New GPS message received \n");
    }
    if(aNote == nil){
        [receivedMessageField setStringValue:@""];
    }
    else if([model lastReceived] != nil){
        [receivedMessageField setStringValue:[model lastReceived]];
    }
}
- (void) updateStatusDisplay:(NSNotification*)aNote{

    [visibleSatsField setStringValue:[NSString stringWithFormat:@"%u",[model visibleSatellites]]];
    [trackedSatsField setStringValue:[NSString stringWithFormat:@"%u",[model trackedSatellites]]];
    
    [accSignalStrengthField setStringValue:[NSString stringWithFormat:@"%u",[model accSignalStrength]]];
    [antennaSenseField setStringValue:[NSString stringWithFormat:@"%@",[model antennaSense]]];
    //[oscTemperatureField setStringValue:[NSString stringWithFormat:@"%.1f",[model oscTemperature]]];
    [oscTemperatureField setStringValue:[model oscTemperature]];
}

- (void) updateDeviceIDDisplay:(NSNotification*)aNote{
    [deviceIDField setStringValue:[model modelInfo]];
}

- (void) autoSurveyChanged:(NSNotification*)aNote
{
}

- (void) statusChanged:(NSNotification*)aNote
{
}

- (void) statusPollChanged:(NSNotification*)aNote
{
    [statusPollCB setIntValue:[model statusPoll]];
}

- (void) visibleSatsChanged:(NSNotification*)aNote
{
}

- (void) trackedSatsChanged:(NSNotification*)aNote
{
}

- (void) visibilityStatusChanged:(NSNotification*)aNote
{
}

- (void) antennaSenseChanged:(NSNotification*)aNote
{
}

- (void) accSignalStrengthChanged:(NSNotification*)aNote
{
}

- (void) oscTemperatureChanged:(NSNotification*)aNote
{
}

#pragma mark ***Actions
- (IBAction) setDefaultsAction:(id)sender
{
    [model setDefaults];
}

- (IBAction) autoSurveyAction:(id)sender
{
    [model autoSurvey];
}

- (void) statusAction:(id)sender
{
  [model requestStatus];
}

- (void) statusPollAction:(id)sender
{
    [model setStatusPoll:[sender intValue]];
}

- (void) deviceIDAction:(id)sender
{
    [model deviceInfo];
}

- (IBAction) cableDelayCorAction:(id)sender
{
    //int delayNanoseconds = [cableDelayCorField intValue];
    [model setCableDelay:[cableDelayCorField intValue]];
    // assume speed of light divided by 1.5 to get approximate cable signal speed
    // (see for instance https://electronics.stackexchange.com/questions/178173/true-gps-location-at-the-antenna-or-receiver-chip/178190 )
    float approxCableLength = 0.3/1.5*[model cableDelay];
    NSString* cableLengthString = [[NSString string]stringByAppendingFormat:@"%.1f m", approxCableLength]; //remove alloc/retain here... flagged by Analysis tool. MAH 06/28/23
    [approxCableLengthField setStringValue:cableLengthString];
    [model cableDelayCorrection:[model cableDelay]];
}

@end


