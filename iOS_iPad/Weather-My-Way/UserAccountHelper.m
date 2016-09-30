//
//  ChangeNotificationHelper.m
//  Copyright © 2016 Sequencing. All rights reserved.
//


#import "UserAccountHelper.h"
#import "UserHelper.h"
#import "SQToken.h"


const NSString *kAccountAPIDomainAddress    = @"https://weathermyway.rocks";

#define kEmailSmsSettingsNotificationsURL       @"https://weathermyway.rocks/ExternalSettings/ChangeNotification"
#define kIOSDevicePushNotificationsURL          @"https://weathermyway.rocks/ExternalSettings/SubscribePushNotification"
#define kSelectedFileInfoURL                    @"https://weathermyway.rocks/ExternalSettings/SaveFile"
#define kSelectedLocationInfoURL                @"https://weathermyway.rocks/ExternalSettings/SaveLocation"
#define kRetreiveUserSettingsURL                @"https://weathermyway.rocks/ExternalSettings/RetrieveUserSettings"
#define kRetreiveGeneticForecastsArrayEndpoint  @"/ExternalForecastRetrieve/GetForecast"

typedef void (^HttpCallback)(NSString *responseText, NSURLResponse *response, NSError *error);



@interface UserAccountHelper ()

@property (strong, nonatomic) UserHelper *userHelper;

@end



@implementation UserAccountHelper

- (UserHelper *)userHelper {
    if (_userHelper == nil) {
        _userHelper = [[UserHelper alloc] init];
    }
    return _userHelper;
}



#pragma mark -
#pragma mark GeneticForecastsArray

- (void)retrieveGeneticForecastsArrayWithParameters:(NSDictionary *)parameters withCompletion:(void (^)(NSArray *geneticForecastsArray))completion {
    NSString *url = [NSString stringWithFormat:@"%@%@", kAccountAPIDomainAddress, kRetreiveGeneticForecastsArrayEndpoint];
    [self execHttpRequestWithUrl:url
                          method:@"POST"
                  JSONparameters:parameters
                  withCompletion:^(NSString *responseText, NSURLResponse *response, NSError *error) {
                      
                      NSLog(@"\nresponseText: %@", responseText);
                      NSLog(@"\nresponse: %@", response);
                      NSLog(@"\nerror: %@", error.localizedDescription);
                      
                      NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
                      NSInteger statusCode = [httpResponse statusCode];
                      
                      if (error) {  // server connection error
                          NSLog(@"\nerror: %@", error.localizedDescription);
                          completion(nil);
                          
                      } else {
                          if (statusCode == 200 || statusCode == 301 || statusCode == 302) {
                              
                              if (responseText && [responseText length] != 0) { // some response is present
                                  NSError *jsonError;
                                  NSData  *jsonData = [responseText dataUsingEncoding:NSUTF8StringEncoding];
                                  NSDictionary *parsedObject = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&jsonError];
                                  
                                  if (jsonError) {  // error with invalid json
                                      completion(nil);
                                  } else {
                                      if (![[parsedObject allKeys] containsObject:@"Data"]) {
                                          completion(nil);
                                      } else {
                                          if ([[parsedObject objectForKey:@"Data"] isKindOfClass:[NSArray class]]) {
                                              NSArray *receivedArray = [parsedObject objectForKey:@"Data"];
                                              if ([receivedArray count] > 0) {  // answer is valid, we can return array as result
                                                  
                                                  completion(receivedArray);
                                                  
                                              } else {
                                                  completion(nil);
                                              }
                                          } else {
                                              completion(nil);
                                          }
                                      }
                                  }
                              } else {
                                  completion(nil);
                              }
                          } else {
                              completion(nil);
                          }
                      }
                  }];
}



#pragma mark -
#pragma mark User Account Information

- (void)requestForUserAccountInformationWithAccessToken:(NSString *)accessToken withResult:(void (^)(NSDictionary *accountInfo))result {
    NSLog(@"\nrequestForUserAccountInformation");
    NSString *urlString = [NSString stringWithFormat:@"https://sequencing.com/indexApi.php?q=js/custom_oauth2_server/custom-token-info/%@", accessToken];
    NSString *urlStringEncoded = [urlString stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlStringEncoded]];
    [request setHTTPMethod:@"GET"];
    [request setTimeoutInterval:15];
    [request setHTTPShouldHandleCookies:NO];
    
    NSURLSessionDataTask *dataTask = [[NSURLSession sharedSession] dataTaskWithRequest:request
                                                                     completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                                                                         
                                                                         if (data && response && error == nil) {
                                                                             NSError *jsonError;
                                                                             NSData *jsonData = data;
                                                                             NSDictionary *parsedObject = [NSJSONSerialization JSONObjectWithData:jsonData
                                                                                                                                          options:0
                                                                                                                                            error:&jsonError];
                                                                             if (!jsonError) {
                                                                                 // json parsed
                                                                                 if ([parsedObject objectForKey:@"username"] && [parsedObject objectForKey:@"email"]) {
                                                                                     // return valid request result
                                                                                     result(parsedObject);
                                                                                     
                                                                                 } else {
                                                                                     // json has no value
                                                                                     NSLog(@"UserHelper: accountInfo json - results not found");
                                                                                     result(nil);
                                                                                 }
                                                                             } else {
                                                                                 // json parsing error
                                                                                 NSLog(@"UserHelper: accountInfo json: %@", error.localizedDescription);
                                                                                 result(nil);
                                                                             }
                                                                         } else {
                                                                             // server request error
                                                                             NSLog(@"%@", error.localizedDescription);
                                                                             result(nil);
                                                                         }
                                                                     }];
    [dataTask resume];
}



