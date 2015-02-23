#import "EMSRCryptoViewController.h"
#import "NSDataCrypto.h"
#import <CommonCrypto/CommonDigest.h>
#import "dukpt.h"

@implementation EMSRCryptoViewController

-(BOOL)textFieldShouldEndEditing:(UITextField *)theTextField;
{
	return YES;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField;
{
	[textField resignFirstResponder];
	return YES;
}

-(BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    //limit the size to 32
    int limit = 32;
    return !([textField.text length]>=limit && [string length] > range.length);
}

-(void)displayAlert:(NSString *)title message:(NSString *)message
{
	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title message:message delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil, nil];
	[alert show];
}

-(IBAction)setActiveHead:(id)sender
{
    NSError *error;
    if(![dtdev emsrSetActiveHead:(int)emsrActiveHead.selectedSegmentIndex error:&error])
        ERRMSG(@"Operation failed!");
}

/**
 Loads initial key in plain text or changes existing key. Keys in plain text can be loaded only once,
 on every subsequent key change, they needs to be encrypted with KEY_EH_AES256_LOADING.
 
 KEY_EH_AES256_LOADING can be used to change all the keys in the head except for the TMK, and KEY_AES256_LOADING
 can be loaded in plain text the first time too.
 */
NSData *emsrGenerateKeyData(int keyID, int keyVersion, const uint8_t *keyData, size_t keyKength, const uint8_t aes256EncryptionKey[32])
{
    uint8_t data[256];
    int index=0;
	data[index++]=0x2b;
	//key to encrypt with, either KEY_AES256_LOADING or 0xff to use plain text
	data[index++]=aes256EncryptionKey?KEY_EH_AES256_LOADING:0xff;
    data[index++]=keyID; //key to set
    data[index++]=keyVersion>>24; //key version
    data[index++]=keyVersion>>16; //key version
    data[index++]=keyVersion>>8; //key version
    data[index++]=keyVersion; //key version
    int keyStart=index;
    memmove(&data[index],keyData,keyKength); //key data
    index+=keyKength;
    CC_SHA256(data,index,&data[index]); //calculate sha256 on the previous packet
	index+=CC_SHA256_DIGEST_LENGTH;
	//encrypt the data if using the encryption key
	if(aes256EncryptionKey)
	{
        NSData *encryptionKey=[NSData dataWithBytes:aes256EncryptionKey length:32];
        NSData *toEncrypt=[NSData dataWithBytes:&data[keyStart] length:index-keyStart];
        NSData *encrypted=[toEncrypt AESEncryptWithKey:encryptionKey]; //encrypt only the key, without the params before it
        
        //store the encryptd data back into the packet
        [encrypted getBytes:&data[keyStart]];
	}
    return [NSData dataWithBytes:data length:index];
}

//prepares and loads a key
//NOTE!!!! There can't be a key with duplicate value, this is PCI requirement!
-(bool)loadKeyID:(int)keyID keyData:(NSData *)keyData keyVersion:(int)keyVersion
{
    [self setActiveHead:nil];
    
	NSData *kekData=([newAES256KeyEncryptionKey.text length]>0)?[newAES256KeyEncryptionKey.text dataUsingEncoding:NSASCIIStringEncoding]:nil;
    NSError *error;
    
    //check to see if there was already a key in that slot, in this case an keyEncryptionKey should be provided
    int keyVer;
    [dtdev emsrGetKeyVersion:keyID keyVersion:&keyVer error:nil];
    if(keyVer<=0)
        kekData=nil;
    if(keyVer>0 && !kekData)
    {
        ERRMSG(NSLocalizedString(@"Key Encryption Key must be provided!",nil));
        return false;
    }
    
    //format the key to load it, optionally encrypt with KEK
    NSData *generatedKeyData=emsrGenerateKeyData(keyID, keyVersion, keyData.bytes, keyData.length, kekData!=nil?kekData.bytes:nil);
    //get the key name, for display purposers
    NSString *keyName=[EMSRKeysInfo keyNameByID:keyID];
    //try to load the key in the slot
    if([dtdev emsrLoadKey:generatedKeyData error:&error])
    {
        [self displayAlert:@"Success!" message:[NSString stringWithFormat:@"Key %@ loaded successfully!",keyName]];
    }else
    {
        NSString *msg=[NSString stringWithFormat:@"Key %@ failed!",keyName];
        ERRMSG(msg);
        return false;
    }
    return true;
}

