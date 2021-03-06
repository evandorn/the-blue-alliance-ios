//
//  EventTeamViewController.m
//  the-blue-alliance
//
//  Created by Zach Orr on 4/25/16.
//  Copyright © 2016 The Blue Alliance. All rights reserved.
//

#import "EventTeamViewController.h"
#import "TBATeamAtEventSummaryViewController.h"
#import "TBATeamAtEventStatsViewController.h"
#import "TBAMatchesViewController.h"
#import "TBAAwardsViewController.h"
#import "MatchViewController.h"
#import "Event.h"
#import "Team.h"

static NSString *const SummaryViewControllerEmbed   = @"SummaryViewControllerEmbed";
static NSString *const MatchesViewControllerEmbed   = @"MatchesViewControllerEmbed";
static NSString *const StatsViewControllerEmbed     = @"StatsViewControllerEmbed";
static NSString *const AwardsViewControllerEmbed    = @"AwardsViewControllerEmbed";

static NSString *const MatchViewControllerSegue     = @"MatchViewControllerSegue";

@interface EventTeamViewController ()

@property (nonatomic, strong) TBATeamAtEventSummaryViewController *summaryViewController;
@property (nonatomic, strong) IBOutlet UIView *summaryView;

@property (nonatomic, strong) TBAMatchesViewController *matchesViewController;
@property (nonatomic, strong) IBOutlet UIView *matchesView;

@property (nonatomic, strong) TBATeamAtEventStatsViewController *statsViewController;
@property (nonatomic, strong) IBOutlet UIView *statsView;

@property (nonatomic, strong) TBAAwardsViewController *awardsViewController;
@property (nonatomic, strong) IBOutlet UIView *awardsView;

@end

@implementation EventTeamViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.refreshViewControllers = @[self.summaryViewController, self.matchesViewController, self.statsViewController, self.awardsViewController];
    self.containerViews = @[self.summaryView, self.matchesView, self.statsView, self.awardsView];
    
    [self styleInterface];
}

#pragma mark - Interface Methods

- (void)styleInterface {
    self.navigationTitleLabel.text = [NSString stringWithFormat:@"Team %@", self.team.teamNumber];
    self.navigationSubtitleLabel.text = [NSString stringWithFormat:@"@ %@", [self.event friendlyNameWithYear:YES]];
}

#pragma mark - Navigation

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:SummaryViewControllerEmbed]) {
        self.summaryViewController = segue.destinationViewController;
        self.summaryViewController.event = self.event;
        self.summaryViewController.team = self.team;
        self.summaryViewController.eventRanking = self.eventRanking;
    } else if ([segue.identifier isEqualToString:MatchesViewControllerEmbed]) {
        self.matchesViewController = segue.destinationViewController;
        self.matchesViewController.event = self.event;
        self.matchesViewController.team = self.team;
        
        __weak typeof(self) weakSelf = self;
        self.matchesViewController.matchSelected = ^(Match *match) {
            [weakSelf performSegueWithIdentifier:MatchViewControllerSegue sender:match];
        };
    } else if ([segue.identifier isEqualToString:StatsViewControllerEmbed]) {
        self.statsViewController = segue.destinationViewController;
        self.statsViewController.event = self.event;
        self.statsViewController.team = self.team;
    } else if ([segue.identifier isEqualToString:AwardsViewControllerEmbed]) {
        self.awardsViewController = segue.destinationViewController;
        self.awardsViewController.event = self.event;
        self.awardsViewController.team = self.team;
    } else if ([segue.identifier isEqualToString:MatchViewControllerSegue]) {
        Match *match = (Match *)sender;
        
        MatchViewController *matchViewController = segue.destinationViewController;
        matchViewController.team = self.team;
        matchViewController.match = match;
    }
}

@end
