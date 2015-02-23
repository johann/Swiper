//
//  KTKAction.h
//  kontakt-ios-sdk
//
//  Created by Krzysiek Cieplucha on 14/03/14.
//  Copyright (c) 2014 kontakt.io. All rights reserved.
//

#import "KTKDataTransferObject.h"

@protocol KTKBeacon;

/**
 KTKAction is a protocol that should be implemented by any object that represents an action assigned to a beacon.
 */
@protocol KTKAction <KTKDataTransferObject>

/**
 Beacons that this action is assigned to.
 */
@property (strong, nonatomic, readonly) id<KTKBeacon> beacon;

/**
 Content category if action type is CONTENT. Possible values are image/png, image/jpeg, image/gif, audio/mp4, audio/mpeg, audio/ogg, audio/webm, video/mpeg, video/mp4, video/ogg and video/webm.
 */
@property (strong, nonatomic, readonly) NSString *contentCategory;

/**
 Content type if action type is CONTENT. Possible values are IMAGE, AUDIO and VIDEO.
 */
@property (strong, nonatomic, readonly) NSString *contentType;

/**
 URL to content if action type is CONTENT.
 */
@property (strong, nonatomic, readonly) NSString *contentURL;

/**
 Action trigger proximity. Possible values are IMMEDIATE, NEAR and FAR.
 */
@property (strong, nonatomic, readonly) NSString *proximity;

/**
 Type of action. Possible values are CONTENT and BROWSER.
 */
@property (strong, nonatomic, readonly) NSString *type;

/**
 URL to page if action type is BROWSER.
 */
@property (strong, nonatomic, readonly) NSString *url;

@end

/**
 KTKAction is a class representing an action assigned to a beacon.
 */
@interface KTKAction : KTKDataTransferObject <KTKAction>

#pragma mark - properties

@property (strong, nonatomic, readwrite) id<KTKBeacon> beacon;
@property (strong, nonatomic, readwrite) NSString *contentCategory;
@property (strong, nonatomic, readwrite) NSString *contentType;
@property (strong, nonatomic, readwrite) NSString *contentURL;
@property (strong, nonatomic, readwrite) NSString *proximity;
@property (strong, nonatomic, readwrite) NSString *type;
@property (strong, nonatomic, readwrite) NSString *url;

@end
