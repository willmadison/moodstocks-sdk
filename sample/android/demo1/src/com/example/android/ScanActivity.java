package com.example.android;

import com.moodstocks.android.*;

import android.app.Activity;
import android.app.AlertDialog;
import android.app.ProgressDialog;
import android.content.DialogInterface;
import android.hardware.Camera;
import android.os.Bundle;
import android.util.Log;
import android.view.Menu;
import android.view.MenuInflater;
import android.view.MenuItem;
import android.view.SurfaceView;
import android.widget.TextView;

public class ScanActivity extends Activity implements Scanner.SyncListener, Scanner.ScanListener, CameraManager.Listener {

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
	private long last_found;
	private ProgressDialog progress;
	private Result _result = null;
	private boolean compatible = true;

	@Override
	public void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);
		setContentView(R.layout.main);
		try {
			scanner = Scanner.get();
			scanner.open(this, "ms.db");
		}  catch (UnsupportedDeviceException e) {
			compatible = false;
			AlertDialog.Builder builder = new AlertDialog.Builder(this);
			builder.setCancelable(false);
			builder.setTitle("Unsupported Device!");
			if (e.getMessage().equals(UnsupportedDeviceException.Message.VERSION)) {
				builder.setMessage("Device must run Android Gingerbread or over, sorry...");
			}
			else {
				builder.setMessage("Device not compatible with Moodstocks SDK, sorry...");
			}
			builder.setNeutralButton("Quit", new DialogInterface.OnClickListener() {
				public void onClick(DialogInterface dialog, int id) {
					finish();
				}
			});
			builder.show();
		} catch (MoodstocksError e) {
			if (e.getErrorCode() == MoodstocksError.Code.CREDMISMATCH) {
				// == DO NOT USE IN PRODUCTION: THIS IS A HELP MESSAGE FOR DEVELOPERS
				String errmsg = "there is a problem with your key/secret pair: "+
						"the current pair does NOT match with the one recorded within the on-disk datastore. "+
						"This could happen if:\n"+
						" * you have first build & run the app without replacing the default"+
						" \"ApIkEy\" and \"ApIsEcReT\" pair, and later on replaced with your real key/secret,\n"+
						" * or, you have first made a typo on the key/secret pair, build & run the"+
						" app, and later on fixed the typo and re-deployed.\n"+
						"\n"+
						"To solve your problem:\n"+
						" 1) uninstall the app from your device,\n"+
						" 2) make sure to properly configure your key/secret pair within Scanner.java\n"+
						" 3) re-build & run\n";
				MoodstocksError err = new MoodstocksError(errmsg, MoodstocksError.Code.CREDMISMATCH);
				err.log(Log.ERROR);
				finish();
				// == DO NOT USE IN PRODUCTION: THIS IS A HELP MESSAGE FOR DEVELOPERS
			}
			else {
				e.log(Log.ERROR);
			}
		}
	}

	@Override
	public void onResume() {
		super.onResume();
		if (compatible) {
			overlay = (Overlay) findViewById(R.id.overlay);
			OrientationListener.init(this);
			status = new Bundle();
			OrientationListener.get().enable();
			OrientationListener.get().setCallback(overlay);
			SurfaceView surface = (SurfaceView) findViewById(R.id.preview);
			boolean camera_success = CameraManager.get().start(this, surface);
			if (!camera_success) finish();
			scanner.setOptions(ScanOptions);
			try {
				int nb = scanner.count();
				// get current status
				status.putBoolean("ready", !(nb == 0));
				status.putBoolean("decode_ean_8", (ScanOptions & Result.Type.EAN8) != 0);
				status.putBoolean("decode_ean_13", (ScanOptions & Result.Type.EAN13) != 0);
				status.putBoolean("decode_qrcode", (ScanOptions & Result.Type.QRCODE) != 0);
				status.putInt("images", nb);
				status.putBundle("result", null);
				// notify overlay 
				overlay.onStatusUpdate(status);
				// non-blocking sync 
				scanner.sync(this);
			} catch (MoodstocksError e) {
				e.log(Log.ERROR);
			}
		}
	}	

	@Override
	public void onPause() {
		super.onPause();
		if(compatible) {
			Scanner.get().scanCancel();
			OrientationListener.get().disable();
			CameraManager.get().stop();
		}
	}

	@Override
	public void onDestroy() {
		super.onDestroy();
		try {
			scanner.close();
		} catch (MoodstocksError e) {
			e.log(Log.ERROR);
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
		if (status.getBoolean("ready")) {
			scanner.scan(this, new Image(data, preview_width, preview_height, preview_width, OrientationListener.get().getOrientation()));
		}
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

	//-----------------
	// Handles results
	//-----------------
	public void onResult(Result result) {
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
				Bundle r = new Bundle();
				r.putInt("type", result.getType());
				r.putString("value", result.getValue());
				status.putBundle("result", r);
				// notify overlay 
				overlay.onStatusUpdate(status);
			}
		}
		else {
			// discard result if nothing is found for 1.5s
			if (last_found > 0 && (System.currentTimeMillis() - last_found) > 1500 /*ms*/) {
				_result = null;
				last_found = -1;
				status.putBundle("result", null);
				overlay.onStatusUpdate(status);
			}
		}
		CameraManager.get().requestNewFrame();
	}

	//------------------
	// Scanner.SyncListener
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
			e.log(Log.ERROR);
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
		builder.setTitle("Network Error!");
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