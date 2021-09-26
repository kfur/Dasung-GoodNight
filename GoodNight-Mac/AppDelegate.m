//
//  AppDelegate.m
//  GoodNight-Mac
//
//  Created by Anthony Agatiello on 11/17/16.
//  Copyright © 2016 ADA Tech, LLC. All rights reserved.
//

#import "AppDelegate.h"
#import "MacGammaController.h"
#import "TemperatureViewController.h"

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Insert code here to initialize your application
    
    [self createMenuItems];
    [self registerDefaultValues];
    [self restoreGammaValues];
    [self setShortcutObservers];
    
    self.dd = [[DasungDisplay alloc] init];
//    [self.dd refresh];
    [self enableDasungDisplayShortcuts];
    
    [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector:@selector(restoreGammaValues) name:NSWorkspaceDidWakeNotification object:nil];
    [[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(restoreGammaValues) name:@"com.apple.screensaver.didstop" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(restoreGammaValues) name:NSApplicationDidChangeScreenParametersNotification object:nil];
}

- (void)createMenuItems {
    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    self.statusItem.image = [NSImage imageNamed:@"menu"];
    [self.statusItem setHighlightMode:YES];
    
    self.statusMenu = [[NSMenu alloc] init];
    
    NSMenuItem *titleItem = [[NSMenuItem alloc] initWithTitle:@"GoodNight" action:nil keyEquivalent:@""];
    
    NSString *appVersionString = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    NSMenuItem *versionItem = [[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:@"Version %@", appVersionString] action:nil keyEquivalent:@""];
    
    NSMenuItem *aboutItem = [[NSMenuItem alloc] initWithTitle:@"About GoodNight..." action:@selector(openAboutWindow) keyEquivalent:@""];
    NSMenuItem *updateItem = [[NSMenuItem alloc] initWithTitle:@"Check for Updates..." action:@selector(checkForUpdateMenuAction) keyEquivalent:@""];

    self.loginItem = [[NSMenuItem alloc] initWithTitle:@"Start at Login" action:@selector(setStartAtLoginEnabled) keyEquivalent:@""];
    [self.loginItem setState:self.willStartAtLogin];
    
    NSMenuItem *resetItem = [[NSMenuItem alloc] initWithTitle:@"Reset All" action:@selector(resetAll) keyEquivalent:@"r"];
    [resetItem setKeyEquivalentModifierMask:GoodNightModifierFlags];
    
    NSMenuItem *darkroomItem = [[NSMenuItem alloc] initWithTitle:@"Toggle Darkroom" action:@selector(toggleDarkroom) keyEquivalent:@"x"];
    [darkroomItem setKeyEquivalentModifierMask:GoodNightModifierFlags];
    
    NSMenuItem *darkThemeItem = [[NSMenuItem alloc] initWithTitle:@"Toggle Dark Theme" action:@selector(menuToggleSystemTheme) keyEquivalent:@"t"];
    [darkThemeItem setKeyEquivalentModifierMask:GoodNightModifierFlags];
    
    
    NSMenuItem *openItem = [[NSMenuItem alloc] initWithTitle:@"Open..." action:@selector(openNewWindow) keyEquivalent:@"g"];
    [openItem setKeyEquivalentModifierMask:GoodNightModifierFlags];
    
    NSMenuItem *closeWindowItem = [[NSMenuItem alloc] initWithTitle:@"Close" action:@selector(performClose:) keyEquivalent:@"w"];
    NSMenuItem *quitItem = [[NSMenuItem alloc] initWithTitle:@"Quit" action:@selector(terminate:) keyEquivalent:@"q"];
    
    [self.statusMenu addItem:titleItem];
    [self.statusMenu addItem:versionItem];
    
    [self initSeperatorItem];
    [self.statusMenu addItem:self.seperatorItem];
    
    [self.statusMenu addItem:aboutItem];
    [self.statusMenu addItem:updateItem];
    
    [self initSeperatorItem];
    [self.statusMenu addItem:self.seperatorItem];
    
    [self.statusMenu addItem:self.loginItem];
    
    [self initSeperatorItem];
    [self.statusMenu addItem:self.seperatorItem];
    
    [self.statusMenu addItem:resetItem];
    [self.statusMenu addItem:darkroomItem];
    [self.statusMenu addItem:darkThemeItem];
    
    [self initSeperatorItem];
    [self.statusMenu addItem:self.seperatorItem];
    
    [self.statusMenu addItem:openItem];
    [self.statusMenu addItem:closeWindowItem];
    [self.statusMenu addItem:quitItem];
    
    [self.statusItem setMenu:self.statusMenu];
}

