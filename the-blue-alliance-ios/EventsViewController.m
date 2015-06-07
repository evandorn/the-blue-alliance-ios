//
//  EventsViewController.m
//  The Blue Alliance
//
//  Created by Donald Pinckney on 5/5/14.
//  Copyright (c) 2014 The Blue Alliance. All rights reserved.
//
#import "EventsViewController.h"

#import "SelectYearViewController.h"
#import "SelectYearTransitionAnimator.h"
#import "HMSegmentedControl.h"
#import "UIColor+TBAColors.h"
#import "Event.h"
#import "Event+Fetch.h"
#import "OrderedDictionary.h"
#import "District.h"
#import "EventViewController.h"
#import <PureLayout/PureLayout.h>
#import "EventTableViewCell.h"

// TODO: Bring the events view to the current week, like the Android app

static NSString *const EventCellReuseIdentifier = @"EventCell";


@interface EventsViewController () <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, strong) IBOutlet UIView *segmentedControlView;
@property (nonatomic, strong) IBOutlet UITableView *tableView;
@property (nonatomic, strong) IBOutlet NSLayoutConstraint *tableViewLeadingConstraint;
@property (nonatomic, strong) IBOutlet NSLayoutConstraint *tableViewTrailingConstraint;

// Ordered dict of "Weeks" (Preseason, Week 1, Week 2, ...)
// Week dicts have ordered dict of event types (Regional Events, MI District Events, ...)
// Event dicts have arrays of events
@property (nonatomic, strong) OrderedDictionary *eventData;

@property (nonatomic, strong) HMSegmentedControl *segmentedControl;
@property (nonatomic, assign) NSInteger currentSegmentIndex;

@property (nonatomic, strong) UISwipeGestureRecognizer *leftSwipeGestureRecognizer;
@property (nonatomic, strong) UISwipeGestureRecognizer *rightSwipeGestureRecognizer;

@end


@implementation EventsViewController

#pragma mark - View Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    
    __weak typeof(self) weakSelf = self;
    self.refresh = ^void() {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (strongSelf) {
            [strongSelf updateRefreshBarButtonItem:YES];
            [strongSelf refreshData];
        }
    };
    
    self.yearSelected = ^void(NSUInteger selectedYear) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        
        if (strongSelf.segmentedControl) {
            strongSelf.segmentedControl.selectedSegmentIndex = 0;
        }
        strongSelf.currentYear = selectedYear;
        strongSelf.navigationItem.title = [NSString stringWithFormat:@"%@ Events", @(selectedYear)];
        
        [strongSelf cancelRefresh];
        [strongSelf updateRefreshBarButtonItem:NO];
        
        [strongSelf fetchEvents];
    };
    
    [self fetchEvents];
    [self styleInterface];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];

    [self cancelRefresh];
    [self updateRefreshBarButtonItem:NO];
}


#pragma mark - Data Methods

- (void)fetchEvents {
    self.eventData = nil;

    __weak typeof(self) weakSelf = self;
    [Event fetchEventForYear:self.currentYear fromContext:self.persistenceController.managedObjectContext withCompletionBlock:^(NSArray *events, NSError *error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (error) {
            [strongSelf showAlertWithTitle:@"Unable to fetch events locally" andMessage:error.localizedDescription];
            return;
        }
        
        if (!events || [events count] == 0) {
            if (strongSelf.refresh) {
                strongSelf.refresh();
            }
        } else {
            strongSelf.eventData = [Event groupEventsByWeek:events];
            dispatch_async(dispatch_get_main_queue(), ^{
                [strongSelf updateInterface];
            });
        }
    }];
}

- (void)refreshData {
    NSInteger year = self.currentYear;
    
    __weak typeof(self) weakSelf = self;
    self.currentRequestIdentifier = [[TBAKit sharedKit] fetchEventsForYear:year withCompletionBlock:^(NSArray *events, NSInteger totalCount, NSError *error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        
        strongSelf.currentRequestIdentifier = 0;
        dispatch_async(dispatch_get_main_queue(), ^{
            [strongSelf updateRefreshBarButtonItem:NO];
        });
        
        if (error) {
            [strongSelf showAlertWithTitle:@"Error fetching events" andMessage:error.localizedDescription];
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                [Event insertEventsWithModelEvents:events inManagedObjectContext:strongSelf.persistenceController.managedObjectContext];
                [strongSelf fetchEvents];
                [strongSelf.persistenceController save];
            });
        }
    }];
}

- (OrderedDictionary *)weekDictionaryForIndex:(NSInteger)index {
    NSArray *weekKeys = [self.eventData allKeys];
    if (!weekKeys || index >= [weekKeys count]) {
        return nil;
    }
    NSString *weekKey = [weekKeys objectAtIndex:index];
    
    return [self.eventData objectForKey:weekKey];
}

