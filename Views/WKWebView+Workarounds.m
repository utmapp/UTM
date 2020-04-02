//
// Copyright © 2020 osy. All rights reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

#import "WKWebView+Workarounds.h"
#import <objc/runtime.h>

static char elementDidFocusImpKey;
static char inputAccessoryViewKey;

@implementation WKWebView (FocusWorkaround)

#pragma mark - Element focus workaround

- (IMP)elementDidFocusOriginalImplementation {
    NSValue* value = objc_getAssociatedObject(self, &elementDidFocusImpKey);
    if (value != nil) {
        return (IMP) [value pointerValue];
    } else {
        return NULL;
    }
}

- (void)setElementDidFocusOriginalImplementation: (IMP) implementation {
    NSValue* value = [NSValue valueWithPointer: (void*)implementation];
    objc_setAssociatedObject(self, &elementDidFocusImpKey, value, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

/**
    Workaround for `keyboardDisplayRequiresUserAction` from UIWebView.
    Source: https://stackoverflow.com/a/48623286
 */
- (void)toggleKeyboardDisplayRequiresUserAction:(BOOL)value {
    Class class = NSClassFromString(@"WKContentView");
    NSOperatingSystemVersion iOS_11_3_0 = (NSOperatingSystemVersion){11, 3, 0};
    NSOperatingSystemVersion iOS_12_2_0 = (NSOperatingSystemVersion){12, 2, 0};
    NSOperatingSystemVersion iOS_13_0_0 = (NSOperatingSystemVersion){13, 0, 0};
    
    if ([[NSProcessInfo processInfo] isOperatingSystemAtLeastVersion: iOS_13_0_0]) {
        SEL selector = sel_getUid("_elementDidFocus:userIsInteracting:blurPreviousNode:activityStateChanges:userObject:");
        Method method = class_getInstanceMethod(class, selector);
        IMP original = [self originalImplementationOf: method];
        
        IMP override;
        if (!value) {
            // tweaked implementation
            override = imp_implementationWithBlock(^void(id me, void* arg0, BOOL arg1, BOOL arg2, BOOL arg3, id arg4) {
                ((void (*)(id, SEL, void*, BOOL, BOOL, BOOL, id))original)(me, selector, arg0, TRUE, arg2, arg3, arg4);
            });
        } else {
            // original implementation
            override = original;
        }
        method_setImplementation(method, override);
    }
    else if ([[NSProcessInfo processInfo] isOperatingSystemAtLeastVersion: iOS_12_2_0]) {
        SEL selector = sel_getUid("_elementDidFocus:userIsInteracting:blurPreviousNode:changingActivityState:userObject:");
        Method method = class_getInstanceMethod(class, selector);
        IMP original = [self originalImplementationOf: method];
        
        IMP override;
        if (!value) {
            // tweaked implementation
            override = imp_implementationWithBlock(^void(id me, void* arg0, BOOL arg1, BOOL arg2, BOOL arg3, id arg4) {
                ((void (*)(id, SEL, void*, BOOL, BOOL, BOOL, id))original)(me, selector, arg0, !value, arg2, arg3, arg4);
            });
        } else {
            // original implementation
            override = original;
        }
        method_setImplementation(method, override);
    }
    else if ([[NSProcessInfo processInfo] isOperatingSystemAtLeastVersion: iOS_11_3_0]) {
        SEL selector = sel_getUid("_startAssistingNode:userIsInteracting:blurPreviousNode:changingActivityState:userObject:");
        Method method = class_getInstanceMethod(class, selector);
        IMP original = [self originalImplementationOf: method];
        
        IMP override;
        if (!value) {
            // tweaked implementation
            override = imp_implementationWithBlock(^void(id me, void* arg0, BOOL arg1, BOOL arg2, BOOL arg3, id arg4) {
                ((void (*)(id, SEL, void*, BOOL, BOOL, BOOL, id))original)(me, selector, arg0, !value, arg2, arg3, arg4);
            });
        } else {
            // back to original implementation
            override = original;
        }
        method_setImplementation(method, override);
    } else {
        SEL selector = sel_getUid("_startAssistingNode:userIsInteracting:blurPreviousNode:userObject:");
        Method method = class_getInstanceMethod(class, selector);
        IMP original = [self originalImplementationOf: method];
        
        IMP override;
        if (!value) {
            // tweaked implementation
            override = imp_implementationWithBlock(^void(id me, void* arg0, BOOL arg1, BOOL arg2, id arg3) {
                ((void (*)(id, SEL, void*, BOOL, BOOL, id))original)(me, selector, arg0, !value, arg2, arg3);
            });
        } else {
            // original implementation
            override = original;
        }
        method_setImplementation(method, override);
    }
}

- (IMP)originalImplementationOf: (Method) method {
    static BOOL originalInitialized = NO;
    @synchronized (self) {
        IMP original;
        if (!originalInitialized) {
            original = method_getImplementation(method);
            [self setElementDidFocusOriginalImplementation: original];
            originalInitialized = YES;
        } else {
            original = [self elementDidFocusOriginalImplementation];
        }
        
        return original;
    }
}

#pragma mark - Input accessory view workaround

/**
    Sets input accessory view as associated objects and does method swizzling on WKContentView
 */
- (void)setCustomInputAccessoryView:(UIView *)view {
    objc_setAssociatedObject(self, &inputAccessoryViewKey, view, OBJC_ASSOCIATION_RETAIN);
    
    // find WKContentView in webview subviews
    UIView* targetView;
    for (UIView* view in self.scrollView.subviews) {
        if ([NSStringFromClass([view class]) hasPrefix: @"WKContent"]) {
            targetView = view;
            NSLog(@"View class: %@", NSStringFromClass([targetView class]));
            break;
        }
    }
    
    NSAssert(targetView != nil, @"WKContentView not found!");
    [self plugInInputAccessoryView:targetView];
}

/**
    Although WebKit allows to subclass WKWebView to provide custom input accessory, it works only on iOS 13+.
    To keep compatibility, workaround is needed, swaping implementation of WKContentView using objc runtime.
 */
- (void)plugInInputAccessoryView:(UIView*)contentView {
    // check if swizzwling was already done
    if ([NSStringFromClass([contentView class]) hasSuffix: @"VMKeyboardView"]) {
        return;
    }
    
    NSString* customClassName = [NSString stringWithFormat:@"%@_VMKeyboardView", NSStringFromClass([contentView class])];
    Class customClass = NSClassFromString(customClassName);
    if (customClass == nil) {
        // create WKContentView subclass
        Class targetClass = [contentView class];
        customClass = objc_allocateClassPair(targetClass, [customClassName UTF8String], 0);

        if (customClass != nil) {
            objc_registerClassPair(customClass);
        }
    }
    
    NSAssert(customClass != nil, @"Custom WKContentView class was not created");
    // add custom implemenation from this VC
    Method customInputAccessoryViewGetter = class_getInstanceMethod([self class], @selector(customInputAccessoryView));
    class_addMethod(customClass,
                    @selector(inputAccessoryView),
                    method_getImplementation(customInputAccessoryViewGetter),
                    method_getTypeEncoding(customInputAccessoryViewGetter));
    // swap class of original view
    object_setClass(contentView, customClass);
}

/**
    This is called from WKContentView, so to access associated object, we need to move up
    through hierarchy to find parent WKWebView
 */
- (UIView * _Nullable)customInputAccessoryView {
    UIView * _Nullable currentView = self;
    while (currentView != nil && ![[currentView class] isEqual: [WKWebView class]]) {
        currentView = currentView.superview;
    }
    
    NSAssert(currentView != nil, @"WKWebView not found in view hierarchy!");
    return (UIView *) objc_getAssociatedObject(currentView, &inputAccessoryViewKey);
}

@end