#pragma mark -
#pragma mark Email, SMS, Settings

- (void)sendEmailSmsAndSettingsInfoWithParameters:(NSDictionary *)parameters {
    NSMutableDictionary *mutableParametersDict = [[NSMutableDictionary alloc] init];
    
    // temperature
    [mutableParametersDict setObject:[parameters objectForKey:@"temperature"] forKey:@"temperature"];
    
    // emailChk
    NSString *emailChk;
    if ([[parameters objectForKey:@"emailChk"] boolValue]) {
        emailChk = @"true";
    } else {
        emailChk = @"false";
    }
    [mutableParametersDict setObject:emailChk forKey:@"emailChk"];
    
    // email
    [mutableParametersDict setObject:[parameters objectForKey:@"email"] forKey:@"email"];
    
    // smsChk
    NSString *smsChk;
    if ([[parameters objectForKey:@"smsChk"] boolValue]) {
        smsChk = @"true";
    } else {
        smsChk = @"false";
    }
    [mutableParametersDict setObject:smsChk forKey:@"smsChk"];
    
    // phone number
    [mutableParametersDict setObject:[parameters objectForKey:@"phone"] forKey:@"phone"];
    
    // wakeupDay
    [mutableParametersDict setObject:[parameters objectForKey:@"wakeupDay"] forKey:@"wakeupDay"];
    
    // wakeupEnd
    [mutableParametersDict setObject:[parameters objectForKey:@"wakeupEnd"] forKey:@"wakeupEnd"];
    
    // timezoneSelect
    [mutableParametersDict setObject:[parameters objectForKey:@"timezoneSelect"] forKey:@"timezoneSelect"];
    
    // timezoneOffset
    [mutableParametersDict setObject:[parameters objectForKey:@"timezoneOffset"] forKey:@"timezoneOffset"];
    
    // weekendMode
    [mutableParametersDict setObject:[parameters objectForKey:@"weekendMode"] forKey:@"weekendMode"];
    
    // access token
    [mutableParametersDict setObject:[parameters objectForKey:@"token"] forKey:@"token"];
    
    // request
    [self execHttpRequestWithUrl:kEmailSmsSettingsNotificationsURL
                          method:@"POST"
                      parameters:[NSDictionary dictionaryWithDictionary:[mutableParametersDict copy]]
                  withCompletion:^(NSString *responseText, NSURLResponse *response, NSError *error) {
                      
                      NSLog(@"\nresponseText: %@\n", responseText);
                  }];
}



#pragma mark -
#pragma mark iPhone push notifications

- (void)sendDevicePushNotificationsSettingsWithParameters:(NSDictionary *)parameters {
    NSMutableDictionary *mutableParametersDict = [[NSMutableDictionary alloc] init];
    
    // pushCheck
    NSString *pushCheck;
    if ([[parameters objectForKey:@"pushCheck"] boolValue]) {
        pushCheck = @"true";
    } else {
        pushCheck = @"false";
    }
    [mutableParametersDict setObject:pushCheck forKey:@"pushCheck"];
    
    // deviceType
    [mutableParametersDict setObject:[parameters objectForKey:@"deviceType"] forKey:@"deviceType"];
    
    // deviceToken
    [mutableParametersDict setObject:[parameters objectForKey:@"deviceToken"] forKey:@"deviceToken"];
    
    // access token
    [mutableParametersDict setObject:[parameters objectForKey:@"accessToken"] forKey:@"accessToken"];
    
    // request
    [self execHttpRequestWithUrl:kIOSDevicePushNotificationsURL
                          method:@"POST"
                      parameters:[NSDictionary dictionaryWithDictionary:[mutableParametersDict copy]]
                  withCompletion:^(NSString *responseText, NSURLResponse *response, NSError *error) {
                      
                      NSLog(@"\nresponseText: %@\n", responseText);
                  }];
}



#pragma mark -
#pragma mark Selected genetic file

- (void)sendSelectedGeneticFileInfoWithParameters:(NSDictionary *)parameters {
    [self execHttpRequestWithUrl:kSelectedFileInfoURL
                          method:@"POST"
                      parameters:parameters
                  withCompletion:^(NSString *responseText, NSURLResponse *response, NSError *error) {
                      
                      NSLog(@"\nresponseText: %@\n", responseText);
                  }];
}



#pragma mark -
#pragma mark Selected Location

- (void)sendSelectedLocationInfoWithParameters:(NSDictionary *)parameters {
    [self execHttpRequestWithUrl:kSelectedLocationInfoURL
                          method:@"POST"
                      parameters:parameters
                  withCompletion:^(NSString *responseText, NSURLResponse *response, NSError *error) {
                      
                      NSLog(@"\nresponseText: %@\n", responseText);
                  }];
}



#pragma mark -
#pragma mark User did sign out

