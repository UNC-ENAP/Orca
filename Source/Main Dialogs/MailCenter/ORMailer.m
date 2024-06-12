//----------------------------------------------------------
//  ORMailer.m
//
//  Created by Mark Howe on Wed Apr 9, 2008.
//  ReWorked to use the Scripting Bridge and a NSOperation Queue Wed Aug 15, 2012
//  Copyright  © 2012 CENPA. All rights reserved.
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

#import "ORMailer.h"
#import "mail.h"
#import "ORMailer.h"
#import "SynthesizeSingleton.h"

@implementation ORMailer

@synthesize to,cc,subject,body,from,delegate;

+ (ORMailer *) mailer {
	return [[[ORMailer alloc] init] autorelease];
}

- (id)init 
{	
	self = [super init];
	self.to		 = @"";
	self.cc		 = @"";
	self.from	 = @"";
	self.subject = @"";
	self.body	 = [[[NSAttributedString alloc] initWithString:@""] autorelease];
	return self;
}

- (void)dealloc 
{
    self.delegate = nil;
	self.to		 = nil;
	self.cc		 = nil;
	self.from	 = nil;
	self.subject = nil;
	self.body	 = nil;
	[super dealloc];
}

- (void) send:(id)aDelegate
{
    if([to length]){
        delegate = aDelegate;
        [[ORMailQueue sharedMailQueue] addOperation:self];
        //ORMailerDelay* aDelay = [[ORMailerDelay alloc] init];
        //[[ORMailQueue sharedMailQueue] addOperation:aDelay];
        //[aDelay release];
    }
}

