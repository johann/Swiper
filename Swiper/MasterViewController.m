//
//  MasterViewController.m
//  Swiper
//
//  Created by Johann Kerr on 8/25/14.
//  Copyright (c) 2014 Johann Kerr. All rights reserved.
//


#import "MasterViewController.h"
#import "NSDataCrypto.h"
#import "dukpt.h"
#import <Parse/Parse.h>
#import "StringConstants.h"
#import <CoreData/CoreData.h>
#import "TWMessageBarManager.h"
#import "AppDelegate.h"
#import <MessageUI/MessageUI.h>
#import "CHCSVParser.h"
#import "Card.h"
#import <CommonCrypto/CommonDigest.h>
#import <AVFoundation/AVFoundation.h>





CGFloat const kTWMesssageBarDemoControllerButtonPadding = 10.0f;
CGFloat const kTWMesssageBarDemoControllerButtonHeight = 50.0f;

// Colors
static UIColor *kTWMesssageBarDemoControllerButtonColor = nil;


@interface MasterViewController () <NSFetchedResultsControllerDelegate, MFMailComposeViewControllerDelegate>
@property (strong, nonatomic) NSFetchedResultsController *fetchedResultsController;
@property (strong) NSMutableArray *cards;
@property (nonatomic) NSString *passNumber;
@property (nonatomic, strong) AppDelegate *appDelegate;




@property (nonatomic, strong) UIButton *errorButton;
@property (nonatomic, strong) UIButton *successButton;
@property (nonatomic, strong) UIButton *infoButton;
@property (nonatomic, strong) UIButton *hideAllButton;

// Button presses
- (void)errorButtonPressed:(id)sender;
- (void)successButtonPressed:(id)sender;
- (void)infoButtonPressed:(id)sender;
- (void)hideAllButtonPressed:(id)sender;

// Generators
- (UIButton *)buttonWithTitle:(NSString *)title;

//- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath;
@end

@implementation MasterViewController

@synthesize suspendDisplayInfo;

bool scanActive=false;
NSTimer *ledTimer=nil;


+ (void)initialize
{
	if (self == [MasterViewController class])
	{
        kTWMesssageBarDemoControllerButtonColor = [UIColor colorWithWhite:0.0 alpha:0.25];
	}
}

- (id)initWithStyleSheet:(NSObject<TWMessageBarStyleSheet> *)stylesheet
{
    self = [super init];
    if (self)
    {
        [TWMessageBarManager sharedInstance].styleSheet = stylesheet;
    }
    return self;
}

- (id)init
{
    return [self initWithStyleSheet:nil];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.appDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
    number = [[NSMutableString alloc] init];
    dtdev=[DTDevices sharedDevice];
	[dtdev addDelegate:self];
    [dtdev connect];
    
	// Do any additional setup after loading the view, typically from a nib.
    //self.navigationItem.leftBarButtonItem = self.editButtonItem;
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Clear All" style:UIBarButtonItemStyleBordered target:self action:@selector(showLeft)];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Email" style:UIBarButtonItemStyleBordered target:self action:@selector(showRight)];
    
    
    
    //NSManagedObjectContext *managedObjectContext = [self managedObjectContext];
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] initWithEntityName:@"Card"];
    [fetchRequest setSortDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"createdAt" ascending:YES]]];
    self.fetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest managedObjectContext:self.managedObjectContext sectionNameKeyPath:nil cacheName:nil];
    [self.fetchedResultsController setDelegate:self];
    NSError *error = nil;
    [self.fetchedResultsController performFetch:&error];
    if (error){
        NSLog(@"Unable to perform fetch.");
        NSLog(@"%@, %@", error, error.localizedDescription);
        
    }
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidEnterForeground:) name:UIApplicationWillEnterForegroundNotification object:nil];
    
    
    UIAlertView *passAlert = [[UIAlertView alloc] initWithTitle:@"Operations Swiper"
                                                        message:@"Enter a pass number" delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Okay", nil];
    passAlert.alertViewStyle = UIAlertViewStylePlainTextInput;
    [[passAlert textFieldAtIndex:0] setKeyboardType:UIKeyboardTypeAlphabet];
    [passAlert show];
    
    
    //self.cards = [[managedObjectContext executeFetchRequest:fetchRequest error:nil] mutableCopy];
    
    //[self.tableView reloadData];
    
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    NSLog(@"view did appear");
}

