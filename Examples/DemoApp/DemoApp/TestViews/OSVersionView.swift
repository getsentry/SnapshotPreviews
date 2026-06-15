//
//  OSVersionView.swift
//  DemoApp
//
//  Created by Noah Martin on 9/4/24.
//

import Foundation
import SwiftUI
import SnapshotPreferences

struct OSVersionView: View {
    var body: some View {
        VStack {
            Text("Current OS Version:")
                .font(.headline)
            Text(getOSVersion())
                .font(.body)
                .padding()
        }
        .padding()
    }

    func getOSVersion() -> String {
        #if os(iOS)
        return UIDevice.current.systemVersion
        #elseif os(macOS)
        let osVersion = ProcessInfo.processInfo.operatingSystemVersion
        return "\(osVersion.majorVersion).\(osVersion.minorVersion).\(osVersion.patchVersion)"
        #else
        return "Unsupported OS"
        #endif
    }
}

struct OSVersionView_Previews: PreviewProvider {
    static var previews: some View {
        OSVersionView()
        .snapshotGroup(.module)
    }
}
