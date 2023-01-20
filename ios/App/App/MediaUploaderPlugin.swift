//
//  MediaUploaderPlugin.swift
//  App
//
//  Created by Ashley Davis on 20/1/2023.
//

import Capacitor

@objc(MediaUploaderPlugin)
public class MediaUploaderPlugin: CAPPlugin {
  @objc func echo(_ call: CAPPluginCall) {
    print("*********** MediaUploaderPlugin ******************")
    let value = call.getString("value") ?? ""
    call.resolve([
        "value": value
    ])
  }
}
