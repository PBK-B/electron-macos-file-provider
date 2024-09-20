/*
 * @Author: Bin
 * @Date: 2024-09-11
 * @FilePath: /electron-macos-file-provider/src/efphelper.mm
 */
#import "FileProvider/NSFileProviderManager.h"
#include "napi.h"
#include <__config>
#include <string>
#include <thread>

Napi::Value AddDomain(const Napi::CallbackInfo &info) {
  Napi::Env env = info.Env();

  if (info.Length() < 7) {
    Napi::TypeError::New(env, "Wrong of arguments")
        .ThrowAsJavaScriptException();
    return env.Null();
  }

  if (!info[0].IsString() || !info[1].IsString() || !info[6].IsFunction()) {
    Napi::TypeError::New(
        env, "Wrong identifier, displayName, callback of arguments TypeError")
        .ThrowAsJavaScriptException();
    return env.Null();
  }

  Napi::String arg0 = info[0].As<Napi::String>();         // identifier
  Napi::String arg1 = info[1].As<Napi::String>();         // displayName
  Napi::Function callback = info[6].As<Napi::Function>(); // callback fun

  // required parameter judgment
  if (!info[2].IsString()) {
    Napi::TypeError::New(env, "Wrong WebDAV url of arguments TypeError")
        .ThrowAsJavaScriptException();
    return env.Null();
  }

  Napi::String urlStr = info[2].As<Napi::String>(); // WebDAV url

  Napi::Value userStr = info[3];     // WebDAV username
  Napi::Value passwordStr = info[4]; // WebDAV password
  Napi::Value cookieStr = info[5];   // WebDAV cookie

  if (@available(macOS 11.0, *)) {

    NSString *identifier =
        [NSString stringWithUTF8String:arg0.Utf8Value().c_str()];
    NSString *displayName =
        [NSString stringWithUTF8String:arg1.Utf8Value().c_str()];

    NSString *wdUrl =
        [NSString stringWithUTF8String:urlStr.Utf8Value().c_str()];
    NSString *wdUser =
        passwordStr.IsNull()
            ? NULL
            : [NSString
                  stringWithUTF8String:userStr.ToString().Utf8Value().c_str()];
    NSString *wdPassword =
        passwordStr.IsNull()
            ? NULL
            : [NSString stringWithUTF8String:passwordStr.ToString()
                                                 .Utf8Value()
                                                 .c_str()];
    NSString *wdCookie =
        cookieStr.IsNull() ? NULL
                           : [NSString stringWithUTF8String:cookieStr.ToString()
                                                                .Utf8Value()
                                                                .c_str()];

    NSString *appGroupId = @"group.cloud.lazycat.clients";
    NSURL *appGroupURL = [[NSFileManager defaultManager]
        containerURLForSecurityApplicationGroupIdentifier:appGroupId];
    auto logFilePath = [[appGroupURL absoluteString] UTF8String];

    // Share data from App Group

    NSUserDefaults *userDefaults =
        [[NSUserDefaults alloc] initWithSuiteName:appGroupId];
    [userDefaults removeObjectForKey:@"WebDAV——Username"];
    [userDefaults removeObjectForKey:@"WebDAV——Userpassword"];
    [userDefaults removeObjectForKey:@"WebDAV——Cookie"];
    [userDefaults removeObjectForKey:@"WebDAV——URL"];

    [userDefaults setObject:wdUrl forKey:@"WebDAV——URL"];

    printf("[FileProvider] logs path:%s url:%s \n", logFilePath,
           [[userDefaults stringForKey:@"WebDAV——URL"] UTF8String]);

    if (wdCookie) {
      // [userDefaults setObject:NULL forKey:@"WebDAV——Username"];
      // [userDefaults setObject:NULL forKey:@"WebDAV——Userpassword"];
      [userDefaults setObject:wdCookie forKey:@"WebDAV——Cookie"];
    } else if (wdUser && wdPassword) {
      // [userDefaults setObject:NULL forKey:@"WebDAV——Cookie"];
      [userDefaults setObject:wdUser forKey:@"WebDAV——Username"];
      [userDefaults setObject:wdPassword forKey:@"WebDAV——Userpassword"];
    } else {
      printf("[FileProvider] Ohhhh! Maybe there is no authentication "
             "information connected to webdav.\n");
    }
    [userDefaults synchronize];

    NSFileProviderDomain *domain =
        [[NSFileProviderDomain alloc] initWithIdentifier:identifier
                                             displayName:displayName];

    auto tsfn =
        Napi::ThreadSafeFunction::New(info.Env(), callback, "callback", 0, 1);

    auto logValueBlock = [tsfn](NSError *_Nullable error) {
      if (!error) {
        printf("[FileProvider] addDomain Ok!\n");
      } else {
        printf("[FileProvider] addDomain failed %s\n",
               [error.debugDescription UTF8String]);
      }
      tsfn.BlockingCall([error](Napi::Env env, Napi::Function fn) {
        if (error == nullptr) {
          fn.Call({env.Undefined()});
        } else {
          fn.Call(
              {Napi::String::New(env, [error.debugDescription UTF8String])});
        }
      });
    };

    [NSFileProviderManager addDomain:domain completionHandler:logValueBlock];
  }

  printf("[FileProvider] call<%s, %s> end\n", arg0.Utf8Value().c_str(),
         arg1.Utf8Value().c_str());
  return env.Undefined();
}