-(IBAction)setAES256KeyEncryptionKey:(id)sender
{
	if([newAES256KeyEncryptionKey.text length]!=32 || ([oldAES256KeyEncryptionKey.text length]>0 && [oldAES256KeyEncryptionKey.text length]!=32))
	{
		[self displayAlert:NSLocalizedString(@"Wrong key",nil) message:NSLocalizedString(@"Key should be 32 symbols long",nil)];
		return;
	}
	NSData *newKeyData=[newAES256KeyEncryptionKey.text dataUsingEncoding:NSASCIIStringEncoding];
    
    if([self loadKeyID:KEY_EH_AES256_LOADING keyData:newKeyData keyVersion:[newAES256KeyEncryptionKeyVersion.text intValue]])
    {
        //copy the key to the "old key" so you can change easily
        oldAES256KeyEncryptionKey.text=newAES256KeyEncryptionKey.text;
    }
}

-(IBAction)setAES256EncryptionKey:(id)sender
{
	if([newAES256EncryptionKey.text length]!=32)
	{
		[self displayAlert:NSLocalizedString(@"Wrong key",nil) message:NSLocalizedString(@"Key should be 32 symbols long",nil)];
		return;
	}
	NSData *newKeyData=[newAES256EncryptionKey.text dataUsingEncoding:NSASCIIStringEncoding];
    [self loadKeyID:KEY_EH_AES256_ENCRYPTION1 keyData:newKeyData keyVersion:[newAES256EncryptionKeyVersion.text intValue]];
}

-(IBAction)setAES128EncryptionKey:(id)sender;
{
    //load a sample AES128 keys. although AES128 is 16 bytes, it needs to be padded to 32 with anything
    [self loadKeyID:KEY_EH_AES128_ENCRYPTION1 keyData:[@"11111111111111110000000000000000" dataUsingEncoding:NSASCIIStringEncoding] keyVersion:2];
    [self loadKeyID:KEY_EH_AES128_ENCRYPTION2 keyData:[@"11111111111111120000000000000000" dataUsingEncoding:NSASCIIStringEncoding] keyVersion:2];
    [self loadKeyID:KEY_EH_AES128_ENCRYPTION3 keyData:[@"11111111111111130000000000000000" dataUsingEncoding:NSASCIIStringEncoding] keyVersion:2];
}

-(bool)setDUKPTEncryptionKey:(int)keyID version:(int)version ipek:(NSData *)ipek ksn:(NSData *)ksn
{
    uint8_t dukptKey[16+10+6]={0};
    memcpy(&dukptKey[0],ipek.bytes,ipek.length);
    memcpy(&dukptKey[16],ksn.bytes,ksn.length);
    
	NSData *newKeyData=[NSData dataWithBytes:dukptKey length:sizeof(dukptKey)];
    return [self loadKeyID:keyID keyData:newKeyData keyVersion:version];
}


