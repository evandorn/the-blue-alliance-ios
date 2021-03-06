//
//  TBADistrictsViewController.m
//  the-blue-alliance-ios
//
//  Created by Zach Orr on 7/12/15.
//  Copyright (c) 2015 The Blue Alliance. All rights reserved.
//

#import "TBADistrictsViewController.h"
#import "District.h"

static NSString *const DistrictsCellIdentifier  = @"DistrictsCell";

@implementation TBADistrictsViewController
@synthesize fetchedResultsController = _fetchedResultsController;

#pragma mark - Properities

- (void)setYear:(NSNumber *)year {
    _year = year;
    
    [self clearFRC];
}

- (NSFetchedResultsController *)fetchedResultsController {
    if (_fetchedResultsController != nil) {
        return _fetchedResultsController;
    }

    if (!self.persistenceController) {
        return nil;
    }
    
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] initWithEntityName:@"District"];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"year == %@", self.year];
    [fetchRequest setPredicate:predicate];
    
    NSSortDescriptor *nameSortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES];
    [fetchRequest setSortDescriptors:@[nameSortDescriptor]];
    
    _fetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest
                                                                    managedObjectContext:self.persistenceController.managedObjectContext
                                                                      sectionNameKeyPath:nil
                                                                               cacheName:nil];
    _fetchedResultsController.delegate = self;
    
    NSError *error = nil;
    if (![_fetchedResultsController performFetch:&error]) {
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
        abort();
    }
    
    return _fetchedResultsController;
}

#pragma mark - View Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.tbaDelegate = self;
    self.cellIdentifier = DistrictsCellIdentifier;
    
    __weak typeof(self) weakSelf = self;
    self.refresh = ^void() {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        [strongSelf refreshDistricts];
    };
}

#pragma mark - Data Methods

- (BOOL)shouldNoDataRefresh {
    return self.fetchedResultsController.fetchedObjects.count == 0;
}

- (void)refreshDistricts {
    if (self.year == 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self showNoDataViewWithText:@"No year selected"];
        });
        return;
    }

    __weak typeof(self) weakSelf = self;
    __block NSUInteger request = [[TBAKit sharedKit] fetchDistrictsForYear:self.year.integerValue withCompletionBlock:^(NSArray *districts, NSInteger totalCount, NSError *error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;

        if (error) {
            [strongSelf showErrorAlertWithMessage:@"Unable to load districts"];
        }

        [strongSelf.persistenceController performChanges:^{
            [District insertDistrictsWithDistrictDicts:districts forYear:strongSelf.year.integerValue inManagedObjectContext:strongSelf.persistenceController.backgroundManagedObjectContext];
        } withCompletion:^{
            [strongSelf removeRequestIdentifier:request];
        }];
    }];
    [self addRequestIdentifier:request];
}

#pragma mark - TBA Table View Data Source

- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath {
    District *district = [self.fetchedResultsController objectAtIndexPath:indexPath];
    cell.textLabel.text = district.name;
}

- (void)showNoDataView {
    [self showNoDataViewWithText:@"No districts found"];
}

#pragma mark - Table View Delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if (!self.districtSelected) {
        return;
    }
    
    District *district = [self.fetchedResultsController objectAtIndexPath:indexPath];
    self.districtSelected(district);
}

@end
