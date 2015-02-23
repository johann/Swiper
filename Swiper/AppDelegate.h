//
//  AppDelegate.h
//  Swiper
//
//  Created by Johann Kerr on 8/25/14.
//  Copyright (c) 2014 Johann Kerr. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;

-(void)resetCoreData;
- (NSManagedObjectContext *)managedObjectContext;
-(void)clearData;
@end
