//
//  MasterViewController.h
//  Swiper
//
//  Created by Johann Kerr on 8/25/14.
//  Copyright (c) 2014 Johann Kerr. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import "DTDevices.h"
#import <Parse/Parse.h>


#import <CoreData/CoreData.h>
#import "TWMessageBarManager.h"
#import <MessageUI/MessageUI.h>



@interface MasterViewController : UIViewController <UITableViewDataSource, UITableViewDelegate,MFMailComposeViewControllerDelegate, DTDeviceDelegate>{
    NSMutableString *number;
    DTDevices *dtdev;
}




- (id)initWithStyleSheet:(NSObject<TWMessageBarStyleSheet> *)stylesheet;
-(void)playSound:(NSString *)fileName volume:(float)volume;

@property (assign) bool suspendDisplayInfo;


@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (strong, nonatomic) NSManagedObjectContext *managedObjectContext;
@property (strong, nonatomic) NSManagedObjectModel *managedObjectModel;
@property (strong, nonatomic) NSPersistentStoreCoordinator *persistentStoreCoordinator;
@property (strong, nonatomic) PFObject *cardObject;
@end


#define SHOWERR(func) func; if(error)[MasterViewController debug:error.localizedDescription];
#define ERRMSG(title) {UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title message:error.localizedDescription delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil, nil]; [alert show];}


