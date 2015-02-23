//Turning this on makes for a much simplified EMV transaction, lot of stuff becomes optional
//and the data is sent as a normal encrypted magnetic card
#define EMV_CARD_EMULATION_MODE

#import "EMV2ViewController.h"
#import "EMVTags.h"
#import "EMVPrivateTags.h"
#import "EMVProcessorHelper.h"
#import "EMVTLV.h"

@implementation EMV2ViewController

static NSData *stringToData(NSString *text)
{
    NSMutableData *d=[NSMutableData data];
    text=[text lowercaseString];
    int count=0;
    uint8_t b=0;
    for(int i=0;i<text.length;i++)
    {
        b<<=4;
        char c=[text characterAtIndex:i];
        if(c<'0' || (c>'9' && c<'a') || c>'f')
        {
            b=0;
            count=0;
            continue;
        }
        if(c>='0' && c<='9')
            b|=c-'0';
        else
            b|=c-'a'+10;
        count++;
        if(count==2)
        {
            [d appendBytes:&b length:1];
            b=0;
            count=0;
        }
    }
    return d;
}

-(void)displayAlert:(NSString *)title message:(NSString *)message
{
	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title message:message delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil, nil];
	[alert show];
}

#define RF_COMMAND(operation,c) {if(!c){[self displayAlert:@"Operatin failed!" message:[NSString stringWithFormat:@"%@ failed, error %@, code: %d",operation,error.localizedDescription,(int)error.code]]; return;} }

-(IBAction)clear:(id)sender
{
    [logView setText:@""];
}

