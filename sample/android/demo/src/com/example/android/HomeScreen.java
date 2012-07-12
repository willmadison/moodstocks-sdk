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
	
	/* SYNC POLICY: this illustrates our recommended best practices concerning
	 * the synchronization process. There are 3 cases to distinguish:
	 * 
	 * 1 - Cold Start: The app has just been launched for the first time 
	 * 		 and the database is currently empty, which implies that the
	 * 		 scanner has never been synced before and will not be able to
	 * 		 work until a first sync completes:
	 * 
	 * 		 a - We show a splash screen including a progress bar that will
	 *				 let the user know that a synchronization is running and 
	 *				 keep him/her posted on the sync progression.
	 *		 b - In case this sync fails (for example because there is no
	 *				 available network), we inform the user that an error occurred
	 *				 and force quit the app as the scanner will not be able to work
	 *				 correctly.
	 *
	 *		 This case is the only one in which we show a progress bar or error
	 *		 popups, to prevent the user from trying to use the scanner as the
	 *		 offline recognition will not be able to work.
	 *
	 * 2 - The app has been killed and is re-launched, which in most cases 
	 * 		 implies that the user has not used the app for quite a long time:
	 * 		 we perform a seamless sync.
	 * 
	 * 3 - The app was still running in the background and comes back to the
	 * 		 the foreground, which in most cases implies that the user has run
	 * 		 the app recently: to avoid useless synchronizations, we perform a 
	 * 		 seamless sync only if the previous one occurred more than one day 
	 * 		 ago.
	 */
	
	/* sync related variables */
	private Splash splash = null;
	private long last_sync = 0;
	private boolean cold_start = true;
	private static final long DAY = 86400000; /* duration of a day in ms */

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
				/* Open the scanner, necessary to perform any operation using it.
				 * This step also checks at runtime that the device is compatible.
				 * If the device is not compatible, it will throw a RuntimeException
				 * and crash the app.
				 */
				scanner.open(this, "ms.db");
				/* Cold start detection */
				if (scanner.count() != 0)
					cold_start = false;
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
	public void onResume() {
		super.onResume();
		if (System.currentTimeMillis() - last_sync > DAY)
			scanner.sync(this);
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
		if (cold_start)
			splash.show(true);
	}

	@Override
	public void onSyncComplete() {
		last_sync = System.currentTimeMillis();
		if (cold_start) {
			splash.show(false);
			cold_start = false;
		}
	}

	@Override
	public void onSyncFailed(MoodstocksError e) {
		e.log();
		if (cold_start) {
			int ecode = e.getErrorCode();
			String s;
			switch(ecode) {
				case MoodstocksError.Code.NOCONN: s = "The Internet connection does not work.";
																					break;
				case MoodstocksError.Code.SLOWCONN: s = "The Internet connection is too slow.";
																						break;
				case MoodstocksError.Code.TIMEOUT: s = "The operation timed out.";
																					 break;
				default: s = "An internal error occurred (code = "+e+").";
								 break;
			}
			AlertDialog.Builder builder = new AlertDialog.Builder(this);
			builder.setCancelable(false);
			builder.setTitle("Oops!");
			builder.setMessage(s+" Please try again later.");
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
		if (cold_start)
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
