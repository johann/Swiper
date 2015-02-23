//#define LABEL_DEMO

#import "SettingsViewController.h"
#import "NSDataCrypto.h"
#import "LabelParser.h"

@implementation SettingsViewController

@synthesize scanMode;

static NSString *settings[]={
	@"Beep upon scan",
	@"Enable scan button",
	@"Automated charge enabled",
	@"Reset barcode engine",
	@"Enable external speaker",
	@"Enable pass-through sync",
	@"Enable 1A USB charging (!!)",
	@"Vibrate on barcode scan",
};

enum SETTINGS{
	SET_BEEP=0,
	SET_ENABLE_SCAN_BUTTON,
	SET_AUTOCHARGING,
	SET_RESET_BARCODE,
	SET_ENABLE_SPEAKER,
	SET_ENABLE_SYNC,
    SET_CHARGE_1A,
    SET_VIBRATE,
    SET_LAST
};


static NSString *scan_modes[]={
	@"Single scan",
	@"Multi scan",
	@"Motion detect",
	@"Single scan on button release",
    @"Multi scan without duplicates",
};

static NSString *section_names[]={
	@"General Settings",
	@"Barcode Scan Mode",
	@"LED Control",
	@"Bluetooth Client",
	@"Bluetooth Server",
    @"TCP/IP Devices",
    @"Firmware Update",
    @"Voltage",
    @"Misc",
};

static NSString *misc_operations[]={
	@"ExtRS Test",
#ifdef LABEL_DEMO
	@"Print Label on Roll",
	@"Print Label on Label",
#endif
};

static NSString *labelFiles[]={
    @"3CALIBRATION.txt",
    @"3DEMO1.txt",
    @"3DEMO1_3X.txt",
    @"3DEMO2.txt",
    @"3DEMO2_3X.txt",
    @"4CALIBRATION.txt",
    @"4DEMO1.txt",
    @"4DEMO1_3X.txt"
    @"FORMAT.txt"
};

static NSString *voltage_settings[]={
	@"Display info",
	@"Generate new key",
	@"Load Config 1 (SPE)",
	@"Load Config 2 (Full Track)",
};

static NSString *led_names[]={
    @"Green",
    @"Red",
    @"Orange",
    @"Blue",
};

static uint32_t led_bits[]={
    0x00000001,
    0x00000002,
    0x00000003,
    0x00000004,
};

static UIColor *led_colors[4];

enum SECTIONS{
    SEC_GENERAL=0,
    SEC_BARCODE_MODE,
    SEC_LEDS,
    SEC_BT_CLIENT,
    SEC_BT_SERVER,
    SEC_TCP_DEVICES,
    SEC_FIRMWARE_UPDATE,
    SEC_VOLTAGE,
    SEC_MISC,
    SEC_LAST
};


enum UPDATE_TARGETS{
    TARGET_DEVICE=0,
    TARGET_BARCODE,
};

static BOOL settings_values[SET_LAST];

int beep1[]={2730,250};
int beep2[]={2730,150,65000,20,2730,150};

-(void)displayAlert:(NSString *)title message:(NSString *)message
{
	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title message:message delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil, nil];
	[alert show];
}

-(bool)isDeviceModelEqual:(NSString *)model
{
    NSString *deviceModel=[dtdev.deviceModel stringByReplacingOccurrencesOfString:@"PM" withString:@"AM"];
    
    if(model.length!=deviceModel.length)
        return false;
    
    for(int i=0;i<model.length;i+=2)
    {
        NSString *feat=[model substringWithRange:NSMakeRange(i,2)];
        if([deviceModel rangeOfString:feat].length==0)
            return false;
    }
    return true;
}

