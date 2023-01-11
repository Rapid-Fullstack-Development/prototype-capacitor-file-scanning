# prototype-file-scanning-with-capacitor

A prototype for file scanning on mobile device using [Capacitor](https://capacitorjs.com/).

This code accompanies chapter 4 of the book [Rapid Fullstack Development](https://rapidfullstackdevelopment.com/).

Follow the author on [Twitter](https://twitter.com/codecapers) for updates.

## Backend

You need to be running the Photosphere backend for this to work:

https://github.com/Rapid-Fullstack-Development/photosphere-monolithic-backend

## Setup

Clone the repository and install dependencies:

```bash
cd prototype-file-scanning-with-capacitor
npm install
```

## Running in development

You need Node.js installed to run this in development.

```bash
npm start
```

## Build and run for Android

You need Android Studio installed for this.

```bash 
npm run build 
npx cap update
npx cap sync
npx cap open android
```

Now build and run using Android Studio.