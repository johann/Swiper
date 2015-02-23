#import <Foundation/Foundation.h>
#import "DTDevices.h"
#import "ProgressViewController.h"

@interface EMV2ViewController : UIViewController
{
	IBOutlet UITextView *logView;
	IBOutlet ProgressViewController *progressViewController;
    
	DTDevices *dtdev;
    NSTimer *cancelTimer;
}

-(IBAction)onEMVTransaction:(id)sender;

@end