- (void)initSeperatorItem {
    self.seperatorItem = nil;
    self.seperatorItem = [NSMenuItem separatorItem];
}

- (BOOL)willStartAtLogin {
    BOOL willStartAtLogin = NO;
    LSSharedFileListRef loginItems = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
    
    if (loginItems) {
        UInt32 seed = 0;
        NSArray *currentLoginItems = (__bridge NSArray *)(LSSharedFileListCopySnapshot(loginItems, &seed));
        
        for (id itemObject in currentLoginItems) {
            LSSharedFileListItemRef item = (__bridge LSSharedFileListItemRef)itemObject;
            UInt32 resolutionFlags = kLSSharedFileListNoUserInteraction | kLSSharedFileListDoNotMountVolumes;
            CFErrorRef err = noErr;
            CFURLRef URL = LSSharedFileListItemCopyResolvedURL(item, resolutionFlags, &err);
            
            if (err == noErr) {
                willStartAtLogin = CFEqual(URL, (__bridge CFTypeRef)([[NSBundle mainBundle] bundleURL]));
                CFRelease(URL);
                
                if (willStartAtLogin) {
                    break;
                }
            }
        }
        CFRelease(loginItems);
    }
    return willStartAtLogin;
}

- (void)setStartAtLoginEnabled {
    LSSharedFileListItemRef existingItem = NULL;
    LSSharedFileListRef loginItems = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
    
    if (loginItems) {
        UInt32 seed = 0;
        NSArray *currentLoginItems = (__bridge NSArray *)(LSSharedFileListCopySnapshot(loginItems, &seed));
        
        for (id itemObject in currentLoginItems) {
            LSSharedFileListItemRef item = (__bridge LSSharedFileListItemRef)itemObject;
            UInt32 resolutionFlags = kLSSharedFileListNoUserInteraction | kLSSharedFileListDoNotMountVolumes;
            CFErrorRef err = noErr;
            CFURLRef URL = LSSharedFileListItemCopyResolvedURL(item, resolutionFlags, &err);
            
            if (err == noErr) {
                BOOL willStartAtLogin = CFEqual(URL, (__bridge CFURLRef)([[NSBundle mainBundle] bundleURL]));
                CFRelease(URL);
                
                if (willStartAtLogin) {
                    existingItem = item;
                    break;
                }
            }
        }
        
        if (!self.willStartAtLogin && (existingItem == NULL)) {
            LSSharedFileListInsertItemURL(loginItems, kLSSharedFileListItemBeforeFirst, NULL, NULL, (__bridge CFURLRef)[[NSBundle mainBundle] bundleURL], NULL, NULL);
            
        }
        else if (self.willStartAtLogin && (existingItem != NULL)) {
            LSSharedFileListItemRemove(loginItems, existingItem);
        }
        
        CFRelease(loginItems);
    }
    
    [self.loginItem setState:self.willStartAtLogin];
}

- (void)registerDefaultValues {
    float defaultValue = 1.0;
    float defaultOrangeValue = 0.0;
    BOOL defaultBooleanValue = NO;
    
    NSDictionary *defaultValues = @{@"orangeValue":     @(defaultOrangeValue),
                                    @"darkroomEnabled": @(defaultBooleanValue),
                                    @"alertShowed":     @(defaultBooleanValue),
                                    @"brightnessValue": @(defaultValue),
                                    @"darkThemeEnabled":@(defaultBooleanValue),
                                    @"whitePointValue": @(defaultValue),
                                    MASOpenShortcutEnabledKey:      @YES,
                                    MASResetShortcutEnabledKey:     @YES,
                                    MASDarkroomShortcutEnabledKey:  @YES,
                                    MASDarkThemeShortcutEnabledKey: @YES};
    
    [userDefaults registerDefaults:defaultValues];
}

- (void)restoreGammaValues {
    float orangeValue = [userDefaults floatForKey:@"orangeValue"];
    if (orangeValue != 0) {
        [MacGammaController setGammaWithOrangeness:[userDefaults floatForKey:@"orangeValue"]];
    }
    
    float brightnessValue = [userDefaults floatForKey:@"brightnessValue"];
    if (brightnessValue != 1) {
        [MacGammaController setGammaWithRed:brightnessValue green:brightnessValue blue:brightnessValue];
    }
    
    float whitePointValue = [userDefaults floatForKey:@"whitePointValue"];
    if (whitePointValue != 0.5) {
        [MacGammaController setWhitePoint:whitePointValue];
    }
}

