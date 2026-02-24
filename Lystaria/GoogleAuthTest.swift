//
//  GoogleAuthTest.swift
//  Lystaria
//
//  Created by Asteria Moon on 2/28/26.
//

import Foundation
import FirebaseCore
import GoogleSignIn

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

final class GoogleAuthTest {

    static func signIn() {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            print("❌ Missing Firebase clientID (check GoogleService-Info.plist is in the target)")
            return
        }

        // Newer GoogleSignIn API: set configuration on the shared instance
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

        #if os(iOS)
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController
        else {
            print("❌ No root view controller")
            return
        }

        GIDSignIn.sharedInstance.signIn(withPresenting: root) { result, error in
            if let error {
                print("❌ Google Sign-In error:", error.localizedDescription)
                return
            }
            let email = result?.user.profile?.email ?? "No email"
            print("✅ Google user:", email)
        }

#elseif os(macOS)
guard let window = NSApp.keyWindow else {
    print("❌ No macOS window to present from")
    return
}

GIDSignIn.sharedInstance.signIn(withPresenting: window) { result, error in
    if let error {
        print("❌ Google Sign-In error:", error.localizedDescription)
        return
    }
    let email = result?.user.profile?.email ?? "No email"
    print("✅ Google user:", email)
}
#endif
    }
}