- (void)sendSignOutRequestWithParameters:(NSDictionary *)parameters {
    // disable push notifications only as for now
    [self execHttpRequestWithUrl:kIOSDevicePushNotificationsURL
                          method:@"POST"
                      parameters:parameters
                  withCompletion:^(NSString *responseText, NSURLResponse *response, NSError *error) {
                      
                      NSLog(@"\nresponseText: %@\n", responseText);
                  }];
}



#pragma mark -
#pragma mark Retrieve User Account Settings

- (void)retrieveUserSettings:(NSDictionary *)parameters withCompletion:(void (^)(NSDictionary *userAccountSettings))completion {
    [self execHttpRequestWithUrl:kRetreiveUserSettingsURL
                          method:@"POST"
                      parameters:parameters
                  withCompletion:^(NSString *responseText, NSURLResponse *response, NSError *error) {
                      
                      NSLog(@"\nresponseText: %@\n", responseText);
                      
                      if (responseText && response && !error) {
                          
                          NSError *jsonError;
                          NSData *jsonData = [responseText dataUsingEncoding:NSUTF8StringEncoding];
                          // data = [data subdataWithRange:NSMakeRange(0, [data length] - 1)];
                          NSDictionary *parsedObject = [NSJSONSerialization JSONObjectWithData:jsonData
                                                                                       options:0
                                                                                         error:&jsonError];
                          if (!jsonError) {
                              if ([[parsedObject allKeys] containsObject:@"Data"]) {
                                  // return valid response result
                                  completion(parsedObject);
                                  
                              } else {
                                  // json is invalid
                                  NSLog(@"json from server is invalid");
                                  completion(nil);
                              }
                          } else {
                              // json error
                              NSLog(@"%@", jsonError.localizedDescription);
                              completion(nil);
                          }
                      } else {
                          // server request error
                          NSLog(@"%@", error.localizedDescription);
                          completion(nil);
                      }
                  }];
}



#pragma mark -
#pragma mark Send User Account Settings To Server

- (void)sendUserSettingsToServer {
    NSString *token =           [self.userHelper loadUserToken].accessToken;
    
    NSNumber *temperature =     [self.userHelper loadSettingTemperatureUnit];
    NSNumber *emailChk =        [self.userHelper loadSettingEmailDailyForecast];
    NSString *email =           [self.userHelper loadSettingEmailAddressForForecast];
    NSNumber *smsChk =          [self.userHelper loadSettingSMSDailyForecast];
    NSString *phone =           [self.userHelper loadSettingPhoneNumberForForecast];
    NSString *wakeupDay =       [self.userHelper loadSettingWakeUpTimeWeekdays];
    NSString *wakeupEnd =       [self.userHelper loadSettingWakeUpTimeWeekends];
    
    NSString *timezoneSelect;
    NSString *timezone = [self.userHelper loadSettingTimezone];
    if (timezone) {
        timezoneSelect = [self shortTimeZoneNameByFullName:timezone];
    } else {
        [self saveTimeZoneDefaultValue];
        timezoneSelect = [self shortTimeZoneNameByFullName:[self.userHelper loadSettingTimezone]];
    }
    NSString *timezoneOffset =  [self convertTimeZoneIntoStringGMTValueByShortTimeZoneName:timezoneSelect];
    
    NSNumber *weekendMode;
    NSString *weekendNotification = [self.userHelper loadSettingWeekendNotification];
    if (weekendNotification) {
        weekendMode = [NSNumber numberWithInt:[self intValueOfWeekendNotification:weekendNotification]];
    } else {
        [self saveWeekendNotificationDefaultValue];
        weekendMode = [NSNumber numberWithInt:[self intValueOfWeekendNotification:[self.userHelper loadSettingWeekendNotification]]];
    }
    
    NSDictionary *parameters = @{@"temperature"   : temperature,
                                 @"emailChk"      : emailChk,
                                 @"email"         : ([email length] != 0) ? email : @"",
                                 @"smsChk"        : smsChk,
                                 @"phone"         : ([phone length] != 0) ? [self encodePhoneNumber:phone] : @"",
                                 @"wakeupDay"     : wakeupDay,
                                 @"wakeupEnd"     : wakeupEnd,
                                 @"timezoneSelect": timezoneSelect,
                                 @"timezoneOffset": timezoneOffset,
                                 @"weekendMode"   : weekendMode,
                                 @"token"         : token};
    [self sendEmailSmsAndSettingsInfoWithParameters:parameters];
}



#pragma mark -
#pragma mark Process user account settings

