//
//  DistrictRankingTableViewCell.m
//  the-blue-alliance-ios
//
//  Created by Zach Orr on 5/2/15.
//  Copyright (c) 2015 The Blue Alliance. All rights reserved.
//

#import "TBAEventRankingTableViewCell.h"
#import "EventRanking.h"
#import "Team.h"

@interface TBAEventRankingTableViewCell ()

@property (nonatomic, strong) IBOutlet UILabel *teamNumberLabel;
@property (nonatomic, strong) IBOutlet UILabel *teamNameLabel;
@property (nonatomic, strong) IBOutlet UILabel *rankLabel;
@property (nonatomic, strong) IBOutlet UILabel *recordLabel;
@property (nonatomic, strong) IBOutlet UILabel *detailLabel;

@end

@implementation TBAEventRankingTableViewCell

- (void)setEventRanking:(EventRanking *)eventRanking {
    _eventRanking = eventRanking;
    
    self.teamNumberLabel.text = [NSString stringWithFormat:@"%@", _eventRanking.team.teamNumber];
    self.rankLabel.text = [NSString stringWithFormat:@"Rank %@", _eventRanking.rank];
    self.teamNameLabel.text = [_eventRanking.team nickname];
    if (_eventRanking.record) {
        self.recordLabel.hidden = NO;
        self.recordLabel.text = _eventRanking.record;
    } else {
        self.recordLabel.text = @"";
    }
    self.detailLabel.text = [_eventRanking infoString];
}

@end
