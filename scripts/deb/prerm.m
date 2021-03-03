#import <Foundation/Foundation.h>

@interface LSApplicationWorkspace : NSObject
    +(instancetype)defaultWorkspace;
    -(BOOL)uninstallApplication:(id)arg1 withOptions:(id)arg2;
@end

int main(int argc, char *argv[]) {
    if (argc == 1 || strcmp(argv[1], "upgrade") != 0) // If it's an upgrade, skip uninstalling the old package.
        [[LSApplicationWorkspace defaultWorkspace] uninstallApplication:@"com.utmapp.UTM" withOptions:nil];
    return 0;
}
