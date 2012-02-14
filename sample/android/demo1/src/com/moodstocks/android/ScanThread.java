package com.moodstocks.android;

import com.moodstocks.android.ScanActivity.MSResultType;

import android.graphics.ImageFormat;
import android.os.AsyncTask;
import android.util.Log;

public class ScanThread extends AsyncTask<byte[], Void, Result> {
	
	//---------------------
	// LISTENER INTERFACE
	//---------------------
	// ScanActivity must implement this interface
	public static interface Listener {
				
		public void onThreadRunning(boolean b);
		public void onResult(Result result);
		
	}
	
	public static final String TAG = "ScanThread";
	
	private Listener listener;
	private int w;
	private int h;
	private int BarcodeFormats;
	private Result _result;
	
	private Scanner scanner;
	
	public ScanThread(Listener l, int w, int h, int formats, Result prev) {
		super();
		this.listener = l;
		this.w = w;
		this.h = h;
		this._result = prev;
		this.BarcodeFormats = formats;
		scanner = Scanner.get();
	}
	
	@Override
	protected void onPreExecute() {
		listener.onThreadRunning(true);
	}
	
	@Override
	protected Result doInBackground(byte[]... params) {
		int ori = OrientationListener.get().getOrientation();
		Image qry = new Image(params[0], w, h, w, ImageFormat.NV21, ori);
		Result result = null;
		try {
			//----------
			// LOCKING
			//----------
			boolean lock = false;
			if (_result != null) {
				int _type = _result.getType();
				String _value = _result.getValue();
				if (_type == MSResultType.MSSCANNER_IMAGE) {
					lock = scanner.match(qry, _value);
				}
				else if (_type == MSResultType.MSSCANNER_QRCODE) {
					Barcode bar = scanner.decode(qry, Barcode.Format.MS_BARCODE_FMT_QRCODE);
					if (bar != null) {
						lock = (bar.getText().equals(_value));
					}
				}
				if (lock) {
					result = _result;
				}
			}
		} catch (MoodstocksError e) {
			Log.d(TAG, "Locking failed:");
			logError(e);
		}
		try {
			//---------------
			// IMAGE SEARCH
			//---------------
			if (result == null) {
				String imageID = scanner.search(qry);
				if (imageID != null) {
					result = new Result(MSResultType.MSSCANNER_IMAGE, imageID);
				}
			}
		} catch (MoodstocksError e) {
			Log.d(TAG, "Image Search failed: ");
			logError(e);
		}
		try {
			//-------------------
			// BARCODE DECODING
			//-------------------
			if (result == null) {
				Barcode bar = scanner.decode(qry, BarcodeFormats);
				if (bar != null) {
					int type = MSResultType.MSSCANNER_NONE;
					switch(bar.getType()) {
						case Barcode.Format.MS_BARCODE_FMT_EAN8:
							type = MSResultType.MSSCANNER_EAN8;
							break;
						case Barcode.Format.MS_BARCODE_FMT_EAN13:
							type = MSResultType.MSSCANNER_EAN13;
						 	break;
						case Barcode.Format.MS_BARCODE_FMT_QRCODE:
							type = MSResultType.MSSCANNER_QRCODE;
						  break;
					}
					result = new Result(type, bar.getText());
				}
			}
		} catch (MoodstocksError e) {
			Log.d(TAG, "Barcode Decoding failed: ");
			logError(e);
		}
		qry.finalize();
		return result;
	}
	
	@Override
	protected void onPostExecute(Result r) {
		listener.onResult(r);
	}
	
	@Override
	protected void onCancelled() {
		listener.onThreadRunning(false);
	}
	
	// log error
	private static void logError(MoodstocksError e) {
		Log.e(TAG, "MS Error #"+e.getErrorCode()+" : "+e.getMessage());
	}
	

}
