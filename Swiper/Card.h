//
//  Card.h
//  Swiper
//
//  Created by Johann Kerr on 8/25/14.
//  Copyright (c) 2014 Johann Kerr. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>


@interface Card : NSManagedObject

@property (nonatomic, retain) NSString * number;
@property (nonatomic, retain) NSDate * createdAt;

@end
