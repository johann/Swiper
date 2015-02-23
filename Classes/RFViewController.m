#import "RFViewController.h"
#import "bertlv.h"

@implementation RFViewController

-(void)displayAlert:(NSString *)title message:(NSString *)message
{
	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title message:message delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil, nil];
	[alert show];
}

#define RF_COMMAND(operation,c) {if(!c){[self displayAlert:@"Operatin failed!" message:[NSString stringWithFormat:@"%@ failed, error %@, code: %d",operation,error.localizedDescription,(int)error.code]]; return;} }

static BOOL stringToHex(NSString *str, uint8_t *data, int length)
{
    NSString *t=[[str stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] lowercaseString];
    if([t length]<(length*3-1))
        return FALSE;
    for(int i=0;i<[t length];i++)
    {
        char c=[t characterAtIndex:i];
        if((c<'0' || c>'9') && (c<'a' || c>'f') && c!=' ')
            return FALSE;
    }
        
    for(int i=0;i<length;i++)
    {
        char c=[t characterAtIndex:i*3];
        if(c>='a')
            data[i]=c-'a'+10;
        else
            data[i]=c-'0';
        data[i]<<=4;
        
        c=[t characterAtIndex:i*3+1];
        if(c>='a')
            data[i]|=c-'a'+10;
        else
            data[i]|=c-'0';
    }
    return true;
}

static NSString *dataToString(NSString * label, NSData *data)
{
    return hexToString(label, data.bytes, data.length);
}

static NSString *hexToString(NSString * label, const void *data, size_t length)
{
	const char HEX[]="0123456789ABCDEF";
	char s[20000];
	for(int i=0;i<length;i++)
	{
		s[i*3]=HEX[((uint8_t *)data)[i]>>4];
		s[i*3+1]=HEX[((uint8_t *)data)[i]&0x0f];
		s[i*3+2]=' ';
	}
	s[length*3]=0;
	
    if(label)
        return [NSString stringWithFormat:@"%@(%d): %s",label,(int)length,s];
    else
        return [NSString stringWithCString:s encoding:NSASCIIStringEncoding];
}

-(IBAction)clear:(id)sender
{
    [logView setText:@""];
}

-(void)rfCardRemoved:(int)cardIndex
{
    [logView setText:[logView.text stringByAppendingString:@"\nCard removed"]];
    logView.backgroundColor=[UIColor colorWithRed:0 green:0 blue:1 alpha:0.3];
}

