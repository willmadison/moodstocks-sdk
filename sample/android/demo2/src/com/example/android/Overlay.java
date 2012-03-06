package com.example.android;

import android.content.Context;
import android.os.Bundle;
import android.util.AttributeSet;
import android.view.View;
import android.view.animation.Animation;
import android.view.animation.AnimationUtils;
import android.widget.RelativeLayout;
import android.widget.TextView;

public class Overlay extends RelativeLayout implements ScanActivity.Listener, Animation.AnimationListener {
	
	public static final String TAG = "Overlay";
	private Animation expand;
	private Animation flash;
	private boolean up = false;
	
	public Overlay(Context context, AttributeSet attrs) {
		super(context, attrs);
		this.expand = AnimationUtils.loadAnimation(this.getContext(), R.anim.expand);
		this.flash = AnimationUtils.loadAnimation(this.getContext(), R.anim.flash);
		this.flash.setAnimationListener(this);
	}
	
	//-----------------------
	// ScanActivity.Listener
	//-----------------------
	@Override
	public void onStatusUpdate(Bundle status) {			
		if (status.getBoolean("searching")) {
			// Update text
			String result = "Searching...";
			TextView v = (TextView) findViewById(R.id.result);
			v.setText(result);
			if (!up) {
				v.setVisibility(VISIBLE);
				v.startAnimation(expand);
				up = true;
			}
			// Flash effect
			View f = findViewById(R.id.flash);
			f.setVisibility(VISIBLE);
			f.startAnimation(flash);
		}
		else {
			// Display result
			Bundle result = status.getBundle("result");
			TextView v = (TextView) findViewById(R.id.result);
			if (result != null) {
				v.setText(result.getString("value"));
				if (!up) {
					v.setVisibility(VISIBLE);
					v.startAnimation(expand);
					up = true;
				}
			}
		}
	}
	
	//-------------------
	// AnimationListener
	//-------------------

	@Override
	public void onAnimationEnd(Animation animation) {
		// stops flash.
		if (animation == this.flash) {
			findViewById(R.id.flash).setVisibility(GONE);
		}
	}

	@Override
	public void onAnimationRepeat(Animation animation) {
		// void implementation
	}

	@Override
	public void onAnimationStart(Animation animation) {
		// void implementation
	}

}
