<!--
 * @Author: Bin
 * @Date: 2024-09-12
 * @FilePath: /electron-macos-file-provider/README.md
-->

# Electron Expand Apple FileProvider for MacOS

> trying to implement Apple FileProvider for macos using the N-API extension electron.

## Install Guide

1. installation dependency

```bash
npm install electron-macos-file-provider
```

2. copy the `PlugIns/EleFileProvider.appex` you have configured and compiled in your Electron application construction process. reference [Developer](#developer) document part configuration and compile EleFileProvider.appex

## APIs

### NSFileProviderManager addDomain

```js
addDomain("cloud.lazycat.client", "", 
    {
        url: "http://localhost:8080/webdav/",
        user: "user001",
        password: "mypassword",
    },
    (err: any) => {
    if(err) {
        console.log("[EleFileProvider] addDomain failed", err);
        return;
    }
    console.log("[EleFileProvider] addDomain success!");
})
```

### NSFileProviderManager removeAllDomains

```js
removeAllDomains((err: any) => {
    if(err) {
        console.log("[EleFileProvider] removeAllDomains failed", err);
        return;
    }
    console.log("[EleFileProvider] removeAllDomains success!");
})
```

### NSFileProviderManager getUserVisibleURLForItemIdentifier

```js
getUserVisiblePath("cloud.lazycat.client", "")
    .then(path => {
        // path = /Users/Apollo/Library/CloudStorage/MyAppClient
        console.log("[EleFileProvider] getUserVisiblePath:", path)
    })
    .catch(error => {
        console.error("[EleFileProvider] getUserVisiblePath failed", error)
    })
```

## Developer

> Please use `xcode` to open `EFPHelper.xcodeproj` and configure your development team and App Identifier and the correct `app groups identifier`. 
> 
> If you need to modify FileProvider Expand, you can try to run the `EFPHelper` application for debugging.

1. execute `npm install` installation dependency

2. configure node-gyp `npm run dev:init`

3. build node native modules `npm run dev:build`

4. build EleFileProvider PlugIns `npm run dev:plugin`

## Supports

- [x] WebDAV Storage

## References

<https://developer.apple.com/documentation/fileprovider/synchronizing-files-using-file-provider-extensions>

<https://nodejs.org/api/n-api.html#node-api>

<https://github.com/nodejs/node-addon-examples>

## Contributing

> This project exists thanks to all the people who contribute.
>
> We welcome contributions of any kind, please see our [contributing guide](https://github.com/electron/electron/blob/main/CONTRIBUTING.md). Found a bug? Please [submit an issue](https://github.com/PBK-B/electron-macos-file-provider/issues/new).

# License

This Project is [MIT](/LICENSE) licensed.


