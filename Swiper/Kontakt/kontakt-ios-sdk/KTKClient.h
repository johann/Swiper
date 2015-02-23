//
//  KTKClient.h
//  kontakt-ios-sdk
//
//  Created by Krzysiek Cieplucha on 12/03/14.
//  Copyright (c) 2014 kontakt.io. All rights reserved.
//

@class KTKBeacon;
@class KTKFirmware;
@class KTKVenue;
@class KTKManager;
@class KTKUser;

@protocol KTKAction;
@protocol KTKBeacon;
@protocol KTKVenue;

extern NSString *const kKTKAdded;
extern NSString *const kKTKModified;
extern NSString *const kKTKDeleted;
extern NSString *const kKTKTimestamp;

/**
 KTKClinet provides easy way to use web API methods.
 */
@interface KTKClient : NSObject

#pragma mark - properties

/**
 Authenticates user. You should write your own API key to this property.
 */
@property (copy, nonatomic, readwrite) NSString *apiKey;

/**
 Points to the server where web API is located. You should not change value of this property.
 */
@property (copy, nonatomic, readwrite) NSURL *apiUrl;

#pragma mark - public methods

/**
 Returns regions that are used by KTKLocationManager to detect beacons.
 
 @param error error if operation fails
 @return array of KTKRegion objects
 */
- (NSArray *)getRegionsError:(NSError **)error;

/**
 Returns venues that were added, changed or deleted since provided point in time.
 
 Return value is a dictionary that contains four keys:
 
 * kKTKAdded - array of added venues
 * kKTKModified - array of modified venues
 * kKTKDeleted - array of deleted venues
 * kKTKTimestamp - current server timestamp
 
 @param since point in time, put 0 to get all venues
 @param error error if operation fails
 @return dictionary of KTKVenue objects
 */
- (NSDictionary *)getVenuesChangedSince:(NSUInteger)since error:(NSError **)error;

/**
 Returns venues assigned to a venue that were added, changed or deleted since provided point in time.
 
 Return value is a dictionary that contains four keys:
 
 * kKTKAdded - array of added beacons
 * kKTKModified - array of modified beacons
 * kKTKDeleted - array of deleted beacons
 * kKTKTimestamp - current server timestamp
 
 @param venues venues array for which get beacons
 @param since point in time, put 0 to get all beacons
 @param error error if operation fails
 @return dictionary of KTKBeacon objects
 */
- (NSDictionary *)getBeaconsForVenues:(NSArray *)venues changedSince:(NSUInteger)since error:(NSError **)error;

/**
 Returns actions assigned to a beacon that were added, changed or deleted since provided point in time.
 
 Return value is a dictionary that contains four keys:
 
 * kKTKAdded - array of added actions
 * kKTKModified - array of modified actions
 * kKTKDeleted - array of deleted actions
 * kKTKTimestamp - current server timestamp
 
 @param beacons beacons array(KTKBeacon object(s)) for which get actions
 @param since point in time, put 0 to get all actions
 @param error error error if operation fails
 @return dictionary of KTKAction objects
 */
- (NSDictionary *)getActionsForBeacons:(NSArray *)beacons changedSince:(NSUInteger)since error:(NSError **)error;

/**
 Returns beacon with specified UUID, major and minor.
 
 @param UUID beacon UUID
 @param major beacon major number
 @param minor beacon minor number
 @param error error if operation fails
 @return KTKBeacon object
 */
- (KTKBeacon *)getBeaconWithUUID:(NSUUID *)UUID major:(NSNumber *)major andMinor:(NSNumber *)minor error:(NSError **)error;

/**
 Returns information about latest beacons firmware update for a list of specified beacons.
 
 @param beacons set of KTKBeaconDevice objects
 @param error error if operation fails
 @return dictionary of KTKFirmware objects indexed by KTKBeaconDevice objects
 */
- (NSDictionary *)getLatestFirmwareForBeacons:(NSSet *)beacons error:(NSError **)error;

/**
 Returns password and master password for beacon with specified uniqueID.
 
 @param password contains password after operation ends
 @param masterPassword contains master password after operation ends
 @param uniqueID uniqueID of beacon
 @return error if operation fails
 */
- (NSError *)getPassword:(NSString **)password andMasterPassword:(NSString **)masterPassword forBeaconWithUniqueID:(NSString *)uniqueID;

/**
 Sends information about beacon to the cloud.
 
 @param beacon beacon to be saved
 @return error if operation fails
 */
