package com.example.app;

import android.content.Intent;
import android.os.Environment;
import android.provider.Settings;
import android.util.Log;

import androidx.work.OneTimeWorkRequest;
import androidx.work.WorkInfo;
import androidx.work.WorkManager;
import androidx.work.WorkRequest;

import com.getcapacitor.JSObject;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;
import com.google.common.util.concurrent.ListenableFuture;

import java.util.List;

@CapacitorPlugin(name = "FileUploader")
public class FileUploader extends Plugin {

    @PluginMethod()
    public void checkPermissions(PluginCall call) {
        JSObject ret = new JSObject();
        ret.put("havePermissions", Environment.isExternalStorageManager());
        call.resolve(ret);
    }

    @PluginMethod()
    public void requestPermissions(PluginCall call) {
        Log.i("Dbg", "Requesting permissions.");
        Intent intent = new Intent();
        intent.setAction(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION);
        this.getActivity().startActivity(intent);
    }

    private boolean isWorkScheduled() {
        try {
            WorkManager instance = WorkManager.getInstance(this.getActivity().getApplicationContext());
            ListenableFuture<List<WorkInfo>> statuses = instance.getWorkInfosByTag(UploadWorker.class.getName());
            boolean running = false;
            List<WorkInfo> workInfoList = statuses.get();
            for (WorkInfo workInfo : workInfoList) {
                WorkInfo.State state = workInfo.getState();
                if (state == WorkInfo.State.RUNNING | state == WorkInfo.State.ENQUEUED) {
                    running = true;
                }
            }
            return running;
        }
        catch (Exception ex) {
            return false;
        }
    }

    @PluginMethod()
    public void checkSyncStatus(PluginCall call) {
//        Log.i("Dbg", "Checking sync status: " + isWorkScheduled());

        JSObject ret = new JSObject();
        ret.put("syncing", isWorkScheduled() || UploadWorker.running);
        call.resolve(ret);
    }

    @PluginMethod()
    public void stopSync(PluginCall call) {
        Log.i("Dbg", "Stopping all work.");
        UploadWorker.stopWork = true;
        WorkManager.getInstance(this.getActivity().getApplicationContext())
                .cancelAllWork();

        call.resolve();
    }

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
    //  get list of files
}