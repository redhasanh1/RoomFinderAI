#import <Foundation/Foundation.h>
#import <Capacitor/Capacitor.h>

// Define the plugin using the CAP_PLUGIN Macro, and
// each method the plugin supports using the CAP_PLUGIN_METHOD macro.
CAP_PLUGIN(iOSNativeUIPlugin, "iOSNativeUI",
           CAP_PLUGIN_METHOD(showNativeNavBar, CAPPluginReturnPromise);
           CAP_PLUGIN_METHOD(showNativeAlert, CAPPluginReturnPromise);
           CAP_PLUGIN_METHOD(showNativeActionSheet, CAPPluginReturnPromise);
           CAP_PLUGIN_METHOD(configureStatusBar, CAPPluginReturnPromise);
           CAP_PLUGIN_METHOD(showNativeLoading, CAPPluginReturnPromise);
           CAP_PLUGIN_METHOD(hideNativeLoading, CAPPluginReturnPromise);
           CAP_PLUGIN_METHOD(showNativeToast, CAPPluginReturnPromise);
           CAP_PLUGIN_METHOD(configureNavigationBar, CAPPluginReturnPromise);
)