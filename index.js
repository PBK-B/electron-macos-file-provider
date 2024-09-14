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

function addDomain(id, name, callback = function () { }) {
    assertion();
    efphelper.addDomain(id, name, callback);
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