-(NSString *)getFirmwareFileName
{
//    {
//        NSString *path=[[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"Firmware"];
//        return [path stringByAppendingPathComponent:@"LINEAPro5_NBPMEV_06.05.26.00.BIN"];
//    }
    
    
    NSMutableString *s=[[NSMutableString alloc] init];
	NSError *error;
	NSString *name=[[dtdev.deviceName stringByReplacingOccurrencesOfString:@" " withString:@""] lowercaseString];
    NSString *path=[[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"Firmware"];
	NSArray *files=[[NSFileManager defaultManager] contentsOfDirectoryAtPath:path error:&error];
    
    
	int lastVer=0;
	NSString *lastPath;
	for(int i=0;i<[files count];i++)
	{
		NSString *file=[[files objectAtIndex:i] lastPathComponent];
        if([[file lowercaseString] hasSuffix:@".bin"])
        {
            if([[file lowercaseString] rangeOfString:name].location!=NSNotFound)
            {
                NSData *data=[NSData dataWithContentsOfFile:[path stringByAppendingPathComponent:file] options:nil error:&error];
                NSDictionary *info=[dtdev getFirmwareFileInformation:data error:&error];
                if(info)
                {
                    NSLog(@"file: %@, name=%@, model=%@",file,[info objectForKey:@"deviceName"],[info objectForKey:@"deviceModel"]);
                    [s appendFormat:@"file: %@, name=%@, model=%@\n",file,[info objectForKey:@"deviceName"],[info objectForKey:@"deviceModel"]];
                }
                
                if(info && [[info objectForKey:@"deviceName"] isEqualToString:dtdev.deviceName] && [self isDeviceModelEqual:[info objectForKey:@"deviceModel"]]/*[[info objectForKey:@"deviceModel"] isEqualToString:dtdev.deviceModel] */&& [[info objectForKey:@"firmwareRevisionNumber"] intValue]>lastVer)
                {
                    lastPath=[path stringByAppendingPathComponent:file];
                    lastVer=[[info objectForKey:@"firmwareRevisionNumber"] intValue];
                }
            }
        }
	}
	if(lastVer>0)
		return lastPath;
	return nil;
}

-(BOOL)textFieldShouldEndEditing:(UITextField *)theTextField;
{
	return YES;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField;
{
    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    [prefs setObject:textField.text forKey:@"tcpAddress"];
    [prefs synchronize];
    
	[textField resignFirstResponder];
	return YES;
}

-(void)connectionState:(int)state {
    NSError *error;
    
	switch (state) {
		case CONN_DISCONNECTED:
		case CONN_CONNECTING:
			break;
		case CONN_CONNECTED:
            btListening=false;
            
            memset(settings_values,0,sizeof(settings_values));
            
			//use stored values for settings that are not readable and set that value
			settings_values[SET_BEEP]=[[NSUserDefaults standardUserDefaults] boolForKey:@"BeepOnScan"];
            
			//read settings
            int value=BUTTON_DISABLED;
			[dtdev barcodeGetScanButtonMode:&value error:&error];
            settings_values[SET_ENABLE_SCAN_BUTTON]=(value==BUTTON_ENABLED);
            
			settings_values[SET_AUTOCHARGING]=[[NSUserDefaults standardUserDefaults] boolForKey:@"AutoCharging"];

            if(![dtdev barcodeGetScanMode:&scanMode error:&error])
                scanMode=0;
            
            BOOL enabled=false;;
            [dtdev getPassThroughSync:&enabled error:&error];
            settings_values[SET_ENABLE_SYNC]=enabled;
            
            enabled=false;;
            [dtdev uiIsSpeakerEnabled:&enabled error:&error];
            settings_values[SET_ENABLE_SPEAKER]=enabled;
			
			settings_values[SET_VIBRATE]=[[NSUserDefaults standardUserDefaults] boolForKey:@"vibrateOnScan"];
            
			[settingsTable reloadData];
			break;
	}
}

-(void)bluetoothDeviceDiscovered:(NSString *)btAddress name:(NSString *)btName
{
    if(!btName || btName.length==0)
        btName=@"Unknown";
    [btDevices addObject:btAddress];
    [btDevices addObject:btName];
}

-(void)bluetoothDiscoverComplete:(BOOL)success
{
    [progressViewController.view removeFromSuperview];
    [settingsTable reloadData];
    if(!success)
        [self displayAlert:NSLocalizedString(@"Bluetooth Error",nil) message:NSLocalizedString(@"Discovery failed!",nil)];
    
	NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    [prefs setObject:btDevices forKey:@"bluetoothDevices"];
    [prefs synchronize];
}

-(void)deviceFeatureSupported:(int)feature value:(int)value
{
    [settingsTable reloadData];
}

-(void)firmwareUpdateEnd:(NSError *)error
{
    [progressViewController.view removeFromSuperview];
    if(error)
        [self displayAlert:NSLocalizedString(@"Firmware Update",nil) message:[NSString stringWithFormat:NSLocalizedString(@"Firmware updated failed with error:%@",nil),error.localizedDescription]];
}

-(void)firmwareUpdateProgress:(int)phase percent:(int)percent
{
    dispatch_async(dispatch_get_main_queue(), ^{
        switch (phase)
        {
            case UPDATE_INIT:
                [progressViewController updateProgress:NSLocalizedString(@"Initializing update...",nil) progress:percent];
                break;
            case UPDATE_ERASE:
                [progressViewController updateProgress:NSLocalizedString(@"Erasing flash...",nil) progress:percent];
                break;
            case UPDATE_WRITE:
                [progressViewController updateProgress:NSLocalizedString(@"Writing firmware...",nil) progress:percent];
                break;
            case UPDATE_COMPLETING:
                [progressViewController updateProgress:NSLocalizedString(@"Completing operation...",nil) progress:percent];
                break;
            case UPDATE_FINISH:
                [progressViewController updateProgress:NSLocalizedString(@"Complete!",nil) progress:percent];
                break;
        }
    });
}

-(void)firmwareUpdateThread:(NSString *)file
{
	@autoreleasepool {
        NSError *error=nil;
    
        BOOL idleTimerDisabled_Old=[UIApplication sharedApplication].idleTimerDisabled;
        [[UIApplication sharedApplication] setIdleTimerDisabled: YES];
        
        if(firmareTarget==TARGET_DEVICE)
        {
            [progressViewController performSelectorOnMainThread:@selector(updateText:) withObject:@"Updating Linea...\nPlease wait!" waitUntilDone:NO];
            
            //In case authentication key is present in Linea, we need to authenticate with it first, before firmware update is allowed
            //For the sample here I'm using the field "Authentication key" in the crypto settings as data and generally ignoring the result of the
            //authentication operation, firmware update will just fail if authentication have failed
            NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
            //last used decryption key is stored in preferences
            NSString *authenticationKey=[prefs objectForKey:@"AuthenticationKey"];
            if(authenticationKey==nil || authenticationKey.length!=32)
                authenticationKey=@"11111111111111111111111111111111"; //sample default
            
            [dtdev cryptoAuthenticateHost:[authenticationKey dataUsingEncoding:NSASCIIStringEncoding] error:nil];
            [dtdev updateFirmwareData:[NSData dataWithContentsOfFile:file] error:&error];
        }
        if(firmareTarget==TARGET_BARCODE)
        {
            if([dtdev getSupportedFeature:FEAT_BARCODE error:nil]==BARCODE_OPTICON)
            {
                NSString *file09=[[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"Opticon_FL49J09.bin"];
                NSFileManager *fileManager=[NSFileManager defaultManager];
                
                if([fileManager fileExistsAtPath:file09])
                {
                    [progressViewController performSelectorOnMainThread:@selector(updateText:) withObject:@"Updating to version Opticon_FL49J09...\nPlease wait!" waitUntilDone:NO];
                    [dtdev barcodeOpticonUpdateFirmware:[NSData dataWithContentsOfFile:file09] bootLoader:FALSE error:&error];
                }
            }
            if([dtdev getSupportedFeature:FEAT_BARCODE error:nil]==BARCODE_CODE)
            {
                [progressViewController performSelectorOnMainThread:@selector(updateText:) withObject:@"Updating engine...\nPlease wait!" waitUntilDone:NO];
                [dtdev barcodeCodeUpdateFirmware:[firmwareFile lastPathComponent] data:[NSData dataWithContentsOfFile:firmwareFile] error:&error];
            }
            
        }

        [[UIApplication sharedApplication] setIdleTimerDisabled: idleTimerDisabled_Old];
        [self performSelectorOnMainThread:@selector(firmwareUpdateEnd:) withObject:error waitUntilDone:FALSE];
    
    }
}

-(void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if(alertView.tag==0)
    {//firmware update
        if(buttonIndex == 1)
        {
            //Make firmware update prettier - call it from a thread and listen to the notifications only
            [progressViewController viewWillAppear:FALSE];
            [self.view addSubview:progressViewController.view];
            
            [NSThread detachNewThreadSelector:@selector(firmwareUpdateThread:) toTarget:self withObject:firmwareFile];
        }
    }
    if(alertView.tag==1)
    {//enable 1A charging
        NSError *error;
        if(![dtdev setUSBChargeCurrent:settings_values[SET_CHARGE_1A]?1000:500 error:&error])
        {
            settings_values[SET_CHARGE_1A]=FALSE;
            ERRMSG(NSLocalizedString(@"Command failed",nil));
        }
        [settingsTable reloadData];
    }
}

-(void)checkForFirmwareUpdate;
{
	firmwareFile=[self getFirmwareFileName];
	if(firmwareFile==nil)
	{
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Firmware Update",nil)
														message:NSLocalizedString(@"No firmware for this device model present",nil) delegate:nil cancelButtonTitle:NSLocalizedString(@"Ok",nil) otherButtonTitles:nil, nil];
		[alert show];
	}else {
        NSDictionary *info=[dtdev getFirmwareFileInformation:[NSData dataWithContentsOfFile:firmwareFile] error:nil];
		
		if(info/* && [[info objectForKey:@"deviceName"] isEqualToString:dtdev.deviceName] && [[info objectForKey:@"deviceModel"] isEqualToString:dtdev.deviceModel]*/)
		{
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Firmware Update",nil)
                                                            message:[NSString stringWithFormat:NSLocalizedString(@"Device ver: %@\nAvailable: %@\n\nDo you want to update firmware?\n\nDO NOT DISCONNECT DEVICE DURING FIRMWARE UPDATE!",nil),[dtdev firmwareRevision],[info objectForKey:@"firmwareRevision"]]
                                                           delegate:self cancelButtonTitle:NSLocalizedString(@"Cancel",nil) otherButtonTitles:NSLocalizedString(@"Update",nil), nil];
            [alert show];
		}else {
			UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Firmware Update",nil)
															message:NSLocalizedString(@"No firmware for this device model present",nil) delegate:nil cancelButtonTitle:NSLocalizedString(@"Ok",nil) otherButtonTitles:nil, nil];
			[alert show];
		}
	}
}