- (void)processUserAccountSettings:(NSDictionary *)userAccountSettings {
    if ([[userAccountSettings allKeys] containsObject:@"Data"]) {
        
        id message = [userAccountSettings objectForKey:@"Message"];
        NSString *messageValue = [NSString stringWithFormat:@"%@", message];
        
        if ([messageValue containsString:@"error"] || [messageValue containsString:@"invalid"]) {
            
            id message = [userAccountSettings objectForKey:@"Message"];
            NSString *messageValue = [NSString stringWithFormat:@"%@", message];
            NSLog(@"\"%@\"", messageValue);
            
        } else {
            id dataObject = (id)[userAccountSettings objectForKey:@"Data"];
            if (dataObject != (id)[NSNull null]) {
                if ([[[userAccountSettings objectForKey:@"Data"] allKeys] count] > 0) {
                    NSDictionary *dataDict = [userAccountSettings objectForKey:@"Data"];
                    
                    //[self processUserLocation:dataDict];
                    
                    [self processTemperatureUnits:dataDict];
                    
                    [self processGeneticFile:dataDict];
                    
                    [self processEmailNotificationSetting:dataDict];
                    [self processEmailNotificationAddress:dataDict];
                    
                    [self processSMSNotificationSetting:dataDict];
                    [self processSMSNotificationPhoneNumber:dataDict];
                    
                    [self processWakeUpTimeWeekdays:dataDict];
                    [self processWakeUpTimeWeekends:dataDict];
                    
                    [self processTimezone:dataDict];
                    
                    [self processWeekendNotification:dataDict];
                } else {
                    NSLog(@"User account settings are invalid (data empty)");
                }
            } else {
                NSLog(@"User account settings are invalid (data empty)");
            }
        }
    } else {
        NSLog(@"User account settings are invalid (data absent)");
    }
}



- (void)processUserLocation:(NSDictionary *)dataDict {
    if ([[dataDict allKeys] containsObject:@"City"]) {
        id temp = [dataDict objectForKey:@"City"];
        NSString *valueString = [NSString stringWithFormat:@"%@", temp];
        
        if (![valueString containsString:@"null"] && [valueString length] != 0) {
            
            NSDictionary *location = [NSDictionary dictionaryWithObjectsAndKeys:
                                      @"",          LOCATION_CITY_DICT_KEY,
                                      @"",          LOCATION_STATE_COUNTRY_DICT_KEY,
                                      valueString,  LOCATION_ID_DICT_KEY, nil];
            [self.userHelper saveUserCurrentLocation:location];
        }
    }
}


- (void)processTemperatureUnits:(NSDictionary *)dataDict {
    if ([[dataDict allKeys] containsObject:@"Temperature"]) {
        id temp = [dataDict objectForKey:@"Temperature"];
        NSString *valueString = [NSString stringWithFormat:@"%@", temp];
        
        if (![valueString containsString:@"null"] && [valueString length] != 0) {
            
            int temperatureValue = [valueString intValue];
            switch (temperatureValue) {
                    
                case 0:
                    [self.userHelper saveSettingTemperatureUnit:[NSNumber numberWithInt:0]];
                    break;
                    
                case 1:
                    [self.userHelper saveSettingTemperatureUnit:[NSNumber numberWithInt:1]];
                    break;
                    
                default:
                    [self saveTemperatureUnitsDefaultValue];
                    break;
            }
        } else {
            [self saveTemperatureUnitsDefaultValue];
        }
    } else {
        [self saveTemperatureUnitsDefaultValue];
    }
}

- (void)saveTemperatureUnitsDefaultValue {
    NSNumber *temperatureUnitsInSettings = [self.userHelper loadSettingTemperatureUnit];
    if (!temperatureUnitsInSettings)
        [self.userHelper saveSettingTemperatureUnit:[NSNumber numberWithInt:0]];
}



- (void)processGeneticFile:(NSDictionary *)dataDict {
    if ([[dataDict allKeys] containsObject:@"DataFileId"] && [[dataDict allKeys] containsObject:@"DataFileName"]) {
        id fileIDTemp   = [dataDict objectForKey:@"DataFileId"];
        id fileNameTemp = [dataDict objectForKey:@"DataFileName"];
        NSString *fileIDValueString   = [NSString stringWithFormat:@"%@", fileIDTemp];
        NSString *fileNameValueString = [NSString stringWithFormat:@"%@", fileNameTemp];
        
        if (![fileIDValueString containsString:@"null"] && [fileIDValueString length] != 0
            && ![fileNameValueString containsString:@"null"] && [fileNameValueString length] != 0) {
            
            NSDictionary *geneticFile = [NSDictionary dictionaryWithObjectsAndKeys:
                                         fileIDValueString,     @"Id",
                                         fileNameValueString,   @"Name",
                                         @"CustomCategory",     @"FileCategory", nil];
            [self.userHelper saveUserGeneticFile:geneticFile];
        }
    }
}


- (void)processEmailNotificationSetting:(NSDictionary *)dataDict {
    if ([[dataDict allKeys] containsObject:@"SendEmail"] && [[dataDict allKeys] containsObject:@"UserEmail"]) {
        id sendEmailTemp    = [dataDict objectForKey:@"SendEmail"];
        id emailAddressTemp = [dataDict objectForKey:@"UserEmail"];
        NSString *sendEmailValueString    = [NSString stringWithFormat:@"%@", sendEmailTemp];
        NSString *emailAddressValueString = [NSString stringWithFormat:@"%@", emailAddressTemp];
        
        if (![sendEmailValueString containsString:@"null"] && [sendEmailValueString length] != 0) {
            
            int sendEmailValue = [sendEmailValueString intValue];
            switch (sendEmailValue) {
                    
                case 0:
                    [self.userHelper saveSettingEmailDailyForecast:[NSNumber numberWithInt:0]];
                    break;
                    
                case 1: {
                    if (![emailAddressValueString containsString:@"null"]
                        && [emailAddressValueString length] != 0
                        && [emailAddressValueString containsString:@"@"]
                        && [emailAddressValueString containsString:@"."]) {
                        
                        [self.userHelper saveSettingEmailDailyForecast:[NSNumber numberWithInt:1]];
                    } else {
                        [self.userHelper saveSettingEmailDailyForecast:[NSNumber numberWithInt:0]];
                    }
                }   break;
                    
                default:
                    [self saveEmailNotificationDefaultValue];
                    break;
            }
        } else {
            [self saveEmailNotificationDefaultValue];
        }
    } else {
        [self saveEmailNotificationDefaultValue];
    }
}

