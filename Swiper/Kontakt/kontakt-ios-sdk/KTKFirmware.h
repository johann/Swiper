//
//  KTKFirmware.h
//  kontakt-ios-sdk
//
//  Created by Krzysiek Cieplucha on 28/04/14.
//  Copyright (c) 2014 kontakt.io. All rights reserved.
//

#import "KTKDataTransferObject.h"

/**
 KTKFirmware is a protocol that should be implemented by any class that represents firmware.
 */
@protocol KTKFirmware <NSObject>

/**
 Firmware description.
 */
@property (strong, nonatomic, readonly) NSString *desc;

/**
 
 */
@property (strong, nonatomic, readonly) NSString *important;

/**
 
 */
@property (strong, nonatomic, readonly) NSString *url;

/**
 
 */
@property (strong, nonatomic, readonly) NSString *version;

@end

/**
 KTKFirmware is a class representing firmware.
 */
@interface KTKFirmware : KTKDataTransferObject <KTKFirmware>

#pragma mark - properties

@property (strong, nonatomic, readonly) NSString *desc;
@property (strong, nonatomic, readonly) NSString *important;
@property (strong, nonatomic, readonly) NSString *url;
@property (strong, nonatomic, readonly) NSString *version;

@end