- (NSError *)saveBeacon:(id<KTKBeacon>)beacon;

#pragma mark - Beacon Configs

/**
 Returns list of beacons that requires configuration.
 
 @param     error error if operation fails
 @return    list of KTKBeacon objects
 */
- (NSArray *)getBeaconsToConfigureWithError:(NSError **)error;

/**
 Creates config for specified beacon
 
 @param config  configuration of beacon that we want to apply
 @param error   error if operation fails
 
 @return true if configuartion was created
 */
- (BOOL)createBeaconConfig:(KTKBeacon *)config withError:(NSError **)error;

#pragma mark - Managers

/**
 Authenticates USER by email and password, returns User object/profile with his API key etc
 
 @param email       user's email
 @param password    user's password
 @param error       error if operation fails
 
 @return user object if request succeeded
 */
- (KTKUser *)getAuthenticatedUserByEmail:(NSString *)email andPassword:(NSString *)password withError:(NSError **)error;

/**
 Creates manager based on KTKManager object
 
 @param manager     manager who will be created
 @param error       error if operation fails
 
 @return true if manager was created successfully
 */
- (BOOL)createManager:(KTKManager *)manager withError:(NSError **)error;

/**
 Updates manager settings based on KTKManager object
 
 @param manager     manager who will be updated with current settings
 @param error       error if operation fails
 
 @return true if manager was updated successfully
 */
- (BOOL)updateManager:(KTKManager *)manager withError:(NSError **)error;

/**
 Deletes manager based on manager's UUID
 
 @param UUID        manager's UUID who will be deleted
 @param error       error if operation fails
 
 @return true if manager was deleted successfully
 */
- (BOOL)deleteManagerWithUUID:(NSString *)UUID withError:(NSError **)error;

/**
 Deletes manager based on KTKManager object
 
 @param manager     manager who will be deleted
 @param error       error if operation fails
 
 @return true if manager was deleted successfully
 */
- (BOOL)deleteManager:(KTKManager *)manager withError:(NSError **)error;

/**
 Assigns managers to supervisor(manager) with specified UUID
 
 @param managers    array of managers(KTKManager) who should be assigned
 @param UUID        supervisor's UUID to whom managers should be assigned
 @param error       error if operation fails
 
 @return true if managers were assigned successfully
 */
- (BOOL)assignManagers:(NSArray *)managers toSupervisorWithUUID:(NSString *)UUID withError:(NSError **)error;

/**
 Returns list of managers
 
 @param error error if operation fails
 
 @return array which is list of managers
 */
- (NSArray *)getManagersWithError:(NSError **)error;

/**
 Returns manager with specified UUID
 
 @param UUID    manager's UUID
 @param error   error if operation fails
 
 @return manager with specified UUID
 */
- (KTKManager *)getManagerWithUUID:(NSString *)UUID withError:(NSError **)error;

/**
 Returns list of subordinates
 
 @param UUID manager's UUID
 @param error error if operation fails
 
 @return array which is list of manager's subordinates
 */
- (NSArray *)getSubordinatesForManagerByUUID:(NSUUID *)UUID withError:(NSError **)error;


#pragma mark - Requests

/**
 Returns properly signed request(without API key attached/in header - atm for authentication) to 
 specified endpoint's category and it's subcategory. You can use this method to create custom requests.
 
 @param     category    endpoint's category like @"manager"
 @param     subcategory endpoint's subcategory(which is related to its category) like @"authenticate"
 @return    return      signed request
 */
- (NSMutableURLRequest *)createRequestWithoutApiKeyToEndpointCategory:(NSString *)category
                                                       andSubcategory:(NSString *)subcategory;

/**
 Returns properly signed request to specified endpoint's category and it's subcategory. You can use this method to create custom requests.
 
 @param     category    endpoint's category like @"action"
 @param     subcategory endpoint's subcategory(which is related to its category) like @":id/content"
 @return    return      signed request
 */
- (NSMutableURLRequest *)createRequestToEndpointCategory:(NSString *)category andSubcategory:(NSString *)subcategory;

/**
 Returns properly signed request to specified endpoint. You can use this method to create custom requests.
 
 @param endpoint endpoint
 @return return signed request
 */
- (NSMutableURLRequest *)createRequestToEndpoint:(NSString *)endpoint;

/**
 Sends request to API. You can use this methods to execute custom requests.
 
 @param request request to be sent
 @param error error if opertaion fails
 @return data returned by API
 */
- (NSData *)sendRequest:(NSURLRequest *)request error:(NSError **)error;

@end