- (void)saveEmailNotificationDefaultValue {
    NSNumber *emailNotificationInSettings = [self.userHelper loadSettingEmailDailyForecast];
    if (!emailNotificationInSettings)
        [self.userHelper saveSettingEmailDailyForecast:[NSNumber numberWithInt:0]];
}



- (void)processEmailNotificationAddress:(NSDictionary *)dataDict {
    if ([[dataDict allKeys] containsObject:@"UserEmail"]) {
        id emailAddressTemp = [dataDict objectForKey:@"UserEmail"];
        NSString *emailAddressValueString = [NSString stringWithFormat:@"%@", emailAddressTemp];
        
        if (![emailAddressValueString containsString:@"null"]
            && [emailAddressValueString length] != 0
            && [emailAddressValueString containsString:@"@"]
            && [emailAddressValueString containsString:@"."]) {
            
            [self.userHelper saveSettingEmailAddressForForecast:emailAddressValueString];
        }
    }
}


- (void)processSMSNotificationSetting:(NSDictionary *)dataDict {
    if ([[dataDict allKeys] containsObject:@"SendSms"] && [[dataDict allKeys] containsObject:@"UserPhone"]) {
        id sendSMSTemp    = [dataDict objectForKey:@"SendSms"];
        id phoneNumberTemp = [dataDict objectForKey:@"UserPhone"];
        NSString *sendSMSValueString    = [NSString stringWithFormat:@"%@", sendSMSTemp];
        NSString *phoneNumberValueString = [NSString stringWithFormat:@"%@", phoneNumberTemp];
        
        if (![sendSMSValueString containsString:@"null"] && [sendSMSValueString length] != 0) {
            
            int sendSMSValue = [sendSMSValueString intValue];
            switch (sendSMSValue) {
                    
                case 0:
                    [self.userHelper saveSettingSMSDailyForecast:[NSNumber numberWithInt:0]];
                    break;
                    
                case 1: {
                    if (![phoneNumberValueString containsString:@"null"] && [phoneNumberValueString length] != 0) {
                        [self.userHelper saveSettingSMSDailyForecast:[NSNumber numberWithInt:1]];
                    } else {
                        [self.userHelper saveSettingSMSDailyForecast:[NSNumber numberWithInt:0]];
                    }
                }   break;
                    
                default:
                    [self saveSMSNotificationDefaultValue];
                    break;
            }
        } else {
            [self saveSMSNotificationDefaultValue];
        }
    } else {
        [self saveSMSNotificationDefaultValue];
    }
}

- (void)saveSMSNotificationDefaultValue {
    NSNumber *smsNotificationInSettings = [self.userHelper loadSettingSMSDailyForecast];
    if (!smsNotificationInSettings)
        [self.userHelper saveSettingSMSDailyForecast:[NSNumber numberWithInt:0]];
}


- (void)processSMSNotificationPhoneNumber:(NSDictionary *)dataDict {
    if ([[dataDict allKeys] containsObject:@"UserPhone"]) {
        id phoneNumberTemp = [dataDict objectForKey:@"UserPhone"];
        NSString *phoneNumberValueString = [NSString stringWithFormat:@"%@", phoneNumberTemp];
        
        if (![phoneNumberValueString containsString:@"null"] && [phoneNumberValueString length] != 0) {
            NSString *phoneNumberCorrected = [self correctPhoneNumber:phoneNumberValueString];
            
            // save phone prefix
            
            // save phone number
            [self.userHelper saveSettingPhoneNumberForForecast:phoneNumberCorrected];
        }
    }
}


- (void)processWakeUpTimeWeekdays:(NSDictionary *)dataDict {
    if ([[dataDict allKeys] containsObject:@"TimeWeekDay"]) {
        id wakeUpTimeTemp = [dataDict objectForKey:@"TimeWeekDay"];
        NSString *wakeUpTimeValueString = [NSString stringWithFormat:@"%@", wakeUpTimeTemp];
        
        if (![wakeUpTimeValueString containsString:@"null"] && [wakeUpTimeValueString length] != 0) {
            [self.userHelper saveSettingWakeUpTimeWeekdays:wakeUpTimeValueString];
            
        } else {
            [self saveWakeUpTimeWeekdaysDefaultValue];
        }
    } else {
        [self saveWakeUpTimeWeekdaysDefaultValue];
    }
}

- (void)saveWakeUpTimeWeekdaysDefaultValue {
    NSString *wakeUpTimeWeekdaysInSettings = [self.userHelper loadSettingWakeUpTimeWeekdays];
    if (!wakeUpTimeWeekdaysInSettings)
        [self.userHelper saveSettingWakeUpTimeWeekdays:kWakeUpTimeForWeekDays];
}


