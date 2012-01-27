package com.moodstocks.android;

import android.app.Activity;
import android.app.AlertDialog;
import android.app.ProgressDialog;
import android.hardware.Camera;
import android.os.Bundle;
import android.util.Log;
import android.view.Menu;
import android.view.MenuInflater;
import android.view.MenuItem;
import android.view.SurfaceView;
import android.widget.TextView;

public class ScanActivity extends Activity implements Scanner.SyncListener, ScanThread.Listener, CameraManager.Listener {
	
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
	private long last_found;
	private ProgressDialog progress;
	private ScanThread thread = null;
	private boolean thread_running = false;
	private Result _result = null;
	private int _losts = 0;
	
	@Override
  public void onCreate(Bundle savedInstanceState) {
    super.onCreate(savedInstanceState);
    setContentView(R.layout.main);
		overlay = (Overlay) findViewById(R.id.overlay);
		OrientationListener.init(this);
		status = new Bundle();
		try {
			scanner = Scanner.get();
			scanner.open(this, "ms.db");
		} catch (MoodstocksError e) {
			logError(e);
			finish();
		}
  }
	
	@Override
	public void onResume() {
		super.onResume();
		OrientationListener.get().enable();
		OrientationListener.get().addCallback(overlay);
		SurfaceView surface = (SurfaceView) findViewById(R.id.preview);
		boolean camera_success = CameraManager.get().start(this, surface);
		if (!camera_success) finish();
		try {
			int nb = scanner.count();
			// get current status
			status.putBoolean("ready", !(nb == 0));
		  status.putBoolean("decode_ean_8", (BarcodeFormats & Barcode.Format.MS_BARCODE_FMT_EAN8) != 0);
		  status.putBoolean("decode_ean_13", (BarcodeFormats & Barcode.Format.MS_BARCODE_FMT_EAN13) != 0);
		  status.putBoolean("decode_qrcode", (BarcodeFormats & Barcode.Format.MS_BARCODE_FMT_QRCODE) != 0);
		  status.putInt("images", nb);
		  status.putBundle("result", null);
		  // notify overlay 
		  overlay.onStatusUpdate(status);
		  // non-blocking sync 
		  scanner.sync(this);
		} catch (MoodstocksError e) {
			logError(e);
		}
		// request first frame if ready.
		// otherwise (initial sync), it will be
		// requested after sync is finished.
		if (status.getBoolean("ready")) {
			CameraManager.get().requestNewFrame();
		}
	}	
	
	@Override
	public void onPause() {
		super.onPause();
		if (thread != null) {
			thread.cancel(true);
		}
		OrientationListener.get().disable();
		CameraManager.get().stop();
	}
	
	@Override
	public void onDestroy() {
		try {
			scanner.close();
		} catch (MoodstocksError e) {
			logError(e);
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
		if (status.getBoolean("ready") && !thread_running) {
			(thread = new ScanThread(this, preview_width, preview_height, BarcodeFormats, _result)).execute(data);
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
	@Override
	public void onResult(Result result) {
		thread = null;
		if (result != null) {
			last_found = System.currentTimeMillis();
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
			// discard result if not not found for 1.5s
			if (last_found > 0 && (System.currentTimeMillis() - last_found) > 1500 /*ms*/) {
				last_found = -1;
				status.putBundle("result", null);
				overlay.onStatusUpdate(status);
			}
		}
		CameraManager.get().requestNewFrame();
		thread_running = false;
	}
	
	//------------------
	// Scanner.Listener
	//------------------
	@Override
	public void onSyncStart() {
		if (!status.getBoolean("ready")) {
			// initial sync
			progress = ProgressDialog.show(this, null, "Syncing...");
			TextView tv = (TextView)progress.findViewById(android.R.id.message);
			tv.setTextSize(20);
			tv.setPadding(10,0,0,0);
		}
		status.putBoolean("syncing", true);
		overlay.onStatusUpdate(status);
	}

	@Override
	public void onSyncComplete() {
		try {
			if (!status.getBoolean("ready")) {
				// end of initial sync
				progress.dismiss();
				CameraManager.get().requestNewFrame();
			}
			status.putBoolean("syncing", false);
			status.putInt("images", scanner.count());
			status.putBoolean("ready", true);
			overlay.onStatusUpdate(status);			
		} catch (MoodstocksError e) {
			logError(e);
		}
	}

	@Override
	public void onSyncFailed(MoodstocksError e) {
		if (!status.getBoolean("ready")) {
			// end of initial sync, failed.
			progress.dismiss();
			CameraManager.get().requestNewFrame();
		}
		status.putBoolean("syncing", false);
		status.putBoolean("ready", true);
		overlay.onStatusUpdate(status);
		AlertDialog.Builder builder = new AlertDialog.Builder(this);
		builder.setTitle("Error!");
		builder.setMessage(e.getMessage());
		builder.setPositiveButton("OK", null);
		builder.create().show();
	}
	
	//------
  // MENU
	//------
	
	@Override
	public boolean onCreateOptionsMenu(Menu menu) {
		MenuInflater inflater = getMenuInflater();
		inflater.inflate(R.menu.menu, menu);
		return true;
	}
	
	@Override
	public boolean onOptionsItemSelected(MenuItem item) {
		if (item.getItemId() == R.id.sync &&
				!status.getBoolean("syncing")) {
			scanner.sync(this);
		}
		return true;
	}

}