- (void) main
{
    NSAutoreleasePool* thePool = [[NSAutoreleasePool alloc] init];

    if(![self isCancelled]){
        BOOL usePythonScript = [[[NSUserDefaults standardUserDefaults] objectForKey:ORMailSelectionPreference] boolValue];

        if(usePythonScript){
            @try {
                //args ->  -u "username" -p "password" -e "server" -F "fromaddress" -t "addresses" -s "subject" -m "message" -a "attachments"
                NSMutableArray* args = [NSMutableArray array];
      
                NSString *scriptPath = [[NSBundle mainBundle] pathForResource:@"sendMail" ofType:@"py"];
                [args addObject:scriptPath];

                //username
                [args addObject:@"-u"];
                [args addObject:[[NSUserDefaults standardUserDefaults] objectForKey:ORMailAddress]];
      
                //password
                [args addObject:@"-p"];
                [args addObject:[[NSUserDefaults standardUserDefaults] objectForKey:ORMailPassword]];
     
                //server
                [args addObject:@"-e"];
                [args addObject:[[NSUserDefaults standardUserDefaults] objectForKey:ORMailServer]];
                
                // from address
                if([[NSUserDefaults standardUserDefaults] objectForKey:ORMailFromAddress]){
                    [args addObject:@"-F"];
                    [args addObject:[[NSUserDefaults standardUserDefaults] objectForKey:ORMailFromAddress]];
                }
                
                //addresses
                [args addObject:@"-t"];
                [args addObject:[self to]];
               
                //subject
                [args addObject:@"-s"];
                [args addObject:[self subject]];
                //[args addObject:[NSString stringWithFormat:@"\"%@\"", [self subject]]];
      
                //body
                [args addObject:@"-m"];
                NSString* content = [NSString stringWithFormat:@"\n\nSent from ORCA running on: %@\n\n\n%@",computerName(),[[self body]string]];
                                
                //NSString* content = [NSString stringWithFormat:@"\"Sent from ORCA running on: %@%@\"",computerName(),[[self body]string]];
                [args addObject:content];
                
                NSTask* task = [[[NSTask alloc] init] autorelease];
                task.launchPath = scriptPath;
                task.arguments = args;
                
                
                NSPipe *stdOutPipe = nil;
                stdOutPipe = [NSPipe pipe];
                [task setStandardOutput:stdOutPipe];
                
                [task launch];
                
               // NSData* data = [[stdOutPipe fileHandleForReading] readDataToEndOfFile];
                
                [task waitUntilExit];
                
                NSInteger exitCode = task.terminationStatus;
                
                if (exitCode != 0){
                    NSLogColor([NSColor redColor], @"Mail Script Error!\n");
                }
                
               //NSString* s = [[[NSString alloc] initWithBytes: data.bytes length:data.length encoding: NSUTF8StringEncoding] autorelease];
               // NSLog(@"%@\n",s);
            }
            @catch (NSException* e){
                NSLogColor([NSColor redColor], @"Python script sending mail exception\n");
            }
        }
        else {
            /* create a new outgoing message object */
            /* create a Scripting Bridge object for talking to the Mail application */
            NSString* content = [NSString stringWithFormat:@"\n\nFrom ORCA running on: %@\n\n\n%@",computerName(),[[self body]string]];

            MailApplication *mail = [SBApplication applicationWithBundleIdentifier:@"com.apple.Mail"];
            MailOutgoingMessage *emailMessage = [[[mail classForScriptingClass:@"outgoing message"] alloc] initWithProperties:
                                                 [NSDictionary dictionaryWithObjectsAndKeys:
                                                  subject, @"subject",
                                                  content, @"content",
                                                  nil]];

            @try {
                /* add the object to the mail app  */
                [[mail outgoingMessages] addObject: emailMessage];
                
                int delayCount = 0;
                while (![mail isRunning]) {
                    [ORTimer delay:1];
                    delayCount++;
                    if(delayCount>5)break;
                }
                
                if([mail isRunning]){
                    /* set the sender, don't show the message */
                    emailMessage.sender = @"ORCA";
                    emailMessage.visible = YES;
                    
                    if ( [mail lastError] != nil ){
                        @throw([NSException exceptionWithName:@"ORMailer had problems sending message" reason:@"" userInfo:nil]);
                    }
                    NSArray* people = [to componentsSeparatedByString:@","];
                    int count = 0;
                    for(id aPerson in people){
                        if([aPerson rangeOfString:@"@"].location != NSNotFound){
                            NSDictionary* properties = [NSDictionary dictionaryWithObjectsAndKeys: aPerson, @"address",nil];
                            MailToRecipient *theRecipient = [[[mail classForScriptingClass:@"to recipient"] alloc] initWithProperties:properties];
                            [emailMessage.toRecipients addObject: theRecipient];
                            [theRecipient release];
                            count++;
                        }
                    }
                    
                    people = [cc componentsSeparatedByString:@","];
                    for(id aPerson in people){
                        if([aPerson rangeOfString:@"@"].location != NSNotFound && [aPerson length]>0){
                            NSDictionary*    properties   = [NSDictionary dictionaryWithObjectsAndKeys: aPerson, @"address",nil];
                            MailCcRecipient* theRecipient = [[[mail classForScriptingClass:@"cc recipient"] alloc] initWithProperties:properties];
                            [emailMessage.ccRecipients addObject: theRecipient];
                            [theRecipient release];
                        }
                    }
                    
                    if ( [mail lastError] == nil && count>0){
                        [emailMessage send];
                        if([mail lastError] != nil)	{
                            @throw([NSException exceptionWithName:@"ORMailer had problems sending message" reason:@"" userInfo:nil]);
                        }
                        else {
                            if([delegate respondsToSelector:@selector(mailSent:)]){
                                [delegate mailSent:to];
                            }
                            else NSLog(@"email sent to: %@\n",to);
                        }
                    }
                }
                else NSLogColor([NSColor redColor],@"Mail app did not start. ORCA unable to send email.\n");
            }
            @catch(NSException* e){
                NSLog( @"Possible problems with sending e-mail to %@\n",to);
            }
            @finally {
                [emailMessage release];
            }
        }
	}
    [thePool release];
}


@end
@implementation ORMailerDelay
- (void) main
{
    NSAutoreleasePool* thePool = [[NSAutoreleasePool alloc] init];

    if(![self isCancelled]){
        int i;
        for(i=0;i<50;i++){
            if([self isCancelled])return;
            usleep(100000);
        }
    }
    [thePool release];
}
@end
											 

//-----------------------------------------------------------
//ORMailQueue: A shared queue for the mailer. You should 
//never have to use this object directly. It will be created
//on demand when email is sent.
//-----------------------------------------------------------
@implementation ORMailQueue
SYNTHESIZE_SINGLETON_FOR_ORCLASS(MailQueue);
+ (NSOperationQueue*) queue				 { return [[ORMailQueue sharedMailQueue] queue]; }
+ (void) addOperation:(NSOperation*)anOp { return [[ORMailQueue sharedMailQueue] addOperation:anOp]; }
+ (NSUInteger) operationCount			 { return [[ORMailQueue sharedMailQueue] operationCount]; }

//don't call this unless you're using this class in a special, non-global way.
- (id) init
{
	self = [super init];
	queue = [[NSOperationQueue alloc] init];
	[queue setMaxConcurrentOperationCount:1];
    return self;
}

- (NSOperationQueue*) queue					{ return queue; }
- (void) addOperation:(NSOperation*)anOp	{ [queue addOperation:anOp]; }
- (NSInteger) operationCount				{ return [[queue operations]count]; }

@end

