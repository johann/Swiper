#import <Foundation/Foundation.h>
#import "DTDevices.h"


@interface EMVViewController : UIViewController <UITextFieldDelegate> {
	IBOutlet UITextView *logView;
    
	DTDevices *dtdev;
}

-(IBAction)onEMVTest:(id)sender;
-(IBAction)onLoadCAKeys:(id)sender;

@end
