/*
 * @Author: Bin
 * @Date: 2024-09-13
 * @FilePath: /electron-macos-file-provider/index.d.ts
 */

declare module 'electron-macos-file-provider' {
    function addDomain(identifier: string, displayName: string, callback?: (...parameters: any) => void): void;
    function removeAllDomains(callback?: (...parameters: any) => void): void;
}
