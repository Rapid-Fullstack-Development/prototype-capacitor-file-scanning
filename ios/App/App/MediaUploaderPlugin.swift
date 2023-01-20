//
//  MediaUploaderPlugin.swift
//  App
//
//  Created by Ashley Davis on 20/1/2023.
//

import Capacitor

@objc(EchoPlugin)
public class EchoPlugin: CAPPlugin {
  @objc func echo(_ call: CAPPluginCall) {
    print("*********** echo ******************")
    let value = call.getString("value") ?? ""
    call.resolve([
        "value": value
    ])
  }
}
