#import <Foundation/Foundation.h>
#import "DTDevices.h"


@interface PrintViewController : UIViewController {
	DTDevices *dtdev;
    
    IBOutlet UILabel *paperStatusLabel;
}

-(IBAction)onFontsDemo:(id)sender;
-(IBAction)onSelfTest:(id)sender;
-(IBAction)onBarcodesDemo:(id)sender;
-(IBAction)onGraphicsDemo:(id)sender;
-(IBAction)onLoadLogo:(id)sender;
-(IBAction)onCalibrate:(id)sender;
-(IBAction)onOnFeedPaper:(id)sender;
-(IBAction)onPageModeDemo:(id)sender;

@end
