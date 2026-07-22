#import "settings_vc.h"

#import <QuartzCore/QuartzCore.h>

#import "about_vc.h"
#import "tunetube_config.h"
#import "tunetube_theme.h"
#import "ytm_api.h"

@interface TuneSettingsChromeView : UIView {
    CAGradientLayer *_gradient;
    BOOL _selected;
}
- (id)initWithSelected:(BOOL)selected;
@end

@implementation TuneSettingsChromeView

- (id)initWithSelected:(BOOL)selected {
    self = [super initWithFrame:CGRectZero];
    if (!self) return nil;
    _selected = selected;
    self.layer.cornerRadius = 9.0f;
    self.layer.borderWidth = 1.0f;
    self.layer.borderColor = TuneThemeBorder().CGColor;
    _gradient = [[CAGradientLayer layer] retain];
    _gradient.cornerRadius = 9.0f;
    [self.layer insertSublayer:_gradient atIndex:0];
    return self;
}

- (void)dealloc {
    [_gradient release];
    [super dealloc];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    _gradient.frame = self.bounds;
    UIColor *top = _selected ? TuneThemeAccent() : TuneThemeSurfaceTop();
    UIColor *bottom = _selected ? TuneThemeHeader() : TuneThemeSurfaceBottom();
    _gradient.colors = [NSArray arrayWithObjects:(id)top.CGColor, (id)bottom.CGColor, nil];
}

@end

@implementation TuneSettingsVC

- (void)applyTheme:(NSNotification *)note {
    (void)note;
    self.view.backgroundColor = TuneThemeBackgroundBottom();
    self.navigationController.navigationBar.barStyle = TuneTubeThemeIsLight()
        ? UIBarStyleDefault : UIBarStyleBlack;
    self.navigationController.navigationBar.tintColor = TuneThemeAccent();
    self.navigationController.navigationBar.titleTextAttributes =
        [NSDictionary dictionaryWithObject:TuneThemePrimaryText()
                                     forKey:UITextAttributeTextColor];
    _backgroundGradient.colors = [NSArray arrayWithObjects:
                                  (id)TuneThemeBackgroundTop().CGColor,
                                  (id)TuneThemeBackgroundBottom().CGColor, nil];
    [_table reloadData];
}

- (void)backgroundAudioChanged:(UISwitch *)toggle {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setBool:toggle.on forKey:TUNETUBE_BACKGROUND_AUDIO_DEFAULTS_KEY];
    [defaults synchronize];
    [[NSNotificationCenter defaultCenter]
     postNotificationName:TUNETUBE_BACKGROUND_AUDIO_DID_CHANGE_NOTIFICATION object:nil];
}

- (void)themeChanged:(UISwitch *)toggle {
    TuneTubeThemeSetLight(toggle.on);
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_table release];
    [_backgroundGradient release];
    [super dealloc];
}

- (void)loadView {
    UIView *view = [[[UIView alloc] initWithFrame:[[UIScreen mainScreen] bounds]] autorelease];
    view.backgroundColor = TuneThemeBackgroundBottom();
    self.view = view;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Settings";
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applyTheme:)
                                                 name:TuneTubeThemeDidChangeNotification
                                               object:nil];
    self.navigationItem.leftBarButtonItem =
        [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                       target:self
                                                       action:@selector(donePressed)] autorelease];

    _backgroundGradient = [[CAGradientLayer layer] retain];
    _backgroundGradient.colors = [NSArray arrayWithObjects:
                                  (id)TuneThemeBackgroundTop().CGColor,
                                  (id)TuneThemeBackgroundBottom().CGColor, nil];
    _backgroundGradient.locations = [NSArray arrayWithObjects:@0.0f, @0.46f, @1.0f, nil];
    [self.view.layer insertSublayer:(CAGradientLayer *)_backgroundGradient atIndex:0];

    _table = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleGrouped];
    _table.dataSource = self;
    _table.delegate = self;
    _table.backgroundColor = [UIColor clearColor];
    _table.backgroundView = nil;
    _table.separatorStyle = UITableViewCellSeparatorStyleNone;
    _table.sectionHeaderHeight = 34.0f;
    _table.sectionFooterHeight = 8.0f;
    [self.view addSubview:_table];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    _backgroundGradient.frame = self.view.bounds;
    _table.frame = self.view.bounds;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self applyTheme:nil];
    [_table reloadData];
}

- (void)donePressed {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    (void)tableView;
    return 4;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    (void)tableView;
    if (section == 0) return 2;
    if (section == 1) return 2;
    return 1;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    (void)tableView; (void)section;
    return 34.0f;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    (void)tableView;
    UIView *header = [[[UIView alloc] initWithFrame:CGRectZero] autorelease];
    header.backgroundColor = [UIColor clearColor];

    UILabel *label = [[[UILabel alloc] initWithFrame:CGRectZero] autorelease];
    label.backgroundColor = [UIColor clearColor];
    label.textColor = TuneThemeAccent();
    label.font = [UIFont boldSystemFontOfSize:11.0f];
    if (section == 0) label.text = @"PLAYBACK";
    else if (section == 1) label.text = @"SEARCH";
    else if (section == 2) label.text = @"APPEARANCE";
    else label.text = @"TUNETUBE";
    label.frame = CGRectMake(22.0f, 12.0f, 260.0f, 18.0f);
    [header addSubview:label];
    return header;
}