- (void)setShortcutObservers {
    [userDefaults addObserver:self forKeyPath:MASOpenShortcutEnabledKey options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew context:MASObservingContext];
    [userDefaults addObserver:self forKeyPath:MASResetShortcutEnabledKey options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew context:MASObservingContext];
    [userDefaults addObserver:self forKeyPath:MASDarkroomShortcutEnabledKey options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew context:MASObservingContext];
    [userDefaults addObserver:self forKeyPath:MASDarkThemeShortcutEnabledKey options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew context:MASObservingContext];
}

- (void)menuToggleSystemTheme {
    [MacGammaController toggleSystemTheme];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (context != MASObservingContext) {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
        return;
    }
    
    BOOL newValue = [[change objectForKey:NSKeyValueChangeNewKey] boolValue];
    
    if ([keyPath isEqualToString:MASOpenShortcutEnabledKey]) {
        [self setOpenShortcutEnabled:newValue];
    }
    if ([keyPath isEqualToString:MASResetShortcutEnabledKey]) {
        [self setResetShortcutEnabled:newValue];
    }
    if ([keyPath isEqualToString:MASDarkroomShortcutEnabledKey]) {
        [self setDarkroomShortcutEnabled:newValue];
    }
    if ([keyPath isEqualToString:MASDarkThemeShortcutEnabledKey]) {
        [self setSystemThemeShortcutEnabled:newValue];
    }
}

- (void)setOpenShortcutEnabled:(BOOL)enabled {
    MASShortcut *shortcut = [MASShortcut shortcutWithKeyCode:kVK_ANSI_G modifierFlags:GoodNightModifierFlags];
    if (enabled) {
        [[MASShortcutMonitor sharedMonitor] registerShortcut:shortcut withAction:^{
            [self openNewWindow];
        }];
    }
    else {
        [[MASShortcutMonitor sharedMonitor] unregisterShortcut:shortcut];
    }
}

- (void)setResetShortcutEnabled:(BOOL)enabled {
    MASShortcut *shortcut = [MASShortcut shortcutWithKeyCode:kVK_ANSI_R modifierFlags:GoodNightModifierFlags];
    if (enabled) {
        [[MASShortcutMonitor sharedMonitor] registerShortcut:shortcut withAction:^{
            [self resetAll];
        }];
    }
    else {
        [[MASShortcutMonitor sharedMonitor] unregisterShortcut:shortcut];
    }
}

- (void)setDarkroomShortcutEnabled:(BOOL)enabled {
    MASShortcut *shortcut = [MASShortcut shortcutWithKeyCode:kVK_ANSI_X modifierFlags:GoodNightModifierFlags];
    if (enabled) {
        [[MASShortcutMonitor sharedMonitor] registerShortcut:shortcut withAction:^{
            [self toggleDarkroom];
        }];
    }
    else {
        [[MASShortcutMonitor sharedMonitor] unregisterShortcut:shortcut];
    }
}

- (void)setSystemThemeShortcutEnabled:(BOOL)enabled {
    MASShortcut *shortcut = [MASShortcut shortcutWithKeyCode:kVK_ANSI_T modifierFlags:GoodNightModifierFlags];
    if (enabled) {
        [[MASShortcutMonitor sharedMonitor] registerShortcut:shortcut withAction:^{
            [MacGammaController toggleSystemTheme];
        }];
    }
    else {
        [[MASShortcutMonitor sharedMonitor] unregisterShortcut:shortcut];
    }
}

