//
// Copyright © 2019 Halts. All rights reserved.
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

#import "VMDisplayMetalViewController.h"
#import "UTMRenderer.h"
#import "UTMVirtualMachine.h"

@interface VMDisplayMetalViewController ()

@end

@implementation VMDisplayMetalViewController {
    MTKView *_view;
    UTMRenderer *_renderer;
}

@synthesize vmScreenshot;
@synthesize vmMessage;
@synthesize vmRendering;

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Set the view to use the default device
    _view = (MTKView *)self.view;
    _view.device = MTLCreateSystemDefaultDevice();
    if (!_view.device) {
        NSLog(@"Metal is not supported on this device");
        return;
    }
    
    _renderer = [[UTMRenderer alloc] initWithMetalKitView:_view];
    if (!_renderer) {
        NSLog(@"Renderer failed initialization");
        return;
    }
    
    // Initialize our renderer with the view size
    [_renderer mtkView:_view drawableSizeWillChange:_view.drawableSize];
    _renderer.source = self.vmRendering;
    
    _view.delegate = _renderer;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:YES animated:animated];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.navigationController setNavigationBarHidden:NO animated:animated];
}

- (void)virtualMachine:(UTMVirtualMachine *)vm transitionToState:(UTMVMState)state {
    switch (state) {
        case kVMError: {
            NSString *msg = self.vmMessage ? self.vmMessage : NSLocalizedString(@"An internal error has occured.", @"Alert message");
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil message:msg preferredStyle:UIAlertControllerStyleAlert];
            UIAlertAction *okay = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", @"OK button") style:UIAlertActionStyleDefault handler:nil];
            [alert addAction:okay];
            dispatch_async(dispatch_get_main_queue(), ^{
                [self presentViewController:alert animated:YES completion:^{
                    [self performSegueWithIdentifier:@"returnToList" sender:self];
                }];
            });
            break;
        }
        case kVMStopping:
        case kVMStopped:
        case kVMPausing:
        case kVMPaused: {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self performSegueWithIdentifier:@"returnToList" sender:self];
            });
            break;
        }
        case kVMStarted: {
            _renderer.source = self.vmRendering;
            break;
        }
        default: {
            break; // TODO: Implement
        }
    }
}

@end