#define CHECK_RESULT(description,result) if(result){[log appendFormat:@"%@: SUCCESS\n",description]; NSLog(@"%@: SUCCESS",description);} else {[log appendFormat:@"%@: FAILED (%@)\n",description,error.localizedDescription]; NSLog(@"%@: FAILED (%@)\n",description,error.localizedDescription); }
-(void)payCardDemo:(int)cardIndex log:(NSMutableString *)log
{
#define READ_RECORD(recNum, sfi) [dtdev iso14APDU:cardIndex cla:0x00 ins:0xB2 p1:recNum p2:(sfi<<3)|0x04 data:nil apduResult:&apduResult error:&error];
#define SELECT_RECORD(file,len) [dtdev iso14APDU:cardIndex cla:0x00 ins:0xA4 p1:0x04 p2:0x00 data:[NSData dataWithBytes:file length:len] apduResult:&apduResult error:&error];
#define GET_PROCESSING_OPTIONS(pdol,len) [dtdev iso14APDU:cardIndex cla:0x80 ins:0xA8 p1:0x00 p2:0x00 data:[NSData dataWithBytes:pdol length:len] apduResult:&apduResult error:&error];
    NSError *error;
    char appName[128]={0};
    char pan[128]={0};
    char name[128]={0};
    int expMonth=0;
    int expYear=0;
    
    
    NSData *ats=[dtdev iso14GetATS:cardIndex error:&error];
    if(ats)
        [log appendFormat:@"ATS: %@\n",hexToString(nil,ats.bytes,ats.length)];
    
    static const uint8_t AIDs[][7]=
    {
        {0xA0,0x00,0x00,0x00,0x03,0x10,0x10},// "VISA CREDIT"));
        {0xA0,0x00,0x00,0x00,0x03,0x20,0x10},// "VISA ELECTRON"));
        {0xA0,0x00,0x00,0x00,0x03,0x30,0x10},// "VISA INTERLINK"));
        {0xA0,0x00,0x00,0x00,0x03,0x40,0x10},// "VISA"));
        {0xA0,0x00,0x00,0x00,0x03,0x50,0x10},// "VISA"));
        {0xA0,0x00,0x00,0x00,0x03,0x80,0x10},// "VISA PLUS"));
        {0xA0,0x00,0x00,0x00,0x04,0x10,0x10},// "MASTERCARD CREDIT"));
        {0xA0,0x00,0x00,0x00,0x04,0x20,0x10},// "MASTERCARD"));
        {0xA0,0x00,0x00,0x00,0x04,0x30,0x10},// "MASTERCARD"));
        {0xA0,0x00,0x00,0x00,0x04,0x30,0x60},// "MAESTRO"));
        {0xA0,0x00,0x00,0x00,0x04,0x40,0x10},// "MASTERCARD"));
        {0xA0,0x00,0x00,0x00,0x04,0x50,0x10},// "MASTERCARD"));
        {0xA0,0x00,0x00,0x00,0x04,0x60,0x00},// "CIRRUS"));
        {0xA0,0x00,0x00,0x00,0x25,0x00,0x00},// "AMEX"));
        {0xA0,0x00,0x00,0x01,0x41,0x00,0x01},// "PAGOBANCOMAT"));
        {0xA0,0x00,0x00,0x02,0x28,0x10,0x10},// "SAMA"));
        {0xA0,0x00,0x00,0x02,0x77,0x10,0x10},// "INTERAC"));
    };
    
    uint16_t apduResult;
    uint8_t apdu[256];
    tlv_t *t=0;
    //select application
    NSData *appData=nil;
    
    //try PSE method first
    //try PSE first
    const char *PSE_NAME="2PAY.SYS.DDF01";
    NSData *pseData=SELECT_RECORD((const uint8_t *)PSE_NAME,strlen(PSE_NAME));
    if(pseData && apduResult==0x9000)
    {
        t=tlvFind1(pseData.bytes,pseData.length,0x4F); //AID
        if(t)
        {
            appData=SELECT_RECORD(t->data,t->length);
        }
    }else
    {//go for application
        //select application
        for(int i=0;i<sizeof(AIDs)/sizeof(AIDs[0]);i++)
        {
            appData=SELECT_RECORD(AIDs[i],sizeof(AIDs[i]));
            if(!appData)
                return;
            if(apduResult==0x9000)
                break;
        }
    }
    
    if(!appData || apduResult!=0x9000)
    {
        [log appendFormat:@"Unknown Application!\n"];
        return;
    }
    
    //get name
    t=tlvFind1(appData.bytes,appData.length,0x50); //app name
    if(t)
    {
        memcpy(appName,t->data,t->length);
        appName[t->length]=0;
    }
    
    //initial application processing
    //pdol
    t=tlvFind1(appData.bytes,appData.length,0x9F38); //PDOL
    int tagLen=0;
    if(t)
    {
        //parse pdol structure
        uint8_t tlvData[256]={0};
        //dummy data
        int index=0;
        
        for(int i=0;i<t->length;)
        {
            int tag=0;
            
            if((t->data[i]&0x1F)==0x1F)
            {//2byte tag
                tag=(t->data[i++]<<8);
            }
            tag|=t->data[i++];
            
            int length=0;
            if(t->data[i]&0x80)
            {//double
                length=((t->data[i++]&0x7f)<<8);
            }
            length|=t->data[i++];
            
            if(tag==0x9f66)
            {
                tlvData[index]=(1<<7)|(0<<5)|(1<<4)|(1<<2)|(0<<1);
            }
            if(tag==0x9F37)
            {
                for(int i=0;i<length;i++)
                    tlvData[index+i]=0x51;
            }
            index+=length;
        }
        
        tagLen=tlvMakeTag(0x83,tlvData,index,apdu);
    }else
        tagLen=tlvMakeTag(0x83,0,0,apdu);
    NSData *processingData=GET_PROCESSING_OPTIONS(apdu,tagLen);
    if(!processingData || apduResult!=0x9000)
        return;
    
    uint8_t aflData[256];
    size_t aflDataLen;
    t=tlvFind1(processingData.bytes,processingData.length,0x94); //AFL
    if(t)
    {
        aflDataLen=t->length;
        memcpy(aflData,t->data,aflDataLen);
    }else
    {
        aflDataLen=processingData.length-1-1-2;
        memcpy(aflData,processingData.bytes+1+1+2,aflDataLen);
    }
    
    //loop through records and extract info
    for(int i=0;i<aflDataLen;)
    {
        int sfi=aflData[i++]>>3;
        int srec=aflData[i++];
        int erec=aflData[i++];
        i++; //nrec
        for (; srec <= erec; srec++)
        {
            NSData *recordData=READ_RECORD(srec,sfi);
            if(!recordData)
                return;
            if(apduResult!=0x9000)
                continue;
            
            //track 1
            t=tlvFind1(recordData.bytes,recordData.length,0x56);
            if(t)
            {
                char *tmp=(char *)&t->data[1];
                char *divider=strchr(tmp,'^');
                *divider=0;
                strcpy(pan,tmp);
                
                tmp=divider+1;
                divider=strchr(tmp,'^');
                *divider=0;
                strcpy(name,tmp);
                
                divider++;
                expYear=2000+(divider[0]-'0')*10+(divider[1]-'0');
                expMonth=(divider[2]-'0')*10+(divider[3]-'0');
            }
            
            //track 2 equivalent data
            t=tlvFind1(recordData.bytes,recordData.length,0x57);
            if(t)
            {
                static char tmp[256];
                tmp[0]=0;
                for(int ti=0;ti<t->length;ti++)
                    sprintf(&tmp[strlen(tmp)],"%02X",t->data[ti]);
                char *divider=strchr(tmp,'D');
                *divider=0;
                strcpy(pan,tmp);
                
                divider++;
                expYear=2000+(divider[0]-'0')*10+(divider[1]-'0');
                expMonth=(divider[2]-'0')*10+(divider[3]-'0');
            }
            
            //PAN
            t=tlvFind1(recordData.bytes,recordData.length,0x5A);
            if(t)
            {
                static char tmp[256];
                tmp[0]=0;
                for(int ti=0;ti<t->length;ti++)
                    sprintf(&tmp[strlen(tmp)],"%02X",t->data[ti]);
                if(tmp[strlen(tmp)-1]=='F')
                    tmp[strlen(tmp)-1]=0;
                strcpy(pan,tmp);
            }
            
            //expiration date
            t=tlvFind1(recordData.bytes,recordData.length,0x5F24);
            if(t)
            {
                expYear=2000+(t->data[0]>>4)*10+(t->data[0]&0x0f);
                expMonth=(t->data[1]>>4)*10+(t->data[1]&0x0f);
            }

            //cardholder name
            t=tlvFind1(recordData.bytes,recordData.length,0x5F20);
            if(t)
            {
                memcpy(name,t->data,t->length);
                name[t->length]=0;
            }
        }
    }
    //mask the pan
    for(int i=6;i<strlen(pan)-4;i++)
        pan[i]='*';
    [log appendFormat:@"Card type: %s\n",appName];
    [log appendFormat:@"PAN: %s\n",pan];
    [log appendFormat:@"Name: %s\n",name];
    [log appendFormat:@"Expires: %02d/%04d\n",expMonth,expYear];
}

