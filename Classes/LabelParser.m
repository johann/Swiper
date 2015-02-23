
int findNext(char c, const uint8_t *data, int index, int length)
{
    for(int i=index;i<length;i++)
        if(data[i]==c)
            return i;
    return length;
}

NSData *getNextElement(const uint8_t *data, int *index, int length)
{
    int start=findNext('^',data, *index, length);
    if(start==length)
        return nil;
    *index=start+1;
    if(data[start+1]=='G' && data[start+2]=='F' && data[start+3]=='B')
    {//image
        int separator;
        separator=findNext(',', data, *index, length);
        *index=separator+1;
        separator=findNext(',', data, *index, length);
        char tmp[10]={0};
        memcpy(tmp,&data[*index],separator-*index);
        int gfxlen=atoi(tmp);
        *index=separator+1;
        separator=findNext(',', data, *index, length);
        *index=separator+1;
        separator=findNext(',', data, *index, length);
        *index=separator+1;
        *index+=gfxlen;
        return [NSData dataWithBytes:&data[start] length:*index-start];
    }
    int end=findNext('^',data, *index, length);
    *index=end;
    return [NSData dataWithBytes:&data[start] length:end-start];
}

NSArray *parseCommand(NSData *data)
{
    NSString *element=[[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
    if(!element)
        return nil;
    element=[element stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSMutableArray *arr=[NSMutableArray array];
    
    [arr addObject:[element substringToIndex:3]];
    if([[arr objectAtIndex:0] isEqualToString:@"FD"])
    {
        [arr addObject:[element substringFromIndex:3]];
    }else
    {
        if(element.length>3)
        {
            NSArray *params=[[element substringFromIndex:3] componentsSeparatedByString:@","];
            [arr addObjectsFromArray:params];
        }
    }
    
    return arr;
}

NSData *composeCommand(NSArray *params)
{
    NSMutableString *sb=[NSMutableString string];
    [sb appendString:[params objectAtIndex:0]];
    for(int i=1;i<params.count;i++)
    {
        [sb appendString:[params objectAtIndex:i]];
        if(i!=params.count-1)
            [sb appendString:@","];
    }
    return [sb dataUsingEncoding:NSASCIIStringEncoding];
}

int ZPLCalcMagnificationFactor(uint8_t font, uint16_t size)
{
    int factor=1;
    
    if(size <= font){
        
        factor = 1;
    }else{
        
        if( ((size%font) == 0) || ((size%font) < (font/2)) ){
            
            factor = size/font;
        }else{
            
            factor = (size/font) +1;
        }
    }
    return factor;
}

#define FONT_WIDTH 12
#define FONT_HEIGHT 32

NSData *preparseLabel(NSData *file)
{
    NSMutableData *result=[NSMutableData data];
    NSMutableArray *resultCommands=[NSMutableArray array];
    
    const uint8_t *data=file.bytes;
    int index=0;
    int length=(int)file.length;
    
    int lastCoordIndex=-1;
    int lastFontIndex=-1;
    int width=0;
    
    while(true)
    {
        NSData *element=getNextElement(data, &index, length);
        if(!element)
            break;
        [resultCommands addObject:element];
    }
    for (int i=0; i<resultCommands.count; i++)
    {
        NSArray *cmd=parseCommand([resultCommands objectAtIndex:i]);
        if(cmd)
        {
            if([[cmd objectAtIndex:0] isEqualToString:@"^PW"])
            {//page width
                width=[[cmd objectAtIndex:1] intValue];
            }
            if([[cmd objectAtIndex:0] isEqualToString:@"^FT"])
            {//coordinates
                lastCoordIndex=i;
            }
            if([[cmd objectAtIndex:0] isEqualToString:@"^A0"])
            {//font
                lastFontIndex=i;
            }
            if([[cmd objectAtIndex:0] isEqualToString:@"^FD"])
            {//text
                NSString *text=[cmd objectAtIndex:1];
                
                NSArray *posCmd=parseCommand([resultCommands objectAtIndex:lastCoordIndex]);
                int x=[[posCmd objectAtIndex:1] intValue];
                int y=[[posCmd objectAtIndex:2] intValue];
                
                char font='0';
                int fontWidth=0;
                int fontHeight=FONT_HEIGHT;
                NSArray *fontCmd=NULL;
                if(lastFontIndex!=-1)
                {
                    fontCmd=parseCommand([resultCommands objectAtIndex:lastFontIndex]);
                    font=[[fontCmd objectAtIndex:1] characterAtIndex:0];
                    fontHeight=[[fontCmd objectAtIndex:2] intValue];
                    fontWidth=[[fontCmd objectAtIndex:3] intValue];
                }
                
                int factor=ZPLCalcMagnificationFactor(fontHeight, fontHeight);
                
                if(y<200)
                {
                    if(x>(width/3)*2)
                    {//right aligned
                        fontWidth=FONT_WIDTH;
                        if([text hasPrefix:@"$"])
                            fontWidth=FONT_WIDTH*2;
                        int textWidth=fontWidth*factor*(int)text.length;
                        x=width-20-textWidth;
                    }
                }
                
                if(fontHeight>150)
                {//the big P
                    font='E';
                    y+=25;
                }
                
                if([text hasPrefix:@"USPS TRACKING"])
                {
                    fontWidth=FONT_WIDTH*2;
                    int textWidth=fontWidth*factor*(int)text.length;
                    x=(width-textWidth)/2;
                }

                if(y>500)
                {
                    fontWidth=FONT_WIDTH;
                    int textWidth=fontWidth*factor*(int)text.length;
                    x=(width-textWidth)/2;
                }
                
                //update the original position command
                NSMutableArray *newPosCmd=[NSMutableArray arrayWithArray:posCmd];
                [newPosCmd replaceObjectAtIndex:1 withObject:[NSString stringWithFormat:@"%d",x]];
                [newPosCmd replaceObjectAtIndex:2 withObject:[NSString stringWithFormat:@"%d",y]];
                [resultCommands replaceObjectAtIndex:lastCoordIndex withObject:composeCommand(newPosCmd)];
                
                //update the original font command
                if(lastFontIndex!=-1)
                {
                    NSMutableArray *newFontCmd=[NSMutableArray arrayWithArray:fontCmd];
                    [newFontCmd replaceObjectAtIndex:0 withObject:[NSString stringWithFormat:@"^A%c",font]];
                    [newFontCmd replaceObjectAtIndex:2 withObject:[NSString stringWithFormat:@"%d",fontHeight]];
                    [newFontCmd replaceObjectAtIndex:3 withObject:[NSString stringWithFormat:@"%d",fontWidth]];
                    [resultCommands replaceObjectAtIndex:lastFontIndex withObject:composeCommand(newFontCmd)];
                }
            }
        }
    }
    
    uint8_t crlf[]={0x0d,0x0a};
    
    for (int i=0; i<resultCommands.count; i++)
    {
        [result appendData:[resultCommands objectAtIndex:i]];
        [result appendBytes:crlf length:sizeof(crlf)];
    }
    
    return result;
}
