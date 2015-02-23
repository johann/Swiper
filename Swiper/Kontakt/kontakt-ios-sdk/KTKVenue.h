//
//  KTKVenue.h
//  kontakt-ios-sdk
//
//  Created by Krzysiek Cieplucha on 14/03/14.
//  Copyright (c) 2014 kontakt.io. All rights reserved.
//

#import "KTKDataTransferObject.h"

/**
 KTKVenue is a protocol that should be implemented by any class that represents venue.
 */
@protocol KTKVenue <KTKDataTransferObject>

/**
 Beacons assigned to the venue.
 */
@property (strong, nonatomic, readonly) NSSet *beacons;

/**
 Type of the venues cover.
 */
@property (strong, nonatomic, readonly) NSString *coverType;

/**
 Venue description.
 */
@property (strong, nonatomic, readonly) NSString *desc;

/**
 URL to the cover image of the venue.
 */
@property (strong, nonatomic, readonly) NSString *imageURL;

/**
 Venues name.
 */
@property (strong, nonatomic, readonly) NSString *name;

/**
 Boolean value indicating if the venue is private.
 */
@property (strong, nonatomic, readonly) NSValue *priv;

@end

/**
 KTKVenue is a class representing venue.
 */
@interface KTKVenue : KTKDataTransferObject <KTKVenue>

#pragma mark - properties

@property (strong, nonatomic, readwrite) NSSet *beacons;
@property (strong, nonatomic, readwrite) NSString *coverType;
@property (strong, nonatomic, readwrite) NSString *desc;
@property (strong, nonatomic, readwrite) NSString *imageURL;
@property (strong, nonatomic, readwrite) NSString *name;
@property (strong, nonatomic, readwrite) NSValue *priv;

@end
