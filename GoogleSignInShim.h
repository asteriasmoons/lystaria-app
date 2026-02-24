#ifndef GOOGLE_SIGN_IN_SHIM_H
#define GOOGLE_SIGN_IN_SHIM_H

// Import the umbrella header first
#import <GoogleSignIn/GoogleSignIn.h>

// Re-export headers that Xcode warns are missing from the umbrella.
// These are guarded so the project remains compatible across versions.
#if __has_include(<GoogleSignIn/GIDAppCheckError.h>)
#import <GoogleSignIn/GIDAppCheckError.h>
#endif

#if __has_include(<GoogleSignIn/GIDSignInButton.h>)
#import <GoogleSignIn/GIDSignInButton.h>
#endif

#endif /* GOOGLE_SIGN_IN_SHIM_H */
