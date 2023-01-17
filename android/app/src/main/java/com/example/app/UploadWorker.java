package com.example.app;

import static android.content.Context.MODE_PRIVATE;

import android.content.Context;
import android.content.SharedPreferences;
import android.os.storage.StorageManager;
import android.os.storage.StorageVolume;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.work.Worker;
import androidx.work.WorkerParameters;

import com.google.gson.Gson;

import java.io.BufferedInputStream;
import java.io.BufferedOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.InputStream;
import java.math.BigInteger;
import java.net.HttpURLConnection;
import java.net.URL;
import java.security.MessageDigest;
import java.util.Date;
import java.util.Map;

class FileDetails {
    public String name;
    public String path;
    public String contentType;
    public String hash;
    public Boolean uploaded;
    public Date creationDate;

    public FileDetails(String name, String path, String contentType, Date creationDate) {
        this.name = name;
        this.path = path;
        this.contentType = contentType;
        this.hash = null;
        this.uploaded = false;
        this.creationDate = creationDate;
    }
}

//
// Scans the file system for files and uploads them.
//
public class UploadWorker extends Worker {

    //
    // Setting to true when the work is running.
    //
    public static boolean running = false;

    //
    // Setting this to true aborts the work.
    //
    public static boolean stopWork = false;

    public static int nextId = 0;
    public int id = ++nextId;

    //
    // Records settings.
    //
    SharedPreferences settings = getApplicationContext().getSharedPreferences("settings", MODE_PRIVATE);

    //
    // Records files that have been found.
    //
    // https://developer.android.com/reference/android/content/SharedPreferences
    // https://www.androidauthority.com/how-to-store-data-locally-in-android-app-717190/
    // https://stackoverflow.com/a/49938549/25868
    //
    SharedPreferences filePrefs = getApplicationContext().getSharedPreferences("local-files", MODE_PRIVATE);

    public UploadWorker(
            @NonNull Context context,
            @NonNull WorkerParameters params) {
        super(context, params);
    }

    @Override
    public Result doWork() {

        //TODO: Would be good to mark all previously recorded files as "unchecked".

        this.running = true;
        this.stopWork = false;

        //
        // Scan the file system for images.
        //
        this.scanFilesystem();

        //
        // Upload files that have been found.
        //
        this.uploadFiles();

        this.running = false;
        this.stopWork = false; // Reset, in case the work was stopped.

        // Indicate whether the work finished successfully with the Result
        return Result.success();
    }

    //
    // Scans the entire file system for files to upload.
    //
    private void scanFilesystem() {
        StorageManager sm = this.getApplicationContext().getSystemService(StorageManager.class);
        for (StorageVolume volume : sm.getStorageVolumes()) {

            Log.i("Dbg[" + id + "]: Scanning -> ", volume.getDirectory().getPath());
            scanDirectory(volume.getDirectory());
        }
    }

    //
    // Scans a directory and uploads files.
    //
    private void scanDirectory(File directory) {

        if (stopWork) {
            Log.i("Dbg", "Stopping work.");
            return;
        }

        File[] files = directory.listFiles();
        if (files == null) {
            return;
        }

        for (File file : files) {
            if (stopWork) {
                Log.i("Dbg", "Stopping work.");
                return;
            }

            if (file.isDirectory()) {
                if (file.getName().equals(".thumbnails")) {
                    Log.i("Dbg[" + id + "]", "Skipping .thumbnails directory.");
                    continue;
                }
                scanDirectory(file);
            }
            else if (file.getName().endsWith(".png")) {
                String existingEntry = filePrefs.getString(file.getPath(), null);
                if (existingEntry == null) {
                    Log.i("Dbg[" + id + "]", "No record yet for " + file.getPath());

                    // https://developer.android.com/reference/android/content/SharedPreferences.Editor
                    SharedPreferences.Editor editor = filePrefs.edit();

                    // https://stackoverflow.com/a/18463758/25868
                    Gson gson = new Gson();
                    Date lastModifiedDate = new Date(file.lastModified());
                    String json = gson.toJson(new FileDetails(file.getName(), file.getPath(), "image/png", lastModifiedDate));
                    editor.putString(file.getPath(), json);
                    editor.commit();
                }
                else {
                    Log.i("Dbg[" + id + "]", "Have record for " + file.getPath());

                    //TODO: Update existing entry, mark as "found".
                }
            }
            else if (file.getName().endsWith(".jpg")) {
                String existingEntry = filePrefs.getString(file.getPath(), null);
                if (existingEntry == null) {
                    Log.i("Dbg[" + id + "]", "No record yet for " + file.getPath());

                    // https://developer.android.com/reference/android/content/SharedPreferences.Editor
                    SharedPreferences.Editor editor = filePrefs.edit();

                    // https://stackoverflow.com/a/18463758/25868
                    Gson gson = new Gson();
                    Date lastModifiedDate = new Date(file.lastModified());
                    String json = gson.toJson(new FileDetails(file.getName(), file.getPath(), "image/jpg", lastModifiedDate));
                    editor.putString(file.getPath(), json);
                    editor.commit();
                }
                else {
                    Log.i("Dbg[" + id + "]", "Have record for " + file.getPath());

                    //TODO: Update existing entry, mark as "found".
                }
            }
        }
    }