const uint8_t DUKPT_BDK[16]={0x01,0x23,0x45,0x67,0x89,0xAB,0xCD,0xEF,0xFE,0xDC,0xBA,0x98,0x76,0x54,0x32,0x10};
const uint8_t DUKPT_KSN1[10]={0xFF,0xFF,0x98,0x76,0x54,0x32,0x10,0x00,0x00,0x00};
const uint8_t DUKPT_KSN2[10]={0xFF,0xFF,0x98,0x76,0x54,0x32,0x11,0x00,0x00,0x00};
-(IBAction)setDUKPTEncryptionKey:(id)sender
{
    [self setActiveHead:nil];
    
    //load 2 same dukpt keys here, derive them given test bdk and ksn
    uint8_t ipek[16]; //the device specific ipek... that would be if the ksn changes per device based on the serial number or something else, it will generate fixed keys in this case
    dukptDeriveIPEK(DUKPT_BDK, DUKPT_KSN1, ipek);
    
    //load on position 1
    [self setDUKPTEncryptionKey:KEY_EH_DUKPT_MASTER1 version:2 ipek:[NSData dataWithBytes:ipek length:sizeof(ipek)] ksn:[NSData dataWithBytes:DUKPT_KSN1 length:sizeof(DUKPT_KSN1)]];
    EMSRDeviceInfo *emsrInfo=[dtdev emsrGetDeviceInfo:nil];
    if(emsrInfo.firmwareVersion>=230)
    {
        dukptDeriveIPEK(DUKPT_BDK, DUKPT_KSN2, ipek);
        //if the emsr has version 2.30+, then we have more slots to load dukpt keys to
        [self setDUKPTEncryptionKey:KEY_EH_DUKPT_MASTER2 version:3 ipek:[NSData dataWithBytes:ipek length:sizeof(ipek)] ksn:[NSData dataWithBytes:DUKPT_KSN2 length:sizeof(DUKPT_KSN2)]];
    }
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

-(IBAction)getEMSRInfo:(id)sender
{
    [self setActiveHead:nil];
    
    NSError *error=nil;
    
    EMSRDeviceInfo *info=[dtdev emsrGetDeviceInfo:&error];
    if(info)
    {
        NSMutableString *log=[NSMutableString string];
        [log appendFormat:@"Ident: %@\nFW version: %@, security: %@\nSerial: %@\n",
         info.ident, info.firmwareVersionString, info.securityVersionString, info.serialNumberString];
        
        EMSRKeysInfo *keys=[dtdev emsrGetKeysInfo:&error];
        if(keys)
        {
//            [log appendFormat:@"AES enc key version: %d\n",[keys getKeyVersion:KEY_ENCRYPTION]];
//            [log appendFormat:@"AES auth key version: %d\n",[keys getKeyVersion:KEY_AUTHENTICATION]];
//            [log appendFormat:@"AES load key version: %d\n",[keys getKeyVersion:KEY_EH_AES256_LOADING]];
//            [log appendFormat:@"DUKPT key version: %d\n",[keys getKeyVersion:KEY_EH_DUKPT_MASTER]];
//            [log appendFormat:@"TMK key version: %d\n",[keys getKeyVersion:KEY_EH_TMK_AES]];
            
            [log appendFormat:@"\nTampered: %@\n",keys.tampered?@"TRUE":@"FALSE"];
            
            [log appendFormat:@"\nLoaded Keys:\n"];
            for (EMSRKey *key in keys.keys)
            {
                if(key.keyVersion)
                    [log appendFormat:@"- %@ ver: %d\n",key.keyName,key.keyVersion];
            }
            
            [log appendFormat:@"\nEmpty Keys:\n"];
            for (EMSRKey *key in keys.keys)
            {
                if(key.keyVersion==0)
                    [log appendFormat:@"- %@\n",key.keyName];
            }
        }
        [self displayAlert:@"EMSR Info" message:log];
    }
    if(error)
        ERRMSG(NSLocalizedString(@"Operation failed!",nil));
}

-(IBAction)enterMSData:(id)sender;
{
    [progressViewController viewWillAppear:FALSE];
    [progressViewController updateText:@"Please use the pinpad to complete the operation..."];
    [mainTabBarController.view addSubview:progressViewController.view];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSError *error;
        bool result=true;
        result=[dtdev ppadMagneticCardEntry:LANG_ENGLISH timeout:60 error:&error];
        dispatch_async(dispatch_get_main_queue(), ^{
            if(!result)
            {
                ERRMSG(NSLocalizedString(@"Operation failed!",nil));
            }
            [progressViewController.view removeFromSuperview];
        });
    });
}

-(IBAction)enterPIN:(id)sender;
{
    [progressViewController viewWillAppear:FALSE];
    [progressViewController updateText:@"Please use the pinpad to complete the operation..."];
    [mainTabBarController.view addSubview:progressViewController.view];
    
    //Ask for pin, display progress dialog, the pin result will be done via notification
    NSError *error;
    bool result=[dtdev ppadStartPINEntry:0 startY:2 timeout:30 echoChar:'*' message:[NSString stringWithFormat:@"Amount: %.2f\nEnter PIN:",12.34] error:&error];
    if(!result)
    {
        [progressViewController.view removeFromSuperview];
        ERRMSG(NSLocalizedString(@"Operation failed!",nil));
    }
}


static NSString * FORMATS[]={
    @"AES 256",
    @"IDTECH 3",
    @"RSA-OAEP",
    @"Voltage",
    @"Magtek",
    @"AES 128",
    @"PPAD DUKPT",
    @"PPAD 3DES",
    @"IDTECH 3 (AES128)",
    @"Magtek (AES128)",
};