-(void)checkForOpticonFirmwareUpdate;
{
    firmwareFile=[[[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"Firmware"] stringByAppendingPathComponent:@"Opticon_FL49J05.bin"];
    NSString *opticonIdent=[dtdev barcodeOpticonGetIdent:nil];
    
	if(firmwareFile==nil)
	{
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Firmware Update",nil)
														message:NSLocalizedString(@"No firmware for this device model present",nil) delegate:nil cancelButtonTitle:NSLocalizedString(@"Ok",nil) otherButtonTitles:nil, nil];
		[alert show];
	}else
    {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Firmware Update",nil)
                                                        message:[NSString stringWithFormat:NSLocalizedString(@"Current engine firmware: %@\n\nDo you want to update firmware?\n\nDO NOT DISCONNECT DEVICE DURING FIRMWARE UPDATE!",nil),opticonIdent]
                                                       delegate:self cancelButtonTitle:NSLocalizedString(@"Cancel",nil) otherButtonTitles:NSLocalizedString(@"Update",nil), nil];
        [alert show];
	}
}

-(void)checkForCodeFirmwareUpdate;
{
    
    firmwareFile=[[[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"Firmware"] stringByAppendingPathComponent:@"C005922_0674-system-cr8000-CD_GEN.crz"];
	if(firmwareFile==nil)
	{
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Firmware Update",nil)
														message:NSLocalizedString(@"No firmware for this device model present",nil) delegate:nil cancelButtonTitle:NSLocalizedString(@"Ok",nil) otherButtonTitles:nil, nil];
		[alert show];
    }else
    {
        NSDictionary *info=[dtdev barcodeCodeGetInformation:nil];
        if(!info)
        {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Firmware Update",nil)
                                                            message:NSLocalizedString(@"Code engine not present or not responding",nil) delegate:nil cancelButtonTitle:NSLocalizedString(@"Ok",nil) otherButtonTitles:nil, nil];
            [alert show];
        }else
        {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Firmware Update",nil)
                                                            message:[NSString stringWithFormat:@"Reader info:\n%@\nDo you want to update engine firmware?",info]
                                                           delegate:self cancelButtonTitle:NSLocalizedString(@"Cancel",nil) otherButtonTitles:NSLocalizedString(@"Update",nil), nil];
            [alert show];
        }
    }
}

