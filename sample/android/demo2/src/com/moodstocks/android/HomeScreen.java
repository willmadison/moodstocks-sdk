package com.moodstocks.android;

import android.app.Activity;
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
		} catch (MoodstocksError e) {
			logError(e);
			finish();
		}
	}
	
	@Override
	public void onDestroy() {
		super.onDestroy();
		try {
			Scanner.get().close();
		} catch (MoodstocksError e) {
			logError(e);
		}
	}

	@Override
	public void onClick(View v) {
		if (v == findViewById(R.id.scan_button)) {
			// launch scanner
			startActivity(new Intent(this, ScanActivity.class));
		}
	}
	
	// log errors.
	private static void logError(MoodstocksError e) {
		Log.e(TAG, "MS Error #"+e.getErrorCode()+" : "+e.getMessage());
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
		logError(e);
	}
	
}
