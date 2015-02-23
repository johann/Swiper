#import "PPadViewController.h"


@implementation PPadViewController

-(void)displayAlert:(NSString *)title message:(NSString *)message
{
	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title message:message delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil, nil];
	[alert show];
}


#define COMMAND(operation,x) if(!x){[self displayAlert:@"Error" message:[NSString stringWithFormat:@"%@ failed with error: %@",operation,err.localizedDescription]]; return; }

-(IBAction)onKeysInfo:(id)sender;
{
    NSError *err;
    
    NSMutableString *s=[NSMutableString string];
    
    [s appendFormat:@"Loaded Pinpad Keys:\n"];
    for(int i=0;i<50;i++)
    {
        DTKeyInfo *key=[dtdev ppadGetKeyInfo:i error:&err];
        COMMAND(@"Get Key",key);
        if(key.version!=0)
            [s appendFormat:@"%2d. Ver: %d, Usage: %@, KCV: %@\n",i,key.version,key.usage,key.checkValue];
    }
    [self displayAlert:@"Keys" message:s];
}


-(void)viewWillAppear:(BOOL)animated
{
}

-(void)viewWillDisappear:(BOOL)animated
{
}

-(void)viewDidLoad
{
	dtdev=[DTDevices sharedDevice];
    [dtdev addDelegate:self];
    [super viewDidLoad];
}


@end