-(void)checkForNewlandFirmwareUpdate;
{
    //just show info for now
    NSError *error;
    NSData *r;
    uint8_t cmdVer[]={0x33,0x47};
    r=[dtdev barcodeNewlandQuery:[NSData dataWithBytes:cmdVer length:sizeof(cmdVer)] error:&error];
    if(r)
    {
        NSString *ver=[[NSString alloc] initWithData:r encoding:NSASCIIStringEncoding];
        [self displayAlert:@"Firmware info" message:[NSString stringWithFormat:@"Version: %@\n",ver]];
    }
}

-(void)bluetoothDeviceConnected:(NSString *)address;
{
    NSLog(@"bluetoothDeviceConnected: addr: %@",address);
    [settingsTable reloadData];
//    const char *test="test\r\n";
//    [dtdev.btOutputStream write:test maxLength:strlen(test)];
}

-(void)bluetoothDeviceDisconnected:(NSString *)address;
{
    NSLog(@"bluetoothDeviceDisconnected: addr: %@",address);
    [settingsTable reloadData];
}

-(BOOL)bluetoothDeviceRequestedConnection:(NSString *)address name:(NSString *)name
{
    NSLog(@"bluetoothDeviceRequestedConnection: addr: %@, name: %@",address,name);
    return true;
}

-(NSString *)bluetoothDevicePINCodeRequired:(NSString *)address name:(NSString *)name;
{
    NSLog(@"bluetoothDevicePINCodeRequired: addr: %@, name: %@",address,name);
    return @"0000";
}


- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // Number of sections is the number of region dictionaries
    return SEC_LAST;
}

- (NSString *)tableView:(UITableView *)aTableView titleForHeaderInSection:(NSInteger)section {
    return NSLocalizedString(section_names[section],nil);
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // Number of rows is the number of names in the region dictionary for the specified section
    size_t nRows=0;
	switch (section)
	{
		case SEC_GENERAL:
            if(dtdev.connstate==CONN_CONNECTED)
                nRows=SET_LAST;
            break;
            
		case SEC_BARCODE_MODE:
            if(dtdev.connstate==CONN_CONNECTED && [dtdev getSupportedFeature:FEAT_BARCODE error:nil]!=FEAT_UNSUPPORTED)
                nRows=5;
            break;
            
		case SEC_LEDS:
            if(dtdev.connstate==CONN_CONNECTED && [dtdev getSupportedFeature:FEAT_LEDS error:nil]!=FEAT_UNSUPPORTED)
                nRows=4;
            break;
            
		case SEC_BT_CLIENT:
            if(dtdev.connstate==CONN_CONNECTED)
            {
                if(dtdev.connstate==CONN_CONNECTED && [dtdev getSupportedFeature:FEAT_BLUETOOTH error:nil]!=FEAT_UNSUPPORTED)
                    nRows=[btDevices count]/2+1;
            }
            break;

		case SEC_BT_SERVER:
            if(dtdev.connstate==CONN_CONNECTED)
            {
                if(dtdev.connstate==CONN_CONNECTED && [dtdev getSupportedFeature:FEAT_BLUETOOTH error:nil]&BLUETOOTH_HOST)
                    nRows=1+dtdev.btConnectedDevices.count;
                //cache the connected devices in case they change between here and the display
                btConnectedDevices=[dtdev.btConnectedDevices copy];
            }
            break;
            
		case SEC_TCP_DEVICES:
            nRows=2;
            break;
            
		case SEC_FIRMWARE_UPDATE:
            if(dtdev.connstate==CONN_CONNECTED)
                nRows=2;
            break;
            
        case SEC_VOLTAGE:
            if(dtdev.connstate==CONN_CONNECTED && [dtdev getSupportedFeature:FEAT_MSR error:nil]&MSR_VOLTAGE)
                nRows=sizeof(voltage_settings)/sizeof(voltage_settings[0]);
            break;
            
        case SEC_MISC:
            nRows=sizeof(misc_operations)/sizeof(misc_operations[0]);
            break;
	}
	return nRows;
}

