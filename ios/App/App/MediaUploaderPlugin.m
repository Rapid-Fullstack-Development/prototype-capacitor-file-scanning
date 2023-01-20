//
//  MediaUploaderPlugin.m
//  App
//
//  Created by Ashley Davis on 20/1/2023.
//

#import <Capacitor/Capacitor.h>

CAP_PLUGIN(MediaUploaderPlugin, "FileUploader",
  CAP_PLUGIN_METHOD(echo, CAPPluginReturnPromise);
)
