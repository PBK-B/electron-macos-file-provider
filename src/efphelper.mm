/*
 * @Author: Bin
 * @Date: 2024-09-11
 * @FilePath: /electron-macos-file-provider/src/efphelper.mm
 */
#import "FileProvider/NSFileProviderManager.h"
#include "napi.h"
#include <string>
#include <thread>

Napi::Value AddDomain(const Napi::CallbackInfo &info) {
  Napi::Env env = info.Env();

  if (info.Length() < 2) {
    Napi::TypeError::New(env, "Wrong number of arguments")
        .ThrowAsJavaScriptException();
    return env.Null();
  }

  if (!info[0].IsString() || !info[1].IsString()) {
    Napi::TypeError::New(env, "Wrong arguments").ThrowAsJavaScriptException();
    return env.Null();
  }

  // Napi::String arg0 = info[0].As<Napi::String>(); // identifier
  // Napi::String arg1 = info[1].As<Napi::String>(); // displayName
  // Napi::Function callback = info[0].As<Napi::Function>();

  if (@available(macOS 11.0, *)) {
    auto logValueBlock = [](NSError *_Nullable error) {
      if (!error) {
        printf("[FileProvider] addDomain Ok!\n");
      } else {
        printf("[FileProvider] addDomain failed %s\n",
               [error.debugDescription UTF8String]);
      }
    };

    NSFileProviderDomain *domain =
        [[NSFileProviderDomain alloc] initWithIdentifier:@"cloud.lazycat.client"
                                             displayName:@"TestFPE"];
    [NSFileProviderManager addDomain:domain completionHandler:logValueBlock];
  }

  printf("[FileProvider] call end\n");
  return env.Undefined();
}

Napi::Value RemoveAllDomains(const Napi::CallbackInfo &info) {
  Napi::Env env = info.Env();

  if (@available(macOS 11.0, *)) {
    auto logValueBlock = [](NSError *_Nullable error) {
      if (!error) {
        printf("[FileProvider] removeAllDomains Ok!\n");
      } else {
        printf("[FileProvider] removeAllDomains failed %s\n",
               [error.debugDescription UTF8String]);
      }
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
