package com.moodstocks.android;

import android.app.Activity;
import android.app.AlertDialog;
import android.graphics.ImageFormat;
import android.hardware.Camera;
import android.os.Bundle;
import android.util.Log;
import android.view.SurfaceView;
import android.view.View;

public class ScanActivity extends Activity implements ScanThread.Listener, CameraManager.Listener, View.OnClickListener, Scanner.SearchListener {

	//-----------------------------------
	// Interface implemented by overlays
	//-----------------------------------
	public static interface Listener {
		public void onStatusUpdate(Bundle status);
	}

	// Enabled barcode formats: configure it according to your needs
	// Here only EAN-13 and QR Code formats are enabled.
	// Feel free to add `MS_BARCODE_FMT_EAN8` if you want in addition to decode EAN-8.
	private int BarcodeFormats = Barcode.Format.MS_BARCODE_FMT_EAN13
														 | Barcode.Format.MS_BARCODE_FMT_QRCODE;

	// Type of a scanning result
	public static final class MSResultType {
		public static final int MSSCANNER_NONE = -1;
		public static final int MSSCANNER_IMAGE = 0;
		public static final int MSSCANNER_EAN8 = 1;
		public static final int MSSCANNER_EAN13 = 2;
		public static final int MSSCANNER_QRCODE = 3;
	}

	public static final String TAG = "Main";

	private int preview_width;
	private int preview_height;
	private Scanner scanner;
	private Overlay overlay;
	private Bundle status;
	private ScanThread thread = null;
	private boolean thread_running = false;
	private boolean search_requested = false;
	private Result _result = null;
	private int _losts = 0;

	@Override
  public void onCreate(Bundle savedInstanceState) {
    super.onCreate(savedInstanceState);
    setContentView(R.layout.main);
		overlay = (Overlay) findViewById(R.id.overlay);
		OrientationListener.init(this);
		status = new Bundle();
		scanner = Scanner.get();
  }

	@Override
	public void onResume() {
		super.onResume();
		OrientationListener.get().enable();
		SurfaceView surface = (SurfaceView) findViewById(R.id.preview);
		boolean camera_success = CameraManager.get().start(this, surface);
		if (!camera_success) finish();
		findViewById(R.id.snap_button).setOnClickListener(this);
		status.putBoolean("searching", false);
	  status.putBundle("result", null);
	  overlay.onStatusUpdate(status);
		CameraManager.get().requestNewFrame();
	}

	@Override
	public void onPause() {
		super.onPause();
		if (thread != null) {
			thread.cancel(true);
		}
		scanner.ApiSearchCancel();
		OrientationListener.get().disable();
		CameraManager.get().stop();
	}

	@Override
	public void onBackPressed() {
		if (status.getBoolean("searching")) {
			scanner.ApiSearchCancel();
			status.putBoolean("searching", false);
			onResult(new Result(MSResultType.MSSCANNER_NONE, "Search cancelled"));
		}
		else {
			super.onBackPressed();
		}
	}

	// log errors.
	private static void logError(MoodstocksError e) {
		Log.e(TAG, "MS Error #"+e.getErrorCode()+" : "+e.getMessage());
	}

	//------------------------
	// CameraManager.Listener
	//------------------------
	@Override
	public void onPreviewSizeFound(int w, int h) {
		this.preview_width = w;
		this.preview_height = h;
	}

	@Override
	public void onPreviewFrame(byte[] data, Camera camera) {
		if (search_requested) {
			//online search
			search_requested = false;
			scanner.apiSearch(this, new Image(data, preview_width, preview_height, preview_width,
																		 		ImageFormat.NV21, OrientationListener.get().getOrientation()));
		}
		else if (!thread_running && !status.getBoolean("searching")) {
			// offline search
			(thread = new ScanThread(this, preview_width, preview_height, BarcodeFormats, _result)).execute(data);
		}
		else {
			CameraManager.get().requestNewFrame();
		}
	}

	//---------------------
	// ScanThread.Listener
	//---------------------
	@Override
	public void onThreadRunning(boolean b) {
		thread_running = b;
	}

	// handles result from ScanThread
	// also used by API Search.
	@Override
	public void onResult(Result result) {
		thread = null;
		if (result != null) {
			// necessary to update status?
			boolean update = false;
			if (_result == null) {
				update = true;
			}
			else if (!_result.equals(result)) {
				update = true;
			}
			// update if required
			if (update) {
				_result = result;
				_losts = 0;
				Bundle r = new Bundle();
				r.putInt("type", result.getType());
				r.putString("value", result.getValue());
				status.putBundle("result", r);
				// notify overlay
				overlay.onStatusUpdate(status);
			}
		}
		else {
			// locking
			if (_result != null) {
				_losts++;
				if (_losts >=2 ) _result = null;
			}
		}
		CameraManager.get().requestNewFrame();
		thread_running = false;
	}

	@Override
	public void onClick(View v) {
		if (v == findViewById(R.id.snap_button) && !status.getBoolean("searching")) {
			search_requested = true;
		}
	}

	//------------------------
	// Scanner.SearchListener
	//------------------------

	@Override
	public void onSearchStart() {
		status.putBoolean("searching", true);
		overlay.onStatusUpdate(status);
		_result = null;
	}

	@Override
	public void onSearchComplete(String result) {
		status.putBoolean("searching", false);
		Result r;
		if (result != null) {
			r = new Result(MSResultType.MSSCANNER_IMAGE, result);
		}
		else {
			r = new Result(MSResultType.MSSCANNER_NONE, "No match found");
		}
		onResult(r);
	}

	@Override
	public void onSearchFailed(MoodstocksError e) {
		AlertDialog.Builder builder = new AlertDialog.Builder(this);
		builder.setMessage(e.getMessage());
		builder.setNeutralButton("OK",null);
		builder.show();
		logError(e);
		status.putBoolean("searching", false);
		onResult(new Result(MSResultType.MSSCANNER_NONE, "Search error"));
	}

}
