/*
 * @Author: Bin
 * @Date: 2024-09-13
 * @FilePath: /lzc-client-desktop/node_modules/electron-macos-file-provider/index.js
 */

// import { createRequire } from "node:module"
// const require = createRequire(import.meta.url)

let efphelper = undefined;
try {
    efphelper = require("./build/Release/efphelper.node")
} catch (error) {
    efphelper = require("./build/Debug/efphelper.node")
}

function removeAllDomains() {
    if(!efphelper || !efphelper.addDomain) throw Error(`efphelper.node init failed`);
    efphelper.removeAllDomains()
}

function addDomain(id, name, callback) {
    if(!efphelper || !efphelper.addDomain) throw Error(`efphelper.node init failed`);
    efphelper.addDomain(id, name, callback)
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
