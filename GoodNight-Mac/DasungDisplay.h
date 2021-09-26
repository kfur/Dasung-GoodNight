//
//  DasungDisplay.h
//  GoodNight-Mac
//
//  Created by kfur on 9/23/21.
//  Copyright © 2021 ADA Tech, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DasungDisplay : NSObject
{
    uint8_t m_mode;
    uint8_t contrast_level;
    uint8_t light_level;
    uint8_t refresh_speed;
    io_service_t framebuffer;
}

@property (strong, nonatomic) NSString *uuid;

- (BOOL) findDisplay;
- (void) refresh;
- (void) contrastAdd;
- (void) contrastSubstract;
- (void) mModeChange;
- (void) refreshSpeedAdd;
- (void) refreshSpeedSubstract;
- (void) lightIntensityAdd;
- (void) lightIntensitySubstract;
- (void) lightIntensityToggle;
- (BOOL) displayFound;
- (void) setUpDefaultSettings;

@end

NS_ASSUME_NONNULL_END