- (NSArray *)eventsForIndex:(NSInteger)index forWeekDictionary:(OrderedDictionary *)weekDictionary {
    if (!weekDictionary || !weekDictionary.allKeys || index >= [weekDictionary.allKeys count]) {
        return nil;
    }
    
    NSString *eventTypeKey = [weekDictionary.allKeys objectAtIndex:index];
    return [weekDictionary objectForKey:eventTypeKey];
}

- (Event *)eventForSegmentIndex:(NSInteger)sectionIndex forIndexPath:(NSIndexPath *)indexPath {
    OrderedDictionary *weekDictionary = [self weekDictionaryForIndex:sectionIndex];
    NSArray *eventsArray = [self eventsForIndex:indexPath.section forWeekDictionary:weekDictionary];
    Event *event = [eventsArray objectAtIndex:indexPath.row];
    
    return event;
}


#pragma mark - Interface Methods

- (void)styleInterface {
    self.rightSwipeGestureRecognizer = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(swipedRight:)];
    self.rightSwipeGestureRecognizer.direction = UISwipeGestureRecognizerDirectionRight;
    [self.tableView addGestureRecognizer:self.rightSwipeGestureRecognizer];
    
    self.leftSwipeGestureRecognizer = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(swipedLeft:)];
    self.leftSwipeGestureRecognizer.direction = UISwipeGestureRecognizerDirectionLeft;
    [self.tableView addGestureRecognizer:self.leftSwipeGestureRecognizer];
    
    
    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
    self.segmentedControlView.backgroundColor = [UIColor TBANavigationBarColor];
    self.navigationItem.title = [NSString stringWithFormat:@"%@ Events", @(self.currentYear)];
    [self updateInterface];
}

- (void)updateInterface {
    [self updateSegmentedControlForEventKeys:self.eventData.allKeys];
    [self.tableView reloadData];
}

- (void)swipedRight:(UISwipeGestureRecognizer *)swipeGestureRecognizer {
    [self animateToIndex:self.currentSegmentIndex - 1];
}

- (void)swipedLeft:(UISwipeGestureRecognizer *)swipeGestureRecognizer {
    [self animateToIndex:self.currentSegmentIndex + 1];
}

- (void)updateSegmentedControlForEventKeys:(NSArray *)eventKeys {
    if (!eventKeys || [eventKeys count] == 0) {
        [self.segmentedControl removeFromSuperview];
        self.segmentedControl = nil;
        return;
    }

    if (self.segmentedControl) {
        self.segmentedControl.sectionTitles = eventKeys;
        [self.segmentedControl setNeedsDisplay];
        return;
    }

    self.segmentedControl = [[HMSegmentedControl alloc] initWithSectionTitles:eventKeys];
    
    self.segmentedControl.frame = self.segmentedControlView.frame;
    self.segmentedControl.segmentEdgeInset = UIEdgeInsetsMake(0, 10, 0, 10);
    self.segmentedControl.selectionStyle = HMSegmentedControlSelectionStyleFullWidthStripe;
    self.segmentedControl.selectionIndicatorLocation = HMSegmentedControlSelectionIndicatorLocationDown;
    self.segmentedControl.backgroundColor = [UIColor TBANavigationBarColor];
    self.segmentedControl.selectionIndicatorColor = [UIColor whiteColor];
    self.segmentedControl.segmentWidthStyle = HMSegmentedControlSegmentWidthStyleDynamic;
    self.segmentedControl.selectionIndicatorHeight = 3.0f;
    
    [self.segmentedControl setTitleFormatter:^NSAttributedString *(HMSegmentedControl *segmentedControl, NSString *title, NSUInteger index, BOOL selected) {
        NSAttributedString *attString = [[NSAttributedString alloc] initWithString:title attributes:@{NSForegroundColorAttributeName : [UIColor whiteColor]}];
        return attString;
    }];
    [self.segmentedControl addTarget:self action:@selector(segmentedControlChangedValue:) forControlEvents:UIControlEventValueChanged];
    [self.segmentedControlView addSubview:self.segmentedControl];
    
    [self.segmentedControl autoPinEdgesToSuperviewEdgesWithInsets:UIEdgeInsetsZero];
}

- (void)segmentedControlChangedValue:(HMSegmentedControl *)segmentedControl {
    [self animateToIndex:segmentedControl.selectedSegmentIndex];
}

