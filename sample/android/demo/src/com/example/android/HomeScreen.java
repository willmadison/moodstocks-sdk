package com.example.android;

import com.moodstocks.android.*;

import android.app.Activity;
import android.app.AlertDialog;
import android.content.DialogInterface;
import android.content.Intent;
import android.os.Bundle;
import android.view.Menu;
import android.view.MenuInflater;
import android.view.MenuItem;
import android.view.View;

public class HomeScreen extends Activity implements View.OnClickListener, Scanner.SyncListener {

	public static final String TAG = "HomeScreen";
	private boolean compatible = false;
	private Scanner scanner = null;
	private Splash splash = null;

	@Override
	public void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);
		/* First of all, check that the device is compatible, aka runs Android 2.3 or over.
		 * If it's not the case, you **must** not try using the scanner as it will crash.
		 * Here we chose to inform the user with a popup and kill the app. In practice, you
		 * may want to do this verification at application startup and display the button
		 * allowing scanner access if and only if the device is compatible.
		 */
		compatible = Scanner.isCompatible();
		if (compatible) {
			setContentView(R.layout.home);
			findViewById(R.id.scan_button).setOnClickListener(this);
			splash = (Splash) findViewById(R.id.splash);
			try {
				this.scanner = Scanner.get();
				/* open the scanner, necessary to perform any operation using it.
				 * This step also checks at runtime that the device is compatible.
				 * If the device is not compatible, it will throw a RuntimeException
				 * and crash the app.
				 */
				scanner.open(this, "ms.db");
				/* Synchronize the image signatures. In this simple example, we chose a very
				 * minimalistic synchronization policy: we show a splash screen while syncing
				 * in the background each time the application starts, which can be pretty rare
				 * as applications can stay alive in the background for days or weeks.
				 * In a real application context, you will have to place this step carefully
				 * according to your needs.
				 * Please note that you can perform this sync in the background, without displaying
				 * anything to the user. Nevertheless, we highly recommend that you inform the user
				 * at least for the very first synchronization.
				 */
				scanner.sync(this);
			} catch (MoodstocksError e) {
				/* an error occurred while opening the scanner */
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
					err.log();
					finish();
					// == DO NOT USE IN PRODUCTION: THIS WAS A HELP MESSAGE FOR DEVELOPERS
				}
				else {
					e.log();
				}
			}
		}
		else {
			/* device is *not* compatible. In this demo application, we chose
       * to inform the user and exit application. `compatible` flag is here
       * to avoid calling scanner methods that *will* fail and log errors. 
       */
      AlertDialog.Builder builder = new AlertDialog.Builder(this);
      builder.setCancelable(false);
      builder.setTitle("Unsupported device!");
      builder.setMessage("Device must run Android Gingerbread or over, sorry...");
      builder.setNeutralButton("Quit", new DialogInterface.OnClickListener() {
        public void onClick(DialogInterface dialog, int id) {
          finish();
        }
      });
      builder.show();
		}
	}

	@Override
	public void onDestroy() {
		super.onDestroy();
		if (compatible) {
			try {
				/* you must close the scanner before exiting */
				scanner.close();
			} catch (MoodstocksError e) {
				e.log();
			}
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
		splash.show(true);
	}

	@Override
	public void onSyncComplete() {
		splash.show(false);
	}

	@Override
	public void onSyncFailed(MoodstocksError e) {
		/* Sync has failed: we check that the database
		 * contains image signatures. If so, the signatures
		 * may be outdated but the scanner will work, so we
		 * just inform the user that he/she should retry
		 * synchronizing.
		 * If the database is empty, we stop the application
		 * to force the user to try again later, as the problem
		 * probably comes from the network.
		 */
		int count = 0;
		try {
			count = scanner.count();
		}
		catch (MoodstocksError e2) {
			// fail silently: we assume count = 0.
		}
		if (count != 0) {
			AlertDialog.Builder builder = new AlertDialog.Builder(this);
			builder.setTitle("Error!");
			builder.setMessage("Synchronization failed, the application " +
					"content may be outdated. Please check you connectivity and" +
					" try again from the menu!\n ("+e.getMessage()+")");
			builder.setPositiveButton("OK", null);
			builder.create().show();
			splash.show(false);
		}
		else {
			AlertDialog.Builder builder = new AlertDialog.Builder(this);
			builder.setCancelable(false);
			builder.setTitle("Error!");
			builder.setMessage("Initial synchronization failed! The scanner won't" +
					" be able to work. Please check your connectivity and relaunch " +
					"the application.");
			builder.setNeutralButton("Quit", new DialogInterface.OnClickListener() {
				public void onClick(DialogInterface dialog, int id) {
					finish();
				}
			});
			builder.show();
		}
	}

	@Override
	public void onSyncProgress(int total, int current) {
		splash.update(total, current);
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
		if (item.getItemId() == R.id.sync && !scanner.isSyncing()) {
			scanner.sync(this);
		}
		return true;
	}

}