- (void)appDidEnterForeground:(NSNotification *)notification {
    NSLog(@"did enter foreground notification");
    
    UIAlertView *passAlert = [[UIAlertView alloc] initWithTitle:@"Operations Swiper"
                                                        message:@"Enter a pass number" delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Okay", nil];
    passAlert.alertViewStyle = UIAlertViewStylePlainTextInput;
    [[passAlert textFieldAtIndex:0] setKeyboardType:UIKeyboardTypeAlphabet];
    [passAlert show];

}

#pragma mark -
#pragma mark Alert View Delegate Methods

-(void)alertView:(UIAlertView*)alertView clickedButtonAtIndex:(NSInteger)buttonIndex{
    if (alertView.alertViewStyle == UIAlertViewStylePlainTextInput && buttonIndex == 1){
        UITextField *textField = [alertView textFieldAtIndex:0];
        
        NSString *valreg = @"^[A-Z][0-9][0-9][0-9][0-9]";
        NSPredicate* valtest = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", valreg];
        
        
        if (![valtest evaluateWithObject:textField.text]){
            
            UIAlertView *passAlert = [[UIAlertView alloc] initWithTitle:@"Invalid"
                                                                message:@"Enter a pass number" delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Okay", nil];
            passAlert.alertViewStyle = UIAlertViewStylePlainTextInput;
            [[passAlert textFieldAtIndex:0] setKeyboardType:UIKeyboardTypeAlphabet];
            [passAlert show];
            [passAlert setTag:1];
            
            
            

        }
        
        self.passNumber = textField.text;
        NSLog(@"%@", self.passNumber);
    }
    if(alertView.tag == 2){
        if (buttonIndex == 1){
            NSLog(@"help");
            [self reset];
        }
        else{
            NSLog(@"help not working");
        }
        
        
    }

}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark -
#pragma mark Magnetic Card Methods


-(void)magneticCardData:(NSString *)track1 track2:(NSString *)track2 track3:(NSString *)track3 {
    //mainTabBarController.selectedViewController=self;
    
    if (track2 != NULL){
    NSManagedObjectContext *context = [self.fetchedResultsController managedObjectContext];
    NSEntityDescription *entity = [[self.fetchedResultsController fetchRequest] entity];
    NSManagedObject *newManagedObject = [NSEntityDescription insertNewObjectForEntityForName:[entity name] inManagedObjectContext:context];
    
    // If appropriate, configure the new managed object.
    // Normally you should use accessor methods, but using KVC here avoids the need to add a custom class to the template.
    [number setString:@""];
    
        [number appendFormat:@"%@", track2];
        NSString *numberWithoutmark = [number stringByReplacingOccurrencesOfString:@";" withString:@""];
        NSString *numberWithoutcolon = [numberWithoutmark stringByReplacingOccurrencesOfString:@"?" withString:@""];
        
        [newManagedObject setValue:[NSDate date] forKey:@"createdAt"];
        [newManagedObject setValue:numberWithoutcolon forKey:@"number"];
        [newManagedObject setValue:self.passNumber forKey:@"pass"];
        [self.cards addObject:newManagedObject];
          
        PFObject *cardInfo = [PFObject objectWithClassName:@"Card"];
        cardInfo[@"number"] = numberWithoutcolon;
        cardInfo[@"time"] = [NSDate date];
        cardInfo[@"pass"] = self.passNumber;
        [cardInfo saveInBackground];
        [[TWMessageBarManager sharedInstance] showMessageWithTitle:kStringMessageBarSuccessTitle
                                                       description:kStringMessageBarSuccessMessage
                                                              type:TWMessageBarMessageTypeSuccess
                                                    statusBarStyle:UIStatusBarStyleDefault
                                                          callback:nil];
        
    NSLog(@"%@", number);
    NSLog(@"%@", [NSDate date]);
    [self.tableView setContentOffset:CGPointMake(0, CGFLOAT_MAX)];
        int sound[]={2780,120,0,30,2730,120};//2730,150,0,30,2730,150
        
        //[dtdev playSound:5 beepData:sound length:sizeof(sound) error:nil];
    }
	//[status setString:@""];
	
    //	NSDictionary *card=[dtdev msProcessFinancialCard:track1 track2:track2];
    //	if(card)
    //	{
    //		if([card valueForKey:@"cardholderName"])
    //			[status appendFormat:@"Name: %@\n",[card valueForKey:@"cardholderName"]];
    //		if([card valueForKey:@"accountNumber"])
    //			[status appendFormat:@"Number: %@\n",[card valueForKey:@"accountNumber"]];
    //		if([card valueForKey:@"expirationMonth"])
    //			[status appendFormat:@"Expiration: %@/%@\n",[card valueForKey:@"expirationMonth"],[card valueForKey:@"expirationYear"]];
    //		[status appendString:@"\n"];
    //	}
    //
    //	if(track1!=NULL)
    //		//[status appendFormat:@"Track1: %@\n",track1];
    //        if(track2!=NULL)
    //            [status appendFormat:@"Track2: %@\n",track2];
    //	if(track3!=NULL)
    //		[status appendFormat:@"Track3: %@\n",track3];
    //	[displayText setText:status];
	
	
	//[self updateBattery];
    
    //    //also, if we have pinpad connected, ask for pin entry
    //    if(card && [dtdev getSupportedFeature:FEAT_PIN_ENTRY error:nil]==FEAT_SUPPORTED)
    //    {
    //        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"PIN Entry" message:@"Do you want to enter PIN?" delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Yes", nil];
    //        [alert show];
    //    }
}


-(NSString *)toHexString:(void *)data length:(int)length space:(bool)space
{
	const char HEX[]="0123456789ABCDEF";
	char s[2000];
	
	int len=0;
	for(int i=0;i<length;i++)
	{
		s[len++]=HEX[((uint8_t *)data)[i]>>4];
		s[len++]=HEX[((uint8_t *)data)[i]&0x0f];
        if(space)
            s[len++]=' ';
	}
	s[len]=0;
	return [NSString stringWithCString:s encoding:NSASCIIStringEncoding];
}


//- (void)insertNewObject:(id)sender
//{
//    NSManagedObjectContext *context = [self.fetchedResultsController managedObjectContext];
//    NSEntityDescription *entity = [[self.fetchedResultsController fetchRequest] entity];
//    NSManagedObject *newManagedObject = [NSEntityDescription insertNewObjectForEntityForName:[entity name] inManagedObjectContext:context];
//
//    // If appropriate, configure the new managed object.
//    // Normally you should use accessor methods, but using KVC here avoids the need to add a custom class to the template.
//    [newManagedObject setValue:[NSDate date] forKey:@"createdAt"];
//    [newManagedObject setValue:[NSString stringWithFormat:@"blarb"] forKey:@"number"];
//
//    // Save the context.
//    NSError *error = nil;
//    if (![context save:&error]) {
//         // Replace this implementation with code to handle the error appropriately.
//         // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
//        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
//        abort();
//    }
//}


#pragma mark Fetched Results Controller Delegate Methods

-(void)controllerWillChangeContent:(NSFetchedResultsController *)controller{
    [self.tableView beginUpdates];
}

-(void)controllerDidChangeContent:(NSFetchedResultsController *)controller{
    [self.tableView endUpdates];
    
    
}

- (void)controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type newIndexPath:(NSIndexPath *)newIndexPath {
    switch (type) {
        case NSFetchedResultsChangeInsert: {
            [self.tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:newIndexPath] withRowAnimation:UITableViewRowAnimationFade];
           
            
            break;
        }
        case NSFetchedResultsChangeDelete: {
            [self.tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
        }
        case NSFetchedResultsChangeUpdate: {
            [self configureCell:[self.tableView cellForRowAtIndexPath:indexPath] atIndexPath:indexPath];
            break;
        }
        case NSFetchedResultsChangeMove: {
            [self.tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
            [self.tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:newIndexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
        }
    }
}

#pragma mark - Table View

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return [[self.fetchedResultsController sections] count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    id <NSFetchedResultsSectionInfo> sectionInfo = [self.fetchedResultsController sections][section];
    return [sectionInfo numberOfObjects];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:indexPath];
    [self configureCell:cell atIndexPath:indexPath];
    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the specified item to be editable.
    return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        NSManagedObjectContext *context = [self.fetchedResultsController managedObjectContext];
        [context deleteObject:[self.fetchedResultsController objectAtIndexPath:indexPath]];
        
        NSError *error = nil;
        if (![context save:&error]) {
            // Replace this implementation with code to handle the error appropriately.
            // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
            abort();
        }
    }
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    // The table view should not be re-orderable.
    return NO;
}



#pragma mark - Fetched results controller

/*
 
 - (NSFetchedResultsController *)fetchedResultsController
 {
 if (_fetchedResultsController != nil) {
 return _fetchedResultsController;
 }
 
 NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
 // Edit the entity name as appropriate.
 NSEntityDescription *entity = [NSEntityDescription entityForName:@"Card" inManagedObjectContext:self.managedObjectContext];
 [fetchRequest setEntity:entity];
 
 // Set the batch size to a suitable number.
 [fetchRequest setFetchBatchSize:20];
 
 // Edit the sort key as appropriate.
 NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"createdAt" ascending:NO];
 NSArray *sortDescriptors = @[sortDescriptor];
 
 [fetchRequest setSortDescriptors:sortDescriptors];
 
 // Edit the section name key path and cache name if appropriate.
 // nil for section name key path means "no sections".
 NSFetchedResultsController *aFetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest managedObjectContext:self.managedObjectContext sectionNameKeyPath:nil cacheName:@"Master"];
 aFetchedResultsController.delegate = self;
 self.fetchedResultsController = aFetchedResultsController;
 
 NSError *error = nil;
 if (![self.fetchedResultsController performFetch:&error]) {
 // Replace this implementation with code to handle the error appropriately.
 // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
 NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
 abort();
 }
 
 return _fetchedResultsController;
 }
 
 - (void)controllerWillChangeContent:(NSFetchedResultsController *)controller
 {
 [self.tableView beginUpdates];
 }
 
 - (void)controller:(NSFetchedResultsController *)controller didChangeSection:(id <NSFetchedResultsSectionInfo>)sectionInfo
 atIndex:(NSUInteger)sectionIndex forChangeType:(NSFetchedResultsChangeType)type
 {
 switch(type) {
 case NSFetchedResultsChangeInsert:
 [self.tableView insertSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationFade];
 break;
 
 case NSFetchedResultsChangeDelete:
 [self.tableView deleteSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationFade];
 break;
 }
 }
 
 - (void)controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject
 atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type
 newIndexPath:(NSIndexPath *)newIndexPath
 {
 UITableView *tableView = self.tableView;
 
 switch(type) {
 case NSFetchedResultsChangeInsert:
 [tableView insertRowsAtIndexPaths:@[newIndexPath] withRowAnimation:UITableViewRowAnimationFade];
 break;
 
 case NSFetchedResultsChangeDelete:
 [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
 break;
 
 case NSFetchedResultsChangeUpdate:
 [self configureCell:[tableView cellForRowAtIndexPath:indexPath] atIndexPath:indexPath];
 break;
 
 case NSFetchedResultsChangeMove:
 [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
 [tableView insertRowsAtIndexPaths:@[newIndexPath] withRowAnimation:UITableViewRowAnimationFade];
 break;
 }
 }
 
 - (void)controllerDidChangeContent:(NSFetchedResultsController *)controller
 {
 [self.tableView endUpdates];
 }
 
 
 // Implementing the above methods to update the table view in response to individual changes may have performance implications if a large number of changes are made simultaneously. If this proves to be an issue, you can instead just implement controllerDidChangeContent: which notifies the delegate that all section and object changes have been processed.
 
 - (void)controllerDidChangeContent:(NSFetchedResultsController *)controller
 {
 // In the simplest, most efficient, case, reload the table view.
 [self.tableView reloadData];
 }
 */

- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath
{
    NSManagedObject *object = [self.fetchedResultsController objectAtIndexPath:indexPath];
    cell.textLabel.text = [[object valueForKey:@"number"] description];
    
   
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@  |  %@",[[object valueForKey:@"pass"] description], [[object valueForKey:@"createdAt"] description]];
    
}

-(void)reset{
    NSFetchRequest *allCards = [[NSFetchRequest alloc] init];
    [allCards setEntity:[NSEntityDescription entityForName:@"Card" inManagedObjectContext:[self managedObjectContext]]];
    [allCards setIncludesPropertyValues:NO]; //only fetch the managedObjectID
    
    NSError * error = nil;
    NSArray * cards = [self.managedObjectContext executeFetchRequest:allCards error:&error];
    
    //error handling goes here
    for (NSManagedObject *card in cards) {
        [self.managedObjectContext deleteObject:card];
    }
    NSError *saveError = nil;
    [self.managedObjectContext save:&saveError];
    NSLog(@"%@", self.managedObjectContext);
}

-(void)resetAllData
{
    NSManagedObjectContext *context = [self managedObjectContext];

    
    NSMutableArray *cells = [[NSMutableArray alloc] init];
    for (NSInteger j = 0; j < [self.tableView numberOfSections]; ++j)
    {
        for (NSInteger i = 0; i < [self.tableView numberOfRowsInSection:j]; ++i)
        {
            
            [context deleteObject:[self.cards objectAtIndex:i]];
            
            NSError *error = nil;
            if (![context save:&error]) {
                NSLog(@"Can't Delete! %@ %@", error, [error localizedDescription]);
                return;
            }
            
            // Remove device from table view
            [self.cards removeObjectAtIndex:i];
            [self.tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:i inSection:j]] withRowAnimation:UITableViewRowAnimationFade];
            //[self.tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
            //[cells addObject:[self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:i inSection:j]]];
        }
    }
   
    
}



