//
//  StringConstants.h
//  Swiper
//
//  Created by Johann Kerr on 9/17/14.
//  Copyright (c) 2014 Johann Kerr. All rights reserved.
//
#define localize(key, default) NSLocalizedStringWithDefaultValue(key, nil, [NSBundle mainBundle], default, nil)

#pragma mark - Message Bars

#define kStringMessageBarErrorTitle localize(@"message.bar.error.title", @"Error Title")
#define kStringMessageBarErrorMessage localize(@"message.bar.error.message", @"This is an error message!")
#define kStringMessageBarSuccessTitle localize(@"message.bar.success.title", @"Success")
#define kStringMessageBarSuccessMessage localize(@"message.bar.success.message", @"Card Swiped!")
#define kStringMessageBarInfoTitle localize(@"message.bar.info.title", @"Information Title")
#define kStringMessageBarInfoMessage localize(@"message.bar.info.message", @"This is an info message!")

#pragma mark - Buttons

#define kStringButtonLabelSuccessMessage localize(@"button.label.success.message", @"Success Message")
#define kStringButtonLabelErrorMessage localize(@"button.label.error.message", @"Error Message")
#define kStringButtonLabelInfoMessage localize(@"button.label.info.message", @"Information Message")
#define kStringButtonLabelHideAll localize(@"button.label.hide.all", @"Hide All")
