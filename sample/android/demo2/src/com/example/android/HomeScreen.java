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
			e.log(Log.ERROR);
			finish();
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
