/*
 * @Author: Bin
 * @Date: 2024-09-13
 * @FilePath: /electron-macos-file-provider/index.d.ts
 */

declare module 'electron-macos-file-provider' {
    type FileProviderDomainOptions = {
        url: string,
        user?: string,
        password?: string,
        cookie?: string,
    }

    function addDomain(identifier: string, displayName: string, options: FileProviderDomainOptions, callback?: (...parameters: any) => void): void;
    function removeAllDomains(callback?: (...parameters: any) => void): void;
    function getUserVisiblePath(identifier: string, displayName?: string): Promise<string>;
    function getFileProviderLogPath(): string;
}