    //
    // Upload files.
    //
    private void uploadFiles() {
        // https://stackoverflow.com/a/18463758/25868
        Gson gson = new Gson();

        for (Map.Entry<String, Object> entry : ((Map<String, Object>) filePrefs.getAll()).entrySet()) {
            if (stopWork) {
                Log.i("Dbg", "Stopping work.");
                return;
            }

            String filePath = entry.getKey();
            File file = new File(filePath);
            String json = entry.getValue().toString();
            FileDetails fileDetails = gson.fromJson(json, FileDetails.class);

            String hash = computeHash(file);
            if (!hash.equals(fileDetails.hash)) {
                Log.i("Dbg[" + id + "]", "No hash or hash changed for " + filePath + "\n"
                                                 + "Old hash: " + fileDetails.hash + "\n"
                                                 + "New hash: " + hash);

                //
                // Hash isn't set yet or this is a different file!
                //
                fileDetails.hash = hash;
                fileDetails.uploaded = false;

                //
                // Save hash.
                //
                SharedPreferences.Editor editor = filePrefs.edit();
                editor.putString(filePath, gson.toJson(fileDetails));
                editor.commit();
            }

            if (!fileDetails.uploaded) {
                boolean isUploaded = checkUploaded(fileDetails.hash);
                if (!isUploaded) {
                    Log.i("Dbg[" + id + "]", "Uploading " + filePath);

                    this.uploadFile(file, fileDetails.hash, fileDetails.contentType);

                    fileDetails.uploaded = true;

                    //
                    // Save uploaded state.
                    //
                    SharedPreferences.Editor editor = filePrefs.edit();
                    editor.putString(filePath, gson.toJson(fileDetails));
                    editor.commit();
                }
                else {
                    Log.v("Dbg[" + id + "]", "Checked with server, Already uploaded: " + filePath);
                }
            }
            else {
                Log.v("Dbg[" + id + "]", "Already uploaded: " + filePath);
            }
        }
    }

    //
    // Converts bytes to hex values.
    //
    // https://stackoverflow.com/q/7166129/25868
    //
    private String bin2hex(byte[] data) {
        return String.format("%0" + (data.length*2) + "X", new BigInteger(1, data));
    }

    //
    // Computes the hash for a file.
    //
    // https://stackoverflow.com/a/32032908/25868
    //
    private String computeHash(File file) {
        try {
            byte[] buffer = new byte[4096];
            int count;
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            BufferedInputStream bis = new BufferedInputStream(new FileInputStream(file));
            while ((count = bis.read(buffer)) > 0) {
                digest.update(buffer, 0, count);
            }
            bis.close();

            return bin2hex(digest.digest());
        }
        catch (Exception ex) {
            Log.e("Err", "Failed to hash file " + file.getPath());
            return null;
        }
    }

    //
    // Checks if a file has been uploaded already.
    //
    public boolean checkUploaded(String hash) {
        try {
            String baseURL = settings.getString("backend", null);
            URL url = new URL(baseURL + "/check-asset?hash=" + hash);
            HttpURLConnection urlConnection = (HttpURLConnection) url.openConnection();
            urlConnection.setRequestMethod("GET");
            urlConnection.connect();
            int responseCode = urlConnection.getResponseCode();
            urlConnection.disconnect();
            return responseCode == 200;
        }
        catch (Exception ex) {
            Log.e("Err", "Failed connecting to server.\r\n" + ex.toString());
            return false;
        }
    }

    //
    // Uploads a file to the Photosphere backend.
    //
    // https://developer.android.com/reference/java/net/HttpURLConnection
    // https://gist.github.com/luankevinferreira/5221ea62e874a9b29d86b13a2637517b
    //
    private void uploadFile(File file, String hash, String contentType) {
        HttpURLConnection urlConnection = null;
        try {
            String baseURL = settings.getString("backend", null);
            URL url = new URL(baseURL + "/asset");
            urlConnection = (HttpURLConnection) url.openConnection();

            urlConnection.setUseCaches(false);
            urlConnection.setDoOutput(true);
            urlConnection.setRequestMethod("POST");
            urlConnection.setChunkedStreamingMode(0);
            urlConnection.setRequestProperty("content-type", contentType);
            urlConnection.setRequestProperty("file-name", file.getName());
            urlConnection.setRequestProperty("width", "256");
            urlConnection.setRequestProperty("height", "256");
            urlConnection.setRequestProperty("hash", hash);

            BufferedOutputStream bos = new BufferedOutputStream(urlConnection.getOutputStream());
            BufferedInputStream bis = new BufferedInputStream(new FileInputStream(file));

            int i;
            byte[] buffer = new byte[4096];
            while ((i = bis.read(buffer)) > 0) {
                bos.write(buffer, 0, i);
            }
            bis.close();
            bos.close();

            InputStream inputStream;
            int responseCode = ((HttpURLConnection) urlConnection).getResponseCode();
            if ((responseCode >= 200) && (responseCode <= 202)) {
                inputStream = ((HttpURLConnection) urlConnection).getInputStream();
                int j;
                while ((j = inputStream.read()) > 0) {
                    //System.out.println(j);
                }
            }
        }
        catch (Exception ex) {
            Log.e("Error", "Failed to upload file " + file.getPath() + "\n" + ex.toString());
        }
        finally {
            if (urlConnection != null) {
                urlConnection.disconnect();
            }
        }
    }
}
