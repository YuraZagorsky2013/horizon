#import <Foundation/Foundation.h>
#import "horizon_ios.h"

int main(int argc, char *argv[]) {
    @autoreleasepool {
        // winit's iOS EventLoop::run_app invokes UIApplicationMain. Do not
        // start a second SwiftUI/UIKit application lifecycle here.
        horizon_start();
    }
    return 0;
}