#ifdef EMV_CARD_EMULATION_MODE
//emv2OnTransactionFinished is used as a success/failure flag only
//tags are present if you want to poke with them too, but the data has already
//been sent as magnetic card
-(void)emv2OnTransactionFinished:(NSData *)data;
{
    NSLog(@"emv2OnTransactionFinished: %@",data);
	[progressViewController.view removeFromSuperview];
    if(cancelTimer)
    {
        [cancelTimer invalidate];
        cancelTimer=nil;
    }
    
    if(!data)
    {
        [dtdev emv2Deinitialise:nil];
        [self displayAlert:@"Error" message:@"Transaction could not be completed!"];
        return;
    }
}
#else
-(void)emv2OnApplicationSelection:(NSArray *)applications;
{
    
}
-(void)emv2OnOnlineProcessing:(NSData *)data;
{
    //server response: transaction allowed
    NSData *serverResponse=[TLV encodeTags:@[[TLV tlvWithHexString:@"30 30" tag:TAG_8A_AUTH_RESP_CODE]]];
    NSData *response=[TLV encodeTags:@[[TLV tlvWithHexString:@"01" tag:0xC2],[TLV tlvWithData:serverResponse tag:0xE6]]];
    [dtdev emv2SetOnlineResult:response error:nil];
}
-(void)emv2OnTransactionFinished:(NSData *)data;
{
	[progressViewController.view removeFromSuperview];
    if(cancelTimer)
    {
        [cancelTimer invalidate];
        cancelTimer=nil;
    }
    
    if(!data)
    {
        [dtdev emv2Deinitialise:nil];
        [self displayAlert:@"Error" message:@"Transaction could not be completed!"];
        return;
    }
    
    //parse data to display, send the rest to server
    
    //find and get Track1 masked and Track2 masked tags for display purposes
    NSString *t1Masked=nil;
    NSString *t2Masked=nil;
    
    NSArray *tags=[TLV decodeTags:data];
    logView.text=[NSString stringWithFormat:@"Final tags:\n%@",tags];
    
    TLV *t;
    
    
    
    NSMutableString *receipt=[NSMutableString string];
    NSLog(@"Tags: %@",tags);
    
    [receipt appendFormat:@"* Infinite Peripherals *\n"];
    [receipt appendFormat:@"\n"];
    
    
    [receipt appendFormat:@"Terminal ID: %@\n",[EMVProcessorHelper decodeNib:[TLV findLastTag:TAG_9F1C_TERMINAL_ID tags:tags].data]];
    [receipt appendFormat:@"\n"];
    
    [receipt appendFormat:@"Date: %@ %@\n",
     [EMVProcessorHelper decodeDateString:[TLV findLastTag:TAG_9A_TRANSACTION_DATE tags:tags].data],
     [EMVProcessorHelper decodeTimeString:[TLV findLastTag:TAG_9F21_TRANSACTION_TIME tags:tags].data]
     ];
    //    [receipt appendFormat:@"Transaction Sequence: %d\n",[EMVProcessorHelper decodeInt:[TLV findLastTag:TAG_9F41_TRANSACTION_SEQ_COUNTER tags:tags].data]];
    //    [receipt appendFormat:@"\n"];
    //
    //    if([cardInfo valueForKey:@"cardholderName"])
    //        [receipt appendFormat:@"Name: %@\n",[cardInfo valueForKey:@"cardholderName"]];
    //    if([cardInfo valueForKey:@"accountNumber"])
    //        [receipt appendFormat:@"PAN: %@\n",[cardInfo valueForKey:@"accountNumber"]];
    //    if([TLV findLastTag:TAG_5F34_PAN_SEQUENCE_NUMBER tags:tags])
    //    {
    //        [receipt appendFormat:@"PAN-SEQ: %@\n",[EMVProcessorHelper decodeNib:[TLV findLastTag:TAG_5F34_PAN_SEQUENCE_NUMBER tags:tags].data]];
    //    }
    //    [receipt appendFormat:@"AID: %@\n",[EMVProcessorHelper decodeHexString:[TLV findLastTag:TAG_84_DF_NAME tags:tags].data]];
    //    [receipt appendFormat:@"\n"];
    
    [receipt appendFormat:@"* Payment *\n"];
    
    
    int transactionResult=[EMVProcessorHelper decodeInt:[TLV findLastTag:TAG_C1_TRANSACTION_RESULT tags:tags].data];
    
    NSString *transactionResultString=nil;
    switch (transactionResult)
    {
        case EMV_RESULT_APPROVED:
            transactionResultString=@"APPROVED";
            break;
        case EMV_RESULT_DECLINED:
            transactionResultString=@"DECLINED";
            break;
        case EMV_RESULT_TRY_ANOTHER_INTERFACE:
            transactionResultString=@"TRY ANOTHER INTERFACE";
            break;
        case EMV_RESULT_END_APPLICATION:
            transactionResultString=@"END APPLICATION";
            break;
    }
    [receipt appendFormat:@"Transaction Result:\n"];
    [receipt appendFormat:@"%@\n",transactionResultString];
    [receipt appendFormat:@"\n"];
    
    
    NSData *trackData=[dtdev emv2GetCardTracksEncryptedWithFormat:ALG_EH_AES256 keyID:KEY_EH_AES256_ENCRYPTION1 error:nil];
    [receipt appendFormat:@"Encrypted track data: %@\n",trackData];
    
    if(transactionResult==EMV_RESULT_APPROVED)
    {
        t=[TLV findLastTag:TAG_D3_TRACK1_MASKED tags:tags];
        if(t)
            t1Masked=[[NSString alloc] initWithData:t.data encoding:NSASCIIStringEncoding];
        t=[TLV findLastTag:TAG_D4_TRACK2_MASKED tags:tags];
        if(t)
            t2Masked=[[NSString alloc] initWithData:t.data encoding:NSASCIIStringEncoding];
        
        NSDictionary *cardInfo=[dtdev msProcessFinancialCard:t1Masked track2:t2Masked];
        
    }
    
    //    [receipt appendFormat:@"TVR: %@\n",[EMVProcessorHelper decodeHexString:[TLV findLastTag:TAG_95_TVR tags:tags].data]];
    //    [receipt appendFormat:@"TSI: %@\n",[EMVProcessorHelper decodeHexString:[TLV findLastTag:TAG_9B_TSI tags:tags].data]];
    //    [receipt appendFormat:@"\n"];
    //
    //    NSString *issuerScriptResults=[EMVProcessorHelper decodeHexString:[TLV findLastTag:TAG_C8_ISSUER_SCRIPT_RESULTS tags:tags].data];
    //    if(issuerScriptResults)
    //        [receipt appendFormat:@"%@\n",issuerScriptResults];
    
    [dtdev emv2Deinitialise:nil];
    [self displayAlert:@"Transaction complete!" message:receipt];
}

