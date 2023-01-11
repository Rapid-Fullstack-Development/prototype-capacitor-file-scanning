package com.example.app;

import android.util.Log;

import androidx.work.OneTimeWorkRequest;
import androidx.work.WorkManager;
import androidx.work.WorkRequest;

import com.getcapacitor.JSObject;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;

@CapacitorPlugin(name = "FileUploader")
public class FileUploader extends Plugin {

    @PluginMethod()
    public void startSync(PluginCall call) {
        WorkManager.getInstance(this.getActivity().getApplicationContext())
                .cancelAllWork();

        WorkRequest uploadWorkRequest =
                new OneTimeWorkRequest.Builder(UploadWorker.class)
                        .build();

        WorkManager
                .getInstance(this.getActivity().getApplicationContext())
                .enqueue(uploadWorkRequest);
        
        call.resolve();
    }

    //todo: have permissions?
    //      request permissions
    //todo: is sync in progress?
    //  stop sync
    //  get list of files
}