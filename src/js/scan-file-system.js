import { Filesystem, Directory } from '@capacitor/filesystem';

export async function scanFileSystem() {
    for (const directory of Object.keys(Directory)) {
        document.write(`Reading ${directory}<br />`);
        const folderContent = await Filesystem.readdir({
            directory: directory,
            path: "",
        });

        document.write(`${JSON.stringify(folderContent, null, 4)}<br />`);
    }
}