- (void)enableDasungDisplayShortcuts {
    MASShortcut *shortcut = [MASShortcut shortcutWithKeyCode:kVK_ANSI_C modifierFlags:NSEventModifierFlagCommand | NSEventModifierFlagOption | NSEventModifierFlagControl];
    [[MASShortcutMonitor sharedMonitor] registerShortcut:shortcut withAction:^{
        if (![[self dd] displayFound]) {
            [[self dd] findDisplay];
        }
        [self.dd refresh];
    }];
    
    shortcut = [MASShortcut shortcutWithKeyCode:kVK_ANSI_Comma modifierFlags:NSEventModifierFlagCommand | NSEventModifierFlagOption | NSEventModifierFlagControl];
    [[MASShortcutMonitor sharedMonitor] registerShortcut:shortcut withAction:^{
        if (![[self dd] displayFound]) {
            [[self dd] findDisplay];
        }
        [self.dd contrastSubstract];
    }];
    
    shortcut = [MASShortcut shortcutWithKeyCode:kVK_ANSI_Period modifierFlags:NSEventModifierFlagCommand | NSEventModifierFlagOption | NSEventModifierFlagControl];
    [[MASShortcutMonitor sharedMonitor] registerShortcut:shortcut withAction:^{
        if (![[self dd] displayFound]) {
            [[self dd] findDisplay];
        }
        [self.dd contrastAdd];
    }];
    
    shortcut = [MASShortcut shortcutWithKeyCode:kVK_ANSI_M modifierFlags:NSEventModifierFlagCommand | NSEventModifierFlagOption | NSEventModifierFlagControl];
    [[MASShortcutMonitor sharedMonitor] registerShortcut:shortcut withAction:^{
        if (![[self dd] displayFound]) {
            [[self dd] findDisplay];
        }
        [self.dd mModeChange];
    }];
    
    shortcut = [MASShortcut shortcutWithKeyCode:kVK_ANSI_Equal modifierFlags:NSEventModifierFlagCommand | NSEventModifierFlagOption | NSEventModifierFlagControl];
    [[MASShortcutMonitor sharedMonitor] registerShortcut:shortcut withAction:^{
        if (![[self dd] displayFound]) {
            [[self dd] findDisplay];
        }
        [self.dd refreshSpeedAdd];
    }];
    
    shortcut = [MASShortcut shortcutWithKeyCode:kVK_ANSI_Minus modifierFlags:NSEventModifierFlagCommand | NSEventModifierFlagOption | NSEventModifierFlagControl];
    [[MASShortcutMonitor sharedMonitor] registerShortcut:shortcut withAction:^{
        if (![[self dd] displayFound]) {
            [[self dd] findDisplay];
        }
        [self.dd refreshSpeedSubstract];
    }];
    
    shortcut = [MASShortcut shortcutWithKeyCode:kVK_ANSI_LeftBracket modifierFlags:NSEventModifierFlagCommand | NSEventModifierFlagOption | NSEventModifierFlagControl];
    [[MASShortcutMonitor sharedMonitor] registerShortcut:shortcut withAction:^{
        if (![[self dd] displayFound]) {
            [[self dd] findDisplay];
        }
        [self.dd lightIntensitySubstract];
    }];
    
    shortcut = [MASShortcut shortcutWithKeyCode:kVK_ANSI_RightBracket modifierFlags:NSEventModifierFlagCommand | NSEventModifierFlagOption | NSEventModifierFlagControl];
    [[MASShortcutMonitor sharedMonitor] registerShortcut:shortcut withAction:^{
        if (![[self dd] displayFound]) {
            [[self dd] findDisplay];
        }
        [self.dd lightIntensityAdd];
    }];
    
    shortcut = [MASShortcut shortcutWithKeyCode:kVK_ANSI_Backslash modifierFlags:NSEventModifierFlagCommand | NSEventModifierFlagOption | NSEventModifierFlagControl];
    [[MASShortcutMonitor sharedMonitor] registerShortcut:shortcut withAction:^{
        if (![[self dd] displayFound]) {
            [[self dd] findDisplay];
        }
        [self.dd lightIntensityToggle];
    }];
    
    shortcut = [MASShortcut shortcutWithKeyCode:kVK_ANSI_I modifierFlags:NSEventModifierFlagCommand | NSEventModifierFlagOption | NSEventModifierFlagControl];
    [[MASShortcutMonitor sharedMonitor] registerShortcut:shortcut withAction:^{
        if (![[self dd] displayFound]) {
            [[self dd] findDisplay];
        }
        [[self dd] setUpDefaultSettings];
    }];
}

- (void)checkForUpdateMenuAction {
    [[[SUUpdater alloc] init] checkForUpdates:nil];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
    
    if ([userDefaults boolForKey:@"darkroomEnabled"]) {
        [self toggleDarkroom];
    }
}

- (void)resetAll {
    [MacGammaController resetAllAdjustments];
}

- (void)toggleDarkroom {
    [MacGammaController toggleDarkroom];
}

- (void)openAboutWindow {
    self.aboutWindowController = [[NSStoryboard storyboardWithName:@"Main" bundle:nil] instantiateControllerWithIdentifier:@"aboutWC"];
    [self.aboutWindowController.window setAppearance:[NSAppearance appearanceNamed:NSAppearanceNameVibrantDark]];
    [self.aboutWindowController showWindow:nil];
    [self.aboutWindowController.window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
}

- (void)openNewWindow {
    self.tabWindowController = [[NSStoryboard storyboardWithName:@"Main" bundle:nil] instantiateControllerWithIdentifier:@"windowController"];
    [self.tabWindowController showWindow:nil];
    [self.tabWindowController.window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
}

@end