static int FORMAT_IDS[]={
    ALG_EH_AES256,
    ALG_EH_IDTECH,
    ALG_EH_RSA_OAEP,
    ALG_EH_VOLTAGE,
    ALG_EH_MAGTEK,
    ALG_EH_AES128,
    ALG_PPAD_DUKPT,
    ALG_PPAD_3DES_CBC,
    ALG_EH_IDTECH_AES128,
    ALG_EH_MAGTEK_AES128,
};

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSString *)tableView:(UITableView *)aTableView titleForHeaderInSection:(NSInteger)section {
	return NSLocalizedString(@"MS Encryption Format",nil);
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return sizeof(FORMATS)/sizeof(NSString *);
}

-(bool)updateEMSRAlgorithm:(NSError **)error
{
    [self setActiveHead:nil];
    
    int emsrAlgorithm=[[[NSUserDefaults standardUserDefaults] objectForKey:@"emsrAlgorithm"] intValue];
    if(emsrAlgorithm<=ALG_EH_AES256)
        emsrAlgorithm=ALG_EH_AES256;
    
    NSDictionary *params=nil;
    int keyID=-1; //if -1, automatically selects the first available key for the specified algorithm
    
    if(emsrAlgorithm==ALG_EH_VOLTAGE)
    {
        params=[NSDictionary dictionaryWithObjectsAndKeys:@"SPE",@"encryption",@"0123456",@"merchantID", nil];
    }
    if(emsrAlgorithm==ALG_EH_IDTECH)
    {//Just a demo how to select key
        keyID=KEY_EH_DUKPT_MASTER1;
    }
    if(emsrAlgorithm==ALG_EH_MAGTEK)
    {//Just a demo how to select key
        keyID=KEY_EH_DUKPT_MASTER1;
    }
    if(emsrAlgorithm==ALG_EH_AES128)
    {//Just a demo how to select key
        keyID=KEY_EH_AES128_ENCRYPTION1;
    }
    if(emsrAlgorithm==ALG_EH_AES256)
    {//Just a demo how to select key
        keyID=KEY_EH_AES256_ENCRYPTION1;
    }
    if(emsrAlgorithm==ALG_PPAD_DUKPT)
    {//Just a demo how to select key, in the pinpad, the dukpt keys are 0 and 1
        keyID=0;
    }
    if(emsrAlgorithm==ALG_PPAD_3DES_CBC)
    {//Just a demo how to select key, in the pinpad, the 3des keys are from 1 to 49, key 1 is automatically selected if you pass 0
        //the key loaded needs to be data encryption 3des type, or card will not read. Assuming such is loaded on position 2:
        keyID=2;
    }
    if(emsrAlgorithm==ALG_EH_IDTECH_AES128)
    {//Just a demo how to select key
        keyID=KEY_EH_DUKPT_MASTER1;
    }
    if(emsrAlgorithm==ALG_EH_MAGTEK_AES128)
    {//Just a demo how to select key
        keyID=KEY_EH_DUKPT_MASTER1;
    }
    
    if(dtdev.connstate==CONN_CONNECTED && ![dtdev emsrSetEncryption:emsrAlgorithm keyID:keyID params:params error:error])
        return false;
    return true;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSError *error;
    
    [[NSUserDefaults standardUserDefaults] setValue:[NSNumber numberWithInt:FORMAT_IDS[indexPath.row]] forKey:@"emsrAlgorithm"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    if(![self updateEMSRAlgorithm:&error])
    {
        ERRMSG(NSLocalizedString(@"Operation failed!",nil));
    }
    
    [emsrAlgorithmTable reloadData];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	UITableViewCell *cell=[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"CryptoCell"];
	
	NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    int emsrAlgorithm=[[prefs objectForKey:@"emsrAlgorithm"] intValue];
    
    cell.accessoryType=UITableViewCellAccessoryNone;
    for(int i=0;i<sizeof(FORMAT_IDS)/sizeof(FORMAT_IDS[0]);i++)
        if(FORMAT_IDS[indexPath.row]==emsrAlgorithm)
        {
            cell.accessoryType=UITableViewCellAccessoryCheckmark;
            break;
        }
    
    [cell.textLabel setText:FORMATS[indexPath.row]];
	return cell;
}


-(void)viewWillAppear:(BOOL)animated
{
}

-(void)viewWillDisappear:(BOOL)animated
{
}

-(void)viewDidLoad
{
    [self.view addSubview:cryptoView];
    ((UIScrollView *)self.view).contentSize=CGSizeMake(cryptoView.frame.size.width, cryptoView.frame.size.height);
	
	//we don't care about dtdev notifications here, so won't add the delegate
	dtdev=[DTDevices sharedDevice];
    [super viewDidLoad];
}



@end
