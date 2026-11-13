#import <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif
void horizon_start(void);
#ifdef __cplusplus
}
#endif

int main(int argc, char *argv[]) {
    @autoreleasepool {
        // winit's iOS EventLoop::run_app invokes UIApplicationMain. Do not
        // start a second SwiftUI/UIKit application lifecycle here.
        horizon_start();
    }
    return 0;
}
