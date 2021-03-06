//
//  TBAYearSelectViewController.h
//  the-blue-alliance-ios
//
//  Created by Zach Orr on 3/27/15.
//  Copyright (c) 2015 The Blue Alliance. All rights reserved.
//

#import "TBAViewController.h"

@interface TBASelectYearViewController : TBAViewController

@property (nonatomic, strong) NSNumber *currentYear;
@property (nonatomic, copy) NSArray *years;

@property (nonatomic, copy) void (^yearSelected)(NSNumber *year);

+ (NSNumber *)currentYear;
+ (NSArray *)yearsBetweenStartYear:(NSInteger)startYear endYear:(NSInteger)endYear;

@end
