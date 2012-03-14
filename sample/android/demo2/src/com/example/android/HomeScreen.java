package com.example.android;

import com.moodstocks.android.*;

import android.app.Activity;
import android.app.AlertDialog;
import android.content.DialogInterface;
import android.content.Intent;
import android.os.Bundle;
import android.util.Log;
import android.view.View;

public class HomeScreen extends Activity implements View.OnClickListener, Scanner.SyncListener {

	public static final String TAG = "HomeScreen";

	@Override
	public void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);
		setContentView(R.layout.home);
		findViewById(R.id.scan_button).setOnClickListener(this);
		try {
			Scanner.get().open(this, "ms.db");
			Scanner.get().sync(this);
		} catch (UnsupportedDeviceException e) {
			AlertDialog.Builder builder = new AlertDialog.Builder(this);
			builder.setCancelable(false);
			builder.setTitle("Unsupported device!");
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
	public void onDestroy() {
		super.onDestroy();
		try {
			Scanner.get().close();
		} catch (MoodstocksError e) {
			e.log(Log.ERROR);
		}
	}

	@Override
	public void onClick(View v) {
		if (v == findViewById(R.id.scan_button)) {
			// launch scanner
			startActivity(new Intent(this, ScanActivity.class));
		}
	}

	//----------------------
	// Scanner.SyncListener
	//----------------------

	@Override
	public void onSyncStart() {
		// void implementation
	}

	@Override
	public void onSyncComplete() {
		// void implementation
	}

	@Override
	public void onSyncFailed(MoodstocksError e) {
		e.log(Log.DEBUG);
	}

}
