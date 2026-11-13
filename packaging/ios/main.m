#import <Foundation/Foundation.h>
#import "horizon_ios.h"

int main(int argc, char *argv[]) {
    @autoreleasepool {
        // Register a lightweight UIKit onboarding overlay before winit starts its
        // single UIApplicationMain lifecycle.
        horizon_install_setup_ui();
        horizon_start();
    }
    return 0;
}
