package com.moodstocks.android;

import android.content.Context;
import android.os.Bundle;
import android.util.AttributeSet;
import android.view.animation.Animation;
import android.view.animation.AnimationUtils;
import android.view.animation.RotateAnimation;
import android.widget.ImageView;
import android.widget.RelativeLayout;
import android.widget.TextView;

public class Overlay extends RelativeLayout implements ScanActivity.Listener, OrientationListener.Callback {
	
	public static final String TAG = "Overlay";
	private int angle = 0;
	private int ori = 0;
	private String ean_info = "";
	private String qr_info = "";
	private String images_info = "";
	private String _result = "";
	private Animation expand;
	
	public Overlay(Context context, AttributeSet attrs) {
		super(context, attrs);
		this.expand = AnimationUtils.loadAnimation(this.getContext(), R.anim.expand);
	}
	
	private void eanInfo(boolean ean8, boolean ean13) {
		TextView tv = (TextView) findViewById(R.id.ean_info);
		String s;
		if (ean8 || ean13) {
			s = "[X] EAN";
		}
		else s = "[ ] EAN";
		if (ean8 || ean13) {
			if (ean8 && ean13) {
				s += " (8,13)";
			}
			else {
				if (ean8) s += " (8)";
				else s += " (13)";
			}
		}
		if (!s.equals(ean_info)) {
			tv.setText(s);
			ean_info = new String(s);
		}
	}
	
	private void qrInfo(boolean qr) {
		TextView tv = (TextView) findViewById(R.id.qrcode_info);
		String s;
		if (qr) {
			s = "[X] QR Codes";
		}
		else {
			s = "[ ] QR Codes";
		}
		if (!s.equals(qr_info)) {
			tv.setText(s);
			qr_info = new String(s);
		}
	}
	
	private void imagesInfo(int count, boolean sync) {
		TextView tv = (TextView) findViewById(R.id.images_info);
		String s = "[X] "+count+" images";
		if (sync) s += " (syncing...)";
		if (!s.equals(images_info)) {
			tv.setText(s);
			images_info = new String(s);
		}
	}
	
	private void displayResult(String result) {
		TextView res = (TextView) findViewById(R.id.result);
		res.setText(result);
		if (result.equals("")) {
			res.clearAnimation();
			_result = "";
		}
		else if (!result.equals(_result)) {
			res.startAnimation(expand);
			_result = new String(result);
		}
	}
	
	private void setTargetVisible(boolean b) {
		ImageView v = (ImageView) findViewById(R.id.target);
		if (b) {
			if (ori == OrientationListener.Orientation.DOWN || 
					ori == OrientationListener.Orientation.UP) {
				v.setImageResource(R.drawable.target);
			}
			else {
				v.setImageResource(R.drawable.target90);				
			}
			angle = 0;
			v.setVisibility(VISIBLE);
		}
		else {
			v.setVisibility(INVISIBLE);
			v.clearAnimation();
		}
	}
	
	private void rotateTarget(int r) {
		ImageView v = (ImageView) findViewById(R.id.target);
		if (v.getVisibility() == VISIBLE) {
			Animation anim = new RotateAnimation(angle, angle+r, Animation.RELATIVE_TO_SELF, 0.5f, Animation.RELATIVE_TO_SELF, 0.5f);
			anim.setDuration(250);
			anim.setFillAfter(true);
			v.startAnimation(anim);
			angle = (360 + angle+r) % 360;
		}
	}
	
	private void allInfoVisible(boolean b) {
		int v = b ? INVISIBLE : VISIBLE;
		((TextView) findViewById(R.id.result)).setVisibility(v);
		v = b ? VISIBLE : INVISIBLE;
		setTargetVisible(b);
		((TextView) findViewById(R.id.info1)).setVisibility(v);
		((TextView) findViewById(R.id.info2)).setVisibility(v);
		((TextView) findViewById(R.id.ean_info)).setVisibility(v);
		((TextView) findViewById(R.id.qrcode_info)).setVisibility(v);
		((TextView) findViewById(R.id.images_info)).setVisibility(v);
	}
	
	
	//-----------------------
	// ScanActivity.Listener
	//-----------------------
	@Override
	public void onStatusUpdate(Bundle status) {
		if (status.getBoolean("ready")) {
			
			// update EAN info
			boolean ean8 = status.getBoolean("decode_ean_8");
			boolean ean13 = status.getBoolean("decode_ean_13");
			eanInfo(ean8, ean13);
			
			// update QR codes info
			qrInfo(status.getBoolean("decode_qrcode"));
			
			// update images info
			imagesInfo(status.getInt("images"), status.getBoolean("syncing"));
			
			// display result
			Bundle result = status.getBundle("result");
			if (result != null) {
				displayResult(result.getString("value"));
				allInfoVisible(false);
			}
			else {
				displayResult("");
				allInfoVisible(true);
			}
			
		}
	}
	
	//------------------------------
	// OrientationListener.Callback
	//------------------------------
	
	@Override
	public void onOrientationChanged(int o) {
		int diff = (4 + o - ori)%4;
		int r;
		switch(diff) {
			case 1: r = -90;
							break;
			case 2: r = 180;
							break;
			case 3: r = 90;
							break;
			default: return;
		}
		rotateTarget(r);
		ori = o;
	}

}
