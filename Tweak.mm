@import UIKit;
#import <AppSupport/AppSupport.h>
#import "rocketbootstrap.h"

@interface PSListController  <UITextFieldDelegate>
@end

@interface FBSystemService
+(id)sharedInstance;
-(void) shutdownAndReboot:(bool)arg;
@end

static UITextField* field;
static NSString* deviceAdress;
static NSMutableDictionary* devices;
static NSDictionary* originalDevices;
static UIViewController *bluetoothController;

//prepare server to listen for reboot
%hook SpringBoard
-(id)init{
    self = %orig;
    CPDistributedMessagingCenter *c = [CPDistributedMessagingCenter centerNamed:@"com.alex.bluetoothrename"];
    rocketbootstrap_distributedmessagingcenter_apply(c);
    [c runServerOnCurrentThread];
    [c registerForMessageName:@"rebootAsked" target:self selector:@selector(rebootAsked)];
    return self;
}
%new
-(void)rebootAsked{
    if (kCFCoreFoundationVersionNumber >= 1280.30){    //test if it is iOS 9.3
        [[FBSystemService sharedInstance] shutdownAndReboot:YES];
    }
    else{
        [self performSelector:@selector(reboot)];
    }
}
%end

%hook PreferencesAppController
// get the BluetoothDevices list
-(BOOL)application:(id)arg1 didFinishLaunchingWithOptions:(id)arg2{
    devices= [[NSMutableDictionary alloc]initWithContentsOfFile: @"/var/mobile/Library/Preferences/com.apple.MobileBluetooth.devices.plist"];
    originalDevices= [[NSDictionary alloc]initWithDictionary:devices];
    return %orig;
}
%end

%hook UIViewController
-(void)viewDidLoad{
    %orig;
    if ([self.title isEqualToString:NSLocalizedString(@"BTMACAddress", @"Bluetooth")] && [[NSBundle mainBundle].bundleIdentifier isEqualToString: @"com.apple.Preferences"]){
        for (NSString* key in devices){
            if(![[originalDevices objectForKey:key] isEqualToDictionary:[devices objectForKey:key]]){
                UIBarButtonItem* rebootButton= [[UIBarButtonItem alloc]initWithTitle:@"Reboot"  style:UIBarButtonItemStyleDone target:self action:@selector(askReboot)];
                [self.navigationItem setRightBarButtonItem:rebootButton animated:YES];
                break;
            }
        }
        bluetoothController=self;
    }
}
-(void)viewWillDisappear:(BOOL)arg{
    %orig;
    if ([self.title isEqualToString:NSLocalizedString(@"BTMACAddress",@"Bluetooth")] && [[NSBundle mainBundle].bundleIdentifier isEqualToString: @"com.apple.Preferences"]){
        if (self.navigationItem.rightBarButtonItem){
            UIAlertController* alert = [UIAlertController alertControllerWithTitle:@"Reboot?"message:@"A reboot is needed to apply changes." preferredStyle:UIAlertControllerStyleAlert];
            UIAlertAction* defaultAction = [UIAlertAction actionWithTitle:@"Reboot" style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                    [self performSelector:@selector(askReboot)];}];
            UIAlertAction* cancelAction = [UIAlertAction actionWithTitle:@"Later" style:UIAlertActionStyleDefault handler:^(UIAlertAction * action){}];
            [alert addAction:cancelAction];
            [alert addAction:defaultAction];
            [[[[UIApplication sharedApplication] keyWindow]rootViewController] presentViewController:alert animated:YES completion:nil];
        }
    }
}
%new
-(void)askReboot{
    CPDistributedMessagingCenter* c = [CPDistributedMessagingCenter centerNamed:@"com.alex.bluetoothrename"];
    [devices writeToFile: @"/var/mobile/Library/Preferences/com.apple.MobileBluetooth.devices.plist" atomically:YES];
    rocketbootstrap_distributedmessagingcenter_apply(c);
    [c sendMessageName:@"rebootAsked" userInfo:nil];
}
%end

%hook UIResponder
// save changes made in the textfield
-(BOOL)resignFirstResponder{
    if([[NSBundle mainBundle].bundleIdentifier isEqualToString: @"com.apple.Preferences"]&& field.isFirstResponder){
        NSMutableDictionary* newDevice= [[NSMutableDictionary alloc]initWithDictionary:[devices objectForKey:deviceAdress]];
        if (deviceAdress){
            if(![field.text isEqualToString:@""]){
                [newDevice setObject: field.text forKey:@"Name"];
            }
            else{
                [newDevice setObject:[newDevice objectForKey:@"DefaultName"] forKey:@"Name"];
            }
            [devices setObject: newDevice forKey: deviceAdress];
        }
        ((UITableViewCell*)[[field superview]superview]).textLabel.alpha = 1.0;
        ((UITableViewCell*)[[field superview]superview]).textLabel.text=field.text;
        [field removeFromSuperview];
        UIBarButtonItem* rebootButton= [[UIBarButtonItem alloc]initWithTitle:@"Reboot"  style: UIBarButtonItemStyleDone target:bluetoothController action:@selector(askReboot)];
        [bluetoothController.navigationItem setRightBarButtonItem:rebootButton animated:YES];
    }
    return %orig;
}
%end

%hook PSListController
//Add UIGestureRecognizer on all BTTableCell representing a paired device
-(id)tableView:(id)arg1 cellForRowAtIndexPath:(NSIndexPath*)arg2{
    if ([%orig isKindOfClass:[objc_getClass("BTTableCell") class]]){
        UITapGestureRecognizer* gesture = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(beginEditName:)];
        [((UITableViewCell*)%orig).textLabel setUserInteractionEnabled:YES];
        [((UITableViewCell*)%orig).textLabel addGestureRecognizer: gesture];
    }
    return %orig;
}
%new
// Add a UITextField on the tapped cell and hide the cell's textLabel
-(void)beginEditName:(UIGestureRecognizer*)recognizer{
    UILabel*label= ((UILabel*)recognizer.view);
    for (NSString* key in devices){
        if ([label.text isEqualToString:[[devices objectForKey:key]objectForKey:@"Name"]]){
            deviceAdress = [[NSString alloc]initWithString:key];
        }
    }
    field=[[UITextField alloc]initWithFrame:label.frame];
    field.text =label.text;
    field.font =label.font;
    field.delegate = self;
    label.alpha= 0.0;
    [[label superview] addSubview: field];
    [field becomeFirstResponder];
}
%new
//implement the return key
-(BOOL)textFieldShouldReturn: (UITextField*) textField{
    [textField resignFirstResponder];
    return YES;
}
%end

%hook UITableView
//Force resign first responder if the user was in the UITextField during table'update (avoid crash)
-(void)_updateWithItems: (id) arg1 updateSupport: (id) arg2 {
    if(field && field.isFirstResponder){
        [field resignFirstResponder];
    }
    %orig;
}
%end