- (void)processWakeUpTimeWeekends:(NSDictionary *)dataDict {
    if ([[dataDict allKeys] containsObject:@"TimeWeekEnd"]) {
        id wakeUpTimeTemp = [dataDict objectForKey:@"TimeWeekEnd"];
        NSString *wakeUpTimeValueString = [NSString stringWithFormat:@"%@", wakeUpTimeTemp];
        
        if (![wakeUpTimeValueString containsString:@"null"] && [wakeUpTimeValueString length] != 0) {
            [self.userHelper saveSettingWakeUpTimeWeekends:wakeUpTimeValueString];
            
        } else {
            [self saveWakeUpTimeWeekendsDefaultValue];
        }
    } else {
        [self saveWakeUpTimeWeekendsDefaultValue];
    }
}

- (void)saveWakeUpTimeWeekendsDefaultValue {
    NSString *wakeUpTimeWeekendsInSettings = [self.userHelper loadSettingWakeUpTimeWeekends];
    if (!wakeUpTimeWeekendsInSettings)
        [self.userHelper saveSettingWakeUpTimeWeekends:kWakeUpTimeForWeekEnds];
}


- (void)processTimezone:(NSDictionary *)dataDict {
    if ([[dataDict allKeys] containsObject:@"TimeZoneValue"]) {
        id timeZoneNameTemp = [dataDict objectForKey:@"TimeZoneValue"];
        NSString *timeZoneNameValueString = [NSString stringWithFormat:@"%@", timeZoneNameTemp];
        
        if (![timeZoneNameValueString containsString:@"null"] && [timeZoneNameValueString length] != 0) {
            NSString *timeZoneFullName = [self fullTimeZoneNameByShortTimeZoneName:timeZoneNameValueString];
            if (timeZoneFullName) {
                [self.userHelper saveSettingTimezone:timeZoneFullName];
            } else {
                [self saveTimeZoneDefaultValue];
            }
        } else {
            [self saveTimeZoneDefaultValue];
        }
    } else {
        [self saveTimeZoneDefaultValue];
    }
}

- (void)saveTimeZoneDefaultValue {
    NSString *timeZoneInSettings = [self.userHelper loadSettingTimezone];
    if (!timeZoneInSettings)
        [self.userHelper saveSettingTimezone:[self localTimeZoneFullName]];
}


- (void)processWeekendNotification:(NSDictionary *)dataDict {
    if ([[dataDict allKeys] containsObject:@"WeekendMode"]) {
        id weekendModeTemp = [dataDict objectForKey:@"WeekendMode"];
        NSString *weekendModeValueString = [NSString stringWithFormat:@"%@", weekendModeTemp];
        
        if (![weekendModeValueString containsString:@"null"]) {
            int weekendModeValue = [weekendModeValueString intValue];
            switch (weekendModeValue) {
                    
                case 0:
                    [self.userHelper saveSettingWeekendNotification:[self stringValueOfEnumWeekendNotifications:WeekendNotificationsSMS]];
                    break;
                    
                case 1:
                    [self.userHelper saveSettingWeekendNotification:[self stringValueOfEnumWeekendNotifications:WeekendNotificationsEmail]];
                    break;
                
                case 2: {
                    [self.userHelper saveSettingWeekendNotification:[self stringValueOfEnumWeekendNotifications:WeekendNotificationsEmailAndSMS]];
                }   break;
                
                case 3:
                    [self.userHelper saveSettingWeekendNotification:[self stringValueOfEnumWeekendNotifications:WeekendNotificationsNone]];
                    break;
                    
                case 4:
                    [self.userHelper saveSettingWeekendNotification:[self stringValueOfEnumWeekendNotifications:WeekendNotificationsiPhone]];
                    break;
                    
                case 5:
                    [self.userHelper saveSettingWeekendNotification:[self stringValueOfEnumWeekendNotifications:WeekendNotificationsiPhoneAndEmail]];
                    break;
                    
                case 6:
                    [self.userHelper saveSettingWeekendNotification:[self stringValueOfEnumWeekendNotifications:WeekendNotificationsiPhoneAndSMS]];
                    break;
                    
                case 7:
                    [self.userHelper saveSettingWeekendNotification:[self stringValueOfEnumWeekendNotifications:WeekendNotificationsAll]];
                    break;
                    
                default:
                    [self saveWeekendNotificationDefaultValue];
                    break;
            }
        } else {
            [self saveWeekendNotificationDefaultValue];
        }
    } else {
        [self saveWeekendNotificationDefaultValue];
    }
}

- (void)saveWeekendNotificationDefaultValue {
    NSString *weekendNotificationInSettings = [self.userHelper loadSettingWeekendNotification];
    if (!weekendNotificationInSettings)
        [self.userHelper saveSettingWeekendNotification:[self stringValueOfEnumWeekendNotifications:WeekendNotificationsAll]];
}



#pragma mark -
#pragma mark Phone number helper methods

