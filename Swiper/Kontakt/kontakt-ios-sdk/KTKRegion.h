//
//  KTKRegion.h
//  kontakt-ios-sdk
//
//  Created by Krzysiek Cieplucha on 31/03/14.
//  Copyright (c) 2014 kontakt.io. All rights reserved.
//

#import "KTKDataTransferObject.h"

/**
 KTKRegion is a protocol that should be implemented by any class that represents region.
 */
@protocol KTKRegion <KTKDataTransferObject>

/**
 UUID that defines region. Region contains beacons with proximity UUID equal to region UUID.
 */
@property (strong, nonatomic, readonly) NSString *uuid;

@end

/**
 KTKRegion is a class representing region.
 */
@interface KTKRegion : KTKDataTransferObject <KTKRegion>

#pragma mark - properties

@property (strong, nonatomic, readwrite) NSString *uuid;

@end