-(void)rfCardDetected:(int)cardIndex info:(DTRFCardInfo *)info
{
    NSError *error;
    
    [progressViewController viewWillAppear:FALSE];
    [self.view addSubview:progressViewController.view];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
    
    NSMutableString *log=[[NSMutableString alloc] init];
    [log appendFormat:@"%@ card detected\n",info.typeStr];
    [log appendFormat:@"Serial: %@\n",hexToString(nil,info.UID.bytes,info.UID.length)];
    NSDate *d=[NSDate date];
    switch (info.type)
    {
        case CARD_MIFARE_DESFIRE:
        {
            NSData *ats=[dtdev iso14GetATS:cardIndex error:&error];
            CHECK_RESULT(@"ATS",ats);
            if(ats)
                [log appendFormat:@"ATS Data: %@\n",hexToString(nil,ats.bytes,ats.length)];
            
            uint16_t apduResult;
            NSData *apdu=[dtdev iso14APDU:cardIndex cla:0x00 ins:0x00 p1:0x00 p2:0x00 data:nil apduResult:&apduResult error:&error];
            CHECK_RESULT(@"APDU",apdu);
            if(apdu!=nil)
            {
                [log appendFormat:@"APDU Result: %04X\n",apduResult];
                [log appendFormat:@"APDU Data: %@\n",hexToString(nil,apdu.bytes,apdu.length)];
            }
            
            
            break;
        }
            
        case CARD_PICOPASS_15693:
        {
            NSData *r;
            tlv_t *t;
            
            r=[dtdev hidGetSerialNumber:&error];
            CHECK_RESULT(@"Get Serial Number",r);
            t=tlvFind1(r.bytes, r.length, 0x8A);
            if(t)
            {
                [log appendFormat:@"HID Serial: %@\n",hexToString(nil,t->data,t->length)];
            }

            r=[dtdev hidGetVersionInfo:&error];
            CHECK_RESULT(@"Get Version Info",r);
            t=tlvFind1(r.bytes, r.length, 0x8A); //SamResponse
            if(t)
            {
                t=tlvFind1(t->data, t->length, 0x80); //version
                if(t)
                {
                    [log appendFormat:@"Version: %d.%d\n",t->data[0],t->data[1]];
                }
            }
            
            r=[dtdev hidGetContentElement:4 pin:nil rootSoOID:nil error:&error];
            CHECK_RESULT(@"Get Content Element",r);
            t=tlvFind1(r.bytes, r.length, 0x8A); //SamResponse
            if(t)
            {
                t=tlvFind1(t->data, t->length, 0x03); //BitString
                if(t)
                {
                    [log appendFormat:@"Content element: %@\n",hexToString(nil,t->data,t->length)];
                }
            }
            break;
        }
        case CARD_PAYMENT:
            [self payCardDemo:cardIndex log:log];
            break;
        case CARD_MIFARE_MINI:
        case CARD_MIFARE_CLASSIC_1K:
        case CARD_MIFARE_CLASSIC_4K:
        case CARD_MIFARE_PLUS:
        {//16 bytes reading and 16 bytes writing
            //try to authenticate first with default key
            const uint8_t key[]={0xFF,0xFF,0xFF,0xFF,0xFF,0xFF};
            //it is best to store the keys you are going to use once in the device memory, then use mfAuthByStoredKey function to authenticate blocks rahter than having the key in your program
            
            BOOL r=[dtdev mfAuthByKey:cardIndex type:'A' address:8 key:[NSData dataWithBytes:key length:sizeof(key)] error:&error];
            CHECK_RESULT(@"Authenticate",r);
            //try reading a block we authenticated before
            NSData *block=[dtdev mfRead:cardIndex address:8 length:16 error:&error];
            CHECK_RESULT(@"Read block",block);
            if(block)
                [log appendFormat:@"Data: %@\n",hexToString(nil,(uint8_t *)block.bytes,block.length)];
            //write something, be VERY cautious where you write, as you can easily render the card useless forever
            //const uint8_t dataToWrite[16]={0x00,0x01,0x02,0x03,0x04,0x05,0x06,0x07,0x08,0x09,0x0A,0x0B,0x0C,0x0D,0x0E,0x0F};
            //r=[linea mfWrite:cardIndex address:8 data:[NSData dataWithBytes:dataToWrite length:sizeof(dataToWrite)] error:&error];
            //CHECK_RESULT(@"Write block",r);
            break;
        }
        case CARD_MIFARE_ULTRALIGHT:
        {//16 bytes reading, 4 bytes writing
            //try reading a block
            NSData *block=[dtdev mfRead:cardIndex address:8 length:16 error:&error];
            CHECK_RESULT(@"Read block",block);
            if(block)
                [log appendFormat:@"Data: %@\n",hexToString(nil,(uint8_t *)block.bytes,block.length)];
            //write something to the card
            const uint8_t dataToWrite[4]={0x00,0x01,0x02,0x03};
            int r=[dtdev mfWrite:cardIndex address:8 data:[NSData dataWithBytes:dataToWrite length:sizeof(dataToWrite)] error:&error];
            CHECK_RESULT(@"Write block",r);
            break;
        }
        case CARD_MIFARE_ULTRALIGHT_C:
        {//16 bytes reading, 4 bytes writing, authentication may be required
            //try reading a block we authenticated before
            NSData *block=[dtdev mfRead:cardIndex address:8 length:16 error:&error];
            CHECK_RESULT(@"Read block",block);
            if(block)
                [log appendFormat:@"Data: %@\n",hexToString(nil,(uint8_t *)block.bytes,block.length)];
            //write something to the card
            const uint8_t dataToWrite[4]={0x00,0x01,0x02,0x03};
            int r=[dtdev mfWrite:cardIndex address:8 data:[NSData dataWithBytes:dataToWrite length:sizeof(dataToWrite)] error:&error];
            CHECK_RESULT(@"Write block",r);
            break;
        }
        case CARD_ISO15693:
        {//block size is different between cards
            [log appendFormat:@"Block size: %d\n",info.blockSize];
            [log appendFormat:@"Number of blocks: %d\n",info.nBlocks];

            NSData *security=[dtdev iso15693GetBlocksSecurityStatus:cardIndex startBlock:0 nBlocks:16 error:&error];
            CHECK_RESULT(@"Block security status",security);
            if(security)
                [log appendFormat:@"Security status: %@\n",hexToString(nil,(uint8_t *)security.bytes,security.length)];
            
            //write something to the card
            const uint8_t dataToWrite[4]={0x00,0x01,0x02,0x03};
            int r=[dtdev iso15693Write:cardIndex startBlock:0 data:[NSData dataWithBytes:dataToWrite length:sizeof(dataToWrite)] error:&error];
            CHECK_RESULT(@"Write blocks",r);
            [log appendFormat:@"\nTime taken: %.02f\n",-[d timeIntervalSinceNow]];

            //try reading 2 blocks
            NSData *block=[dtdev iso15693Read:cardIndex startBlock:0 length:info.blockSize error:&error];
            CHECK_RESULT(@"Read blocks",block);
            if(block)
                [log appendFormat:@"Data: %@\n",hexToString(nil,(uint8_t *)block.bytes,block.length)];
            
            break;
        }
        case CARD_FELICA:
        {//16 byte blocks for both reading and writing
            //write something to the card
            int r;
            
            //check if the card is FeliCa SmartTag or normal felica
            uint8_t *uid=(uint8_t *)info.UID.bytes;
            if(uid[0]==0x03 && uid[1]==0xFE && uid[2]==0x00 && uid[3]==0x1D)
            {//SmartTag
                //read battery, call this command ALWAYS before communicating with the card
                int battery;
                r=[dtdev felicaSmartTagGetBatteryStatus:cardIndex status:&battery error:&error];
                CHECK_RESULT(@"Get battery",r);
                
                NSString *batteryString=@"Unknown";
                
                switch (battery)
                {
                    case FELICA_SMARTTAG_BATTERY_NORMAL1:
                    case FELICA_SMARTTAG_BATTERY_NORMAL2:
                        batteryString=@"Normal";
                        break;
                    case FELICA_SMARTTAG_BATTERY_LOW1:
                        batteryString=@"Low";
                        break;
                    case FELICA_SMARTTAG_BATTERY_LOW2:
                        batteryString=@"Very low";
                        break;
                }
                
                [log appendFormat:@"Battery status: %@(%d)\n",batteryString,battery];
                
                //perform read/write operations before screen access
                uint8_t dataToWrite[32];
                static uint8_t val=0;
                memset(dataToWrite,val,sizeof(dataToWrite));
                val++;
                r=[dtdev felicaSmartTagWrite:cardIndex address:0x0000 data:[NSData dataWithBytes:dataToWrite length:sizeof(dataToWrite)-5] error:&error];
                CHECK_RESULT(@"Write data",r);
                //try reading 2 blocks
                NSData *block=[dtdev felicaSmartTagRead:cardIndex address:0x0000 length:sizeof(dataToWrite) error:&error];
                CHECK_RESULT(@"Read data",block);
                if(block)
                    [log appendFormat:@"Data: %@\n",hexToString(nil,(uint8_t *)block.bytes,block.length)];
                
//                r=[dtdev felicaSmartTagClearScreen:cardIndex error:&error];
//                CHECK_RESULT(@"Clear screen",r);
//                r=[dtdev felicaSmartTagWaitCompletion:cardIndex error:&error];
//                CHECK_RESULT(@"Wait to complete",r);
//                r=[dtdev felicaSmartTagDisplayLayout:cardIndex layout:1 error:&error];
//                CHECK_RESULT(@"Display layout",r);
                
                UIImage *image=[UIImage imageNamed:@"paypass_logo.bmp"];
                r=[dtdev felicaSmartTagDrawImage:cardIndex image:[UIImage imageNamed:@"paypass_logo.bmp"] topLeftX:(200-image.size.width)/2 topLeftY:(96-image.size.height)/2 drawMode:FELICA_SMARTTAG_DRAW_WHITE_BACKGROUND layout:0 error:&error];
                CHECK_RESULT(@"Draw image",r);
//                UIImage *image=[UIImage imageNamed:@"rftaz.png"];
//                r=[dtdev felicaSmartTagDrawImage:cardIndex image:image topLeftX:(200-image.size.width)/2 topLeftY:0 drawMode:0 layout:0 error:&error];
//                CHECK_RESULT(@"Draw image",r);
//                r=[dtdev felicaSmartTagSaveLayout:cardIndex layout:1 error:&error];
//                CHECK_RESULT(@"Save layout",r);
            }else
            {//Normal
                uint8_t dataToWrite[16]={0x00,0x01,0x02,0x03,0x04,0x05,0x06,0x07,0x08,0x09,0x0A,0x0B,0x0C,0x0D,0x0E,0x0F};
                
                //write 1 block
                r=[dtdev felicaWrite:cardIndex serviceCode:0x0900 startBlock:0 data:[NSData dataWithBytes:dataToWrite length:sizeof(dataToWrite)] error:&error];
                CHECK_RESULT(@"Write blocks",r);
                
                //read 1 block
                NSData *block=[dtdev felicaRead:cardIndex serviceCode:0x0900 startBlock:0 length:sizeof(dataToWrite) error:&error];
                CHECK_RESULT(@"Read blocks",block);
                if(block)
                    [log appendFormat:@"Data: %@\n",hexToString(nil,(uint8_t *)block.bytes,block.length)];
            }
            break;
        }
        case CARD_ST_SRI:
        {//4 byte blocks for both reading and writing
            [log appendFormat:@"Block size: %d\n",info.blockSize];
            [log appendFormat:@"Number of blocks: %d\n",info.nBlocks];
            
            //write something to the card
            const uint8_t dataToWrite[4]={0x00,0x01,0x02,0x03};
            int r=[dtdev stSRIWrite:cardIndex address:8 data:[NSData dataWithBytes:dataToWrite length:sizeof(dataToWrite)] error:&error];
            CHECK_RESULT(@"Write blocks",r);
            [log appendFormat:@"\nTime taken: %.02f\n",-[d timeIntervalSinceNow]];
            
            //try reading 2 blocks
            NSData *block=[dtdev stSRIRead:cardIndex address:8 length:2*info.blockSize error:&error];
            CHECK_RESULT(@"Read blocks",block);
            if(block)
                [log appendFormat:@"Data: %@\n",hexToString(nil,(uint8_t *)block.bytes,block.length)];
        }
    }
 	[progressViewController.view removeFromSuperview];
    
    [log appendFormat:@"\nTime taken: %.02f\n",-[d timeIntervalSinceNow]];
    [log appendFormat:@"Please remove card"];
    [logView setText:log];
    
    if(error)
        logView.backgroundColor=[UIColor colorWithRed:1 green:0 blue:0 alpha:0.3];
    else
        logView.backgroundColor=[UIColor colorWithRed:0 green:1 blue:0 alpha:0.3];
    
    [dtdev rfRemoveCard:cardIndex error:nil];
}

-(void)viewWillAppear:(BOOL)animated
{
}

-(void)viewWillDisappear:(BOOL)animated
{
    [dtdev rfClose:nil];
}

-(void)viewDidAppear:(BOOL)animated
{
    NSError *error;
    logView.backgroundColor=[UIColor colorWithRed:0 green:0 blue:1 alpha:0.3];
    logView.text=@"";
    RF_COMMAND(@"RF Init",[dtdev rfInit:CARD_SUPPORT_PICOPASS_ISO15|CARD_SUPPORT_TYPE_A|CARD_SUPPORT_TYPE_B|CARD_SUPPORT_ISO15|CARD_SUPPORT_STSRI|CARD_SUPPORT_FELICA error:&error]);
//    RF_COMMAND(@"RF Init",[dtdev rfInit:CARD_SUPPORT_PICOPASS_ISO15 error:&error]);
}

-(void)viewDidLoad
{
	dtdev=[DTDevices sharedDevice];
    [dtdev addDelegate:self];
    [super viewDidLoad];
}


@end