#endif
-(void)emv2OnUserInterfaceCode:(int)code status:(int)status holdTime:(NSTimeInterval)holdTime;
{
    NSString *ui=@"";
    NSString *uistatus=@"not provided";
    switch (code)
    {
        case EMV_UI_NOT_WORKING:
            ui = @"Not working";
            break;
        case EMV_UI_APPROVED:
            ui = @"Approved";
            break;
        case EMV_UI_DECLINED:
            ui = @"Declined";
            break;
        case EMV_UI_PLEASE_ENTER_PIN:
            ui = @"Please enter PIN";
            break;
        case EMV_UI_ERROR_PROCESSING:
            ui = @"Error processing";
            break;
        case EMV_UI_REMOVE_CARD:
            ui = @"Please remove card";
            break;
        case EMV_UI_IDLE:
            ui = @"Idle";
            break;
        case EMV_UI_PRESENT_CARD:
            ui = @"Please present card";
            break;
        case EMV_UI_PROCESSING:
            ui = @"Processing...";
            break;
        case EMV_UI_CARD_READ_OK_REMOVE:
            ui = @"It is okay to remove card";
            break;
        case EMV_UI_TRY_OTHER_INTERFACE:
            ui = @"Try another interface";
            break;
        case EMV_UI_CARD_COLLISION:
            ui = @"Card collision";
            break;
        case EMV_UI_SIGN_APPROVED:
            ui = @"Signature approved";
            break;
        case EMV_UI_ONLINE_AUTHORISATION:
            ui = @"Online authorization";
            break;
        case EMV_UI_TRY_OTHER_CARD:
            ui = @"Try another card";
            break;
        case EMV_UI_INSERT_CARD:
            ui = @"Please insert card";
            break;
        case EMV_UI_CLEAR_DISPLAY:
            ui = @"Clear display";
            break;
        case EMV_UI_SEE_PHONE:
            ui = @"See phone";
            break;
        case EMV_UI_PRESENT_CARD_AGAIN:
            ui = @"Please present card again";
            break;
        case EMV_UI_NA:
            ui = @"N/A";
            break;
    }
    switch (status)
    {
        case EMV_UI_STATUS_NOT_READY:
            uistatus = @"Status Not Ready";
            break;
        case EMV_UI_STATUS_IDLE:
            uistatus = @"Status Idle";
            break;
        case EMV_UI_STATUS_READY_TO_READ:
            uistatus = @"Status Ready To Read";
            break;
        case EMV_UI_STATUS_PROCESSING:
            uistatus = @"Status Processing";
            break;
        case EMV_UI_STATUS_CARD_READ_SUCCESS:
            uistatus = @"Status Card Read Success";
            break;
        case EMV_UI_STATUS_ERROR_PROCESSING:
            uistatus = @"Status Processing";
            break;
    }
    [progressViewController updateText:ui];
}

-(void)timerFunc:id
{
    [dtdev emv2CancelTransaction:nil];
    [progressViewController.view removeFromSuperview];
}

