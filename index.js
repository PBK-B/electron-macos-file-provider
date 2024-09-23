/*
 * @Author: Bin
 * @Date: 2024-09-13
 * @FilePath: /electron-macos-file-provider/index.js
 */

// import { createRequire } from "node:module"
// const require = createRequire(import.meta.url)

let efphelper = undefined;

try {
    try {
        efphelper = require("./build/Release/efphelper.node")
    } catch (error) {
        efphelper = require("./build/Debug/efphelper.node")
    }
} catch (error) {
    console.warn('[FileProvider]', error);
}

function assertion() {
    if (process.platform != 'darwin') throw Error(`the current system ${process.platform} is not supported`);
    if (!efphelper || !efphelper.addDomain) throw Error(`efphelper.node init failed`);
}

function removeAllDomains(callback = function () { }) {
    assertion();
    efphelper.removeAllDomains(callback);
}

function addDomain(id, name, options, callback = function () { }) {
    assertion();
    if (!options?.url) {
        throw Error("WebDAV url are mandatory items")
    }
    if ((!options?.password || !options?.user) && !options?.cookie) {
        throw Error("authentication method auth user password and cookie are empty")
    }
    // 0. domain identifier
    // 1. domain displayName
    // 2. WebDAV url
    // 3. WebDAV user auth name
    // 4. WebDAV user auth password
    // 5. WebDAV user cookie
    // 6. domain add callback function

    efphelper.addDomain(
        id,
        name,
        options.url,
        options?.user ?? undefined,
        options?.password ?? null,
        options?.cookie ?? null,
        callback
    );
}

function getUserVisiblePath(identifier, displayName = '') {
    return new Promise((resolve, reject) => {
        try {
            assertion();
            efphelper.getUserVisiblePath(identifier, displayName, (path, err) => {
                if (err) {
                    reject(err)
                    return
                }
                resolve(path)
            })
        } catch (error) {
            reject(error)
        }
    });
}

function getFileProviderLogPath() {
    assertion();
    return efphelper.getFileProviderLogPath();
}

// export default {
//     __helper: efphelper,
//     addDomain,
//     removeAllDomains
// }

// export {
//     addDomain,
//     removeAllDomains 
// }

exports.addDomain = addDomain
exports.removeAllDomains = removeAllDomains
exports.getUserVisiblePath = getUserVisiblePath
exports.getFileProviderLogPath = getFileProviderLogPath
