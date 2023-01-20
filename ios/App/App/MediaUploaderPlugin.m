//
//  MediaUploaderPlugin.m
//  App
//
//  Created by Ashley Davis on 20/1/2023.
//

#import <Capacitor/Capacitor.h>

CAP_PLUGIN(EchoPlugin, "Echo",
  CAP_PLUGIN_METHOD(echo, CAPPluginReturnPromise);
)
