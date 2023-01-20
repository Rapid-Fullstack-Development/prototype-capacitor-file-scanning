import { SplashScreen } from '@capacitor/splash-screen';
import { registerPlugin } from '@capacitor/core';

const EchoPlugin = registerPlugin('Echo');
const FileUploader = registerPlugin('FileUploader');

window.customElements.define(
    'capacitor-welcome',
    class extends HTMLElement {
        constructor() {
            super();

            SplashScreen.hide();

            const root = this.attachShadow({ mode: 'open' });

            root.innerHTML = `
    <style>
      :host {
        font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif, "Apple Color Emoji", "Segoe UI Emoji", "Segoe UI Symbol";
        display: block;
        width: 100%;
        height: 100%;
      }
      h1, h2, h3, h4, h5 {
        text-transform: uppercase;
      }
      .button {
        display: inline-block;
        padding: 10px;
        background-color: #73B5F6;
        color: #fff;
        font-size: 0.9em;
        border: 0;
        border-radius: 3px;
        text-decoration: none;
        cursor: pointer;
      }
      main {
        padding: 15px;
      }
      main hr { height: 1px; background-color: #eee; border: 0; }
      main h1 {
        font-size: 1.4em;
        text-transform: uppercase;
        letter-spacing: 1px;
      }
      main h2 {
        font-size: 1.1em;
      }
      main h3 {
        font-size: 0.9em;
      }
      main p {
        color: #333;
      }
      main pre {
        white-space: pre-line;
      }

      .hidden {
        display: none;
      }
    </style>
    <div>
      <capacitor-welcome-titlebar>
        <h1>Capacitor file scanning prototype</h1>
      </capacitor-welcome-titlebar>
      <main>
        <p>
          Press the button start uploading files to the backend.
        </p>
        <p>
          <button class="button" id="request-permission">Request permissions to manage files</button>
          <span id="permissions-granted-msg" class="hidden">Permissions granted</span>
        </p>
        <p>
          <button class="button" id="stop-sync" class="hidden">Stop file sync</button>
        </p>
        <p>
          <button class="button" id="start-sync" class="hidden">Start file sync</button>
        </p>
      </main>
    </div>
    `;
        }

        connectedCallback() {
            const self = this;

            console.log(`Doing echo!`); //fio:

            EchoPlugin.echo({ value: "hello world" })
              .then(result => {
                console.log(`Got echo: `);
                console.log(result);
              })
              .catch(err => {
                console.error(`Failed to run plugin:`);
                console.error(err);
              });

            const backend = import.meta.env.VITE_BACKEND_URL;
            if (!backend) {
                console.error(`VITE_BACKEND_URL environment variable should be set.`);
            }
            else {
                console.log(`VITE_BACKEND_URL environment variable is set to ${backend}`);
            }
            FileUploader.updateSettings({
                backend: backend,
            });

            const startSyncButton = self.shadowRoot.querySelector('#start-sync')
            startSyncButton.addEventListener('click', async function (e) {
                FileUploader.startSync()
                    .catch(err => {
                        console.error(`Failed with error:`);
                        console.error(err);
                    })
            });

            const stopSyncButton = self.shadowRoot.querySelector('#stop-sync');
            stopSyncButton.addEventListener('click', async function (e) {
                FileUploader.stopSync()
                    .catch(err => {
                        console.error(`Failed with error:`);
                        console.error(err);
                    })
            });

            const requestPermissionButton = self.shadowRoot.querySelector('#request-permission');
            requestPermissionButton.addEventListener('click', async function (e) {
                FileUploader.requestPermissions()
                    .then(() => {
                        return FileUploader.checkPermissions()
                            .then(result => {
                                if (result.havePermissions) {
                                    permissionsGrantedMsg.classList.remove("hidden");
                                }
                                else {
                                    permissionsGrantedMsg.classList.add("hidden");
                                }
                            });
                    })
                    .catch(err => {
                        console.error(`Failed with error:`);
                        console.error(err);
                    });
            });

            function checkPermissions() {
                FileUploader.checkPermissions()
                    .then(result => {
                        const permissionsGrantedMsg = self.shadowRoot.querySelector('#permissions-granted-msg');
                        if (result.havePermissions) {
                            permissionsGrantedMsg.classList.remove("hidden");
                        }
                        else {
                            permissionsGrantedMsg.classList.add("hidden");

                            setTimeout(() => checkPermissions(), 1000);
                        }
                    });
            }

            checkPermissions();

            function checkSyncStatus() {
                FileUploader.getFiles()
                    .then(result => {
                        console.log(result);
                    });

                FileUploader.checkSyncStatus()
                    .then(result => {
                        if (result.syncing) {
                            startSyncButton.classList.add("hidden");
                            stopSyncButton.classList.remove("hidden");
                        }
                        else {
                            startSyncButton.classList.remove("hidden");
                            stopSyncButton.classList.add("hidden");
                        }

                        setTimeout(() => checkSyncStatus(), 5000);
                    });
            }

            checkSyncStatus();

        }
    }
);

window.customElements.define(
    'capacitor-welcome-titlebar',
    class extends HTMLElement {
        constructor() {
            super();
            const root = this.attachShadow({ mode: 'open' });
            root.innerHTML = `
    <style>
      :host {
        position: relative;
        display: block;
        padding: 15px 15px 15px 15px;
        text-align: center;
        background-color: #73B5F6;
      }
      ::slotted(h1) {
        margin: 0;
        font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif, "Apple Color Emoji", "Segoe UI Emoji", "Segoe UI Symbol";
        font-size: 0.9em;
        font-weight: 600;
        color: #fff;
      }
    </style>
    <slot></slot>
    `;
        }
    }
);
