package com.example.android;

import com.moodstocks.android.*;

import android.app.Activity;
import android.app.AlertDialog;
import android.content.DialogInterface;
import android.hardware.Camera;
import android.os.Bundle;
import android.view.SurfaceView;
import android.widget.SlidingDrawer;

public class ScanActivity extends Activity implements ScannerSession.ScanListener, CameraManager.Listener {

	//-----------------------------------
	// Interface implemented by overlays
	//-----------------------------------
	public static interface Listener {
		public void onStatusUpdate(Bundle status);
	}

	// Enabled scanning types: configure it according to your needs.
	// Here we allow Image recognition, EAN13 and QRCodes decoding.
	// Feel free to add `EAN8` if you want in addition to decode EAN-8.
	private int ScanOptions = Result.Type.IMAGE | Result.Type.EAN13 | Result.Type.QRCODE;

	public static final String TAG = "Main";

	private int preview_width;
	private int preview_height;
	private Scanner scanner;
	private ScannerSession session;
	private Overlay overlay;
	private Bundle status;
	private Result _result = null;

	@Override
	public void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);
		setContentView(R.layout.main);
	}

	@Override
	public void onResume() {
		super.onResume();
		overlay = (Overlay) findViewById(R.id.overlay);
		overlay.init();
		OrientationListener.init(this);
		status = new Bundle();
		OrientationListener.get().enable();
		OrientationListener.get().setCallback(overlay);
		SurfaceView surface = (SurfaceView) findViewById(R.id.preview);
		boolean camera_success = CameraManager.get().start(this, surface);
		if (!camera_success) finish();
		try {
			scanner = Scanner.get();
			int nb = scanner.count();
			// get current status
			status.putBoolean("decode_ean_8", (ScanOptions & Result.Type.EAN8) != 0);
			status.putBoolean("decode_ean_13", (ScanOptions & Result.Type.EAN13) != 0);
			status.putBoolean("decode_qrcode", (ScanOptions & Result.Type.QRCODE) != 0);
			status.putInt("images", nb);
			status.putBundle("result", null);
			// notify overlay 
			overlay.onStatusUpdate(status);
			// non-blocking sync 
		} catch (MoodstocksError e) {
			e.log();
		}
		session = new ScannerSession(scanner);
		session.setOptions(ScanOptions);
	}	

	@Override
	public void onPause() {
		super.onPause();
		session.scanCancel();
		OrientationListener.get().disable();
		CameraManager.get().stop();
		finish();
	}
	
	@Override
	public void onBackPressed() {
		SlidingDrawer drawer = (SlidingDrawer) findViewById(R.id.drawer);
		if (drawer.isOpened()) {
			drawer.animateClose();
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
		/* this is where the offline search/decoding is launched
		 * using the video frames. 
		 */
		session.scan(this, new Image(data, preview_width, preview_height, preview_width, OrientationListener.get().getOrientation()));
	}

	//---------------------
	// Scanner.ScanListener
	//---------------------

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
			e.log();
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
	
}