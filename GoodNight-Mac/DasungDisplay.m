//
//  DasungDisplay.m
//  GoodNight-Mac
//
//  Created by kfur on 9/23/21.
//  Copyright Joey Korkames 2016 http://github.com/kfix
//

#import "DasungDisplay.h"
#import <AppKit/NSScreen.h>
#import "DDC.h"

#define MyLog(...) (void)printf("%s\n",[[NSString stringWithFormat:__VA_ARGS__] UTF8String])

NSString *getDisplayDeviceLocation(CGDirectDisplayID cdisplay)
{
    // FIXME: scraping prefs files is vulnerable to use of stale data?
    // TODO: try shelling `system_profiler SPDisplaysDataType -xml` to get "_spdisplays_displayPath" keys
    //    this seems to use private routines in:
    //      /System/Library/SystemProfiler/SPDisplaysReporter.spreporter/Contents/MacOS/SPDisplaysReporter

    // get the WindowServer's table of DisplayIds -> IODisplays
    NSString *wsPrefs = @"/Library/Preferences/com.apple.windowserver.plist";
    NSDictionary *wsDict = [NSDictionary dictionaryWithContentsOfFile:wsPrefs];
    if (!wsDict)
    {
        MyLog(@"E: Failed to parse WindowServer's preferences! (%@)", wsPrefs);
        return NULL;
    }

    NSArray *wsDisplaySets = [wsDict valueForKey:@"DisplayAnyUserSets"];
    if (!wsDisplaySets)
    {
        MyLog(@"E: Failed to get 'DisplayAnyUserSets' key from WindowServer's preferences! (%@)", wsPrefs);
        return NULL;
    }

    // $ PlistBuddy -c "Print DisplayAnyUserSets:0:0:IODisplayLocation" -c "Print DisplayAnyUserSets:0:0:DisplayID" /Library/Preferences/com.apple.windowserver.plist
    // > IOService:/AppleACPIPlatformExpert/PCI0@0/AppleACPIPCI/PEG0@1/IOPP/GFX0@0/ATY,Longavi@0/AMDFramebufferVIB
    // > 69733382
    for (NSArray *displaySet in wsDisplaySets) {
        for (NSDictionary *display in displaySet) {
            if ([[display valueForKey:@"DisplayID"] integerValue] == cdisplay) {
                return [display valueForKey:@"IODisplayLocation"]; // kIODisplayLocationKey
            }
        }
    }

    MyLog(@"E: Failed to find display in WindowServer's preferences! (%@)", wsPrefs);
    return NULL;
}

NSString *EDIDString(char *string)
{
    NSString *temp = [[NSString alloc] initWithBytes:string length:13 encoding:NSASCIIStringEncoding];
    return ([temp rangeOfString:@"\n"].location != NSNotFound) ? [[temp componentsSeparatedByString:@"\n"] objectAtIndex:0] : temp;
}

void setControl(io_service_t framebuffer, uint control_id, uint new_value)
{
    struct DDCWriteCommand command;
    command.control_id = control_id;
    command.new_value = new_value;

    MyLog(@"D: setting VCP control #%u => %u", command.control_id, command.new_value);
    if (!DDCWrite(framebuffer, &command)){
        MyLog(@"E: Failed to send DDC command!");
    }
}

