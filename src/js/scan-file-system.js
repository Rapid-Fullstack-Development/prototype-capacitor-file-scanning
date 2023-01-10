import { registerPlugin } from '@capacitor/core';

const Echo = registerPlugin('Echo');

export async function scanFileSystem() {
    const { value } = await Echo.echo({ value: 'Hello World!' });
    console.log('Response from native:', value);
}