-(IBAction)onEMVTransaction:(id)sender
{
    NSError *error=nil;
    
    RF_COMMAND(@"EMV Initialize",[dtdev emv2Initialise:&error]);
#ifdef EMV_CARD_EMULATION_MODE
    RF_COMMAND(@"EMV Set card emulation",[dtdev emv2SetCardEmulationMode:true encryption:ALG_EH_IDTECH keyID:KEY_EH_DUKPT_MASTER1 error:&error]);
#else
    RF_COMMAND(@"EMV Set card emulation",[dtdev emv2SetCardEmulationMode:false encryption:0 keyID:0 error:&error]);
#endif
    
    //try loading configuration, if it is not there already
    DTEMV2Info *info=[dtdev emv2GetInfo:&error];
    if(info)
    {
        NSData *config=stringToData(@"E0139F3501215F3601029F3303A020009F1A020840E406C10400000005E506C1019CC2019CE257DF810C01049F0606A000000025019F09020001DF8121050000000000DF8120050000000000DF81220500000000009F1E0836303233333231329F160F111213141516171819202122232425CFFFFF020101CFFF80010100E21B9F0607B0000003241010DF810C010F9F3303602800CFFF80010100E21C9F0608A000000324101001DF810C010F9F3303602800CFFF80010100E21B9F0607A0000003241010DF810C010F9F3303602800CFFF80010100E282008A9F3303A020009F0607A0000000041010DF8130010DDF81312800080000080020000004000004002000000100000100200000020000020020000000000000000700DF811A039F6A04DF810C01029F6D020001DF811E0110DF812C0100DF812406000000030000DF8125060000000500009F350114DF8126060000000200009F7E009F1C00CFFF80010100E282008A9F3303A020009F0607A0000000043060DF8130010DDF81312800080000080020000004000004002000000100000100200000020000020020000000000000000700DF811A039F6A04DF810C01029F6D020001DF811E0110DF812C0100DF812406000000030000DF8125060000000500009F350114DF8126060000000300009F7E009F1C00CFFF80010100E2359F400560000050019F1B04000027109F0607A0000000031010DF810C01039F33032008C8DFDE01079F660480000000CFFF80010100E2359F400560000050019F1B04000027109F0607A0000000999090DF810C01039F33032008C8DFDE01079F660480000000CFFF80010100E2349F400560000050019F1B04000027109F0606A00000999901DF810C01039F33032008C8DFDE01079F660480000000CFFF80010100");
        
        if(info.configurationVersion!=5)
        {//configuration missing or wrong version, load it
            RF_COMMAND(@"EMV Load Configuration",[dtdev emv2LoadConfigurationData:config error:&error]);
        }
        //process with transaction
        //amount: $1.00, currency code: USD(840), according to ISO 4217
        RF_COMMAND(@"EMV Init",[dtdev emv2SetTransactionType:0x01 amount:1500 currencyCode:840 error:&error]);
        //start the transaction, transaction steps will be notified via emv2On... delegate methods
        RF_COMMAND(@"EMV Start Transaction",[dtdev emv2StartTransactionWithFlags:0 initData:nil error:&error]);
    }
    
    if(error)
    {
        [dtdev emv2Deinitialise:&error];
    }else
    {
        [progressViewController viewWillAppear:FALSE];
        [self.view addSubview:progressViewController.view];
        [progressViewController updateText:@"Tap NFC Card to execute transaction"];
        
        //cancel in 10 seconds if still running, do not leave EMV transaction going on for long time, as this will drain the battery
        cancelTimer=[NSTimer scheduledTimerWithTimeInterval:10.0 target:self selector:@selector(timerFunc:) userInfo:nil repeats:NO];
    }
    
}

-(void)viewWillAppear:(BOOL)animated
{
}

-(void)viewWillDisappear:(BOOL)animated
{
    [dtdev rfClose:nil];
}

-(void)viewDidLoad
{
	dtdev=[DTDevices sharedDevice];
    [dtdev addDelegate:self];
    [super viewDidLoad];
}


@end
