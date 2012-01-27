package com.moodstocks.android;

import android.hardware.Camera;
import android.os.Handler;
import android.os.Message;
import android.util.Log;

public class AutoFocusManager extends Handler implements Camera.AutoFocusCallback {
	
	public static final String TAG = "Autofocus";
	
	private Camera camera;
	private static int FOCUS_REQUEST;
	
	private static final long FOCUS_DELAY = 1500;
	
	public AutoFocusManager(Camera cam) {
		if (cam != null) {
			this.camera = cam;
		}
		else {
			Log.e(TAG, "AutofocusManager passed null camera");
		}
	}
	
	public void start() {
		if (camera != null) {
			camera.autoFocus(this);
		}
	}
	
	public void stop() {
		this.removeMessages(FOCUS_REQUEST);
	}
	
	@Override
	public void handleMessage(Message m) {
		if (m.what == FOCUS_REQUEST && camera != null) {
			Log.d(TAG, "received autofocus order");
			camera.autoFocus(this);
		}
	}
	
	@Override
	public void onAutoFocus(boolean success, Camera camera) {
		this.sendEmptyMessageDelayed(FOCUS_REQUEST, FOCUS_DELAY);
	}

}
