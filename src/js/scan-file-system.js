import { registerPlugin } from '@capacitor/core';

const FileUploader = registerPlugin('FileUploader');

export async function scanFileSystem() {
    await FileUploader.startSync();
}