//
//  ORLNGSSlowControlsController.h
//  Orca
//
//  Created by Mark Howe on Thursday, Aug 20,2009
//  Copyright (c) 2009 Univerisy of North Carolina. All rights reserved.
//-----------------------------------------------------------
//This program was prepared for the Regents of the Univerisy of 
//North Carolina sponsored in part by the United States 
//Department of Energy (DOE) under Grant #DE-FG02-97ER41020. 
//The University has certain rights in the program pursuant to 
//the contract and the program should not be copied or distributed 
//outside your organization.  The DOE and the Univerisy of North 
//Carolina reserve all rights in the program. Neither the authors,
//Univerisy of North Carolina, or U.S. Government make any warranty, 
//express or implied, or assume any liability or responsibility 
//for the use of this software.
//-------------------------------------------------------------

#import "OrcaObjectController.h"
#import "ORTimedTextField.h"

@interface ORLNGSSlowControlsController : OrcaObjectController
{
	IBOutlet NSButton*		    lockButton;
	IBOutlet NSButton*		    sendButton;
	IBOutlet ORTimedTextField*	timeoutField;

	IBOutlet NSProgressIndicator* pollingProgress;
	IBOutlet NSPopUpButton*     pollTimePopup;
	IBOutlet NSButton*          pollNowButton;
    IBOutlet NSSecureTextField* passWordField;
    IBOutlet NSTextField*       userNameField;
    IBOutlet NSTextField*       ipAddressField;
}

#pragma mark ***Interface Management
//- (void) timedOut:(NSNotification*)aNote;
- (void) lockChanged:(NSNotification*)aNote;
- (void) pollTimeChanged:(NSNotification*)aNote;
- (void) dataIsValidChanged:(NSNotification*)aNote;
- (void) userNameChanged:(NSNotification*)aNote;
- (void) passWordChanged:(NSNotification*)aNote;
- (void) ipAddressChanged:(NSNotification*)aNote;

#pragma mark •••Actions
- (IBAction) lockAction:(id) sender;
- (IBAction) pollTimeAction:(id)sender;
- (IBAction) pollNowAction:(id)sender;
- (IBAction) userNameAction:(id)sender;
- (IBAction) passWordAction:(id)sender;
- (IBAction) ipAddressAction:(id)sender;
@end