-(void)showLeft{
    
    
    NSLog(@"cleared");
    
    UIAlertView *clearAlert = [[UIAlertView alloc] initWithTitle:@"Operations Swiper"
                                                        message:@"Do you want to clear the data?" delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Okay", nil];
    [clearAlert setTag:2];
    [clearAlert show];
        
    
    
}
-(void)showRight{
    NSLog(@"right");
    [self emailCompiler];
}

-(void)emailCompiler{
    NSFetchRequest *allCards = [[NSFetchRequest alloc] init];
    [allCards setEntity:[NSEntityDescription entityForName:@"Card" inManagedObjectContext:[self managedObjectContext]]];
    NSOutputStream *stream = [[NSOutputStream alloc] initToMemory];
    CHCSVWriter *writer = [[CHCSVWriter alloc] initWithOutputStream:stream encoding:NSUTF8StringEncoding delimiter:','];
    
    [allCards setIncludesPropertyValues:NO]; //only fetch the managedObjectID
    
    NSError * error = nil;
    NSArray * cards = [self.managedObjectContext executeFetchRequest:allCards error:&error];
    NSManagedObject *marker = [cards objectAtIndex:0];
    
    
    //error handling goes here
    for (NSManagedObject *card in cards) {
        [writer writeLineOfFields:@[[card valueForKey:@"number"]]];
        
    }

    [writer closeStream];
    NSData *buffer = [stream propertyForKey:NSStreamDataWrittenToMemoryStreamKey];
    NSString *output = [[NSString alloc] initWithData:buffer encoding:NSUTF8StringEncoding];
    NSLog(@"%@", output);
    
    NSString *emailTitle = [NSString stringWithFormat:@"%@", [marker valueForKey:@"pass"]];
    NSString *messageBody = [NSString stringWithFormat:@"%@", output];
    //NSArray *toRecipients = [NSArray arrayWithObject:@"johann.kerr10@stjohns.edu"];
    NSMutableArray *recipients = [NSMutableArray arrayWithObjects:@"labuzi@stjohns.edu", @"lopezd1@stjohns.edu", @"jeromef@stjohns.edu", @"stuoperations@stjohns.edu",@"jeannotj@stjohns.edu" ,nil];
    NSArray *array = [[NSArray alloc] initWithArray:recipients];
    MFMailComposeViewController *mc = [[MFMailComposeViewController alloc] init];
    
    
    if ([MFMailComposeViewController canSendMail]){
        mc.mailComposeDelegate = self;
        [mc setSubject:emailTitle];
        [mc setMessageBody:messageBody isHTML:NO];
        [mc setToRecipients:array];
        [self presentViewController:mc animated:YES completion:nil];
        
    }
    
    
}

-(void)mailComposeController:(MFMailComposeViewController*)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError*)error {
    [self dismissModalViewControllerAnimated:YES];
}



@end