NSString *getLogFile()
{
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
	return [[paths objectAtIndex:0] stringByAppendingPathComponent:@"random.bin"];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSError *error=nil;
    
	switch ([indexPath indexAtPosition:0])
	{
		case SEC_GENERAL:
            if(settings_values[indexPath.row])
			{
				settings_values[indexPath.row]=FALSE;
			}else
			{
				settings_values[indexPath.row]=TRUE;
			}
			switch (indexPath.row)
            {
                case SET_BEEP:
                    if(settings_values[SET_BEEP])
                    {
                        [dtdev barcodeSetScanBeep:settings_values[SET_BEEP] volume:100 beepData:beep2 length:sizeof(beep2) error:nil];
                        [dtdev playSound:100 beepData:beep2 length:sizeof(beep2) error:nil];
                    }else
                    {
                        [dtdev barcodeSetScanBeep:settings_values[SET_BEEP] volume:0 beepData:nil length:0 error:nil];
                    }
                    [[NSUserDefaults standardUserDefaults] setBool:settings_values[SET_BEEP] forKey:@"BeepOnScan"];
                    break;
                case SET_ENABLE_SCAN_BUTTON:
                    [dtdev barcodeSetScanButtonMode:settings_values[SET_ENABLE_SCAN_BUTTON] error:nil];
                    break;
                case SET_AUTOCHARGING:
                    [[NSUserDefaults standardUserDefaults] setBool:settings_values[SET_AUTOCHARGING] forKey:@"AutoCharging"];
                    [[NSUserDefaults standardUserDefaults] synchronize];
                    [dtdev setCharging:settings_values[SET_AUTOCHARGING] error:nil];
                    break;
                case SET_RESET_BARCODE:
                    if([dtdev barcodeEngineResetToDefaults:&error])
                        [self displayAlert:@"Success" message:@"Barcode engine was resetted"];
                    else
                        ERRMSG(NSLocalizedString(@"Command failed",nil));
                    settings_values[indexPath.row]=FALSE;
                    break;
                case SET_ENABLE_SPEAKER:
                    if(![dtdev uiEnableSpeaker:settings_values[indexPath.row] error:&error])
                    {
                        settings_values[indexPath.row]=FALSE;
                        ERRMSG(NSLocalizedString(@"Command failed",nil));
                    }
                    if(error==nil)
                        [scannerViewController playSound:@"News_Intro-Maximilien_-1801238420.wav" volume:0.7];
                    break;
                case SET_ENABLE_SYNC:
                    if(![dtdev setPassThroughSync:settings_values[indexPath.row] error:&error])
                    {
                        settings_values[indexPath.row]=FALSE;
                        ERRMSG(NSLocalizedString(@"Command failed",nil));
                    }
                    break;
                case SET_CHARGE_1A:
                    if(settings_values[indexPath.row])
                    {
                        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"WARNING!!!",nil)
                                                                        message:NSLocalizedString(@"Linea's charge adds additional 300mA to the 1A and you can damage your adapter/port if you increase the charge current beyound its limits!!! Do not put 1A charge on 1A adapters, always use 2A adapter! Do not use 1A charge on PCs, unless it goes through high-power usb HUB!",nil)
                                                                       delegate:self cancelButtonTitle:NSLocalizedString(@"Cancel",nil) otherButtonTitles:NSLocalizedString(@"Set charge",nil), nil];
                        alert.tag=1;
                        [alert show];
                    }else
                    if(![dtdev setUSBChargeCurrent:settings_values[indexPath.row]?1000:500 error:&error])
                    {
                        settings_values[indexPath.row]=FALSE;
                        ERRMSG(NSLocalizedString(@"Command failed",nil));
                    }
                    break;
                case SET_VIBRATE:
                    [[NSUserDefaults standardUserDefaults] setBool:settings_values[indexPath.row] forKey:@"vibrateOnScan"];
                    [[NSUserDefaults standardUserDefaults] synchronize];
                    if(settings_values[indexPath.row])
                    {
                        [dtdev uiEnableVibrationForTime:0.5 error:nil];
                        [NSThread sleepForTimeInterval:0.5];
                    }
                    break;
    
            }
			[[tableView cellForRowAtIndexPath: indexPath] setAccessoryType:settings_values[indexPath.row]?UITableViewCellAccessoryCheckmark:UITableViewCellAccessoryNone];
			break;
            
        case SEC_BARCODE_MODE:
            if([dtdev barcodeSetScanMode:(int)indexPath.row error:nil])
                scanMode=(int)indexPath.row;
            [tableView reloadData];
            break;
            
        case SEC_LEDS:
        {
            for(int i=0;i<4;i++)
            {
                [dtdev uiControlLEDsWithBitMask:led_bits[indexPath.row] error:nil];
                [NSThread sleepForTimeInterval:0.3];
                [dtdev uiControlLEDsWithBitMask:0 error:nil];
                [NSThread sleepForTimeInterval:0.2];
            }
            break;
        }
            
        case SEC_BT_CLIENT:
            if(indexPath.row==0)
            {//perform discovery
                NSError *error=nil;
                [progressViewController viewWillAppear:FALSE];
                [self.view addSubview:progressViewController.view];
                [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
                
                [btDevices removeAllObjects];
#ifdef LABEL_DEMO
                if(![dtdev btDiscoverDevicesInBackground:10 maxTime:8 codTypes:0 error:&error])
#else
                if(![dtdev btDiscoverSupportedDevicesInBackground:10 maxTime:8 filter:BLUETOOTH_FILTER_ALL error:&error])
#endif
                {
                    [progressViewController.view removeFromSuperview];
                    ERRMSG(NSLocalizedString(@"Bluetooth Error",nil));
                }
            }else
            {//connect to the device
                [progressViewController viewWillAppear:FALSE];
                [self.view addSubview:progressViewController.view];
                [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
                
                NSString *selectedAddress=[btDevices objectAtIndex:(indexPath.row-1)*2];
                [[NSUserDefaults standardUserDefaults] setValue:selectedAddress forKey:@"selectedPrinterAddress"];
                [[NSUserDefaults standardUserDefaults] synchronize];
                
                if([dtdev.btConnectedDevices containsObject:selectedAddress])
                {
                    [dtdev btDisconnect:selectedAddress error:nil];
                }else
                {
                    NSError *error=nil;
#ifdef LABEL_DEMO
                    if(![dtdev btConnect:selectedAddress pin:@"0000" error:&error])
#else
                    if(![dtdev btConnectSupportedDevice:selectedAddress pin:@"0000" error:&error])
#endif
                    {
                        ERRMSG(NSLocalizedString(@"Bluetooth Error",nil));
                    }
                }
                
                [progressViewController.view removeFromSuperview];
                [tableView reloadData];
            }
            break;

        case SEC_BT_SERVER:
            [progressViewController viewWillAppear:FALSE];
            [self.view addSubview:progressViewController.view];
            [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
            
            if(indexPath.row==0)
            {//init/stop server
                NSError *error=nil;
                
                if(!btListening)
                {
                    if(![dtdev btListenForDevices:TRUE discoverable:TRUE localName:@"BTDTDevices" cod:0x000000 error:&error])
                    {
                        [progressViewController.view removeFromSuperview];
                        ERRMSG(NSLocalizedString(@"Bluetooth Error",nil));
                    }else
                        btListening=true;
                }else
                {
                    [dtdev btListenForDevices:FALSE discoverable:TRUE localName:nil cod:0x000000 error:&error];
                    btListening=false;
                }
            }else
            {//disconnect from active connection
                [dtdev btDisconnect:[dtdev.btConnectedDevices objectAtIndex:indexPath.row-1] error:nil];
            }
            [progressViewController.view removeFromSuperview];
            [tableView reloadData];
            break;
            
        case SEC_TCP_DEVICES:
        {
            if(indexPath.row==0)
            {//connect to the specified address
                NSError *error;
                [progressViewController viewWillAppear:FALSE];
                [self.view addSubview:progressViewController.view];
                [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
                
                error=nil;
                
                NSString *selectedAddress=[[NSUserDefaults standardUserDefaults] objectForKey:@"tcpAddress"];
                
                if([dtdev.tcpConnectedDevices containsObject:selectedAddress])
                {
                    [dtdev tcpDisconnect:selectedAddress error:nil];
                }else
                {
                    NSError *error=nil;
                    if(![dtdev tcpConnectSupportedDevice:selectedAddress error:&error])
                    {
                        ERRMSG(NSLocalizedString(@"Connection Error",nil));
                    }
                }

                [progressViewController.view removeFromSuperview];
                [tableView reloadData];
            }
            break;
        }
            
		case SEC_FIRMWARE_UPDATE:
            firmareTarget=(int)indexPath.row;
            switch (firmareTarget)
            {
                case TARGET_DEVICE:
                    [self checkForFirmwareUpdate];
                    break;
                case TARGET_BARCODE:
                    if([dtdev getSupportedFeature:FEAT_BARCODE error:nil]==BARCODE_OPTICON)
                    {
                        [self checkForOpticonFirmwareUpdate];
                    }
                    if([dtdev getSupportedFeature:FEAT_BARCODE error:nil]==BARCODE_CODE)
                    {
                        [self checkForCodeFirmwareUpdate];
                    }
                    if([dtdev getSupportedFeature:FEAT_BARCODE error:nil]==BARCODE_NEWLAND)
                    {
                        [self checkForNewlandFirmwareUpdate];
                    }
                    break;
            }
			break;
            
        case SEC_VOLTAGE:
            if(indexPath.row==0)
            {//display info
                DTVoltageInfo *info;
                if(!(info=[dtdev voltageGetInfo:&error]))
                {
                    ERRMSG(@"Voltage error");
                }else
                {
                    [self displayAlert:@"Voltage info" message:[NSString stringWithFormat:@"Settings ver: %d\nKey present: %d\nGenerating: %d\nLast date: %@",info.settingsVersion,info.keyGenerated,info.keyGenerationInProgress,info.keyGenerationDate]];
                }
            }
            if(indexPath.row==1)
            {//regenerate key
                if(![dtdev voltageGenerateNewKey:&error])
                {
                    ERRMSG(@"Voltage error");
                }else
                    [self displayAlert:@"Success" message:@"Settings has been set and new key is currently generating, please wait for couple of minutes for generation to finish. You can always check the status"];
            }
            if(indexPath.row==2)
            {//load some defaults
                NSData *file=[NSData dataWithContentsOfFile:[[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"LINEA_VOLTAGE_PARAMS_TEST_1_S2.0.0.0.BIN"]];
                
                if([dtdev voltageLoadConfiguration:file error:&error])
                {
                    [dtdev voltageGenerateNewKey:&error];
                    [self displayAlert:@"Success" message:@"Settings has been set and new key is currently generating, please wait for couple of minutes for generation to finish. You can always check the status"];
                }else
                {
                    [self displayAlert:@"Voltage error" message:[NSString stringWithFormat:@"voltageLoadConfiguration failed: %@",error.localizedDescription]];
                }
            }
            if(indexPath.row==3)
            {//load some defaults
                NSData *file=[NSData dataWithContentsOfFile:[[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"LINEA_VOLTAGE_PARAMS_TEST_2_S2.0.0.0.BIN"]];
                
                if([dtdev voltageLoadConfiguration:file error:&error])
                {
                    [dtdev voltageGenerateNewKey:&error];
                    [self displayAlert:@"Success" message:@"Settings has been set and new key is currently generating, please wait for couple of minutes for generation to finish. You can always check the status"];
                }else
                {
                    [self displayAlert:@"Voltage error" message:[NSString stringWithFormat:@"voltageLoadConfiguration failed: %@",error.localizedDescription]];
                }
            }
            break;
            
        case SEC_MISC:
            if(indexPath.row==0)
            {//EXTRS test
                if([dtdev getSupportedFeature:FEAT_EXTERNAL_SERIAL_PORT error:nil]==FEAT_SUPPORTED)
                {
                    bool r;
                    r=[dtdev extOpenSerialPort:1 baudRate:9600 parity:PARITY_NONE dataBits:DATABITS_8 stopBits:STOPBITS_1 flowControl:FLOW_NONE error:&error];
                    
                    NSMutableData *toSend=[NSMutableData data];
                    for(int i=0;i<255;i++)
                    {
                        uint8_t b=0x30+i%10;
                        [toSend appendBytes:&b length:1];
                    }
                    if(r)
                    {
                        r=[dtdev extWriteSerialPort:1 data:toSend error:&error];
                        if(r)
                        {
                            NSData *rcv=[dtdev extReadSerialPort:1 length:(int)toSend.length timeout:1 error:&error];
                            if(rcv && rcv.length==toSend.length && [rcv isEqualToData:toSend])
                            {
                                NSLog(@"R(%d): %@",(int)rcv.length,rcv);
                                r=true;
                            }else
                            {
                                [self displayAlert:@"SerErr Read" message:[NSString stringWithFormat:@"Received bytes: %d",rcv?(int)rcv.length:0]];
                                r=false;
                            }
                        }else
                        {
                            [self displayAlert:@"SerErr Write" message:error.localizedDescription];
                            r=false;
                        }
                        
                        [dtdev extCloseSerialPort:1 error:&error];
                    }
                    if(r)
                        [self displayAlert:@"Success" message:@"Test complete"];
                }
            }
#ifdef LABEL_DEMO
            if(indexPath.row==1)
            {
                NSDate *date=[NSDate date];
                NSData *file=[NSData dataWithContentsOfFile:[[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"label-203.txt"]];
                file=preparseLabel(file);
                NSData *cmdRoll=[@"^XA\r\n^MNN\r\n^XZ\r\n~SD15\r\n" dataUsingEncoding:NSASCIIStringEncoding];
                [[dtdev btOutputStream] write:cmdRoll.bytes maxLength:cmdRoll.length];
                [[dtdev btOutputStream] write:file.bytes maxLength:file.length];
                [self displayAlert:@"Complete" message:[NSString stringWithFormat:@"Send complete in %.02f",-[date timeIntervalSinceNow]]];
            }
            if(indexPath.row==2)
            {
                NSDate *date=[NSDate date];
                NSData *file=[NSData dataWithContentsOfFile:[[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"label-203.txt"]];
                file=preparseLabel(file);
                NSData *cmdLabel=[@"^XA\r\n^MNM\r\n^XZ\r\n~SD15\r\n" dataUsingEncoding:NSASCIIStringEncoding];
                [[dtdev btOutputStream] write:cmdLabel.bytes maxLength:cmdLabel.length];
                [[dtdev btOutputStream] write:file.bytes maxLength:file.length];
                [self displayAlert:@"Complete" message:[NSString stringWithFormat:@"Send complete in %.02f",-[date timeIntervalSinceNow]]];
            }
#endif
            break;
	}
}

-(void)testVoltage
{
    NSError *error;
    
    
    if(![dtdev voltageGenerateNewKey:&error])
        [self displayAlert:@"Voltage error" message:[NSString stringWithFormat:@"voltageGenerateNewKey failed: %@",error.localizedDescription]];
    
    
}




- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	UITableViewCell *cell=[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"SettingsCell"];
	
	switch ([indexPath indexAtPosition:0])
	{
		case SEC_GENERAL:
			if(settings_values[indexPath.row])
				cell.accessoryType=UITableViewCellAccessoryCheckmark;
			else
				cell.accessoryType=UITableViewCellAccessoryNone;
			[cell.textLabel setText:NSLocalizedString(settings[indexPath.row],nil)];
			break;
            
		case SEC_BARCODE_MODE:
			if(scanMode==indexPath.row)
				cell.accessoryType=UITableViewCellAccessoryCheckmark;
			else
				cell.accessoryType=UITableViewCellAccessoryNone;
			[cell.textLabel setText:NSLocalizedString(scan_modes[indexPath.row],nil)];
			break;
            
		case SEC_LEDS:
            cell.accessoryType=UITableViewCellAccessoryNone;
            [cell.textLabel setText:NSLocalizedString(led_names[indexPath.row],nil)];
            cell.textLabel.textColor=led_colors[indexPath.row];
			break;
            
		case SEC_BT_CLIENT:
			if(indexPath.row==0)
            {
                [cell.textLabel setText:NSLocalizedString(@"Discover devices",nil)];
            }else
            {
                [cell.textLabel setText:[btDevices objectAtIndex:(indexPath.row-1)*2+1]];
                [cell.detailTextLabel setText:[btDevices objectAtIndex:(indexPath.row-1)*2]];
                
                NSLog(@"dtdev.btConnectedDevices: %@",dtdev.btConnectedDevices);

                if([dtdev.btConnectedDevices containsObject:[btDevices objectAtIndex:(indexPath.row-1)*2]])
                    cell.accessoryType=UITableViewCellAccessoryCheckmark;
                else
                    cell.accessoryType=UITableViewCellAccessoryNone;
            }
			break;

        case SEC_BT_SERVER:
			if(indexPath.row==0)
            {
                if(btListening)
                {
                    [cell.textLabel setText:NSLocalizedString(@"Stop Server",nil)];
                    cell.accessoryType=UITableViewCellAccessoryCheckmark;
                }else
                {
                    [cell.textLabel setText:NSLocalizedString(@"Start Server",nil)];
                    cell.accessoryType=UITableViewCellAccessoryNone;
                }
            }else
            {
                NSLog(@"dtdev.btConnectedDevices: %@",dtdev.btConnectedDevices);
                [cell.textLabel setText:[btConnectedDevices objectAtIndex:indexPath.row-1]];
                [cell.detailTextLabel setText:@"Connected"];
                
                cell.accessoryType=UITableViewCellAccessoryCheckmark;
            }
			break;

		case SEC_TCP_DEVICES:
			if(indexPath.row==0)
            {
                if(dtdev.tcpConnectedDevices.count>0)
                    [cell.textLabel setText:NSLocalizedString(@"Disconnect from device",nil)];
                else
                    [cell.textLabel setText:NSLocalizedString(@"Connect to device",nil)];
            }else
            {
                NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
                
                UITextField *textField = [[UITextField alloc] initWithFrame:CGRectMake(0, 0, 200, 21)];
                textField.placeholder = @"Address";
                textField.text = [prefs objectForKey:@"tcpAddress"];
                if(textField.text.length<=0)
                {
                    textField.text=@"192.168.11.110";
                    [prefs setObject:textField.text forKey:@"tcpAddress"];
                    [prefs synchronize];
                }
                textField.tag = indexPath.row;
                textField.delegate = self;
                cell.accessoryView = textField;
                if(dtdev.tcpConnectedDevices.count>0)
                    cell.accessoryType=UITableViewCellAccessoryCheckmark;
                else
                    cell.accessoryType=UITableViewCellAccessoryNone;
            }
			break;
            
		case SEC_FIRMWARE_UPDATE:
            switch (indexPath.row)
            {
                case TARGET_DEVICE:
                    [[cell textLabel] setText:NSLocalizedString(@"Update device firmware",nil)];
                    break;
                case TARGET_BARCODE:
                    [[cell textLabel] setText:NSLocalizedString(@"Update barcode firmware",nil)];
                    break;
            }
			break;
            
		case SEC_VOLTAGE:
            cell.accessoryType=UITableViewCellAccessoryNone;
            [cell.textLabel setText:voltage_settings[indexPath.row]];
			break;

		case SEC_MISC:
            cell.accessoryType=UITableViewCellAccessoryNone;
            [cell.textLabel setText:NSLocalizedString(misc_operations[indexPath.row],nil)];
			break;
	}
	return cell;	
}

- (void)viewWillAppear:(BOOL)animated
{
	NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    
	btDevices=[[prefs arrayForKey:@"bluetoothDevices"] mutableCopy];
    if(!btDevices)
        btDevices=[[NSMutableArray alloc] init];
    [settingsTable reloadData];
    
	//update display according to current connection state
	[self connectionState:dtdev.connstate];
}


- (void)viewDidLoad
{
    [super viewDidLoad];
    
	dtdev=[DTDevices sharedDevice];
	[dtdev addDelegate:self];
    
    led_colors[0]=[UIColor greenColor];
    led_colors[1]=[UIColor redColor];
    led_colors[2]=[UIColor orangeColor];
    led_colors[3]=[UIColor blueColor];
}

@end
