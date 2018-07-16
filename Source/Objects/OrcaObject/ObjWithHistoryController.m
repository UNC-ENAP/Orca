//--------------------------------------------------------
// ObjWithHistoryController
// Created by Mark  A. Howe on Fri Jul 22 2005
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

#import "ObjWithHistoryController.h"
#import "ObjWithHistoryModel.h"
#import "ORTimeRoiController.h"
#import "ORCompositePlotView.h"
#import "ORTimeSeriesPlot.h"

#if !defined(MAC_OS_X_VERSION_10_10) && MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_10 // 10.10-specific
@interface ObjWithHistoryController (private)
- (void) _deleteHistorySheetDidEnd:(id)sheet returnCode:(int)returnCode contextInfo:(NSDictionary*)userInfo;
@end
#endif

@implementation ObjWithHistoryController

#pragma mark ***Initialization
- (void) dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[roiController release];
	[super dealloc];
}

- (void) awakeFromNib
{
	[super awakeFromNib];

	roiController = [[ORTimeRoiController panel] retain];
	[roiView addSubview:[roiController view]];

	[self plotOrderDidChange:[self plotView]];
	[analyzeButton setTitle:@"Analyze..."];	
}

- (ORTimeRoiController*) roiController
{
	return roiController;
}

- (id) analysisDrawer
{
	return analysisDrawer;
}

- (BOOL) analysisDrawerIsOpen
{
	return [analysisDrawer state] == NSDrawerOpenState;
}

- (void) openAnalysisDrawer
{
	[analysisDrawer open];
}

#pragma mark ***Notifications
- (void) registerNotificationObservers
{
	NSNotificationCenter* notifyCenter = [NSNotificationCenter defaultCenter];
    [super registerNotificationObservers];
	
    [notifyCenter addObserver : self
                     selector : @selector(drawerDidOpen:)
                         name : NSDrawerDidOpenNotification
                       object : analysisDrawer];
	
	[notifyCenter addObserver : self
                     selector : @selector(drawerDidClose:)
                         name : NSDrawerDidCloseNotification
                       object : analysisDrawer];
	
}

- (void) drawerDidOpen:(NSNotification *)aNotification
{
    if([aNotification object] == analysisDrawer){
        [plotter0 enableCursorRects];  
		[plotter0 becomeFirstResponder];
        [plotter0 setNeedsDisplay:YES];    
		[analyzeButton setTitle:@"Close"];
    }
}

- (void) drawerDidClose:(NSNotification *)aNotification
{
    if([aNotification object] == analysisDrawer){
		[plotter0 disableCursorRects];    
		[plotter0 setNeedsDisplay:YES];  
		[analyzeButton setTitle:@"Analyze..."];
    }
}

#pragma mark ***Actions
- (IBAction)doAnalysis:(NSToolbarItem*)item
{
	[analysisDrawer toggle:self];
}

#pragma mark ***Data Source
- (id) plotView
{
	return plotter0;
}

- (void) plotOrderDidChange:(id)aPlotView
{
	id theTopPlot = [plotter0 topPlot];
	id topRoi = [theTopPlot roi];
	[roiController setModel:topRoi];
}

- (BOOL) plotterShouldShowRoi:(id)aPlot
{
	if([analysisDrawer state] == NSDrawerOpenState)return YES;
	else return NO;
}

- (NSMutableArray*) roiArrayForPlotter:(id)aPlot
{
	return [model rois:(int)[aPlot tag]];
}

- (void) closeAnalysisDrawer
{
	[analysisDrawer close];
}

- (IBAction) deleteHistory:(id)sender
{
#if defined(MAC_OS_X_VERSION_10_10) && MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_10 // 10.10-specific
    NSAlert *alert = [[[NSAlert alloc] init] autorelease];
    [alert setMessageText:@"Clear History"];
    [alert setInformativeText:@"Really clear history? You will not be able to undo this."];
    [alert addButtonWithTitle:@"YES/Clear History"];
    [alert addButtonWithTitle:@"Cancel"];
    [alert setAlertStyle:NSWarningAlertStyle];
    
    [alert beginSheetModalForWindow:[self window] completionHandler:^(NSModalResponse result){
        if (result == NSAlertFirstButtonReturn){
            [model deleteHistory];
       }
    }];
#else
    NSBeginAlertSheet(@"Clear History",
                      @"Cancel",
                      @"Yes/Clear History",
                      nil,[self window],
                      self,
                      @selector(_deleteHistorySheetDidEnd:returnCode:contextInfo:),
                      nil,
                      nil,@"Really clear history? You will not be able to undo this.");
#endif
}

@end

#if !defined(MAC_OS_X_VERSION_10_10) && MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_10 // 10.10-specific
@implementation ObjWithHistoryController (private)
- (void) _deleteHistorySheetDidEnd:(id)sheet returnCode:(int)returnCode contextInfo:(NSDictionary*)userInfo
{
    if(returnCode == NSAlertAlternateReturn){
        [model deleteHistory];
    }
}
@end
#endif
