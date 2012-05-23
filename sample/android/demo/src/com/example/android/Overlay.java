package com.example.android;

import com.moodstocks.android.*;

import android.content.Context;
import android.os.Bundle;
import android.util.AttributeSet;
import android.view.View;
import android.view.animation.Animation;
import android.view.animation.RotateAnimation;
import android.widget.ImageView;
import android.widget.RelativeLayout;
import android.widget.SlidingDrawer;
import android.widget.TextView;
import android.widget.ScrollView;

public class Overlay extends RelativeLayout 
implements ScanActivity.Listener, OrientationListener.Callback, 
SlidingDrawer.OnDrawerCloseListener, SlidingDrawer.OnDrawerOpenListener {

	public static final String TAG = "Overlay";
	private int angle = 0;
	private int ori = 0;
	private String ean_info = "";
	private String qr_info = "";
	private String images_info = "";
	private SlidingDrawer drawer = null;

	public Overlay(Context context, AttributeSet attrs) {
		super(context, attrs);
	}

	public void init() {
		this.drawer = ((SlidingDrawer) findViewById(R.id.drawer));
		this.drawer.setOnDrawerCloseListener(this);
		this.drawer.setOnDrawerOpenListener(this);
		((ScrollView) findViewById(R.id.scroll)).setSmoothScrollingEnabled(true);
		allInfoVisible(true);
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

	private void imagesInfo(int count) {
		TextView tv = (TextView) findViewById(R.id.images_info);
		String s = "[X] "+count+" images";
		if (!s.equals(images_info)) {
			tv.setText(s);
			images_info = new String(s);
		}
	}

	private void displayResult(String result) {
		TextView res = (TextView) findViewById(R.id.result);
		res.setText(result);
		if (drawer.getVisibility() != View.VISIBLE) {
			drawer.setVisibility(View.VISIBLE);
		}
		if (!drawer.isOpened()) {
			drawer.animateOpen();
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
		int v = b ? VISIBLE : INVISIBLE;
		((TextView) findViewById(R.id.info1)).setVisibility(v);
		((TextView) findViewById(R.id.info2)).setVisibility(v);
		((TextView) findViewById(R.id.ean_info)).setVisibility(v);
		((TextView) findViewById(R.id.qrcode_info)).setVisibility(v);
		((TextView) findViewById(R.id.images_info)).setVisibility(v);
		int id = b ? android.R.drawable.arrow_up_float : android.R.drawable.arrow_down_float;
		((ImageView) findViewById(R.id.handle)).setImageResource(id);
	}


	//-----------------------
	// ScanActivity.Listener
	//-----------------------
	@Override
	public void onStatusUpdate(Bundle status) {

		// update EAN info
		boolean ean8 = status.getBoolean("decode_ean_8");
		boolean ean13 = status.getBoolean("decode_ean_13");
		eanInfo(ean8, ean13);

		// update QR codes info
		qrInfo(status.getBoolean("decode_qrcode"));

		// update images info
		imagesInfo(status.getInt("images"));

		// display result
		Bundle result = status.getBundle("result");
		if (result != null) {
			displayResult(result.getString("value"));
		}
		if (drawer.isOpened()) allInfoVisible(false);
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

	//-------------------------------------
	// SlidingDrawer.OnDrawerListeners
	//-------------------------------------
	@Override
	public void onDrawerClosed() {
		allInfoVisible(true);
	}

	@Override
	public void onDrawerOpened() {
		allInfoVisible(false);
	}

}