Napi::Value RemoveAllDomains(const Napi::CallbackInfo &info) {
  Napi::Env env = info.Env();

  if (info.Length() < 1) {
    Napi::TypeError::New(env, "Wrong of arguments")
        .ThrowAsJavaScriptException();
    return env.Null();
  }

  if (!info[0].IsFunction()) {
    Napi::TypeError::New(env, "Wrong callback Function arguments TypeError")
        .ThrowAsJavaScriptException();
    return env.Null();
  }

  Napi::Function callback = info[0].As<Napi::Function>();

  auto tsfn =
      Napi::ThreadSafeFunction::New(info.Env(), callback, "callback", 0, 1);

  if (@available(macOS 11.0, *)) {
    auto logValueBlock = [tsfn](NSError *_Nullable error) {
      if (!error) {
        printf("[FileProvider] removeAllDomains Ok!\n");
      } else {
        printf("[FileProvider] removeAllDomains failed %s\n",
               [error.debugDescription UTF8String]);
      }
      tsfn.BlockingCall([error](Napi::Env env, Napi::Function fn) {
        if (error == nullptr) {
          fn.Call({env.Undefined()});
        } else {
          fn.Call(
              {Napi::String::New(env, [error.debugDescription UTF8String])});
        }
      });
    };

    [NSFileProviderManager removeAllDomainsWithCompletionHandler:logValueBlock];
  }

  return env.Undefined();
}

/**
 * This code is our entry-point. We receive two arguments here, the first is the
 * environment that represent an independent instance of the JavaScript runtime,
 * the second is exports, the same as module.exports in a .js file.
 * You can either add properties to the exports object passed in or create your
 * own exports object. In either case you must return the object to be used as
 * the exports for the module when you return from the Init function.
 */
Napi::Object Init(Napi::Env env, Napi::Object exports) {
  exports.Set("addDomain", Napi::Function::New(env, AddDomain));
  exports.Set("removeAllDomains", Napi::Function::New(env, RemoveAllDomains));
  return exports;
}

/**
 * This code defines the entry-point for the Node addon, it tells Node where to
 * go once the library has been loaded into active memory. The first argument
 * must match the "target" in our *binding.gyp*. Using NODE_GYP_MODULE_NAME
 * ensures that the argument will be correct, as long as the module is built
 * with node-gyp (which is the usual way of building modules). The second
 * argument points to the function to invoke. The function must not be
 * namespaced.
 */
NODE_API_MODULE(NODE_GYP_MODULE_NAME, Init)