- (UIView *)darkCellBackground:(BOOL)selected {
    return [[[TuneSettingsChromeView alloc] initWithSelected:selected] autorelease];
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellID = @"TuneTubeSettingsCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellID];
    if (!cell)
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
                                       reuseIdentifier:cellID] autorelease];

    cell.backgroundColor = [UIColor clearColor];
    cell.backgroundView = [self darkCellBackground:NO];
    cell.selectedBackgroundView = [self darkCellBackground:YES];
    cell.textLabel.textColor = TuneThemePrimaryText();
    cell.textLabel.font = [UIFont boldSystemFontOfSize:14.0f];
    cell.detailTextLabel.textColor = TuneThemeSecondaryText();
    cell.detailTextLabel.font = [UIFont systemFontOfSize:12.0f];
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.accessoryView = nil;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;

    if (indexPath.section == 0) {
        if (indexPath.row == 0) {
            cell.textLabel.text = @"Background audio";
            cell.detailTextLabel.text = nil;
            UISwitch *toggle = [[[UISwitch alloc] initWithFrame:CGRectZero] autorelease];
            id value = [[NSUserDefaults standardUserDefaults]
                        objectForKey:TUNETUBE_BACKGROUND_AUDIO_DEFAULTS_KEY];
            toggle.on = !value || [value boolValue];
            toggle.onTintColor = TuneThemeAccent();
            [toggle addTarget:self action:@selector(backgroundAudioChanged:)
             forControlEvents:UIControlEventValueChanged];
            cell.accessoryView = toggle;
        } else {
            cell.textLabel.text = @"Player mode";
            cell.detailTextLabel.text = @"Anonymous";
        }
    } else if (indexPath.section == 1) {
        NSString *customKey = [[NSUserDefaults standardUserDefaults]
                                objectForKey:TUNETUBE_API_KEY_DEFAULTS_KEY];
        if (indexPath.row == 0) {
            cell.textLabel.text = @"YouTube Music API key";
            cell.detailTextLabel.text = customKey.length ? @"Custom" : @"Built-in";
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            cell.selectionStyle = UITableViewCellSelectionStyleBlue;
        } else {
            cell.textLabel.text = @"Reset API key";
            cell.detailTextLabel.text = customKey.length ? @"Use built-in key" : @"Already default";
            cell.accessoryType = customKey.length
                ? UITableViewCellAccessoryDisclosureIndicator : UITableViewCellAccessoryNone;
            cell.selectionStyle = customKey.length
                ? UITableViewCellSelectionStyleBlue : UITableViewCellSelectionStyleNone;
        }
    } else if (indexPath.section == 2) {
        cell.textLabel.text = @"Light theme";
        cell.detailTextLabel.text = nil;
        UISwitch *toggle = [[[UISwitch alloc] initWithFrame:CGRectZero] autorelease];
        toggle.on = TuneTubeThemeIsLight();
        toggle.onTintColor = TuneThemeAccent();
        [toggle addTarget:self action:@selector(themeChanged:)
         forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = toggle;
    } else {
        cell.textLabel.text = @"About TuneTube";
        cell.detailTextLabel.text = TUNETUBE_VERSION;
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.selectionStyle = UITableViewCellSelectionStyleBlue;
    }
    return cell;
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
    (void)tableView;
    if (section != 3) return nil;
    UILabel *footer = [[[UILabel alloc] initWithFrame:CGRectZero] autorelease];
    footer.backgroundColor = [UIColor clearColor];
    footer.textColor = TuneThemeMutedText();
    footer.font = [UIFont systemFontOfSize:11.0f];
    footer.numberOfLines = 0;
    footer.textAlignment = NSTextAlignmentCenter;
    footer.text = @"Youtube Music for the legacy communitty :D";
    return footer;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    (void)tableView;
    return section == 3 ? 38.0f : 8.0f;
}

- (void)showAPIKeyEditor {
    UIAlertView *alert = [[[UIAlertView alloc] initWithTitle:@"YouTube Music API key"
                                                     message:@"Leave empty to use the built-in key."
                                                    delegate:self
                                           cancelButtonTitle:@"Cancel"
                                           otherButtonTitles:@"Save", nil] autorelease];
    alert.alertViewStyle = UIAlertViewStylePlainTextInput;
    UITextField *field = [alert textFieldAtIndex:0];
    field.text = [[NSUserDefaults standardUserDefaults]
                  objectForKey:TUNETUBE_API_KEY_DEFAULTS_KEY];
    field.autocapitalizationType = UITextAutocapitalizationTypeNone;
    field.autocorrectionType = UITextAutocorrectionTypeNo;
    field.keyboardType = UIKeyboardTypeASCIICapable;
    [alert show];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex != alertView.firstOtherButtonIndex) return;
    NSString *key = [[alertView textFieldAtIndex:0].text
                     stringByTrimmingCharactersInSet:
                     [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if (key.length)
        [defaults setObject:key forKey:TUNETUBE_API_KEY_DEFAULTS_KEY];
    else
        [defaults removeObjectForKey:TUNETUBE_API_KEY_DEFAULTS_KEY];
    [defaults synchronize];
    [_table reloadData];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section == 1 && indexPath.row == 0) {
        [self showAPIKeyEditor];
    } else if (indexPath.section == 1 && indexPath.row == 1) {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:TUNETUBE_API_KEY_DEFAULTS_KEY];
        [[NSUserDefaults standardUserDefaults] synchronize];
        [tableView reloadData];
    } else if (indexPath.section == 3) {
        TuneAboutVC *about = [[[TuneAboutVC alloc] init] autorelease];
        [self.navigationController pushViewController:about animated:YES];
    }
}

@end