- (NSString *)encodePhoneNumber:(NSString *)phoneNumber {
    NSMutableString *temp = [phoneNumber mutableCopy];
    NSString *phoneNumberEncoded = @"";
    if ([phoneNumber length] != 0) {
        NSArray *escapeChars = [NSArray arrayWithObjects:
                                @";", @"/", @"?", @":", @"@", @"&", @"=", @"+", @"$", @",",
                                @"[", @"]", @"#", @"!", @"'", @"(", @")", @"*", @" ", nil];
        NSArray *replaceChars = [NSArray arrayWithObjects:
                                 @"", @"",  @"",  @"",  @"",  @"",  @"",  @"%2B",@"",  @"",
                                 @"", @"",  @"",  @"",  @"",  @"",  @"",  @"",  @"",  nil];
        /*
         !   *   '   (   )   ;   :   @   &   =   +   $   ,   /   ?   #   [   ]
         %21 %2A %27 %28 %29 %3B %3A %40 %26 %3D %2B %24 %2C %2F %3F %23 %5B %5D    */
        
        for(int i = 0; i < [escapeChars count]; i++) {
            [temp replaceOccurrencesOfString:[escapeChars objectAtIndex:i]
                                  withString:[replaceChars objectAtIndex:i]
                                     options:NSLiteralSearch
                                       range:NSMakeRange(0, [temp length])];
        }
        phoneNumberEncoded = [NSString stringWithString:temp];
    }
    return phoneNumberEncoded;
}

- (NSString *)correctPhoneNumber:(NSString *)phoneNumber {
    NSString *phoneNumberCorrected = [[[[[[[[[[phoneNumber copy]
                                     stringByReplacingOccurrencesOfString:@" " withString:@""]
                                     stringByReplacingOccurrencesOfString:@"." withString:@""]
                                     stringByReplacingOccurrencesOfString:@"," withString:@""]
                                     stringByReplacingOccurrencesOfString:@"*" withString:@""]
                                     stringByReplacingOccurrencesOfString:@"#" withString:@""]
                                     stringByReplacingOccurrencesOfString:@"-" withString:@""]
                                     stringByReplacingOccurrencesOfString:@";" withString:@""]
                                     stringByReplacingOccurrencesOfString:@"(" withString:@""]
                                     stringByReplacingOccurrencesOfString:@")" withString:@""];
    return phoneNumberCorrected;
}



#pragma mark -
#pragma mark Weekend Notifications helper methods

- (NSString *)stringValueOfEnumWeekendNotifications:(WeekendNotifications)notification {
    NSString *result;
    switch (notification) {
        case WeekendNotificationsSMS:
            result = @"SMS only";
            break;
        case WeekendNotificationsEmail:
            result = @"Email only";
            break;
        case WeekendNotificationsEmailAndSMS:
            result = @"Email & SMS (no iPhone)";
            break;
        case WeekendNotificationsNone:
            result = @"No weekend notifications";
            break;
        case WeekendNotificationsiPhone:
            result = @"iPhone notification only";
            break;
        case WeekendNotificationsiPhoneAndEmail:
            result = @"iPhone & Email (no SMS)";
            break;
        case WeekendNotificationsiPhoneAndSMS:
            result = @"iPhone & SMS (no Email)";
            break;
        case WeekendNotificationsAll:
            result = @"All notifications";
            break;
        default:
            break;
    }
    return result;
}

- (int)intValueOfWeekendNotification:(NSString *)stringValue {
    int value = 7;
    NSArray *notifications = @[@"SMS only",
                               @"Email only",
                               @"Email & SMS (no iPhone)",
                               @"No weekend notifications",
                               @"iPhone notification only",
                               @"iPhone & Email (no SMS)",
                               @"iPhone & SMS (no Email)",
                               @"All notifications"];
    
    if ([notifications containsObject:stringValue]) {
        value = (int)[notifications indexOfObject:stringValue];
    }
    return value;
}



#pragma mark -
#pragma mark TimeZone helper methods

- (NSString *)localTimeZoneName {
    NSTimeZone *localTimeZone = [NSTimeZone localTimeZone];
    return localTimeZone.name;
}


- (NSDictionary *)availableTimeZones {
    NSMutableDictionary *timeZonesDict = [[NSMutableDictionary alloc] init];
    NSArray *timeZonesArray = [NSTimeZone knownTimeZoneNames];
    
    for (NSString *timeZoneName in timeZonesArray) {
        
        NSString *timeZoneStr = [self formatTimeBasedOnSeconds:[[NSTimeZone timeZoneWithName:timeZoneName] secondsFromGMT]];
        NSString *timeZoneKey = [NSString stringWithFormat:@"%@ %@", timeZoneStr, timeZoneName];
        
        if (timeZoneName && timeZoneKey) {
            [timeZonesDict setValue:timeZoneName forKey:timeZoneKey];
        }
    }
    return [NSDictionary dictionaryWithDictionary:[timeZonesDict copy]];
}


- (NSString *)formatTimeBasedOnSeconds:(NSInteger)seconds {
    NSMutableString *formattedTime = [[NSMutableString alloc] init];
    
    if (seconds < 0) {
        [formattedTime appendString:@"GMT-"];
    } else if (seconds == 0) {
        [formattedTime appendString:@"GMT"];
    } else if (seconds > 0) {
        [formattedTime appendString:@"GMT+"];
    }
    
    int hours = abs((int)seconds / 3600);
    int minutes = abs((int)seconds / 60) %60;
    
    if (hours > 0 || minutes > 0) {
        [formattedTime appendString:[NSString stringWithFormat:@"%02d:%02d", hours, minutes]];
    }
    
    return [NSString stringWithString:formattedTime];
}


