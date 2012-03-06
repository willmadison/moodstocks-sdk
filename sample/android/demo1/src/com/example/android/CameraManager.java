package com.example.android;

import java.io.IOException;
import java.util.List;

import android.util.Log;
import android.view.Display;
import android.view.SurfaceHolder;
import android.view.SurfaceView;
import android.view.WindowManager;
import android.graphics.ImageFormat;
import android.hardware.Camera;
import android.hardware.Camera.Parameters;
import android.hardware.Camera.Size;

public class CameraManager implements SurfaceHolder.Callback {
	
	public static interface Listener extends Camera.PreviewCallback {
		
		public void onPreviewSizeFound(int w, int h);
		public WindowManager getWindowManager();
		
	}
	
	public static final String TAG = "CameraManager";
	
	private static CameraManager instance = null;
	private Listener listener;
	private Camera cam;
	private SurfaceHolder preview;
	private AutoFocusManager focus_manager;
	
	private int preview_width;
	private int preview_height;
	private byte[] buffer;
	
	private CameraManager() {
		super();
	}
	
	public static CameraManager get() {
		if (CameraManager.instance == null) {
			synchronized(CameraManager.class) {
				if (CameraManager.instance == null) {
					CameraManager.instance = new CameraManager();
				}
			}
		}
		return CameraManager.instance;
	}
	
	public boolean start(Listener l, SurfaceView surface) {
		this.listener = l;
		this.cam = getCameraInstance();
		if (this.cam == null) {
			Log.e(TAG, "ERROR: Could not access camera");
			return false;
		}
		preview = surface.getHolder();
		preview.setType(SurfaceHolder.SURFACE_TYPE_PUSH_BUFFERS);
		preview.addCallback(this);
		findBestPreviewSize();
		cam.setPreviewCallbackWithBuffer(listener);
	  focus_manager = new AutoFocusManager(cam);
		return true;
	}
	
	public void stop() {
		focus_manager.stop();
		if (cam != null) {
			cam.stopPreview();
			cam.setPreviewCallback(null);
			cam.cancelAutoFocus();
			cam.release();
			cam = null;
		}
	}
	
	public void requestNewFrame() {
		cam.addCallbackBuffer(buffer);
	}
	
	private static Camera getCameraInstance(){
    Camera c = null;
    try {
        c = Camera.open(); // attempt to get a Camera instance
    }
    catch (Exception e){
    	// camera is unavailable, return null
    }
    return c;
	}
	
	// compute best preview size: highest possible
	// with ratio within 10% of screen resolution
	public void findBestPreviewSize() {
		Parameters params  = cam.getParameters();
		// get screen ratio:
		Display display = listener.getWindowManager().getDefaultDisplay();
		float ratio = (float)display.getHeight()/(float)display.getWidth();
		// available preview sizes:
		List<Size> prev_sizes = params.getSupportedPreviewSizes();
		int best_w = 0;
		int best_h = 0;
		for (Size s : prev_sizes) {
			int w = s.width;
			int h = s.height;
			float r = (float)w/(float)h;
			if (((r-ratio)*(r-ratio))/(ratio*ratio) < 0.01 && w > best_w) {
				best_w = w;
				best_h = h;
			}
		}
		// nothing found with good ratio? take biggest.
		// should rarely (never?) happen.
		if (best_w == 0) {
			for (Size s : prev_sizes) {
				int w = s.width;
				if (w > best_w) {
					best_w = w;
					best_h = s.height;
				}
			}
		}
		// set the values
		preview_width = best_w;
		preview_height = best_h;
		params.setPreviewSize(preview_width, preview_height);
		// we force the preview format to NV21
		params.setPreviewFormat(ImageFormat.NV21);
		cam.setParameters(params);
		// adapt preview orientation or portrait mode
		cam.setDisplayOrientation(90);
		// pre-allocate buffer of size #pixels x 3/2
		// as NV21 uses #pixels for grayscale and twice
		// #pixels/4 for chroma.
		buffer = new byte[preview_width*preview_height*3/2];
		// notify Listener
		listener.onPreviewSizeFound(preview_width, preview_height);
	}

	//------------------------
	// SurfaceHolder.Callback
	//------------------------
	@Override
	public void surfaceChanged(SurfaceHolder holder, int format, int width, int height) {
		// void implementation
	}

	@Override
	public void surfaceCreated(SurfaceHolder holder) {
		try {
			cam.setPreviewDisplay(holder);
		} catch (IOException e) {
			Log.e(TAG, "ERROR: Could not start preview");
		}
		cam.startPreview();
		focus_manager.start();
	}

	@Override
	public void surfaceDestroyed(SurfaceHolder holder) {
		// void implementation
	}

}
