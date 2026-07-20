#import "settings_vc.h"

#import <QuartzCore/QuartzCore.h>

#import "about_vc.h"
#import "tuntube_config.h"
#import "ytm_api.h"

static UIColor *SettingsColor(CGFloat red, CGFloat green, CGFloat blue, CGFloat alpha) {
    return [UIColor colorWithRed:red green:green blue:blue alpha:alpha];
}

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
    self.layer.borderColor = SettingsColor(0.28f, 0.48f, 0.49f, 0.4f).CGColor;
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
    UIColor *top = _selected ? SettingsColor(0.28f, 0.07f, 0.06f, 1.0f)
                             : SettingsColor(0.11f, 0.18f, 0.19f, 1.0f);
    UIColor *bottom = _selected ? SettingsColor(0.15f, 0.03f, 0.03f, 1.0f)
                                : SettingsColor(0.05f, 0.09f, 0.10f, 1.0f);
    _gradient.colors = [NSArray arrayWithObjects:(id)top.CGColor, (id)bottom.CGColor, nil];
}

@end

@implementation TuneSettingsVC

- (void)dealloc {
    [_table release];
    [_backgroundGradient release];
    [super dealloc];
}

- (void)loadView {
    UIView *view = [[[UIView alloc] initWithFrame:[[UIScreen mainScreen] bounds]] autorelease];
    view.backgroundColor = SettingsColor(0.02f, 0.06f, 0.08f, 1.0f);
    self.view = view;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Settings";
    self.navigationController.navigationBar.barStyle = UIBarStyleBlack;
    self.navigationController.navigationBar.tintColor = SettingsColor(0.77f, 0.06f, 0.05f, 1.0f);
    self.navigationController.navigationBar.titleTextAttributes =
        [NSDictionary dictionaryWithObject:[UIColor whiteColor]
                                     forKey:UITextAttributeTextColor];
    self.navigationItem.leftBarButtonItem =
        [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                       target:self
                                                       action:@selector(donePressed)] autorelease];

    _backgroundGradient = [[CAGradientLayer layer] retain];
    _backgroundGradient.colors = [NSArray arrayWithObjects:
                                  (id)SettingsColor(0.03f, 0.20f, 0.22f, 1.0f).CGColor,
                                  (id)SettingsColor(0.02f, 0.06f, 0.08f, 1.0f).CGColor,
                                  (id)SettingsColor(0.01f, 0.02f, 0.03f, 1.0f).CGColor, nil];
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
    [_table reloadData];
}

- (void)donePressed {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    (void)tableView;
    return 3;
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
    label.textColor = SettingsColor(0.63f, 0.80f, 0.80f, 1.0f);
    label.font = [UIFont boldSystemFontOfSize:11.0f];
    label.text = section == 0 ? @"PLAYBACK" : (section == 1 ? @"SEARCH" : @"TUNETUBE");
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
    cell.textLabel.textColor = [UIColor whiteColor];
    cell.textLabel.font = [UIFont boldSystemFontOfSize:14.0f];
    cell.detailTextLabel.textColor = SettingsColor(0.70f, 0.82f, 0.81f, 1.0f);
    cell.detailTextLabel.font = [UIFont systemFontOfSize:12.0f];
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;

    if (indexPath.section == 0) {
        if (indexPath.row == 0) {
            cell.textLabel.text = @"Background audio";
            cell.detailTextLabel.text = @"Enabled";
        } else {
            cell.textLabel.text = @"Player mode";
            cell.detailTextLabel.text = @"Anonymous";
        }
    } else if (indexPath.section == 1) {
        NSString *customKey = [[NSUserDefaults standardUserDefaults]
                                objectForKey:TUNTUBE_API_KEY_DEFAULTS_KEY];
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
    } else {
        cell.textLabel.text = @"About TuneTube";
        cell.detailTextLabel.text = TUNTUBE_VERSION;
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.selectionStyle = UITableViewCellSelectionStyleBlue;
    }
    return cell;
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
    (void)tableView;
    if (section != 2) return nil;
    UILabel *footer = [[[UILabel alloc] initWithFrame:CGRectZero] autorelease];
    footer.backgroundColor = [UIColor clearColor];
    footer.textColor = SettingsColor(0.46f, 0.62f, 0.63f, 1.0f);
    footer.font = [UIFont systemFontOfSize:11.0f];
    footer.numberOfLines = 0;
    footer.textAlignment = NSTextAlignmentCenter;
    footer.text = @"Youtube Music for the legacy communitty :D";
    return footer;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    (void)tableView;
    return section == 2 ? 38.0f : 8.0f;
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
                  objectForKey:TUNTUBE_API_KEY_DEFAULTS_KEY];
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
        [defaults setObject:key forKey:TUNTUBE_API_KEY_DEFAULTS_KEY];
    else
        [defaults removeObjectForKey:TUNTUBE_API_KEY_DEFAULTS_KEY];
    [defaults synchronize];
    [_table reloadData];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section == 1 && indexPath.row == 0) {
        [self showAPIKeyEditor];
    } else if (indexPath.section == 1 && indexPath.row == 1) {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:TUNTUBE_API_KEY_DEFAULTS_KEY];
        [[NSUserDefaults standardUserDefaults] synchronize];
        [tableView reloadData];
    } else if (indexPath.section == 2) {
        TuneAboutVC *about = [[[TuneAboutVC alloc] init] autorelease];
        [self.navigationController pushViewController:about animated:YES];
    }
}

@end