- (void)animateToIndex:(NSInteger)index {
    if (index == self.currentSegmentIndex || index < 0 || index >= [self.eventData.allKeys count]) {
        return;
    }

    ALAttribute firstAttr;
    ALAttribute secondAttr;
    if (index > self.currentSegmentIndex) {
        firstAttr = ALAttributeLeading;
        secondAttr = ALAttributeTrailing;
    } else {
        firstAttr = ALAttributeTrailing;
        secondAttr = ALAttributeLeading;
    }
    
    UIView *oldTableView = [self.tableView snapshotViewAfterScreenUpdates:NO];
    oldTableView.frame = self.tableView.frame;
    [self.view addSubview:oldTableView];
    
    self.currentSegmentIndex = index;
    [self.tableView reloadData];
    
    NSLayoutConstraint *oldTableViewCenterVerticalConstraint = [oldTableView autoAlignAxis:ALAxisVertical toSameAxisOfView:self.view];
    [oldTableView autoPinEdge:ALEdgeTop toEdge:ALEdgeBottom ofView:self.segmentedControlView];
    [oldTableView autoSetDimension:ALDimensionHeight toSize:CGRectGetHeight(oldTableView.frame)];
    [oldTableView autoSetDimension:ALDimensionWidth toSize:CGRectGetWidth(oldTableView.frame)];
    
    NSLayoutConstraint *tableViewWidthConstraint = [self.tableView autoSetDimension:ALDimensionWidth toSize:CGRectGetWidth(self.tableView.frame)];
    [self.view removeConstraints:@[self.tableViewLeadingConstraint, self.tableViewTrailingConstraint]];
    NSLayoutConstraint *tableViewCenterVerticalConstrait = [self.tableView autoConstrainAttribute:firstAttr toAttribute:secondAttr ofView:self.view];

    [self.view layoutIfNeeded];
    
    [self.view removeConstraint:oldTableViewCenterVerticalConstraint];
    [oldTableView autoConstrainAttribute:secondAttr toAttribute:firstAttr ofView:self.view];
    
    [self.view removeConstraint:tableViewCenterVerticalConstrait];
    tableViewCenterVerticalConstrait = [self.tableView autoAlignAxis:ALAxisVertical toSameAxisOfView:self.view];

    [self.segmentedControl setSelectedSegmentIndex:index animated:YES];
    
    // Same duration that our sliding tabs are moving
    [UIView animateWithDuration:0.15f animations:^{
        [self.view layoutIfNeeded];
    } completion:^(BOOL finished) {
        [oldTableView removeFromSuperview];
        [self.view removeConstraints:@[tableViewWidthConstraint, tableViewCenterVerticalConstrait]];
        [self.view addConstraints:@[self.tableViewLeadingConstraint, self.tableViewTrailingConstraint]];
    }];
}


#pragma mark - Table View Data Source

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 28.0f;
}

- (void)tableView:(UITableView *)tableView willDisplayHeaderView:(UIView *)view forSection:(NSInteger)section {
    UITableViewHeaderFooterView *header = (UITableViewHeaderFooterView *)view;
    
    header.backgroundView.backgroundColor = [UIColor TBANavigationBarColor];
    header.textLabel.textColor = [UIColor whiteColor];
    header.textLabel.font = [UIFont systemFontOfSize:12.0f];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    OrderedDictionary *weekDictionary = [self weekDictionaryForIndex:self.currentSegmentIndex];
    return [weekDictionary.allKeys objectAtIndex:section];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    if (!self.eventData) {
        // TODO: Show no data screen
        return 0;
    }
    OrderedDictionary *weekDictionary = [self weekDictionaryForIndex:self.currentSegmentIndex];
    if (!weekDictionary) {
        // TODO: Show no data screen
        return 0;
    }
    return [weekDictionary.allKeys count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    OrderedDictionary *weekDictionary = [self weekDictionaryForIndex:self.currentSegmentIndex];
    NSArray *events = [self eventsForIndex:section forWeekDictionary:weekDictionary];
    return [events count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    EventTableViewCell *cell = (EventTableViewCell *)[tableView dequeueReusableCellWithIdentifier:EventCellReuseIdentifier forIndexPath:indexPath];
    
    Event *event = [self eventForSegmentIndex:self.currentSegmentIndex forIndexPath:indexPath];
    
    cell.nameLabel.text = [event friendlyNameWithYear:NO];
    cell.locationLabel.text = event.location;
    cell.datesLabel.text = [event dateString];
    
    return cell;
}


#pragma mark - Table View Delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    Event *event = [self eventForSegmentIndex:self.currentSegmentIndex forIndexPath:indexPath];
    [self performSegueWithIdentifier:@"EventViewControllerSegue" sender:event];
}


#pragma mark - Navigation

/*
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"EventViewControllerSegue"]) {
        Event *event = (Event *)sender;
        
        EventViewController *eventViewController = segue.destinationViewController;
        eventViewController.event = event;
    } else if ([segue.identifier isEqualToString:@"EventViewControllerSegue"]) {
        Event *event = (Event *)sender;
        
        EventViewController *eventViewController = segue.destinationViewController;
        eventViewController.event = event;
    }
}
*/

@end
