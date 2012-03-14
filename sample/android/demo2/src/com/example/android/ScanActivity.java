package com.example.android;

import com.moodstocks.android.*;

import android.app.Activity;
import android.app.AlertDialog;
import android.content.DialogInterface;
import android.hardware.Camera;
import android.os.Bundle;
import android.util.Log;
import android.view.SurfaceView;
import android.view.View;

public class ScanActivity extends Activity implements CameraManager.Listener, View.OnClickListener, Scanner.ApiSearchListener, Scanner.ScanListener {

	//-----------------------------------
	// Interface implemented by overlays
	//-----------------------------------
	public static interface Listener {
		public void onStatusUpdate(Bundle status);
	}

	// Enabled scanning types: configure it according to your needs
	// Here we allow Image recognition, EAN13 and QRCodes decoding.
	// Feel free to add `EAN8` if you want in addition to decode EAN-8.
	private int ScanOptions = Result.Type.IMAGE | Result.Type.EAN13 | Result.Type.QRCODE;

	public static final String TAG = "Main";

	private int preview_width;
	private int preview_height;
	private Scanner scanner;
	private Overlay overlay;
	private Bundle status;
	private boolean search_requested = false;
	private Result _result = null;

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
		scanner.setOptions(ScanOptions);
		findViewById(R.id.snap_button).setOnClickListener(this);
		status.putBoolean("searching", false);
		status.putBundle("result", null);
		overlay.onStatusUpdate(status);
		CameraManager.get().requestNewFrame();
	}

	@Override
	public void onPause() {
		super.onPause();
		scanner.scanCancel();
		scanner.apiSearchCancel();
		OrientationListener.get().disable();
		CameraManager.get().stop();
	}

	@Override
	public void onBackPressed() {
		if (status.getBoolean("searching")) {
			scanner.apiSearchCancel();
			status.putBoolean("searching", false);
			onResult(new Result(Result.Type.NONE, "Search cancelled"));
		}
		else {
			super.onBackPressed();
		}
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
		Image qry = new Image(data, preview_width, preview_height, preview_width, OrientationListener.get().getOrientation());
		if (search_requested) {
			//online search
			search_requested = false;
			scanner.apiSearch(this, qry);
		}
		else if (!status.getBoolean("searching")) {
			// offline search and barcode decoding
			scanner.scan(this, qry);
		}
		else {
			CameraManager.get().requestNewFrame();
		}
	}

	//-----------------
	// Handles results
	//-----------------
	public void onResult(Result result) {
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
				Bundle r = new Bundle();
				r.putInt("type", result.getType());
				r.putString("value", result.getValue());
				status.putBundle("result", r);
				// notify overlay
				overlay.onStatusUpdate(status);
			}
		}
		CameraManager.get().requestNewFrame();
	}

	@Override
	public void onClick(View v) {
		if (v == findViewById(R.id.snap_button) && !status.getBoolean("searching")) {
			search_requested = true;
		}
	}

	//------------------------
	// Scanner.ScanListener
	//------------------------

	@Override
	public void onScanStart() {
		// void implementation
	}

	@Override
	public void onScanComplete(Result result) {
		onResult(result);
	}

	@Override
	public void onScanFailed(MoodstocksError e) {
		/* we catch "invalid use of the library" and
		 * "empty database" errors that are supposed
		 * to be development errors only, and should
		 * not happen at runtime.
		 */
		if (e.getErrorCode() == MoodstocksError.Code.MISUSE) {
			e.log(Log.ERROR);
			CameraManager.get().requestNewFrame();
		}
		else {
			AlertDialog.Builder builder = new AlertDialog.Builder(this);
			builder.setCancelable(false);
			builder.setTitle("An error occurred");
			builder.setMessage(e.getMessage());
			builder.setNeutralButton("Quit", new DialogInterface.OnClickListener() {
				public void onClick(DialogInterface dialog, int id) {
					finish();
				}
			});
			builder.show();
		}
	}

	//---------------------------
	// Scanner.ApiSearchListener
	//---------------------------

	@Override
	public void onApiSearchStart() {
		status.putBoolean("searching", true);
		overlay.onStatusUpdate(status);
		_result = null;
	}

	@Override
	public void onApiSearchComplete(String result) {
		status.putBoolean("searching", false);
		Result r;
		if (result != null) {
			r = new Result(Result.Type.IMAGE, result);
		}
		else {
			r = new Result(Result.Type.NONE, "No match found");
		}
		onResult(r);
	}

	@Override
	public void onApiSearchFailed(MoodstocksError e) {
		AlertDialog.Builder builder = new AlertDialog.Builder(this);
		builder.setMessage(e.getMessage());
		builder.setNeutralButton("OK",null);
		builder.show();
		e.log(Log.DEBUG);
		status.putBoolean("searching", false);
		onResult(new Result(Result.Type.NONE, "Search error"));
	}

}
