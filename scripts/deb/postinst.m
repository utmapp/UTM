#import <Foundation/Foundation.h>

@interface LSApplicationWorkspace : NSObject
    +(instancetype)defaultWorkspace;
    -(BOOL)installApplication:(id)arg1 withOptions:(id)arg2;
@end

int main() {
    [[LSApplicationWorkspace defaultWorkspace] installApplication:[NSURL fileURLWithPath:@"/Library/Caches/com.utmapp.UTM/UTM.ipa"] withOptions:[NSDictionary dictionaryWithObject:@"com.utmapp.UTM" forKey:@"CFBundleIdentifier"]]; // This function will remove the ipa file.
    return 0;
}