- (NSString *)fullTimeZoneNameByShortTimeZoneName:(NSString *)timeZoneName {
    NSDictionary *knownTimeZones = [self availableTimeZones];
    NSString *fullTimeZoneName;
    
    for (NSString *keyTimeZone in [knownTimeZones allKeys]) {
        if ([keyTimeZone containsString:timeZoneName]) {
            fullTimeZoneName = [keyTimeZone copy];
            break;
        }
    }
    return fullTimeZoneName;
}


- (NSString *)shortTimeZoneNameByFullName:(NSString *)timeZoneName {
    NSDictionary *knownTimeZones = [self availableTimeZones];
    NSString *shortTimeZoneName;
    
    for (NSString *keyTimeZone in [knownTimeZones allKeys]) {
        if ([keyTimeZone containsString:timeZoneName]) {
            shortTimeZoneName = [[knownTimeZones objectForKey:keyTimeZone] copy];
            break;
        }
    }
    return shortTimeZoneName;
}


- (NSString *)localTimeZoneFullName {
    NSString *localTimeZoneName = [self localTimeZoneName];
    NSString *localTimeZoneFullName;
    
    localTimeZoneFullName = [self fullTimeZoneNameByShortTimeZoneName:localTimeZoneName];
    if (!localTimeZoneFullName) {
        localTimeZoneFullName = [self fullTimeZoneNameByShortTimeZoneName:kDefaultTimeZoneName];
    }
    return localTimeZoneFullName;
}


- (NSString *)convertTimeZoneIntoStringGMTValueByLongTimeZoneName:(NSString *)selectedTimeZone {
    NSDictionary *timeZoneDictionary = [self availableTimeZones];
    NSString *shortTimeZoneName = [timeZoneDictionary objectForKey:selectedTimeZone];
    return [self convertTimeZoneIntoStringGMTValueByShortTimeZoneName:shortTimeZoneName];
}


- (NSString *)convertTimeZoneIntoStringGMTValueByShortTimeZoneName:(NSString *)timeZoneName {
    NSMutableString *temp = [[NSMutableString alloc] init];
    NSString *gmt;
    
    NSTimeZone *timeZone = [NSTimeZone timeZoneWithName:timeZoneName];
    NSInteger seconds = timeZone.secondsFromGMT;
    double value = (double)seconds / 3600;
    if (seconds > 0)
        [temp appendString:@"+"];
    
    [temp appendString:[NSString stringWithFormat:@"%.5f", value]];
    gmt = [NSString stringWithString:[temp copy]];
    return gmt;
}




#pragma mark -
#pragma mark HTTP Helper

- (void)execHttpRequestWithUrl:(NSString *)url
                        method:(NSString *)method
                JSONparameters:(NSDictionary *)parameters
                withCompletion:(HttpCallback)completion {
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
    [request setHTTPMethod:method];
    [request setTimeoutInterval:15];
    [request setHTTPShouldHandleCookies:NO];
    [request setValue:@"en-us" forHTTPHeaderField:@"Accept-Language"];
    [request setValue:@"application/json" forHTTPHeaderField:@"content-type"];
    
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:parameters options:0 error:&error];
    if (jsonData) [request setHTTPBody:jsonData];
    
    NSURLSessionDataTask *dataTask = [[NSURLSession sharedSession] dataTaskWithRequest:request
                                                                     completionHandler:^(NSData* data, NSURLResponse* response, NSError* error) {
                                                                         completion([[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding], response, error);
                                                                     }];
    [dataTask resume];
}



- (void)execHttpRequestWithUrl:(NSString *)url
                        method:(NSString *)method
                    parameters:(NSDictionary *)parameters
                withCompletion:(HttpCallback)completion {
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
    [request setHTTPMethod:method];
    
    if (parameters) {
        NSString *stringEncoded = [self urlEncodedString:parameters];
        NSLog(@"%@", stringEncoded);
        NSData *stringUTF8ENcoded = [stringEncoded dataUsingEncoding:NSUTF8StringEncoding];
        [request setHTTPBody:stringUTF8ENcoded];
    }
    
    [request setTimeoutInterval:15];
    [request setHTTPShouldHandleCookies:NO];
    
    NSURLSessionDataTask *dataTask = [[NSURLSession sharedSession] dataTaskWithRequest:request
                                                                     completionHandler:^(NSData* data, NSURLResponse* response, NSError* error) {
                                                                         completion([[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding], response, error);
                                                                     }];
    [dataTask resume];
}


// helper function: get the url encoded string form of any object
- (NSString *)urlEncode:(id)object {
    NSString *string = [NSString stringWithFormat: @"%@", object];
    return [string stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLPathAllowedCharacterSet]];
}

- (NSString *)urlEncodedString:(NSDictionary *)dictionary {
    NSMutableArray *parts = [NSMutableArray array];
    for (id key in dictionary) {
        id value = [dictionary objectForKey: key];
        if (value != [NSNull null]) {
            NSString *part = [NSString stringWithFormat: @"%@=%@", key, value];
            [parts addObject: part];
        }
    }
    return [parts componentsJoinedByString: @"&"];
}



@end