io_service_t get_framebuffer() {
    CGDirectDisplayID cdisplay;
    NSString *screenName = @"";
    io_service_t framebuffer = 0;
    NSString *devLoc;
    
    for (NSScreen *screen in NSScreen.screens)
    {
        NSDictionary *description = [screen deviceDescription];
        if ([description objectForKey:@"NSDeviceIsScreen"]) {
            CGDirectDisplayID screenNumber = [[description objectForKey:@"NSScreenNumber"] unsignedIntValue];
            if (CGDisplayIsBuiltin(screenNumber)) continue; // ignore MacBook screens because the lid can be closed and they don't use DDC.
            // https://stackoverflow.com/a/48450870/3878712
            CFUUIDRef screenUUID = CGDisplayCreateUUIDFromDisplayID(screenNumber);
            CFStringRef screenUUIDstr = CFUUIDCreateString(NULL, screenUUID);
            cdisplay = screenNumber;
            devLoc = getDisplayDeviceLocation(cdisplay);
            framebuffer = IOFramebufferPortFromCGDisplayID(cdisplay, (__bridge CFStringRef)devLoc);
            
            struct EDID edid = {};
            if (EDIDTest(framebuffer, &edid)) {
                for (union descriptor *des = edid.descriptors; des < edid.descriptors + sizeof(edid.descriptors) / sizeof(edid.descriptors[0]); des++) {
                    switch (des->text.type)
                    {
                        case 0xFF:
                            MyLog(@"I: got edid.serial: %@", EDIDString(des->text.data));
                            break;
                        case 0xFC:
                            screenName = EDIDString(des->text.data);
                            if ([ screenName isEqualToString:@"DASUNG Paper"]) {
                                MyLog(@"I: found Dasung display");
                                goto _ret;
                            }
                            MyLog(@"I: got edid.name: %@", screenName);
                            break;
                    }
                }
            } else {
                MyLog(@"E: Failed to poll display!");
                IOObjectRelease(framebuffer);
                return 0;
            }
            
        }
    }
_ret:
    return framebuffer;
}

@implementation DasungDisplay

- (instancetype)init
{
    self = [super init];
    if (self) {
        self->framebuffer = 0;
        [self findDisplay];
    }
    return self;
}

- (BOOL) findDisplay {
    self->framebuffer = get_framebuffer();
    MyLog(@"%d", self->framebuffer);
    if (self->framebuffer) {
        [self setUpDefaultSettings];
        return YES;
    } else {
        return NO;
    }
}

- (void) setUpDefaultSettings {
    self->contrast_level = 1;
    self->light_level = 0;
    self->m_mode = 3;
    self->refresh_speed = 4;
    
    setControl(framebuffer, 0x08, self->contrast_level);
    setControl(framebuffer, 0x07, self->m_mode);
    setControl(framebuffer, 0x0c, self->refresh_speed);
    setControl(framebuffer, 0xD + 2, self->light_level);
}

- (void) refresh {
    setControl(framebuffer, 0x06, 0x03);
}

- (BOOL) displayFound {
    if (self->framebuffer)
        return YES;
    else
        return NO;
}

- (void) contrastAdd {
    if (self->contrast_level >= 9) {
        self->contrast_level = 0;
    }
    setControl(framebuffer, 0x08, ++self->contrast_level);
}

- (void) contrastSubstract {
    if (self->contrast_level <= 1) {
        self->contrast_level = 10;
    }
    setControl(framebuffer, 0x08, --self->contrast_level);
}

- (void) mModeChange {
    if (self->m_mode <= 1) {
        self->m_mode = 4;
    }
    setControl(framebuffer, 0x07, --self->m_mode);
}

- (void) refreshSpeedSubstract {
    if (self->refresh_speed >= 5) {
        self->refresh_speed = 0;
    }
    setControl(framebuffer, 0x0c, ++self->refresh_speed);
}

- (void) refreshSpeedAdd {
    if (self->refresh_speed <= 1) {
        self->refresh_speed = 6;
    }
    setControl(framebuffer, 0x0c, --self->refresh_speed);
}

- (void) lightIntensityAdd {
    if (self->light_level >= 85) {
        self->light_level = 255;
    }
    setControl(framebuffer, 0xD + 2, ++self->light_level * 3);
}

- (void) lightIntensitySubstract {
    if (self->light_level <= 0) {
        self->light_level = 86;
    }
    setControl(framebuffer, 0xD + 2, --self->light_level * 3);
}

- (void) lightIntensityToggle {
    if (self->light_level) {
        self->light_level = 0;
        setControl(framebuffer, 0xD + 2, self->light_level);
    } else {
        self->light_level = 1;
        setControl(framebuffer, 0xD + 2, self->light_level * 3);
    }
}

@end
